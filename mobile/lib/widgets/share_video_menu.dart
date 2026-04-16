// ABOUTME: Share menu for videos with list management, bookmarks, and social sharing
// ABOUTME: Provides NIP-51 list management, bookmark sets, follow sets, and sharing features

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory, NIP71VideoKinds;
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/localized_content_label_name.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/sound_detail_screen.dart';
import 'package:openvine/services/bookmark_service.dart';
import 'package:openvine/services/content_deletion_service.dart';
import 'package:openvine/services/content_moderation_service.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/utils/delete_failure_localization.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/watermark_text_resolver.dart';
import 'package:openvine/widgets/add_to_list_dialog.dart';
import 'package:openvine/widgets/report_content_dialog.dart';
import 'package:openvine/widgets/save_original_progress_sheet.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/user_picker_sheet.dart';
import 'package:openvine/widgets/watermark_download_progress_sheet.dart';
import 'package:share_plus/share_plus.dart';
import 'package:unified_logger/unified_logger.dart';

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(12),
      child: Center(
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: VineTheme.secondaryText,
          ),
        ),
      ),
    );
  }
}

/// Comprehensive share menu for videos
class ShareVideoMenu extends ConsumerStatefulWidget {
  const ShareVideoMenu({required this.video, super.key, this.onDismiss});
  final VideoEvent video;
  final VoidCallback? onDismiss;

  @override
  ConsumerState<ShareVideoMenu> createState() => _ShareVideoMenuState();
}

