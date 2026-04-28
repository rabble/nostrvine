// ABOUTME: Composable video grid widget with automatic broken video filtering
// ABOUTME: Reusable component for Explore, Hashtag, and Search screens

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide AspectRatio;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/mixins/scroll_pagination_mixin.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/services/content_deletion_service.dart';
import 'package:openvine/utils/delete_failure_localization.dart';
import 'package:openvine/widgets/share_video_menu.dart';
import 'package:openvine/widgets/user_name.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';

/// Composable video grid that automatically filters broken videos
/// and provides consistent styling across Explore, Hashtag, and Search screens.
///
/// Supports infinite scroll pagination via [onLoadMore] callback.
class ComposableVideoGrid extends ConsumerStatefulWidget {
  const ComposableVideoGrid({
    required this.videos,
    required this.onVideoTap,
    super.key,
    this.crossAxisCount = 2,
    this.thumbnailAspectRatio = 1,
    this.useMasonryLayout = false,
    this.padding,
    this.emptyBuilder,
    this.onRefresh,
    this.onLoadMore,
    this.isLoadingMore = false,
    this.hasMoreContent = false,
    this.loadMoreThreshold = 5,
  });

  final List<VideoEvent> videos;
  final Function(List<VideoEvent> videos, int index) onVideoTap;
  final int crossAxisCount;
  final double thumbnailAspectRatio;

  /// When true, each item determines its own aspect ratio from video
  /// dimensions. Square videos use 1:1, vertical videos use 2:3.
  final bool useMasonryLayout;
  final EdgeInsets? padding;
  final Widget Function()? emptyBuilder;
  final Future<void> Function()? onRefresh;

  /// Called when user scrolls near the bottom to load more content.
  final Future<void> Function()? onLoadMore;

  /// Whether more content is currently being loaded.
  final bool isLoadingMore;

  /// Whether there is more content available to load.
  final bool hasMoreContent;

  /// Number of items from the bottom to trigger load more.
  final int loadMoreThreshold;

  @override
  ConsumerState<ComposableVideoGrid> createState() =>
      _ComposableVideoGridState();
}

