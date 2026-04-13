// ABOUTME: Share action button for video feed overlay.
// ABOUTME: Opens unified share sheet with horizontal contacts row, message
// ABOUTME: input, and more actions (save, copy, share via, report, etc.).

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/blocs/share_sheet/share_sheet_bloc.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/services/image_cache_manager.dart';
import 'package:openvine/services/video_sharing_service.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/utils/watermark_text_resolver.dart';
import 'package:openvine/widgets/add_to_list_dialog.dart';
import 'package:openvine/widgets/find_people_sheet.dart';
import 'package:openvine/widgets/report_content_dialog.dart';
import 'package:openvine/widgets/save_original_progress_sheet.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/user_name.dart';
import 'package:openvine/widgets/video_feed_item/actions/actions.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';
import 'package:openvine/widgets/watermark_download_progress_sheet.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:share_plus/share_plus.dart';
import 'package:unified_logger/unified_logger.dart';

part 'share_sheet_header.dart';
part 'share_sheet_message_input.dart';
part 'share_sheet_more_actions.dart';
part 'share_with_section.dart';

/// Share action button for video overlay.
///
/// Shows a share icon that opens a unified share bottom sheet with:
/// - Video context/preview header
/// - "Share with" horizontal contact row with "Find people" search
/// - Optional message input when a recipient is selected
/// - "More actions" horizontal row (Save, download, Add to List, Copy,
///   Share via, Report, debug tools)
class ShareActionButton extends StatelessWidget {
  const ShareActionButton({required this.video, super.key});

  final VideoEvent video;