class _ShareVideoMenuState extends ConsumerState<ShareVideoMenu> {
  /// Safely pop the context, handling cases where there's nothing to pop
  void _safePop(BuildContext ctx) {
    if (ctx.canPop()) {
      ctx.pop();
    } else {
      // If we can't pop via go_router, try Navigator.maybePop as fallback
      Navigator.of(ctx).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) => Material(
    color: VineTheme.backgroundColor,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
    child: SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          _buildHeader(),

          // Share options
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  _buildVideoStatusSection(),
                  if (!_isUserOwnContent() &&
                      !widget.video.isOriginalContent) ...[
                    const SizedBox(height: 16),
                    _buildQuickAIReportButton(),
                  ],
                  const SizedBox(height: 24),
                  _buildShareSection(),
                  // NOTE: Subtitle generation temporarily disabled due to Android build issues
                  // See: https://github.com/divinevideo/divine-mobile/issues/1568
                  // if (_isUserOwnContent()) ...[
                  //   const SizedBox(height: 24),
                  //   _buildSubtitleSection(),
                  // ],
                  const SizedBox(height: 24),
                  _buildListSection(),
                  const SizedBox(height: 24),
                  _buildBookmarkSection(),
                  const SizedBox(height: 24),
                  _buildFollowSetSection(),
                  if (_isUserOwnContent()) ...[
                    const SizedBox(height: 24),
                    _buildDeleteSection(),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );

  Widget _buildHeader() => Container(
    padding: const EdgeInsets.all(16),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: VineTheme.cardBackground)),
    ),
    child: Row(
      children: [
        const Icon(Icons.share, color: VineTheme.whiteText),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.shareMenuTitle,
                style: const TextStyle(
                  color: VineTheme.whiteText,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (widget.video.title != null)
                Text(
                  widget.video.title ?? '',
                  style: const TextStyle(
                    color: VineTheme.secondaryText,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => _safePop(context),
          icon: const Icon(Icons.close, color: VineTheme.secondaryText),
        ),
      ],
    ),
  );

  /// Build quick AI report button for one-tap reporting
  Widget _buildQuickAIReportButton() => Container(
    decoration: BoxDecoration(
      color: VineTheme.warning.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: VineTheme.warning.withValues(alpha: 0.3)),
    ),
    child: ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: VineTheme.warning.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.psychology_alt,
          color: VineTheme.warning,
          size: 20,
        ),
      ),
      title: Text(
        context.l10n.shareMenuReportAiContent,
        style: const TextStyle(
          color: VineTheme.whiteText,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        context.l10n.shareMenuReportAiContentSubtitle,
        style: const TextStyle(color: VineTheme.secondaryText, fontSize: 12),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        color: VineTheme.warning,
        size: 16,
      ),
      onTap: _quickReportAI,
    ),
  );

  /// Quick report for AI-generated content (kind 1984 event)
  Future<void> _quickReportAI() async {
    try {
      // Show loading snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: VineTheme.whiteText,
                  ),
                ),
                const SizedBox(width: 12),
                Text(context.l10n.shareMenuReportingAiContent),
              ],
            ),
            backgroundColor: VineTheme.warning,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      final reportService = await ref.read(
        contentReportingServiceProvider.future,
      );
      final result = await reportService.reportContent(
        eventId: widget.video.id,
        authorPubkey: widget.video.pubkey,
        reason: ContentFilterReason.other,
        details: 'Suspected AI-generated content',
      );

      if (mounted) {
        _safePop(context); // Close share menu

        if (result.success) {
          // Show success confirmation dialog using root navigator
          showDialog(
            context: context,
            builder: (context) => const ReportConfirmationDialog(),
          );
        } else {
          // Show error snackbar
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: VineTheme.whiteText),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.l10n.shareMenuFailedToReportContent(
                        result.error ?? '',
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: VineTheme.error,
            ),
          );
        }
      }
    } catch (e) {
      Log.error(
        'Failed to submit AI report: $e',
        name: 'ShareVideoMenu',
        category: LogCategory.ui,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.shareMenuFailedToReportAiContent('$e'),
            ),
            backgroundColor: VineTheme.error,
          ),
        );
      }
    }
  }

  /// Build video status section showing what lists the video is in
  Widget _buildVideoStatusSection() => Consumer(
    builder: (context, ref, child) {
      final curatedListServiceAsync = ref.watch(curatedListsStateProvider);
      final curatedListService = ref
          .read(curatedListsStateProvider.notifier)
          .service;
      final bookmarkServiceAsync = ref.watch(bookmarkServiceProvider);

      return curatedListServiceAsync.when(
        data: (lists) {
          return bookmarkServiceAsync.when(
            data: (bookmarkService) {
              final listsContaining =
                  curatedListService?.getListsContainingVideo(
                    widget.video.id,
                  ) ??
                  [];
              final bookmarkStatus = bookmarkService.getVideoBookmarkSummary(
                widget.video.id,
              );

              final statusParts = <String>[];

              // Add curated lists status
              if (listsContaining.isNotEmpty) {
                if (listsContaining.length == 1) {
                  statusParts.add('In "${listsContaining.first.name}"');
                } else if (listsContaining.length <= 3) {
                  final names = listsContaining
                      .map((list) => '"${list.name}"')
                      .join(', ');
                  statusParts.add('In $names');
                } else {
                  statusParts.add('In ${listsContaining.length} lists');
                }
              }

              // Add bookmark status
              if (bookmarkStatus != 'Not bookmarked') {
                statusParts.add(bookmarkStatus);
              }

              if (statusParts.isEmpty) {
                return const SizedBox.shrink(); // Hide if no status to show
              }

              return Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: VineTheme.cardBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: VineTheme.cardBackground),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: VineTheme.vineGreen,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          context.l10n.shareMenuVideoStatus,
                          style: const TextStyle(
                            color: VineTheme.whiteText,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...statusParts.map(
                      (status) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            const SizedBox(width: 26), // Align with icon
                            Expanded(
                              child: Text(
                                '• $status',
                                style: const TextStyle(
                                  color: VineTheme.lightText,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (listsContaining.length > 3) ...[
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () => _showAllListsDialog(listsContaining),
                        child: Padding(
                          padding: const EdgeInsetsDirectional.only(start: 26),
                          child: Text(
                            context.l10n.shareMenuViewAllLists,
                            style: const TextStyle(
                              color: VineTheme.vineGreen,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
            loading: () => const _LoadingIndicator(),
            error: (_, _) => const SizedBox.shrink(),
          );
        },
        loading: () => const _LoadingIndicator(),
        error: (_, _) => const SizedBox.shrink(),
      );
    },
  );

  Widget _buildShareSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        context.l10n.shareMenuShareWith,
        style: const TextStyle(
          color: VineTheme.whiteText,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 12),

      // External share (native share sheet includes copy option)
      _buildActionTile(
        icon: Icons.share,
        title: context.l10n.shareMenuShareViaOtherApps,
        subtitle: context.l10n.shareMenuShareViaOtherAppsSubtitle,
        onTap: _shareExternally,
      ),

      const SizedBox(height: 8),

      // Save original video (no watermark) — own content only
      if (_isUserOwnContent()) ...[
        _buildActionTile(
          icon: Icons.save_alt,
          title: context.l10n.shareMenuSaveToGallery,
          subtitle: context.l10n.shareMenuSaveOriginalSubtitle,
          onTap: () => _saveOriginal(context),
        ),
        const SizedBox(height: 8),
      ],

      // Save video with watermark
      _buildActionTile(
        icon: Icons.download,
        title: _isUserOwnContent()
            ? context.l10n.shareMenuSaveWithWatermark
            : context.l10n.shareMenuSaveVideo,
        subtitle: _isUserOwnContent()
            ? context.l10n.shareMenuDownloadWithWatermark
            : context.l10n.shareMenuSaveVideoSubtitle,
        onTap: () => _saveWithWatermark(context),
      ),

      // Use this sound option (only if video has audio reference)
      if (widget.video.hasAudioReference) ...[
        const SizedBox(height: 8),
        _UseThisSoundTile(
          video: widget.video,
          onDismiss: () => _safePop(context),
        ),
      ],
    ],
  );

  Widget _buildListSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        context.l10n.shareMenuLists,
        style: const TextStyle(
          color: VineTheme.whiteText,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 12),

      // Dynamic part: show which lists contain this video (loaded async)
      Consumer(
        builder: (context, ref, child) {
          final listServiceAsync = ref.watch(curatedListsStateProvider);
          final listService = ref
              .read(curatedListsStateProvider.notifier)
              .service;

          return listServiceAsync.when(
            data: (lists) {
              final listsContainingVideo =
                  listService?.getListsContainingVideo(widget.video.id) ?? [];

              if (listsContainingVideo.isEmpty) {
                return const SizedBox.shrink();
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: VineTheme.vineGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: VineTheme.vineGreen.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.playlist_add_check,
                            color: VineTheme.vineGreen,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'In ${listsContainingVideo.length} list${listsContainingVideo.length == 1 ? '' : 's'}',
                            style: const TextStyle(
                              color: VineTheme.vineGreen,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...listsContainingVideo.map(
                        (list) => Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: InkWell(
                            onTap: () => _removeFromList(list.id),
                            borderRadius: BorderRadius.circular(4),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 4,
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.folder,
                                    color: VineTheme.secondaryText,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      list.name,
                                      style: const TextStyle(
                                        color: VineTheme.whiteText,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.remove_circle_outline,
                                    color: VineTheme.secondaryText,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
            loading: () => const _LoadingIndicator(),
            error: (_, _) => const SizedBox.shrink(),
          );
        },
      ),

      // Static buttons - always visible immediately
      _buildActionTile(
        icon: Icons.playlist_add,
        title: context.l10n.shareMenuAddToList,
        subtitle: context.l10n.shareMenuAddToListSubtitle,
        onTap: _showSelectListDialog,
      ),

      const SizedBox(height: 8),

      _buildActionTile(
        icon: Icons.create_new_folder,
        title: context.l10n.shareMenuCreateNewList,
        subtitle: context.l10n.shareMenuCreateNewListSubtitle,
        onTap: _showCreateListDialog,
      ),
    ],
  );

  /// Remove video from a specific list
  Future<void> _removeFromList(String listId) async {
    try {
      final listService = ref.read(curatedListsStateProvider.notifier).service;
      await listService?.removeVideoFromList(listId, widget.video.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.shareMenuRemovedFromList),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      Log.error(
        'Failed to remove from list: $e',
        name: 'ShareVideoMenu',
        category: LogCategory.ui,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.shareMenuFailedToRemoveFromList),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Build bookmark section for quick bookmarking
  Widget _buildBookmarkSection() => Consumer(
    builder: (context, ref, child) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.shareMenuBookmarks,
            style: const TextStyle(
              color: VineTheme.whiteText,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          // Add to global bookmarks
          _buildActionTile(
            icon: Icons.bookmark_outline,
            title: context.l10n.shareMenuAddToBookmarks,
            subtitle: context.l10n.shareMenuAddToBookmarksSubtitle,
            onTap: _addToGlobalBookmarks,
          ),

          const SizedBox(height: 8),

          // Add to bookmark set
          _buildActionTile(
            icon: Icons.bookmark_add,
            title: context.l10n.shareMenuAddToBookmarkSet,
            subtitle: context.l10n.shareMenuAddToBookmarkSetSubtitle,
            onTap: _showBookmarkSetsDialog,
          ),
        ],
      );
    },
  );

  /// Build follow set section for adding authors to follow sets
  Widget _buildFollowSetSection() => Consumer(
    builder: (context, ref, child) {
      final socialService = ref.watch(socialServiceProvider);
      final followSets = socialService.followSets;

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.shareMenuFollowSets,
            style: const TextStyle(
              color: VineTheme.whiteText,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),

          // Create new follow set with this author
          _buildActionTile(
            icon: Icons.group_add,
            title: context.l10n.shareMenuCreateFollowSet,
            subtitle: context.l10n.shareMenuCreateFollowSetSubtitle,
            onTap: _showCreateFollowSetDialog,
          ),

          // Show existing follow sets if any
          if (followSets.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildActionTile(
              icon: Icons.people,
              title: context.l10n.shareMenuAddToFollowSet,
              subtitle: context.l10n.shareMenuFollowSetsAvailable(
                followSets.length,
              ),
              onTap: _showSelectFollowSetDialog,
            ),
          ],
        ],
      );
    },
  );

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    Color? iconColor,
  }) => ListTile(
    leading: Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: VineTheme.cardBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: iconColor ?? VineTheme.whiteText, size: 20),
    ),
    title: Text(
      title,
      style: const TextStyle(
        color: VineTheme.whiteText,
        fontWeight: FontWeight.w500,
      ),
    ),
    subtitle: Text(
      subtitle,
      style: const TextStyle(color: VineTheme.secondaryText, fontSize: 12),
    ),
    onTap: onTap,
    enabled: onTap != null,
    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
  );

  // === BOOKMARK ACTIONS ===

  Future<void> _addToGlobalBookmarks() async {
    try {
      final bookmarkService = await ref.read(bookmarkServiceProvider.future);
      final success = await bookmarkService.addVideoToGlobalBookmarks(
        widget.video.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? context.l10n.shareMenuAddedToBookmarks
                  : context.l10n.shareMenuFailedToAddBookmark,
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        _safePop(context);
      }
    } catch (e) {
      Log.error(
        'Failed to add bookmark: $e',
        name: 'ShareVideoMenu',
        category: LogCategory.ui,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.shareMenuFailedToAddBookmark),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _showBookmarkSetsDialog() {
    showDialog(
      context: context,
      builder: (context) => _SelectBookmarkSetDialog(video: widget.video),
    );
  }

  // === FOLLOW SET ACTIONS ===

  void _showCreateFollowSetDialog() {
    showDialog(
      context: context,
      builder: (context) =>
          _CreateFollowSetDialog(authorPubkey: widget.video.pubkey),
    );
  }

  void _showSelectFollowSetDialog() {
    showDialog(
      context: context,
      builder: (context) =>
          _SelectFollowSetDialog(authorPubkey: widget.video.pubkey),
    );
  }

  Future<void> _shareExternally() async {
    try {
      final sharingService = ref.read(videoSharingServiceProvider);
      final shareText = sharingService.generateShareText(widget.video);

      await SharePlus.instance.share(ShareParams(text: shareText));
    } catch (e) {
      Log.error(
        'Failed to share externally: $e',
        name: 'ShareVideoMenu',
        category: LogCategory.ui,
      );
    }
  }

  /// Save video with Divine watermark overlay
  Future<void> _saveOriginal(BuildContext ctx) async {
    // Close the share menu first
    _safePop(ctx);

    if (!ctx.mounted) return;

    await showSaveOriginalSheet(context: ctx, ref: ref, video: widget.video);
  }

  Future<void> _saveWithWatermark(BuildContext ctx) async {
    // Close the share menu first
    _safePop(ctx);

    // Resolve the creator's displayed NIP-05 or fallback handle.
    final profile = ref
        .read(userProfileReactiveProvider(widget.video.pubkey))
        .value;
    final watermarkText = resolveWatermarkText(
      profile: profile,
      fallbackAuthorName: widget.video.authorName,
    );

    if (!ctx.mounted) return;

    await showWatermarkDownloadSheet(
      context: ctx,
      ref: ref,
      video: widget.video,
      watermarkText: watermarkText,
    );
  }

  Future<void> _showCreateListDialog() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => CreateListDialog(video: widget.video),
    );

    // If list was created successfully, handle closing share menu and showing snackbar
    if (result != null && mounted) {
      _safePop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.shareMenuCreatedListAndAddedVideo(result),
          ),
        ),
      );
    }
  }

  void _showSelectListDialog() {
    showDialog(
      context: context,
      builder: (context) => SelectListDialog(video: widget.video),
    );
  }

  /// Check if this is the user's own content
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
        name: 'ShareVideoMenu',
        category: LogCategory.ui,
      );
      return false;
    }
  }

  /// Build delete section for user's own content
  Widget _buildDeleteSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        context.l10n.shareMenuManageContent,
        style: const TextStyle(
          color: VineTheme.whiteText,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 12),

      // Edit content option
      _buildActionTile(
        icon: Icons.edit,
        iconColor: VineTheme.vineGreen,
        title: context.l10n.shareMenuEditVideo,
        subtitle: context.l10n.shareMenuEditVideoSubtitle,
        onTap: _showEditDialog,
      ),

      const SizedBox(height: 8),

      // Delete content option
      _buildActionTile(
        icon: Icons.delete_outline,
        iconColor: VineTheme.error,
        title: context.l10n.shareMenuDeleteVideo,
        subtitle: context.l10n.shareMenuDeleteVideoSubtitle,
        onTap: _showDeleteDialog,
      ),
    ],
  );

  /// Show edit dialog
  void _showEditDialog() {
    showDialog(
      context: context,
      builder: (context) => _EditVideoDialog(video: widget.video),
    );
  }

  /// Show delete confirmation dialog
  void _showDeleteDialog() {
    showDialog(context: context, builder: _buildDeleteDialog);
  }

  void _showAllListsDialog(List<CuratedList> lists) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VineTheme.backgroundColor,
        title: Text(
          context.l10n.shareMenuVideoInTheseLists,
          style: const TextStyle(color: VineTheme.whiteText),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: lists.length,
            itemBuilder: (context, index) {
              final list = lists[index];
              return ListTile(
                leading: Icon(
                  list.isPublic ? Icons.public : Icons.lock,
                  color: VineTheme.vineGreen,
                  size: 20,
                ),
                title: Text(
                  list.name,
                  style: const TextStyle(color: VineTheme.whiteText),
                ),
                subtitle: list.description != null
                    ? Text(
                        list.description!,
                        style: const TextStyle(color: VineTheme.lightText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
                trailing: Text(
                  context.l10n.shareMenuVideoCount(
                    list.videoEventIds.length,
                  ),
                  style: const TextStyle(
                    color: VineTheme.lightText,
                    fontSize: 12,
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: context.pop,
            child: Text(
              context.l10n.shareMenuClose,
              style: const TextStyle(color: VineTheme.vineGreen),
            ),
          ),
        ],
      ),
    );
  }

  /// Build delete confirmation dialog
  Widget _buildDeleteDialog(BuildContext dialogContext) => AlertDialog(
    backgroundColor: VineTheme.cardBackground,
    title: Text(
      dialogContext.l10n.shareMenuDeleteVideo,
      style: const TextStyle(color: VineTheme.whiteText),
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          dialogContext.l10n.shareMenuDeleteConfirmation,
          style: const TextStyle(color: VineTheme.whiteText),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => dialogContext.pop(),
        child: Text(dialogContext.l10n.shareMenuCancel),
      ),
      TextButton(
        onPressed: () {
          dialogContext.pop();
          _deleteContent();
        },
        style: TextButton.styleFrom(foregroundColor: VineTheme.error),
        child: Text(dialogContext.l10n.shareMenuDelete),
      ),
    ],
  );

  /// Deletes the user's own video via [contentDeletionServiceProvider].
  Future<void> _deleteContent() async {
    // Capture the router before any navigation happens
    // This allows us to navigate after the bottom sheet is dismissed
    final router = GoRouter.of(context);

    try {
      final deletionService = await ref.read(
        contentDeletionServiceProvider.future,
      );

      // Show loading snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: VineTheme.whiteText,
                  ),
                ),
                const SizedBox(width: 12),
                Text(context.l10n.shareMenuDeletingContent),
              ],
            ),
            backgroundColor: VineTheme.warning,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      final result = await deletionService.quickDelete(
        video: widget.video,
        reason: DeleteReason.personalChoice,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  result.success ? Icons.check_circle : Icons.error,
                  color: VineTheme.whiteText,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    result.success
                        ? context.l10n.shareMenuDeleteRequestSent
                        : localizedDeleteFailureMessage(context, result),
                  ),
                ),
              ],
            ),
            backgroundColor: result.success
                ? VineTheme.vineGreen
                : VineTheme.error,
          ),
        );

        // Remove video from all local feeds after successful deletion
        if (result.success) {
          final videoEventService = ref.read(videoEventServiceProvider);
          videoEventService.removeVideoCompletely(widget.video.id);
          Log.info(
            'Video removed from all local feeds after deletion: ${widget.video.id}',
            name: 'ShareVideoMenu',
            category: LogCategory.ui,
          );

          // Close the share menu (bottom sheet) first
          if (widget.onDismiss != null) {
            widget.onDismiss!();
          } else if (mounted) {
            // Fallback: close the bottom sheet via Navigator
            _safePop(context);
          }

          // Navigate back to previous screen (profile or feed)
          // Use the captured router since context may be invalid after bottom sheet closes
          if (router.canPop()) {
            router.pop();
          }
        }
      }
    } catch (e) {
      Log.error(
        'Failed to delete content: $e',
        name: 'ShareVideoMenu',
        category: LogCategory.ui,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.shareMenuDeleteFailedGeneric,
            ),
            backgroundColor: VineTheme.error,
          ),
        );
      }
    }
  }
}