class _ComposableVideoGridState extends ConsumerState<ComposableVideoGrid>
    with ScrollPaginationMixin {
  static const double _pointerRefreshTriggerDistance = 80;

  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey =
      GlobalKey<RefreshIndicatorState>();
  final ScrollController _scrollController = ScrollController();
  double _pointerRefreshPullDistance = 0;
  bool _isPointerRefreshRunning = false;

  @override
  ScrollController get paginationScrollController => _scrollController;

  @override
  bool canLoadMore() =>
      widget.onLoadMore != null &&
      widget.hasMoreContent &&
      !widget.isLoadingMore;

  @override
  FutureOr<void> onLoadMore() => widget.onLoadMore?.call();

  @override
  void initState() {
    super.initState();
    initPagination();
  }

  @override
  void dispose() {
    disposePagination();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch broken video tracker asynchronously
    final brokenTrackerAsync = ref.watch(brokenVideoTrackerProvider);

    return brokenTrackerAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: VineTheme.vineGreen),
      ),
      error: (error, stack) {
        // Fallback: show all videos if tracker fails
        return _buildGrid(context, widget.videos);
      },
      data: (tracker) {
        // Filter out broken videos
        final filteredVideos = widget.videos
            .where((video) => !tracker.isVideoBroken(video.id))
            .toList();

        return _buildGrid(context, filteredVideos);
      },
    );
  }

  Widget _buildGrid(BuildContext context, List<VideoEvent> videosToShow) {
    if (videosToShow.isEmpty && widget.emptyBuilder != null) {
      return _buildEmptyState(context);
    }

    // Get subscribed list cache to check if videos are in lists
    final subscribedListCache = ref.watch(subscribedListVideoCacheProvider);

    // Responsive column count: 3 for tablets/desktop (width >= 600),
    // 2 for phones
    final screenWidth = MediaQuery.of(context).size.width;
    final responsiveCrossAxisCount = screenWidth >= 600
        ? 3
        : widget.crossAxisCount;

    // Calculate total item count (videos + optional loading indicator)
    final showLoadingIndicator =
        widget.isLoadingMore ||
        (widget.hasMoreContent && widget.onLoadMore != null);
    final totalItemCount = videosToShow.length + (showLoadingIndicator ? 1 : 0);

    Widget buildItem(BuildContext context, int index) {
      // If this is the last item and we're loading more, show loading indicator
      if (index == videosToShow.length) {
        return _LoadingMoreIndicator(isLoading: widget.isLoadingMore);
      }

      final video = videosToShow[index];
      final listIds = subscribedListCache?.getListsForVideo(video.id);
      final isInSubscribedList = listIds != null && listIds.isNotEmpty;

      return _VideoItem(
        video: video,
        aspectRatio: widget.thumbnailAspectRatio,
        onVideoTap: widget.onVideoTap,
        index: index,
        displayedVideos: videosToShow,
        onLongPress: () => _showVideoContextMenu(context, video),
        isInSubscribedList: isInSubscribedList,
      );
    }

    final gridView = widget.useMasonryLayout
        ? MasonryGridView.count(
            controller: _scrollController,
            padding: widget.padding ?? const EdgeInsets.all(4),
            crossAxisCount: responsiveCrossAxisCount,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            itemCount: totalItemCount,
            itemBuilder: buildItem,
          )
        : GridView.builder(
            controller: _scrollController,
            padding: widget.padding ?? const EdgeInsets.all(12),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: responsiveCrossAxisCount,
              childAspectRatio: widget.thumbnailAspectRatio,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: totalItemCount,
            itemBuilder: buildItem,
          );

    return _wrapWithRefreshIndicator(context, gridView);
  }

  Widget _buildEmptyState(BuildContext context) {
    final emptyState = widget.emptyBuilder!();

    if (widget.onRefresh == null) {
      return emptyState;
    }

    return _wrapWithRefreshIndicator(
      context,
      CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverFillRemaining(hasScrollBody: false, child: emptyState),
        ],
      ),
    );
  }

  Widget _wrapWithRefreshIndicator(BuildContext context, Widget child) {
    if (widget.onRefresh == null) {
      return child;
    }

    return Listener(
      onPointerSignal: _handlePointerSignal,
      child: RefreshIndicator(
        key: _refreshIndicatorKey,
        semanticsLabel: context.l10n.videoGridRefreshLabel,
        onRefresh: widget.onRefresh!,
        displacement: 70,
        color: VineTheme.onPrimary,
        backgroundColor: VineTheme.vineGreen,
        child: child,
      ),
    );
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent ||
        !_scrollController.hasClients ||
        widget.onRefresh == null) {
      return;
    }

    final position = _scrollController.position;
    final isAtTop = position.pixels <= position.minScrollExtent + 0.5;
    final isPullingDown = event.scrollDelta.dy < 0;

    if (!isAtTop || !isPullingDown) {
      _pointerRefreshPullDistance = 0;
      return;
    }

    _pointerRefreshPullDistance += -event.scrollDelta.dy;
    if (_pointerRefreshPullDistance < _pointerRefreshTriggerDistance) {
      return;
    }

    _pointerRefreshPullDistance = 0;
    unawaited(_showRefreshFromPointerSignal());
  }

  Future<void> _showRefreshFromPointerSignal() async {
    if (_isPointerRefreshRunning) {
      return;
    }

    final refreshIndicator = _refreshIndicatorKey.currentState;
    if (refreshIndicator == null) {
      return;
    }

    _isPointerRefreshRunning = true;
    try {
      await refreshIndicator.show();
    } finally {
      _isPointerRefreshRunning = false;
    }
  }

  /// Show context menu for long press on video tiles
  void _showVideoContextMenu(BuildContext context, VideoEvent video) {
    // Check if user owns this video
    final nostrService = ref.read(nostrServiceProvider);
    final userPubkey = nostrService.publicKey;
    final isOwnVideo = userPubkey == video.pubkey;

    // Only show context menu for own videos
    if (!isOwnVideo) {
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: VineTheme.backgroundColor,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.more_vert, color: VineTheme.whiteText),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.l10n.videoGridOptionsTitle,
                      style: const TextStyle(
                        color: VineTheme.whiteText,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: context.pop,
                    icon: const Icon(
                      Icons.close,
                      color: VineTheme.secondaryText,
                    ),
                  ),
                ],
              ),
            ),

            // Edit option
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: VineTheme.cardBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.edit,
                  color: VineTheme.vineGreen,
                  size: 20,
                ),
              ),
              title: Text(
                context.l10n.videoGridEditVideo,
                style: const TextStyle(
                  color: VineTheme.whiteText,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                context.l10n.videoGridEditVideoSubtitle,
                style: const TextStyle(
                  color: VineTheme.secondaryText,
                  fontSize: 12,
                ),
              ),
              onTap: () {
                context.pop();
                showEditDialogForVideo(context, video);
              },
            ),

            // Delete option
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: VineTheme.cardBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.delete_outline,
                  color: VineTheme.error,
                  size: 20,
                ),
              ),
              title: Text(
                context.l10n.videoGridDeleteVideo,
                style: const TextStyle(
                  color: VineTheme.whiteText,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                context.l10n.videoGridDeleteVideoSubtitle,
                style: const TextStyle(
                  color: VineTheme.secondaryText,
                  fontSize: 12,
                ),
              ),
              onTap: () {
                context.pop();
                _showDeleteConfirmation(context, video);
              },
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  /// Show delete confirmation dialog
  Future<void> _showDeleteConfirmation(
    BuildContext context,
    VideoEvent video,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VineTheme.cardBackground,
        title: Text(
          context.l10n.videoGridDeleteConfirmTitle,
          style: const TextStyle(color: VineTheme.whiteText),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.videoGridDeleteConfirmMessage,
              style: const TextStyle(color: VineTheme.whiteText),
            ),
            const SizedBox(height: 12),
            Text(
              context.l10n.videoGridDeleteConfirmNote,
              style: const TextStyle(
                color: VineTheme.secondaryText,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: Text(context.l10n.videoGridDeleteCancel),
          ),
          TextButton(
            onPressed: () => context.pop(true),
            style: TextButton.styleFrom(foregroundColor: VineTheme.error),
            child: Text(context.l10n.videoGridDeleteConfirm),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await _deleteVideo(context, video);
    }
  }

  /// Delete video using ContentDeletionService
  Future<void> _deleteVideo(BuildContext context, VideoEvent video) async {
    try {
      final deletionService = await ref.read(
        contentDeletionServiceProvider.future,
      );

      // Show loading snackbar
      if (context.mounted) {
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
                Text(context.l10n.videoGridDeletingContent),
              ],
            ),
            backgroundColor: VineTheme.warning,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      final result = await deletionService.quickDelete(
        video: video,
        reason: DeleteReason.personalChoice,
      );

      // Remove video from local feeds after successful deletion
      if (result.success) {
        final videoEventService = ref.read(videoEventServiceProvider);
        videoEventService.removeVideoCompletely(video.id);
      }

      if (context.mounted) {
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
                        ? context.l10n.videoGridDeleteSuccess
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
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.shareMenuDeleteFailedGeneric),
            backgroundColor: VineTheme.error,
          ),
        );
      }
    }
  }
}

