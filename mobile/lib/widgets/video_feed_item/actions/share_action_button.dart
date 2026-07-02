// ABOUTME: Share action button for video feed overlay.
// ABOUTME: Opens unified share sheet: tap a contact to select it (never an
// ABOUTME: instant send), compose an optional message, send explicitly.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/blocs/owner_video_actions/owner_video_actions_cubit.dart';
import 'package:openvine/blocs/share_sheet/share_sheet_bloc.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/providers/video_clip_import_provider.dart';
import 'package:openvine/screens/inbox/conversation/conversation_page.dart';
import 'package:openvine/screens/video_metadata/video_metadata_edit_screen.dart';
import 'package:openvine/services/video_clip_import_service.dart';
import 'package:openvine/services/video_sharing_service.dart';
import 'package:openvine/utils/delete_failure_localization.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/utils/watermark_text_resolver.dart';
import 'package:openvine/widgets/add_to_list_dialog.dart';
import 'package:openvine/widgets/find_people_sheet.dart';
import 'package:openvine/widgets/owner_video_delete_confirmation_dialog.dart';
import 'package:openvine/widgets/profile/profile_saved_videos_sync_scope.dart';
import 'package:openvine/widgets/save_original_progress_sheet.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/user_name.dart';
import 'package:openvine/widgets/video_feed_item/actions/actions.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:openvine/widgets/watermark_download_progress_sheet.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:share_plus/share_plus.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:unified_logger/unified_logger.dart';

part 'share_sheet_header.dart';
part 'share_sheet_message_input.dart';
part 'share_sheet_more_actions.dart';
part 'share_with_section.dart';

/// Share action button for video overlay.
///
/// Shows a share icon that opens a unified share bottom sheet with:
/// - Video context/preview header
/// - "Share with" horizontal contact row with "Find people" search.
///   Tapping contacts toggles their selection (tick on the avatar) —
///   nothing is sent until the explicit send button, which fans the
///   video out to every selected person as separate DMs.
/// - Message composer shown while any recipient is selected (replaces
///   the actions row)
/// - "More actions" horizontal row (Save, download, Add to List, Copy,
///   Share via, debug tools)
class ShareActionButton extends StatelessWidget {
  const ShareActionButton({required this.video, this.onInteracted, super.key});

  final VideoEvent video;
  final VoidCallback? onInteracted;