/// Dialog for creating new follow set with this video's author
class _CreateFollowSetDialog extends ConsumerStatefulWidget {
  const _CreateFollowSetDialog({required this.authorPubkey});
  final String authorPubkey;

  @override
  ConsumerState<_CreateFollowSetDialog> createState() =>
      _CreateFollowSetDialogState();
}

class _CreateFollowSetDialogState
    extends ConsumerState<_CreateFollowSetDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: VineTheme.cardBackground,
    title: Text(
      context.l10n.shareMenuCreateFollowSet,
      style: const TextStyle(color: VineTheme.whiteText),
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _nameController,
          enableInteractiveSelection: true,
          style: const TextStyle(color: VineTheme.whiteText),
          decoration: InputDecoration(
            labelText: context.l10n.shareMenuFollowSetName,
            labelStyle: const TextStyle(color: VineTheme.secondaryText),
            hintText: context.l10n.shareMenuFollowSetNameHint,
            hintStyle: const TextStyle(color: VineTheme.secondaryText),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _descriptionController,
          enableInteractiveSelection: true,
          style: const TextStyle(color: VineTheme.whiteText),
          decoration: InputDecoration(
            labelText: context.l10n.shareMenuDescriptionOptional,
            labelStyle: const TextStyle(color: VineTheme.secondaryText),
          ),
          maxLines: 2,
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: context.pop,
        child: Text(context.l10n.shareMenuCancel),
      ),
      TextButton(
        onPressed: _createFollowSet,
        child: Text(context.l10n.shareMenuCreate),
      ),
    ],
  );

  Future<void> _createFollowSet() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    try {
      final socialService = ref.read(socialServiceProvider);
      final newSet = await socialService.createFollowSet(
        name: name,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        initialPubkeys: [widget.authorPubkey],
      );

      if (newSet != null && mounted) {
        context.pop(); // Close dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.shareMenuCreatedFollowSetAndAddedCreator(name),
            ),
          ),
        );
      }
    } catch (e) {
      Log.error(
        'Failed to create follow set: $e',
        name: 'ShareVideoMenu',
        category: LogCategory.ui,
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

/// Dialog for selecting existing follow set to add author to
class _SelectFollowSetDialog extends StatelessWidget {
  const _SelectFollowSetDialog({required this.authorPubkey});
  final String authorPubkey;

  @override
  Widget build(BuildContext context) => Consumer(
    builder: (context, ref, child) {
      final socialService = ref.watch(socialServiceProvider);
      final followSets = socialService.followSets;

      return AlertDialog(
        backgroundColor: VineTheme.cardBackground,
        title: Text(
          context.l10n.shareMenuAddToFollowSet,
          style: const TextStyle(color: VineTheme.whiteText),
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: ListView.builder(
            itemCount: followSets.length,
            itemBuilder: (context, index) {
              final set = followSets[index];
              final isInSet = socialService.isInFollowSet(set.id, authorPubkey);

              return ListTile(
                leading: Icon(
                  isInSet ? Icons.check_circle : Icons.people,
                  color: isInSet ? VineTheme.vineGreen : VineTheme.whiteText,
                ),
                title: Text(
                  set.name,
                  style: const TextStyle(color: VineTheme.whiteText),
                ),
                subtitle: Text(
                  '${set.pubkeys.length} users${set.description != null ? ' • ${set.description}' : ''}',
                  style: const TextStyle(color: VineTheme.secondaryText),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => _toggleAuthorInFollowSet(
                  context,
                  socialService,
                  set,
                  isInSet,
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: context.pop,
            child: Text(context.l10n.shareMenuDone),
          ),
        ],
      );
    },
  );

  Future<void> _toggleAuthorInFollowSet(
    BuildContext context,
    SocialService socialService,
    FollowSet set,
    bool isCurrentlyInSet,
  ) async {
    try {
      bool success;
      if (isCurrentlyInSet) {
        success = await socialService.removeFromFollowSet(set.id, authorPubkey);
      } else {
        success = await socialService.addToFollowSet(set.id, authorPubkey);
      }

      if (success && context.mounted) {
        final message = isCurrentlyInSet
            ? 'Removed from ${set.name}'
            : 'Added to ${set.name}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      Log.error(
        'Failed to toggle user in follow set: $e',
        name: 'ShareVideoMenu',
        category: LogCategory.ui,
      );
    }
  }
}

/// Dialog for editing video metadata
class _EditVideoDialog extends ConsumerStatefulWidget {
  const _EditVideoDialog({required this.video});
  final VideoEvent video;

  @override
  ConsumerState<_EditVideoDialog> createState() => _EditVideoDialogState();
}

class _EditVideoDialogState extends ConsumerState<_EditVideoDialog> {
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _hashtagsController;
  late List<String> _collaboratorPubkeys;
  Set<ContentLabel> _contentWarningLabels = {};
  InspiredByInfo? _inspiredByVideo;
  String? _inspiredByNpub;
  bool _isUpdating = false;
  bool _isDeleting = false;

  static const _maxCollaborators = 5;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.video.title ?? '');

    // Strip existing NIP-27 inspired-by line from content for editing
    var content = widget.video.content;
    final npubPattern = RegExp(r'\n\nInspired by nostr:npub1[a-z0-9]+$');
    content = content.replaceFirst(npubPattern, '');
    _descriptionController = TextEditingController(text: content);

    // Convert hashtags list to comma-separated string
    final hashtagsText = widget.video.hashtags.join(', ');
    _hashtagsController = TextEditingController(text: hashtagsText);

    // Initialize collaborators and inspired-by from existing video
    _collaboratorPubkeys = List<String>.from(widget.video.collaboratorPubkeys);
    _contentWarningLabels = widget.video.contentWarningLabels
        .map(ContentLabel.fromValue)
        .whereType<ContentLabel>()
        .toSet();
    _inspiredByVideo = widget.video.inspiredByVideo;
    _inspiredByNpub = widget.video.inspiredByNpub;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: VineTheme.cardBackground,
    title: Text(
      context.l10n.shareMenuEditVideo,
      style: const TextStyle(color: VineTheme.whiteText),
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            enabled: !_isUpdating,
            enableInteractiveSelection: true,
            style: const TextStyle(color: VineTheme.whiteText),
            decoration: InputDecoration(
              labelText: context.l10n.shareMenuEditTitle,
              labelStyle: const TextStyle(color: VineTheme.secondaryText),
              hintText: context.l10n.shareMenuEditTitleHint,
              hintStyle: const TextStyle(color: VineTheme.secondaryText),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            enabled: !_isUpdating,
            enableInteractiveSelection: true,
            style: const TextStyle(color: VineTheme.whiteText),
            decoration: InputDecoration(
              labelText: context.l10n.shareMenuEditDescription,
              labelStyle: const TextStyle(color: VineTheme.secondaryText),
              hintText: context.l10n.shareMenuEditDescriptionHint,
              hintStyle: const TextStyle(color: VineTheme.secondaryText),
            ),
            maxLines: 3,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _hashtagsController,
            enabled: !_isUpdating,
            enableInteractiveSelection: true,
            style: const TextStyle(color: VineTheme.whiteText),
            decoration: InputDecoration(
              labelText: context.l10n.shareMenuEditHashtags,
              labelStyle: const TextStyle(color: VineTheme.secondaryText),
              hintText: context.l10n.shareMenuEditHashtagsHint,
              hintStyle: const TextStyle(color: VineTheme.secondaryText),
            ),
          ),
          const SizedBox(height: 16),

          _EditContentLabelsSection(
            selectedLabels: _contentWarningLabels,
            isDisabled: _isUpdating,
            onTap: _isUpdating ? null : _showContentLabelPicker,
          ),

          const SizedBox(height: 16),

          // Collaborators section
          _EditCollaboratorsSection(
            collaboratorPubkeys: _collaboratorPubkeys,
            isDisabled: _isUpdating,
            onAdd: (pubkey) => setState(() => _collaboratorPubkeys.add(pubkey)),
            onRemove: (pubkey) =>
                setState(() => _collaboratorPubkeys.remove(pubkey)),
          ),

          const SizedBox(height: 16),

          // Inspired By section
          _EditInspiredBySection(
            inspiredByNpub: _inspiredByNpub,
            inspiredByVideo: _inspiredByVideo,
            isDisabled: _isUpdating,
            onSetNpub: (npub) => setState(() {
              _inspiredByNpub = npub;
              _inspiredByVideo = null;
            }),
            onClear: () => setState(() {
              _inspiredByNpub = null;
              _inspiredByVideo = null;
            }),
          ),

          const SizedBox(height: 8),
          Text(
            context.l10n.shareMenuEditMetadataNote,
            style: const TextStyle(
              color: VineTheme.secondaryText,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          // Delete button
          TextButton.icon(
            onPressed: (_isUpdating || _isDeleting) ? null : _confirmDelete,
            icon: _isDeleting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: VineTheme.error,
                    ),
                  )
                : const Icon(Icons.delete_outline, color: VineTheme.error),
            label: Text(
              _isDeleting
                  ? context.l10n.shareMenuDeleting
                  : context.l10n.shareMenuDeleteVideo,
              style: const TextStyle(color: VineTheme.error),
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: (_isUpdating || _isDeleting) ? null : context.pop,
        child: Text(context.l10n.shareMenuCancel),
      ),
      TextButton(
        onPressed: (_isUpdating || _isDeleting) ? null : _updateVideo,
        child: _isUpdating
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: VineTheme.vineGreen,
                ),
              )
            : Text(context.l10n.shareMenuUpdate),
      ),
    ],
  );

  Future<void> _showContentLabelPicker() async {
    final result = await _EditContentLabelsPicker.show(
      context: context,
      selected: _contentWarningLabels,
    );

    if (!mounted || result == null) return;

    setState(() {
      _contentWarningLabels = result;
    });
  }

  Future<void> _updateVideo() async {
    setState(() => _isUpdating = true);

    try {
      // Parse hashtags from comma-separated string
      final hashtagsText = _hashtagsController.text.trim();
      final hashtags = hashtagsText.isEmpty
          ? <String>[]
          : hashtagsText
                .split(',')
                .map((tag) => tag.trim())
                .where((tag) => tag.isNotEmpty)
                .toList();

      // Get auth service to create and sign the updated event
      final authService = ref.read(authServiceProvider);
      if (!authService.isAuthenticated) {
        throw Exception('User not authenticated');
      }

      // Create updated tags for the addressable event
      final tags = <List<String>>[];

      // Required 'd' tag - must use the same identifier
      tags.add(['d', widget.video.stableId]);

      // Extract ALL valid HTTP video URLs from the original imeta tag.
      // The original event may have multiple URL entries (streaming MP4,
      // HLS, R2 fallback, etc.) which must all be preserved.
      final videoUrls = <String>[];
      for (final tag in widget.video.nostrEventTags) {
        if (tag.isEmpty || tag[0] != 'imeta') continue;
        if (tag.length > 1 && tag[1].contains(' ')) {
          // Old imeta format: ['imeta', 'url https://...', 'm video/mp4', ...]
          for (var i = 1; i < tag.length; i++) {
            final spaceIdx = tag[i].indexOf(' ');
            if (spaceIdx > 0) {
              final key = tag[i].substring(0, spaceIdx);
              final value = tag[i].substring(spaceIdx + 1);
              if (key == 'url' &&
                  _isHttpUrl(value) &&
                  !videoUrls.contains(value)) {
                videoUrls.add(value);
              }
            }
          }
        } else {
          // New imeta format: ['imeta', 'url', 'https://...', 'm', 'video/mp4', ...]
          for (var i = 1; i < tag.length - 1; i += 2) {
            if (tag[i] == 'url' &&
                _isHttpUrl(tag[i + 1]) &&
                !videoUrls.contains(tag[i + 1])) {
              videoUrls.add(tag[i + 1]);
            }
          }
        }
      }

      // Fallback: if nostrEventTags is empty (e.g., loaded from JSON cache
      // where nostrEventTags is not serialized), use the single videoUrl.
      if (videoUrls.isEmpty && _isHttpUrl(widget.video.videoUrl)) {
        videoUrls.add(widget.video.videoUrl!);
      }

      // Refuse to republish if no valid HTTP video URLs can be preserved.
      // This prevents corrupt events with local file paths from being published.
      if (videoUrls.isEmpty) {
        throw Exception('Cannot update video: no valid HTTP video URLs found');
      }

      // Build imeta tag components (preserve all original media URLs)
      final imetaComponents = <String>[];
      for (final url in videoUrls) {
        imetaComponents.add('url $url');
      }
      imetaComponents.add('m video/mp4');

      if (widget.video.thumbnailUrl != null) {
        imetaComponents.add('image ${widget.video.thumbnailUrl!}');
      }

      if (widget.video.blurhash != null) {
        imetaComponents.add('blurhash ${widget.video.blurhash!}');
      }

      if (widget.video.dimensions != null) {
        imetaComponents.add('dim ${widget.video.dimensions!}');
      }

      if (widget.video.sha256 != null) {
        imetaComponents.add('x ${widget.video.sha256!}');
      }

      if (widget.video.fileSize != null) {
        imetaComponents.add('size ${widget.video.fileSize!}');
      }

      // Add the complete imeta tag
      if (imetaComponents.isNotEmpty) {
        tags.add(['imeta', ...imetaComponents]);
      }

      // Add updated metadata
      final title = _titleController.text.trim();
      if (title.isNotEmpty) {
        tags.add(['title', title]);
      }

      // Add hashtags
      for (final hashtag in hashtags) {
        tags.add(['t', hashtag]);
      }

      // Add content warning labels (NIP-32)
      for (final label in _contentWarningLabels) {
        tags.add(['l', label.value, 'content-warning']);
      }

      // Preserve other original tags that shouldn't be changed
      if (widget.video.publishedAt != null) {
        tags.add(['published_at', widget.video.publishedAt!]);
      }

      if (widget.video.duration != null) {
        tags.add(['duration', widget.video.duration.toString()]);
      }

      if (widget.video.altText != null) {
        tags.add(['alt', widget.video.altText!]);
      }

      // Add collaborator p-tags
      for (final pubkey in _collaboratorPubkeys) {
        tags.add(['p', pubkey]);
      }

      // Add inspired-by a-tag (video reference)
      if (_inspiredByVideo != null) {
        tags.add([
          'a',
          _inspiredByVideo!.addressableId,
          _inspiredByVideo!.relayUrl ?? '',
          'inspired-by',
        ]);
      }

      // Add client tag
      tags.add(['client', 'diVine']);

      // Build content with optional NIP-27 inspired-by person reference
      var content = _descriptionController.text.trim();
      if (_inspiredByNpub != null && _inspiredByNpub!.isNotEmpty) {
        final ibText = '\n\nInspired by nostr:$_inspiredByNpub';
        content = content.isEmpty ? ibText.trim() : '$content$ibText';
      }

      // Create and sign the updated event
      // Use original created_at + 1 so relays treat this as a replacement
      // while preserving the video's chronological position in feeds.
      final event = await authService.createAndSignEvent(
        kind: NIP71VideoKinds.addressableShortVideo, // Kind 34236
        content: content,
        tags: tags,
        createdAt: widget.video.createdAt + 1,
      );

      if (event == null) {
        throw Exception('Failed to create updated event');
      }

      // Publish the updated event
      final nostrService = ref.read(nostrServiceProvider);
      await nostrService.publishEvent(event);

      // Update local cache for immediate UI update
      final personalEventCache = ref.read(personalEventCacheServiceProvider);
      personalEventCache.cacheUserEvent(event);

      // Update VideoEventService to replace old video in all feeds
      // This triggers callbacks that automatically refresh:
      // - profileFeedProvider (via addVideoUpdateListener)
      // - homeFeedProvider (via addVideoUpdateListener)
      // - exploreTabVideosProvider (via exploreTabVideoUpdateListenerProvider)
      final videoEventService = ref.read(videoEventServiceProvider);
      final updatedVideoEvent = VideoEvent.fromNostrEvent(event);
      videoEventService.updateVideoEvent(updatedVideoEvent);

      if (mounted) {
        context.pop(); // Close edit dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.shareMenuVideoUpdated),
            backgroundColor: VineTheme.vineGreen,
          ),
        );
      }
    } catch (e) {
      Log.error(
        'Failed to update video: $e',
        name: 'ShareVideoMenu',
        category: LogCategory.ui,
      );

      if (mounted) {
        setState(() => _isUpdating = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.shareMenuFailedToUpdateVideo('$e'),
            ),
            backgroundColor: VineTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VineTheme.cardBackground,
        title: Text(
          context.l10n.shareMenuDeleteVideoQuestion,
          style: const TextStyle(color: VineTheme.whiteText),
        ),
        content: Text(
          context.l10n.shareMenuDeleteRelayWarning,
          style: const TextStyle(color: VineTheme.secondaryText),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: Text(context.l10n.shareMenuCancel),
          ),
          TextButton(
            onPressed: () => context.pop(true),
            child: Text(
              context.l10n.shareMenuDelete,
              style: const TextStyle(color: VineTheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _deleteVideo();
    }
  }

  Future<void> _deleteVideo() async {
    setState(() => _isDeleting = true);

    try {
      final deletionService = await ref.read(
        contentDeletionServiceProvider.future,
      );

      final result = await deletionService.quickDelete(
        video: widget.video,
        reason: DeleteReason.personalChoice,
      );

      if (result.success) {
        final videoEventService = ref.read(videoEventServiceProvider);
        videoEventService.removeVideoCompletely(widget.video.id);

        Log.info(
          'Video deleted successfully: ${widget.video.id}',
          name: 'EditVideoDialog',
          category: LogCategory.ui,
        );

        if (mounted) {
          context.pop(); // Close edit dialog

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.shareMenuVideoDeletionRequested,
              ),
              backgroundColor: VineTheme.vineGreen,
            ),
          );
        }
      } else {
        if (mounted) {
          setState(() => _isDeleting = false);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                localizedDeleteFailureMessage(context, result),
              ),
              backgroundColor: VineTheme.error,
            ),
          );
        }
      }
    } catch (e) {
      Log.error(
        'Failed to delete video: $e',
        name: 'EditVideoDialog',
        category: LogCategory.ui,
      );

      if (mounted) {
        setState(() => _isDeleting = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.shareMenuDeleteFailedGeneric,
            ),
            backgroundColor: VineTheme.error,
          ),
        );
      }
    }
  }

  /// Check if a URL is a valid HTTP/HTTPS URL (not a local file path).
  static bool _isHttpUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _hashtagsController.dispose();
    super.dispose();
  }
}