  /// Opens the unified share sheet for the given [video].
  ///
  /// This is exposed as a static method so share entry points can reuse the
  /// same bottom-sheet wiring without duplicating setup logic.
  static void showShareSheet(BuildContext context, VideoEvent video) {
    // Read here so the sheet receives a guaranteed non-null repository.
    // If Nostr client hasn't initialized yet, skip opening the sheet.
    final container = ProviderScope.containerOf(context);
    final profileRepository = container.read(profileRepositoryProvider);
    if (profileRepository == null) return;

    context.showVideoPausingVineBottomSheet<void>(
      builder: (context) => _UnifiedShareSheet(
        video: video,
        profileRepository: profileRepository,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return VideoActionButton(
      icon: .shareFatDuo,
      semanticIdentifier: 'share_button',
      semanticLabel: context.l10n.shareVideoLabel,
      onPressed: () {
        Log.info(
          'Share button tapped for ${video.id}',
          name: 'ShareActionButton',
          category: LogCategory.ui,
        );
        ShareActionButton.showShareSheet(context, video);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Unified Share Sheet (Page — creates BLoC, handles side effects)
// ---------------------------------------------------------------------------

class _UnifiedShareSheet extends ConsumerStatefulWidget {
  const _UnifiedShareSheet({
    required this.video,
    required this.profileRepository,
  });

  final VideoEvent video;
  final ProfileRepository profileRepository;

  @override
  ConsumerState<_UnifiedShareSheet> createState() => _UnifiedShareSheetState();
}

class _UnifiedShareSheetState extends ConsumerState<_UnifiedShareSheet> {
  final TextEditingController _messageController = TextEditingController();
  late final ShareSheetBloc _shareSheetBloc;

  @override
  void initState() {
    super.initState();
    _shareSheetBloc = ShareSheetBloc(
      video: widget.video,
      relayUrl: ref.read(currentEnvironmentProvider).relayUrl,
      videoSharingService: ref.read(videoSharingServiceProvider),
      profileRepository: widget.profileRepository,
      followRepository: ref.read(followRepositoryProvider),
      bookmarkServiceFuture: ref.read(bookmarkServiceProvider.future),
      cacheManager: openVineImageCache,
    )..add(const ShareSheetContactsLoadRequested());
  }

  @override
  void dispose() {
    _shareSheetBloc.close();
    _messageController.dispose();
    super.dispose();
  }

  void _safePop(BuildContext ctx) {
    try {
      if (ctx.canPop()) {
        ctx.pop();
        return;
      }
    } catch (_) {
      // GoRouter context extensions throw when the router is not in the
      // widget tree (e.g., inside modal bottom sheets). Fall through to
      // the standard Navigator as a safe fallback.
    }
    Navigator.of(ctx).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final isOwnContent = _isUserOwnContent();

    return BlocProvider.value(
      value: _shareSheetBloc,
      child: BlocListener<ShareSheetBloc, ShareSheetState>(
        listenWhen: (prev, curr) =>
            curr.actionResult != null && prev.actionResult != curr.actionResult,
        listener: _handleActionResult,
        child: _UnifiedShareSheetView(
          video: widget.video,
          messageController: _messageController,
          isOwnContent: isOwnContent,
          onFindPeople: _handleFindPeople,
          onAddToList: _handleAddToList,
          onReport: _handleReport,
          onSaveOriginal: isOwnContent ? _handleSaveOriginal : null,
          onSaveWithWatermark: _handleSaveWithWatermark,
        ),
      ),
    );
  }

  void _handleActionResult(BuildContext context, ShareSheetState state) {
    final result = state.actionResult;
    if (result == null) return;

    final messenger = ScaffoldMessenger.of(context);

    switch (result) {
      case ShareSheetSendSuccess(:final recipientName, :final shouldDismiss):
        if (shouldDismiss) _safePop(context);
        messenger.showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.sharePostSharedWith(recipientName),
          ),
        );
      case ShareSheetSendFailure():
        messenger.showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.shareFailedToSend,
            error: true,
          ),
        );
      case ShareSheetSaveResult(:final succeeded):
        _safePop(context);
        messenger.showSnackBar(
          DivineSnackbarContainer.snackBar(
            succeeded
                ? context.l10n.shareAddedToBookmarks
                : context.l10n.shareFailedToAddBookmark,
            error: !succeeded,
          ),
        );
      case ShareSheetCopiedToClipboard(:final label, :final text):
        Clipboard.setData(ClipboardData(text: text));
        _safePop(context);
        messenger.showSnackBar(DivineSnackbarContainer.snackBar(label));
      case ShareSheetShareViaTriggered(
        :final shareUrl,
        :final thumbnailPath,
        :final title,
        :final subject,
      ):
        final files = thumbnailPath != null ? [XFile(thumbnailPath)] : null;
        SharePlus.instance.share(
          ShareParams(
            text: shareUrl,
            files: files,
            title: title,
            subject: subject,
          ),
        );
      case ShareSheetActionFailure():
        messenger.showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.shareActionFailed,
            error: true,
          ),
        );
    }
  }

  Future<void> _handleFindPeople() async {
    final selectedUser = await FindPeopleSheet.show(
      context,
      contacts: _shareSheetBloc.state.contacts,
    );
    if (selectedUser != null && mounted) {
      _shareSheetBloc.add(ShareSheetRecipientSelected(selectedUser));
    }
  }

  void _handleAddToList() {
    _presentAfterDismiss<void>((hostContext) {
      return showDialog<void>(
        context: hostContext,
        builder: (context) => SelectListDialog(video: widget.video),
      );
    });
  }

  void _handleReport() {
    _presentAfterDismiss<void>((hostContext) {
      return showDialog<void>(
        context: hostContext,
        builder: (context) => ReportContentDialog(video: widget.video),
      );
    });
  }

  bool _isUserOwnContent() {
    try {
      final authService = ref.read(authServiceProvider);
      if (!authService.isAuthenticated) return false;

      final userPubkey = authService.currentPublicKeyHex;
      if (userPubkey == null) return false;

      return widget.video.pubkey == userPubkey;
    } catch (e) {
      Log.error(
        'Error checking content ownership: $e',
        name: 'ShareActionButton',
        category: LogCategory.ui,
      );
      return false;
    }
  }

