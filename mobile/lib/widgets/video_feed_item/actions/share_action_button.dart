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
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/services/video_sharing_service.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/utils/watermark_text_resolver.dart';
import 'package:openvine/widgets/add_to_list_dialog.dart';
import 'package:openvine/widgets/find_people_sheet.dart';
import 'package:openvine/widgets/report_content_dialog.dart';
import 'package:openvine/widgets/save_original_progress_sheet.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/user_name.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';
import 'package:openvine/widgets/watermark_download_progress_sheet.dart';
import 'package:share_plus/share_plus.dart';

part 'share_sheet_header.dart';
part 'share_with_section.dart';
part 'share_sheet_message_input.dart';
part 'share_sheet_more_actions.dart';

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
    context.showVideoPausingVineBottomSheet<void>(
      builder: (context) => _UnifiedShareSheet(video: video),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          identifier: 'share_button',
          container: true,
          explicitChildNodes: true,
          button: true,
          label: 'Share video',
          child: IconButton(
            padding: const EdgeInsets.all(8),
            constraints: const BoxConstraints.tightFor(width: 48, height: 48),
            style: IconButton.styleFrom(
              highlightColor: Colors.transparent,
              splashFactory: NoSplash.splashFactory,
            ),
            onPressed: () {
              Log.info(
                'Share button tapped for ${video.id}',
                name: 'ShareActionButton',
                category: LogCategory.ui,
              );
              ShareActionButton.showShareSheet(context, video);
            },
            icon: DecoratedBox(
              decoration: BoxDecoration(
                boxShadow: [
                  BoxShadow(
                    color: VineTheme.backgroundColor.withValues(alpha: 0.15),
                    blurRadius: 15,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: const DivineIcon(
                icon: DivineIconName.shareFat,
                size: 32,
                color: VineTheme.whiteText,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Unified Share Sheet (Page — creates BLoC, handles side effects)
// ---------------------------------------------------------------------------

class _UnifiedShareSheet extends ConsumerStatefulWidget {
  const _UnifiedShareSheet({required this.video});

  final VideoEvent video;

  @override
  ConsumerState<_UnifiedShareSheet> createState() => _UnifiedShareSheetState();
}

class _UnifiedShareSheetState extends ConsumerState<_UnifiedShareSheet> {
  final TextEditingController _messageController = TextEditingController();
  late final ShareSheetBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = ShareSheetBloc(
      video: widget.video,
      relayUrl: ref.read(currentEnvironmentProvider).relayUrl,
      videoSharingService: ref.read(videoSharingServiceProvider),
      userProfileService: ref.read(userProfileServiceProvider),
      followRepository: ref.read(followRepositoryProvider),
      bookmarkServiceFuture: ref.read(bookmarkServiceProvider.future),
    )..add(const ShareSheetContactsLoadRequested());
  }

  @override
  void dispose() {
    _messageController.dispose();
    _bloc.close();
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
      value: _bloc,
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
          DivineSnackbarContainer.snackBar('Post shared with $recipientName'),
        );
      case ShareSheetSendFailure():
        messenger.showSnackBar(
          DivineSnackbarContainer.snackBar('Failed to send video', error: true),
        );
      case ShareSheetSaveResult(:final succeeded):
        _safePop(context);
        messenger.showSnackBar(
          DivineSnackbarContainer.snackBar(
            succeeded ? 'Added to bookmarks' : 'Failed to add bookmark',
            error: !succeeded,
          ),
        );
      case ShareSheetCopiedToClipboard(:final label, :final text):
        Clipboard.setData(ClipboardData(text: text));
        _safePop(context);
        messenger.showSnackBar(DivineSnackbarContainer.snackBar(label));
      case ShareSheetShareViaTriggered(:final shareText):
        SharePlus.instance.share(ShareParams(text: shareText));
      case ShareSheetActionFailure():
        messenger.showSnackBar(
          DivineSnackbarContainer.snackBar('Action failed', error: true),
        );
    }
  }

  Future<void> _handleFindPeople() async {
    final selectedUser = await FindPeopleSheet.show(
      context,
      contacts: _bloc.state.contacts,
    );
    if (selectedUser != null && mounted) {
      _bloc.add(ShareSheetRecipientSelected(selectedUser));
    }
  }

  void _handleAddToList() {
    _safePop(context);

    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => SelectListDialog(video: widget.video),
    );
  }

  void _handleReport() {
    _safePop(context);
    showDialog<void>(
      context: context,
      builder: (context) => ReportContentDialog(video: widget.video),
    );
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
    _safePop(context);
    if (!context.mounted) return;

    await showSaveOriginalSheet(
      context: context,
      ref: ref,
      video: widget.video,
    );
  }

  Future<void> _handleSaveWithWatermark() async {
    _safePop(context);

    final profileService = ref.read(userProfileServiceProvider);
    final profile = profileService.getCachedProfile(widget.video.pubkey);
    final watermarkText = resolveWatermarkText(
      profile: profile,
      fallbackAuthorName: widget.video.authorName,
    );

    if (!context.mounted) return;

    await showWatermarkDownloadSheet(
      context: context,
      ref: ref,
      video: widget.video,
      watermarkText: watermarkText,
    );
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
    return Material(
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
    );
  }
}