class _EditContentLabelsSection extends StatelessWidget {
  const _EditContentLabelsSection({
    required this.selectedLabels,
    required this.isDisabled,
    required this.onTap,
  });

  final Set<ContentLabel> selectedLabels;
  final bool isDisabled;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final displayText = selectedLabels.isEmpty
        ? context.l10n.shareMenuAddContentLabels
        : selectedLabels
              .map(
                (label) => localizedContentLabelName(context.l10n, label),
              )
              .join(', ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.shareMenuContentLabels,
          style: VineTheme.labelSmallFont(
            color: VineTheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: isDisabled ? null : onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: VineTheme.onSurfaceMuted),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    displayText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: VineTheme.bodyMediumFont(),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  color: isDisabled
                      ? VineTheme.secondaryText
                      : VineTheme.onSurfaceMuted,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _EditContentLabelsPicker extends StatefulWidget {
  const _EditContentLabelsPicker({required this.selected});

  final Set<ContentLabel> selected;

  static Future<Set<ContentLabel>?> show({
    required BuildContext context,
    required Set<ContentLabel> selected,
  }) => showModalBottomSheet<Set<ContentLabel>>(
    context: context,
    backgroundColor: VineTheme.cardBackground,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    isScrollControlled: true,
    builder: (_) => _EditContentLabelsPicker(selected: selected),
  );

  @override
  State<_EditContentLabelsPicker> createState() =>
      _EditContentLabelsPickerState();
}

class _EditContentLabelsPickerState extends State<_EditContentLabelsPicker> {
  late Set<ContentLabel> _selected;

  @override
  void initState() {
    super.initState();
    _selected = Set<ContentLabel>.of(widget.selected);
  }

  void _toggle(ContentLabel label) {
    setState(() {
      if (_selected.contains(label)) {
        _selected.remove(label);
      } else {
        _selected.add(label);
      }
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.l10n.shareMenuContentLabels,
                style: VineTheme.titleMediumFont(),
              ),
              if (_selected.isNotEmpty)
                TextButton(
                  onPressed: () => setState(_selected.clear),
                  child: Text(
                    context.l10n.shareMenuClearAll,
                    style: const TextStyle(color: VineTheme.vineGreen),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: ContentLabel.values
                  .map(
                    (label) => CheckboxListTile(
                      value: _selected.contains(label),
                      onChanged: (_) => _toggle(label),
                      title: Text(
                        localizedContentLabelName(
                          context.l10n,
                          label,
                        ),
                        style: const TextStyle(color: VineTheme.whiteText),
                      ),
                      activeColor: VineTheme.vineGreen,
                      checkColor: VineTheme.whiteText,
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(_selected),
              child: Text(context.l10n.shareMenuDone),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Collaborators editing section for the post-publish edit dialog.
///
/// Manages its own state via callbacks rather than videoEditorProvider.
class _EditCollaboratorsSection extends ConsumerWidget {
  const _EditCollaboratorsSection({
    required this.collaboratorPubkeys,
    required this.isDisabled,
    required this.onAdd,
    required this.onRemove,
  });

  final List<String> collaboratorPubkeys;
  final bool isDisabled;
  final ValueChanged<String> onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        context.l10n.shareMenuCollaborators,
        style: VineTheme.labelSmallFont(
          color: VineTheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 8),
      if (collaboratorPubkeys.isNotEmpty)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: collaboratorPubkeys
              .map(
                (pubkey) => _EditCollaboratorChip(
                  pubkey: pubkey,
                  isDisabled: isDisabled,
                  onRemove: () => onRemove(pubkey),
                ),
              )
              .toList(),
        ),
      if (collaboratorPubkeys.isNotEmpty) const SizedBox(height: 8),
      if (!isDisabled &&
          collaboratorPubkeys.length < _EditVideoDialogState._maxCollaborators)
        GestureDetector(
          onTap: () => _addCollaborator(context, ref),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: VineTheme.onSurfaceMuted),
                ),
                child: const Icon(
                  Icons.add,
                  color: VineTheme.onSurfaceMuted,
                  size: 14,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                context.l10n.shareMenuAddCollaborator,
                style: VineTheme.bodyMediumFont(
                  color: VineTheme.onSurfaceMuted,
                ),
              ),
            ],
          ),
        ),
    ],
  );

  Future<void> _addCollaborator(BuildContext context, WidgetRef ref) async {
    final profile = await showUserPickerSheet(
      context,
      filterMode: UserPickerFilterMode.mutualFollowsOnly,
      title: context.l10n.shareMenuAddCollaborator,
    );

    if (profile == null || !context.mounted) return;

    // Verify mutual follow
    final followRepo = ref.read(followRepositoryProvider);
    final isMutual = await followRepo.isMutualFollow(profile.pubkey);

    if (!isMutual) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.shareMenuMutualFollowRequired(
              profile.bestDisplayName,
            ),
          ),
          backgroundColor: VineTheme.cardBackground,
        ),
      );
      return;
    }

    // Avoid duplicates
    if (!collaboratorPubkeys.contains(profile.pubkey)) {
      onAdd(profile.pubkey);
    }
  }
}