  /// Opens the unified share sheet for the given [video].
  ///
  /// This is exposed as a static method so share entry points can reuse the
  /// same bottom-sheet wiring without duplicating setup logic.
  static void showShareSheet(BuildContext context, VideoEvent video) {
    // Read here so the sheet receives guaranteed non-null sharing dependencies.
    // If Nostr client hasn't initialized yet, skip opening the sheet.
    final container = ProviderScope.containerOf(context);
    final profileRepository = container.read(profileRepositoryProvider);
    final videoSharingService = container.read(videoSharingServiceProvider);
    if (profileRepository == null || videoSharingService == null) return;

    final inheritedLookupContext = context;

    context.showVideoPausingVineBottomSheet<void>(
      builder: (sheetContext) => _UnifiedShareSheet(
        video: video,
        profileRepository: profileRepository,
        videoSharingService: videoSharingService,
        inheritedLookupContext: inheritedLookupContext,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return VideoActionButton(
      icon: .shareFatDuo,
      semanticIdentifier: 'share_button',
      semanticLabel: context.l10n.shareVideoLabel,
      labelWhenZero: context.l10n.videoActionShareLabel,
      onPressed: () {
        onInteracted?.call();
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
    required this.videoSharingService,
    required this.inheritedLookupContext,
  });

  final VideoEvent video;
  final ProfileRepository profileRepository;
  final VideoSharingService videoSharingService;

  /// Context from the widget that opened the sheet (not the modal builder).
  /// Used to reach [ProfileSavedVideosBloc] under the profile grid, which a
  /// modal route context may not inherit.
  final BuildContext inheritedLookupContext;

  @override
  ConsumerState<_UnifiedShareSheet> createState() => _UnifiedShareSheetState();
}

class _UnifiedShareSheetState extends ConsumerState<_UnifiedShareSheet> {
  final TextEditingController _messageController = TextEditingController();
  late final ShareSheetBloc _shareSheetBloc;
  OwnerVideoActionsCubit? _ownerVideoActionsCubit;

  @override
  void initState() {
    super.initState();
    _shareSheetBloc = ShareSheetBloc(
      video: widget.video,
      relayUrl: ref.read(currentEnvironmentProvider).relayUrl,
      videoSharingService: widget.videoSharingService,
      profileRepository: widget.profileRepository,
      followRepository: ref.read(followRepositoryProvider),
      bookmarkServiceFuture: ref.read(bookmarkServiceProvider.future),
      cacheManager: openVineImageCache,
      videoClipImportService: ref.read(
        videoClipImportServiceProvider,
      ),
    )..add(const ShareSheetContactsLoadRequested());
  }

  @override
  void dispose() {
    _ownerVideoActionsCubit?.close();
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
    final canAddVideoToClips =
        (widget.video.isOriginalVine || isOwnContent) && !kIsWeb;

    return BlocProvider.value(
      value: _shareSheetBloc,
      child: MultiBlocListener(
        listeners: [
          BlocListener<ShareSheetBloc, ShareSheetState>(
            listenWhen: (prev, curr) =>
                curr.actionResult != null &&
                prev.actionResult != curr.actionResult,
            listener: _handleActionResult,
          ),
          // Screen readers get no signal from the tick/composer swap when a
          // recipient is added — announce it.
          BlocListener<ShareSheetBloc, ShareSheetState>(
            listenWhen: (prev, curr) =>
                curr.selectedRecipients.length > prev.selectedRecipients.length,
            listener: (context, state) {
              SemanticsService.sendAnnouncement(
                View.of(context),
                context.l10n.shareSelectedRecipientAnnouncement(
                  state.selectedRecipients.last.displayName ??
                      context.l10n.shareUserFallback,
                ),
                Directionality.of(context),
              );
            },
          ),
        ],
        child: _UnifiedShareSheetView(
          video: widget.video,
          messageController: _messageController,
          isOwnContent: isOwnContent,
          onFindPeople: _handleFindPeople,
          onAddToList: _handleAddToList,
          onEditVideo: isOwnContent ? _handleEditVideo : null,
          onDeleteVideo: isOwnContent ? _handleDeleteVideo : null,
          onSaveOriginal: isOwnContent ? _handleSaveOriginal : null,
          onSaveWithWatermark: _handleSaveWithWatermark,
          onAddVideoToClips: canAddVideoToClips ? _handleAddVideoToClips : null,
        ),
      ),
    );
  }

  void _handleActionResult(BuildContext context, ShareSheetState state) {
    final result = state.actionResult;
    if (result == null) return;

    final messenger = ScaffoldMessenger.of(context);

    switch (result) {
      case ShareSheetSendSuccess(
        :final recipientNames,
        :final recipientPubkey,
        :final conversationId,
      ):
        final sharedWithText = recipientNames.length == 1
            ? context.l10n.sharePostSharedWith(recipientNames.single)
            : context.l10n.sharePostSharedWithCount(recipientNames.length);
        final viewChatLabel = context.l10n.dmReelReplyViewChat;
        // "View chat" only when there is a single thread to open.
        final showViewChat = conversationId != null && recipientPubkey != null;
        // The snackbar action outlives the sheet, so capture a context that
        // survives the pop for the conversation push.
        final hostContext = Navigator.of(context, rootNavigator: true).context;
        _safePop(context);
        messenger.showSnackBar(
          DivineSnackbarContainer.snackBar(
            sharedWithText,
            actionLabel: showViewChat ? viewChatLabel : null,
            onActionPressed: showViewChat
                ? () {
                    if (!hostContext.mounted) return;
                    hostContext.push(
                      ConversationPage.pathForId(conversationId),
                      extra: [recipientPubkey],
                    );
                  }
                : null,
          ),
        );
      case ShareSheetSendFailure():
        // Dismiss too: the send is durably queued and retried in the
        // background, so there is no in-sheet manual retry to keep open for.
        _safePop(context);
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            DivineSnackbarContainer.snackBar(
              context.l10n.shareFailedToSend,
              error: true,
            ),
          );
      case ShareSheetSaveResult(
        :final succeeded,
        :final removed,
        :final wasBookmarkedBeforeToggle,
      ):
        final snackText = succeeded
            ? (removed
                  ? context.l10n.shareRemovedFromBookmarks
                  : context.l10n.shareAddedToBookmarks)
            : (wasBookmarkedBeforeToggle
                  ? context.l10n.shareFailedToRemoveBookmark
                  : context.l10n.shareFailedToAddBookmark);
        _safePop(context);
        messenger.showSnackBar(
          DivineSnackbarContainer.snackBar(
            snackText,
            error: !succeeded,
          ),
        );
        if (succeeded) {
          requestProfileSavedVideosSyncIfAvailable(
            widget.inheritedLookupContext,
          );
        }
      case ShareSheetVideoClipImportResult(
        :final succeeded,
        :final libraryTitle,
      ):
        final snackText = succeeded
            ? context.l10n.shareSheetSavedClipToClips(
                libraryTitle ?? context.l10n.shareSheetUntitledClip,
              )
            : context.l10n.shareSheetAddToClipsFailed;
        _safePop(context);
        messenger.showSnackBar(
          DivineSnackbarContainer.snackBar(
            snackText,
            error: !succeeded,
          ),
        );
      case ShareSheetCopiedToClipboard(:final kind, :final text):
        final snackText = switch (kind) {
          ShareSheetCopiedKind.postLink => context.l10n.shareCopiedPostLink,
          ShareSheetCopiedKind.eventJson => context.l10n.shareCopiedEventJson,
          ShareSheetCopiedKind.eventId => context.l10n.shareCopiedEventId,
        };
        Clipboard.setData(ClipboardData(text: text));
        _safePop(context);
        messenger.showSnackBar(
          DivineSnackbarContainer.snackBar(snackText),
        );
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

  Future<void> _handleAddVideoToClips() async {
    final initialTitle = VideoClipImportService.defaultLibraryTitleFor(
      widget.video,
    );
    final libraryTitle = await _ClipTitleSheet.show(
      context: context,
      initialTitle: initialTitle,
    );
    if (!mounted || libraryTitle == null) return;

    _shareSheetBloc.add(
      ShareSheetAddVideoToClipsRequested(libraryTitle: libraryTitle),
    );
  }

  Future<void> _handleFindPeople() async {
    final selectedUser = await FindPeopleSheet.show(
      context,
      contacts: _shareSheetBloc.state.contacts,
    );
    if (selectedUser != null && mounted) {
      _shareSheetBloc.add(ShareSheetRecipientToggled(selectedUser));
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

  void _handleEditVideo() {
    _presentAfterDismiss<void>((hostContext) async {
      hostContext.push(
        VideoMetadataEditScreen.pathFor(widget.video.id),
        extra: widget.video,
      );
    });
  }

  Future<void> _handleDeleteVideo() async {
    final confirmed = await showOwnerVideoDeleteConfirmationDialog(context);
    if (confirmed && mounted) {
      await _deleteVideo();
    }
  }

  Future<void> _deleteVideo() async {
    final ownerVideoActionsCubit = _ownerVideoActionsCubit ??=
        OwnerVideoActionsCubit(
          contentDeletionServiceFuture: ref.read(
            contentDeletionServiceProvider.future,
          ),
          videoEventService: ref.read(videoEventServiceProvider),
        );
    await ownerVideoActionsCubit.deleteVideo(widget.video);

    if (!mounted) return;

    final state = ownerVideoActionsCubit.state;
    if (state.deleteStatus == OwnerVideoDeleteStatus.success) {
      final messenger = ScaffoldMessenger.of(context);
      final snackBar = DivineSnackbarContainer.snackBar(
        context.l10n.shareMenuVideoDeletionRequested,
      );
      _safePop(context);
      messenger.showSnackBar(snackBar);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(
          state.deleteResult == null
              ? context.l10n.shareMenuDeleteFailedGeneric
              : localizedDeleteFailureMessage(context, state.deleteResult!),
          error: true,
        ),
      );
    }
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

class _ClipTitleSheet extends StatefulWidget {
  const _ClipTitleSheet({required this.initialTitle});

  final String initialTitle;

  static Future<String?> show({
    required BuildContext context,
    required String initialTitle,
  }) {
    return VineBottomSheet.show<String>(
      context: context,
      showHeaderDivider: false,
      body: _ClipTitleSheet(initialTitle: initialTitle),
    );
  }

  @override
  State<_ClipTitleSheet> createState() => _ClipTitleSheetState();
}

class _ClipTitleSheetState extends State<_ClipTitleSheet> {
  late final TextEditingController _controller;

  bool get _canSave => _controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle)
      ..addListener(_onTitleChanged);
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onTitleChanged)
      ..dispose();
    super.dispose();
  }

  void _onTitleChanged() => setState(() {});

  void _save() {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    Navigator.of(context).pop(title);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            20,
            16,
            16 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                context.l10n.shareSheetNameClipTitle,
                textAlign: TextAlign.center,
                style: VineTheme.headlineSmallFont(),
              ),
              const SizedBox(height: 8),
              Text(
                context.l10n.shareSheetNameClipSubtitle,
                textAlign: TextAlign.center,
                style: VineTheme.bodyLargeFont(
                  color: VineTheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              DivineTextField(
                controller: _controller,
                labelText: context.l10n.shareSheetClipTitleLabel,
                maxLength: 80,
                maxLines: 1,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.singleLineFormatter,
                ],
                onSubmitted: (_) => _save(),
                primaryWhenFilled: true,
              ),
              const SizedBox(height: 24),
              DivineButton(
                label: context.l10n.shareSheetSaveClip,
                onPressed: _canSave ? _save : null,
                expanded: true,
              ),
              const SizedBox(height: 12),
              DivineButton(
                label: context.l10n.commonCancel,
                type: DivineButtonType.secondary,
                onPressed: () => Navigator.of(context).pop(),
                expanded: true,
              ),
            ],
          ),
        ),
      ),
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
    required this.onSaveWithWatermark,
    this.onAddVideoToClips,
    this.onEditVideo,
    this.onDeleteVideo,
    this.onSaveOriginal,
  });

  final VideoEvent video;
  final TextEditingController messageController;
  final bool isOwnContent;
  final VoidCallback onFindPeople;
  final VoidCallback onAddToList;
  final VoidCallback? onEditVideo;
  final Future<void> Function()? onDeleteVideo;
  final Future<void> Function()? onSaveOriginal;
  final Future<void> Function() onSaveWithWatermark;
  final VoidCallback? onAddVideoToClips;

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: 1.5);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: Material(
        color: VineTheme.surfaceBackground,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        child: SafeArea(
          child: SingleChildScrollView(
            // Lift the content above the keyboard so the message TextField
            // stays visible when a recipient is selected. Without this the
            // sheet is anchored at the screen bottom and the field hides
            // behind the keyboard. Mirrors _ClipTitleSheet below.
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
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
                      selectedPubkeys: {
                        for (final r in state.selectedRecipients) r.pubkey,
                      },
                      onFindPeople: onFindPeople,
                      // Select-then-send, multi-select: each tap toggles a
                      // recipient's tick. Nothing sends until the explicit
                      // send button. The draft survives selection changes
                      // and is dropped only when the last recipient is
                      // deselected.
                      onContactTapped: (user) {
                        final deselectingLast =
                            state.selectedRecipients.length == 1 &&
                            state.isSelected(user);
                        if (deselectingLast) messageController.clear();
                        bloc.add(ShareSheetRecipientToggled(user));
                      },
                    ),
                    if (state.selectedRecipients.isNotEmpty)
                      _MessageInput(
                        controller: messageController,
                        isSending: state.isSending,
                        onSend: () => bloc.add(
                          ShareSheetSendRequested(
                            message: messageController.text,
                          ),
                        ),
                      ),
                    if (state.selectedRecipients.isEmpty) ...[
                      const Divider(color: VineTheme.cardBackground, height: 1),
                      _MoreActionsSection(
                        video: video,
                        isOwnContent: isOwnContent,
                        onSave: () => bloc.add(const ShareSheetSaveRequested()),
                        onSaveOriginal: onSaveOriginal,
                        onSaveWithWatermark: onSaveWithWatermark,
                        onAddVideoToClips: onAddVideoToClips,
                        onEditVideo: onEditVideo,
                        onDeleteVideo: onDeleteVideo,
                        onAddToList: onAddToList,
                        onCopyLink: () =>
                            bloc.add(const ShareSheetCopyLinkRequested()),
                        onShareVia: () =>
                            bloc.add(const ShareSheetShareViaRequested()),
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