  Future<void> _handleSaveOriginal() async {
    await _presentAfterDismiss<void>((hostContext) {
      return showSaveOriginalSheet(
        context: hostContext,
        ref: ref,
        video: widget.video,
      );
    });
  }

  Future<void> _handleSaveWithWatermark() async {
    final profileRepo = ref.read(profileRepositoryProvider);
    final profile = await profileRepo?.getCachedProfile(
      pubkey: widget.video.pubkey,
    );
    final watermarkText = resolveWatermarkText(
      profile: profile,
      fallbackAuthorName: widget.video.authorName,
    );

    await _presentAfterDismiss<void>((hostContext) {
      return showWatermarkDownloadSheet(
        context: hostContext,
        ref: ref,
        video: widget.video,
        watermarkText: watermarkText,
      );
    });
  }

  Future<T?> _presentAfterDismiss<T>(
    Future<T?> Function(BuildContext hostContext) presenter,
  ) async {
    final hostContext = Navigator.of(context, rootNavigator: true).context;
    _safePop(context);
    await Future<void>.delayed(Duration.zero);
    if (!mounted || !hostContext.mounted) return null;
    return presenter(hostContext);
  }
}

// ---------------------------------------------------------------------------
// Unified Share Sheet View (pure UI — reads BLoC state)
// ---------------------------------------------------------------------------

class _UnifiedShareSheetView extends StatelessWidget {
  const _UnifiedShareSheetView({
    required this.video,
    required this.messageController,
    required this.isOwnContent,
    required this.onFindPeople,
    required this.onAddToList,
    required this.onReport,
    required this.onSaveWithWatermark,
    this.onSaveOriginal,
  });

  final VideoEvent video;
  final TextEditingController messageController;
  final bool isOwnContent;
  final VoidCallback onFindPeople;
  final VoidCallback onAddToList;
  final VoidCallback onReport;
  final Future<void> Function()? onSaveOriginal;
  final Future<void> Function() onSaveWithWatermark;

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context).clamp(
      maxScaleFactor: 1.5,
    );
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: Material(
        color: VineTheme.surfaceBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: SafeArea(
          child: SingleChildScrollView(
            child: BlocBuilder<ShareSheetBloc, ShareSheetState>(
              builder: (context, state) {
                final bloc = context.read<ShareSheetBloc>();

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _DragIndicator(),
                    _ShareSheetHeader(video: video),
                    const Divider(color: VineTheme.cardBackground, height: 1),
                    _ShareWithSection(
                      contacts: state.contacts,
                      contactsLoaded: state.contactsLoaded,
                      selectedRecipient: state.selectedRecipient,
                      sentPubkeys: state.sentPubkeys,
                      onFindPeople: onFindPeople,
                      onContactTapped: (user) =>
                          bloc.add(ShareSheetQuickSendRequested(user)),
                    ),
                    if (state.selectedRecipient != null)
                      _MessageInput(
                        controller: messageController,
                        recipient: state.selectedRecipient!,
                        isSending: state.isSending,
                        onSend: () => bloc.add(
                          ShareSheetSendRequested(
                            message: messageController.text,
                          ),
                        ),
                      ),
                    if (state.selectedRecipient == null) ...[
                      const Divider(color: VineTheme.cardBackground, height: 1),
                      _MoreActionsSection(
                        video: video,
                        isOwnContent: isOwnContent,
                        onSave: () => bloc.add(const ShareSheetSaveRequested()),
                        onSaveOriginal: onSaveOriginal,
                        onSaveWithWatermark: onSaveWithWatermark,
                        onAddToList: onAddToList,
                        onCopyLink: () =>
                            bloc.add(const ShareSheetCopyLinkRequested()),
                        onShareVia: () =>
                            bloc.add(const ShareSheetShareViaRequested()),
                        onReport: onReport,
                        onCopyEventJson: () =>
                            bloc.add(const ShareSheetCopyEventJsonRequested()),
                        onCopyEventId: () =>
                            bloc.add(const ShareSheetCopyEventIdRequested()),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