/// Single collaborator chip for the edit dialog.
class _EditCollaboratorChip extends ConsumerWidget {
  const _EditCollaboratorChip({
    required this.pubkey,
    required this.isDisabled,
    required this.onRemove,
  });

  final String pubkey;
  final bool isDisabled;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(fetchUserProfileProvider(pubkey));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: VineTheme.surfaceBackground,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          UserAvatar(
            imageUrl: profileAsync.value?.picture,
            name: profileAsync.value?.bestDisplayName,
            size: 20,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              profileAsync.value?.bestDisplayName ??
                  context.l10n.shareMenuLoading,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: VineTheme.labelMediumFont(),
            ),
          ),
          if (!isDisabled) ...[
            const SizedBox(width: 4),
            GestureDetector(
              onTap: onRemove,
              child: const Icon(
                Icons.close,
                color: VineTheme.onSurfaceMuted,
                size: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Inspired-by editing section for the post-publish edit dialog.
class _EditInspiredBySection extends ConsumerWidget {
  const _EditInspiredBySection({
    required this.inspiredByNpub,
    required this.inspiredByVideo,
    required this.isDisabled,
    required this.onSetNpub,
    required this.onClear,
  });

  final String? inspiredByNpub;
  final InspiredByInfo? inspiredByVideo;
  final bool isDisabled;
  final ValueChanged<String> onSetNpub;
  final VoidCallback onClear;

  bool get _hasInspiredBy => inspiredByNpub != null || inspiredByVideo != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        context.l10n.shareMenuInspiredBy,
        style: VineTheme.labelSmallFont(
          color: VineTheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 8),
      if (_hasInspiredBy)
        _EditInspiredByDisplay(
          inspiredByNpub: inspiredByNpub,
          inspiredByVideo: inspiredByVideo,
          isDisabled: isDisabled,
          onClear: onClear,
        )
      else if (!isDisabled)
        GestureDetector(
          onTap: () => _selectInspiredBy(context, ref),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: VineTheme.onSurfaceMuted),
                ),
                child: const Icon(
                  Icons.add,
                  color: VineTheme.onSurfaceMuted,
                  size: 14,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                context.l10n.shareMenuAddInspirationCredit,
                style: VineTheme.bodyMediumFont(
                  color: VineTheme.onSurfaceMuted,
                ),
              ),
            ],
          ),
        ),
    ],
  );

  Future<void> _selectInspiredBy(BuildContext context, WidgetRef ref) async {
    final profile = await showUserPickerSheet(
      context,
      filterMode: UserPickerFilterMode.allUsers,
      title: context.l10n.shareMenuInspiredBy,
    );

    if (profile == null || !context.mounted) return;

    // Check if the user has muted us
    final blocklistService = ref.read(contentBlocklistServiceProvider);
    if (blocklistService.hasMutedUs(profile.pubkey)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.l10n.shareMenuCreatorCannotBeReferenced,
          ),
          backgroundColor: VineTheme.cardBackground,
        ),
      );
      return;
    }

    final npub = NostrKeyUtils.encodePubKey(profile.pubkey);
    onSetNpub(npub);
  }
}