class _VideoItem extends StatelessWidget {
  const _VideoItem({
    required this.video,
    required this.aspectRatio,
    required this.onVideoTap,
    required this.onLongPress,
    required this.index,
    required this.displayedVideos,
    this.isInSubscribedList = false,
  });

  final VideoEvent video;
  final double aspectRatio;
  final Function(List<VideoEvent> videos, int index) onVideoTap;
  final VoidCallback onLongPress;
  final int index;
  final List<VideoEvent> displayedVideos;
  final bool isInSubscribedList;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'video_thumbnail_$index',
      label: 'Video thumbnail ${index + 1}',
      button: true,
      child: GestureDetector(
        onTap: () => onVideoTap(displayedVideos, index),
        onLongPress: onLongPress,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            children: [
              _VideoThumbnail(video: video),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _VideoInfoSection(video: video, index: index),
              ),
              if (isInSubscribedList)
                PositionedDirectional(
                  top: 6,
                  start: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: VineTheme.vineGreen.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.collections,
                      size: 14,
                      color: VineTheme.whiteText,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoInfoSection extends StatelessWidget {
  const _VideoInfoSection({required this.video, required this.index});

  final VideoEvent video;
  final int index;

  @override
  Widget build(BuildContext context) {
    final hasDescription =
        (video.displayTitle ?? video.displayContent).isNotEmpty;

    // Always show the info section with username (using bestDisplayName
    // fallback). UserName.fromPubKey handles fallback to truncated npub when
    // no profile name.
    return Container(
      padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8, top: 50),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [VineTheme.transparent, VineTheme.scrim50],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Always show username - UserName.fromPubKey uses bestDisplayName
          // which falls back to truncated npub when no profile name is set
          Semantics(
            identifier: 'video_thumbnail_author_$index',
            container: true,
            explicitChildNodes: true,
            label: 'Video author: ${video.authorName ?? ''}',
            child: UserName.fromPubKey(
              video.pubkey,
              embeddedName: video.authorName,
              maxLines: 1,
              style: VineTheme.titleTinyFont().copyWith(
                decoration: TextDecoration.none,
                shadows: const [
                  Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 2,
                    color: VineTheme.scrim15,
                  ),
                ],
              ),
            ),
          ),
          if (hasDescription)
            Semantics(
              identifier: 'video_thumbnail_description_$index',
              container: true,
              explicitChildNodes: true,
              label:
                  'Video description: ${video.displayTitle ?? video.displayContent}',
              child: Text(
                video.displayTitle ?? video.displayContent,
                style: VineTheme.bodyMediumFont().copyWith(
                  decoration: TextDecoration.none,
                  shadows: const [
                    Shadow(
                      offset: Offset(0, 1),
                      blurRadius: 2,
                      color: VineTheme.scrim15,
                    ),
                  ],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}

class _VideoThumbnail extends StatelessWidget {
  const _VideoThumbnail({required this.video});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: VineTheme.cardBackground,
      child: video.thumbnailUrl != null
          ? VideoThumbnailWidget(video: video)
          : const AspectRatio(
              aspectRatio: 2 / 3,
              child: ColoredBox(
                color: VineTheme.cardBackground,
                child: Icon(
                  Icons.videocam,
                  size: 40,
                  color: VineTheme.secondaryText,
                ),
              ),
            ),
    );
  }
}

/// Loading indicator shown at the bottom of the grid during pagination
class _LoadingMoreIndicator extends StatelessWidget {
  const _LoadingMoreIndicator({required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      alignment: Alignment.center,
      child: isLoading
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: VineTheme.vineGreen,
              ),
            )
          : const SizedBox.shrink(),
    );
  }
}
