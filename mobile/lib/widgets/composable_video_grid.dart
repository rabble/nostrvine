// ABOUTME: Composable video grid widget with automatic broken video filtering
// ABOUTME: Reusable component for Explore, Hashtag, and Search screens

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide AspectRatio;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/services/content_deletion_service.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:openvine/widgets/share_video_menu.dart';
import 'package:openvine/widgets/user_name.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';

/// Composable video grid that automatically filters broken videos
/// and provides consistent styling across Explore, Hashtag, and Search screens.
///
/// Supports infinite scroll pagination via [onLoadMore] callback.
class ComposableVideoGrid extends ConsumerStatefulWidget {
  const ComposableVideoGrid({
    super.key,
    required this.videos,
    required this.onVideoTap,
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

  /// When true, each item determines its own aspect ratio from video dimensions.
  /// Square videos use 1:1, vertical videos use 2:3.
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

class _ComposableVideoGridState extends ConsumerState<ComposableVideoGrid> {
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingTriggered = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (widget.onLoadMore == null) return;
    if (!widget.hasMoreContent) return;
    if (widget.isLoadingMore) return;
    if (_isLoadingTriggered) return;

    final position = _scrollController.position;
    final maxScroll = position.maxScrollExtent;
    final currentScroll = position.pixels;

    // Trigger load more when within 200 pixels of the bottom
    if (currentScroll >= maxScroll - 200) {
      _triggerLoadMore();
    }
  }

  Future<void> _triggerLoadMore() async {
    if (_isLoadingTriggered) return;
    _isLoadingTriggered = true;

    try {
      await widget.onLoadMore?.call();
    } finally {
      if (mounted) {
        _isLoadingTriggered = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch broken video tracker asynchronously
    final brokenTrackerAsync = ref.watch(brokenVideoTrackerProvider);

    return brokenTrackerAsync.when(
      loading: () =>
          Center(child: CircularProgressIndicator(color: VineTheme.vineGreen)),
      error: (error, stack) {
        // Fallback: show all videos if tracker fails
        return _buildGrid(context, widget.videos);
      },
      data: (tracker) {
        // Filter out broken videos
        final filteredVideos = widget.videos
            .where((video) => !tracker.isVideoBroken(video.id))
            .toList();

        if (filteredVideos.isEmpty && widget.emptyBuilder != null) {
          return widget.emptyBuilder!();
        }

        return _buildGrid(context, filteredVideos);
      },
    );
  }

  Widget _buildGrid(BuildContext context, List<VideoEvent> videosToShow) {
    if (videosToShow.isEmpty && widget.emptyBuilder != null) {
      return widget.emptyBuilder!();
    }

    // Get subscribed list cache to check if videos are in lists
    final subscribedListCache = ref.watch(subscribedListVideoCacheProvider);

    // Responsive column count: 3 for tablets/desktop (width >= 600), 2 for phones
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

    // Wrap with RefreshIndicator if onRefresh is provided
    if (widget.onRefresh != null) {
      return RefreshIndicator(
        semanticsLabel: 'searching for more videos',
        onRefresh: widget.onRefresh!,
        displacement: 70,
        child: gridView,
        color: VineTheme.onPrimary,
        backgroundColor: VineTheme.vineGreen,
      );
    }

    return gridView;
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
                  Icon(Icons.more_vert, color: VineTheme.whiteText),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Video Options',
                      style: TextStyle(
                        color: VineTheme.whiteText,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: context.pop,
                    icon: Icon(Icons.close, color: VineTheme.secondaryText),
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
                child: Icon(Icons.edit, color: VineTheme.vineGreen, size: 20),
              ),
              title: Text(
                'Edit Video',
                style: TextStyle(
                  color: VineTheme.whiteText,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                'Update title, description, and hashtags',
                style: TextStyle(color: VineTheme.secondaryText, fontSize: 12),
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
                child: Icon(Icons.delete_outline, color: Colors.red, size: 20),
              ),
              title: Text(
                'Delete Video',
                style: TextStyle(
                  color: VineTheme.whiteText,
                  fontWeight: FontWeight.w500,
                ),
              ),
              subtitle: Text(
                'Permanently remove this content',
                style: TextStyle(color: VineTheme.secondaryText, fontSize: 12),
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
          'Delete Video',
          style: TextStyle(color: VineTheme.whiteText),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete this video?',
              style: TextStyle(color: VineTheme.whiteText),
            ),
            SizedBox(height: 12),
            Text(
              'This will send a delete request (NIP-09) to all relays. Some relays may still retain the content.',
              style: TextStyle(color: VineTheme.secondaryText, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => context.pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text('Delete'),
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
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Text('Deleting content...'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
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
                  color: Colors.white,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    result.success
                        ? 'Delete request sent successfully'
                        : 'Failed to delete content: ${result.error}',
                  ),
                ),
              ],
            ),
            backgroundColor: result.success ? VineTheme.vineGreen : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete content: $e'),
            backgroundColor: Colors.red,
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
      button: true,
      label: 'Video thumbnail',
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
                child: _VideoInfoSection(video: video),
              ),
              if (isInSubscribedList)
                Positioned(
                  top: 6,
                  left: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: VineTheme.vineGreen.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.collections,
                      size: 14,
                      color: Colors.white,
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
  const _VideoInfoSection({required this.video});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    final hasDescription = (video.title ?? video.content).isNotEmpty;

    // Always show the info section with username (using bestDisplayName fallback)
    // UserName.fromPubKey handles fallback to truncated npub when no profile name
    return Container(
      padding: const EdgeInsets.only(left: 8, right: 8, bottom: 8, top: 50),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Color(0x80000000)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: 0,
        children: [
          // Always show username - UserName.fromPubKey uses bestDisplayName
          // which falls back to truncated npub when no profile name is set
          UserName.fromPubKey(
            video.pubkey,
            embeddedName: video.authorName,
            maxLines: 1,
            style: VineTheme.titleTinyFont(color: Colors.white).copyWith(
              shadows: const [
                Shadow(
                  offset: Offset(0, 1),
                  blurRadius: 2,
                  color: Color(0x26000000),
                ),
              ],
            ),
          ),
          if (hasDescription)
            Text(
              video.title ?? video.content,
              style: const TextStyle(
                fontFamily: 'Inter',
                color: Colors.white,
                fontSize: 14,
                height: 20 / 14,
                letterSpacing: 0.25,
                shadows: [
                  Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 2,
                    color: Color(0x26000000),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
    return Container(
      color: VineTheme.cardBackground,
      child: video.thumbnailUrl != null
          ? VideoThumbnailWidget(video: video)
          : AspectRatio(
              aspectRatio: 2 / 3,
              child: Container(
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
          ? SizedBox(
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