/// Displays the current inspired-by attribution in the edit dialog.
class _EditInspiredByDisplay extends ConsumerWidget {
  const _EditInspiredByDisplay({
    required this.inspiredByNpub,
    required this.inspiredByVideo,
    required this.isDisabled,
    required this.onClear,
  });

  final String? inspiredByNpub;
  final InspiredByInfo? inspiredByVideo;
  final bool isDisabled;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Resolve the pubkey to display
    String? displayName;
    String? avatarUrl;

    if (inspiredByVideo != null) {
      final pubkey = inspiredByVideo!.creatorPubkey;
      final profileAsync = ref.watch(fetchUserProfileProvider(pubkey));
      displayName = profileAsync.value?.bestDisplayName;
      avatarUrl = profileAsync.value?.picture;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: VineTheme.surfaceBackground,
      ),
      child: Row(
        children: [
          UserAvatar(
            imageUrl: avatarUrl,
            name: displayName ?? inspiredByNpub,
            size: 24,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              displayName ?? inspiredByNpub ?? context.l10n.shareMenuUnknown,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: VineTheme.labelMediumFont(),
            ),
          ),
          if (!isDisabled)
            GestureDetector(
              onTap: onClear,
              child: const Icon(
                Icons.close,
                color: VineTheme.onSurfaceMuted,
                size: 16,
              ),
            ),
        ],
      ),
    );
  }
}

/// Dialog for selecting bookmark set or creating new one
class _SelectBookmarkSetDialog extends StatelessWidget {
  const _SelectBookmarkSetDialog({required this.video});
  final VideoEvent video;

  @override
  Widget build(BuildContext context) => Consumer(
    builder: (context, ref, child) {
      final bookmarkServiceAsync = ref.watch(bookmarkServiceProvider);

      return bookmarkServiceAsync.when(
        data: (bookmarkService) {
          final bookmarkSets = bookmarkService.bookmarkSets;

          return AlertDialog(
            backgroundColor: VineTheme.cardBackground,
            title: Text(
              context.l10n.shareMenuAddToBookmarkSet,
              style: const TextStyle(color: VineTheme.whiteText),
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Create New Set button at top
                  ListTile(
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: VineTheme.vineGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.add, color: VineTheme.vineGreen),
                    ),
                    title: Text(
                      context.l10n.shareMenuCreateNewSet,
                      style: const TextStyle(
                        color: VineTheme.whiteText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      context.l10n.shareMenuStartNewBookmarkCollection,
                      style: const TextStyle(
                        color: VineTheme.secondaryText,
                      ),
                    ),
                    onTap: () {
                      context.pop();
                      _showCreateBookmarkSetDialog(context, ref, video);
                    },
                  ),

                  // Divider if there are existing sets
                  if (bookmarkSets.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    const Divider(color: VineTheme.cardBackground),
                    const SizedBox(height: 8),
                  ],

                  // List of existing bookmark sets
                  if (bookmarkSets.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        context.l10n.shareMenuNoBookmarkSets,
                        style: const TextStyle(
                          color: VineTheme.secondaryText,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    SizedBox(
                      height: 300,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: bookmarkSets.length,
                        itemBuilder: (context, index) {
                          final set = bookmarkSets[index];
                          final isInSet = bookmarkService.isInBookmarkSet(
                            set.id,
                            video.id,
                            'e',
                          );

                          return ListTile(
                            leading: Icon(
                              isInSet
                                  ? Icons.check_circle
                                  : Icons.bookmark_border,
                              color: isInSet
                                  ? VineTheme.vineGreen
                                  : VineTheme.whiteText,
                            ),
                            title: Text(
                              set.name,
                              style: const TextStyle(
                                color: VineTheme.whiteText,
                              ),
                            ),
                            subtitle: Text(
                              '${set.items.length} videos${set.description != null ? ' • ${set.description}' : ''}',
                              style: const TextStyle(
                                color: VineTheme.secondaryText,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () => _toggleVideoInBookmarkSet(
                              context,
                              ref,
                              bookmarkService,
                              set,
                              video,
                              isInSet,
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: context.pop,
                child: Text(context.l10n.shareMenuDone),
              ),
            ],
          );
        },
        loading: () => const AlertDialog(
          backgroundColor: VineTheme.cardBackground,
          content: Center(
            child: CircularProgressIndicator(color: VineTheme.vineGreen),
          ),
        ),
        error: (_, _) => AlertDialog(
          backgroundColor: VineTheme.cardBackground,
          title: Text(
            context.l10n.shareMenuError,
            style: const TextStyle(color: VineTheme.whiteText),
          ),
          content: Text(
            context.l10n.shareMenuFailedToLoadBookmarkSets,
            style: const TextStyle(color: VineTheme.whiteText),
          ),
        ),
      );
    },
  );

  static void _showCreateBookmarkSetDialog(
    BuildContext context,
    WidgetRef ref,
    VideoEvent video,
  ) {
    showDialog(
      context: context,
      builder: (context) => _CreateBookmarkSetDialog(video: video),
    );
  }

  static Future<void> _toggleVideoInBookmarkSet(
    BuildContext context,
    WidgetRef ref,
    BookmarkService bookmarkService,
    BookmarkSet set,
    VideoEvent video,
    bool isCurrentlyInSet,
  ) async {
    try {
      bool success;
      final bookmarkItem = BookmarkItem(type: 'e', id: video.id);

      if (isCurrentlyInSet) {
        success = await bookmarkService.removeFromBookmarkSet(
          set.id,
          bookmarkItem,
        );
      } else {
        success = await bookmarkService.addToBookmarkSet(set.id, bookmarkItem);
      }

      if (success && context.mounted) {
        final message = isCurrentlyInSet
            ? 'Removed from "${set.name}"'
            : 'Added to "${set.name}"';

        // Close the bookmark sets dialog
        context.pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      Log.error(
        'Failed to toggle video in bookmark set: $e',
        name: 'ShareVideoMenu',
        category: LogCategory.ui,
      );
    }
  }
}

/// Dialog for creating new bookmark set
class _CreateBookmarkSetDialog extends ConsumerStatefulWidget {
  const _CreateBookmarkSetDialog({required this.video});
  final VideoEvent video;

  @override
  ConsumerState<_CreateBookmarkSetDialog> createState() =>
      _CreateBookmarkSetDialogState();
}

class _CreateBookmarkSetDialogState
    extends ConsumerState<_CreateBookmarkSetDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: VineTheme.cardBackground,
    title: Text(
      context.l10n.shareMenuCreateBookmarkSet,
      style: const TextStyle(color: VineTheme.whiteText),
    ),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _nameController,
          enableInteractiveSelection: true,
          autofocus: true,
          style: const TextStyle(color: VineTheme.whiteText),
          decoration: InputDecoration(
            labelText: context.l10n.shareMenuSetName,
            labelStyle: const TextStyle(color: VineTheme.secondaryText),
            hintText: context.l10n.shareMenuSetNameHint,
            hintStyle: const TextStyle(color: VineTheme.secondaryText),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _descriptionController,
          enableInteractiveSelection: true,
          style: const TextStyle(color: VineTheme.whiteText),
          decoration: InputDecoration(
            labelText: context.l10n.shareMenuDescriptionOptional,
            labelStyle: const TextStyle(color: VineTheme.secondaryText),
          ),
          maxLines: 2,
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: context.pop,
        child: Text(context.l10n.shareMenuCancel),
      ),
      TextButton(
        onPressed: _createBookmarkSet,
        child: Text(context.l10n.shareMenuCreate),
      ),
    ],
  );

  Future<void> _createBookmarkSet() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      // Don't close dialog - name is required
      return;
    }

    try {
      final bookmarkService = await ref.read(bookmarkServiceProvider.future);
      final newSet = await bookmarkService.createBookmarkSet(
        name: name,
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
      );

      if (newSet != null && mounted) {
        // Add the video to the new set
        final bookmarkItem = BookmarkItem(type: 'e', id: widget.video.id);
        await bookmarkService.addToBookmarkSet(newSet.id, bookmarkItem);

        if (mounted) {
          context.pop(); // Close create dialog

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.l10n.shareMenuCreatedSetAndAddedVideo(name),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      Log.error(
        'Failed to create bookmark set: $e',
        name: 'ShareVideoMenu',
        category: LogCategory.ui,
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

/// Public helper to show edit dialog for a video from anywhere
void showEditDialogForVideo(BuildContext context, VideoEvent video) {
  showDialog(
    context: context,
    builder: (context) => _EditVideoDialog(video: video),
  );
}

/// Action tile for "Use this sound" feature.
///
/// Fetches the audio event and navigates to SoundDetailScreen.
/// Shows loading state while fetching audio, and handles errors gracefully.
class _UseThisSoundTile extends ConsumerWidget {
  const _UseThisSoundTile({required this.video, this.onDismiss});

  final VideoEvent video;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only show if video has an audio reference
    if (!video.hasAudioReference || video.audioEventId == null) {
      return const SizedBox.shrink();
    }

    // Watch the audio event asynchronously
    final audioAsync = ref.watch(soundByIdProvider(video.audioEventId!));

    return audioAsync.when(
      data: (audio) {
        if (audio == null) {
          Log.warning(
            'Audio event not found for video ${video.id}, hiding Use Sound tile',
            name: 'ShareVideoMenu',
            category: LogCategory.ui,
          );
          return const SizedBox.shrink();
        }

        return ListTile(
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: VineTheme.vineGreen.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.music_note,
              color: VineTheme.vineGreen,
              size: 20,
            ),
          ),
          title: Text(
            context.l10n.shareMenuUseThisSound,
            style: const TextStyle(
              color: VineTheme.whiteText,
              fontWeight: FontWeight.w500,
            ),
          ),
          subtitle: Text(
            audio.title ?? context.l10n.shareMenuOriginalSound,
            style: const TextStyle(
              color: VineTheme.secondaryText,
              fontSize: 12,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () {
            Log.info(
              'User tapped Use this sound: ${audio.id}',
              name: 'ShareVideoMenu',
              category: LogCategory.ui,
            );

            // Dismiss the share menu first
            onDismiss?.call();

            // Navigate to sound detail screen using GoRouter
            context.push(SoundDetailScreen.pathForId(audio.id), extra: audio);
          },
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
        );
      },
      loading: () => ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: VineTheme.cardBackground,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: VineTheme.secondaryText,
              ),
            ),
          ),
        ),
        title: Text(
          context.l10n.shareMenuUseThisSound,
          style: const TextStyle(
            color: VineTheme.secondaryText,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          context.l10n.shareMenuLoading,
          style: const TextStyle(
            color: VineTheme.secondaryText,
            fontSize: 12,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      error: (error, stack) {
        Log.error(
          'Failed to load audio for Use Sound tile: $error',
          name: 'ShareVideoMenu',
          category: LogCategory.ui,
        );
        return const SizedBox.shrink();
      },
    );
  }
}
