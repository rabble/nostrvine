// ABOUTME: Composable video grid widget with automatic broken video filtering
// ABOUTME: Reusable component for Explore, Hashtag, and Search screens

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide AspectRatio;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/services/content_deletion_service.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/string_utils.dart';
import 'package:openvine/widgets/share_video_menu.dart';
import 'package:openvine/widgets/user_name.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';

/// Composable video grid that automatically filters broken videos
/// and provides consistent styling across Explore, Hashtag, and Search screens
class ComposableVideoGrid extends ConsumerWidget {
  const ComposableVideoGrid({
    super.key,
    required this.videos,
    required this.onVideoTap,
    this.crossAxisCount = 2,
    this.thumbnailAspectRatio = 1,
    this.padding,
    this.emptyBuilder,
    this.onRefresh,
  });

  final List<VideoEvent> videos;
  final Function(List<VideoEvent> videos, int index) onVideoTap;
  final int crossAxisCount;
  final double thumbnailAspectRatio;
  final EdgeInsets? padding;
  final Widget Function()? emptyBuilder;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch broken video tracker asynchronously
    final brokenTrackerAsync = ref.watch(brokenVideoTrackerProvider);

    return brokenTrackerAsync.when(
      loading: () =>
          Center(child: CircularProgressIndicator(color: VineTheme.vineGreen)),
      error: (error, stack) {
        // Fallback: show all videos if tracker fails
        return _buildGrid(context, ref, videos);
      },
      data: (tracker) {
        // Filter out broken videos
        final filteredVideos = videos
            .where((video) => !tracker.isVideoBroken(video.id))
            .toList();

        if (filteredVideos.isEmpty && emptyBuilder != null) {
          return emptyBuilder!();
        }

        return _buildGrid(context, ref, filteredVideos);
      },
    );
  }

  Widget _buildGrid(
    BuildContext context,
    WidgetRef ref,
    List<VideoEvent> videosToShow,
  ) {
    if (videosToShow.isEmpty && emptyBuilder != null) {
      return emptyBuilder!();
    }

    // Get subscribed list cache to check if videos are in lists
    final subscribedListCache = ref.watch(subscribedListVideoCacheProvider);

    // Responsive column count: 3 for tablets/desktop (width >= 600), 2 for phones
    final screenWidth = MediaQuery.of(context).size.width;
    final responsiveCrossAxisCount = screenWidth >= 600 ? 3 : crossAxisCount;

    final gridView = GridView.builder(
      padding: padding ?? const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: responsiveCrossAxisCount,
        childAspectRatio: thumbnailAspectRatio,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: videosToShow.length,
      itemBuilder: (context, index) {
        final video = videosToShow[index];
        // Check if video is in any subscribed lists
        final listIds = subscribedListCache?.getListsForVideo(video.id);
        final isInSubscribedList = listIds != null && listIds.isNotEmpty;

        return _VideoItem(
          video: video,
          aspectRatio: thumbnailAspectRatio,
          onVideoTap: onVideoTap,
          index: index,
          displayedVideos: videosToShow,
          onLongPress: () => _showVideoContextMenu(context, ref, video),
          isInSubscribedList: isInSubscribedList,
        );
      },
    );

    // Wrap with RefreshIndicator if onRefresh is provided
    if (onRefresh != null) {
      return RefreshIndicator(
        semanticsLabel: 'searching for more videos',
        onRefresh: onRefresh!,
        child: gridView,
        color: VineTheme.vineGreen,
      );
    }

    return gridView;
  }

  /// Show context menu for long press on video tiles
  void _showVideoContextMenu(
    BuildContext context,
    WidgetRef ref,
    VideoEvent video,
  ) {
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
                _showDeleteConfirmation(context, ref, video);
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
    WidgetRef ref,
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
      await _deleteVideo(context, ref, video);
    }
  }

  /// Delete video using ContentDeletionService
  Future<void> _deleteVideo(
    BuildContext context,
    WidgetRef ref,
    VideoEvent video,
  ) async {
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
    return GestureDetector(
      onTap: () => onVideoTap(displayedVideos, index),
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Stack(
          children: [
            AspectRatio(
              aspectRatio: aspectRatio,
              child: _VideoThumbnail(video: video),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: _VideoInfoSection(video: video),
            ),
            // Show list indicator badge if video is in subscribed lists
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
    );
  }
}

class _VideoInfoSection extends StatelessWidget {
  const _VideoInfoSection({required this.video});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          color: VineTheme.cardBackground,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 1,
            children: [
              // Creator name
              UserName.fromPubKey(video.pubkey, maxLines: 1),
              // Title or content
              Flexible(
                child: Text(
                  video.title ?? video.content,
                  style: TextStyle(
                    color: VineTheme.primaryText,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Stats row - watch social provider for current metrics
              _VideoStats(video: video),
            ],
          ),
        ),
      ],
    );
  }
}

class _VideoThumbnail extends StatelessWidget {
  const _VideoThumbnail({required this.video});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    alignment: Alignment.center,
    children: [
      Container(
        color: VineTheme.cardBackground,
        child: video.thumbnailUrl != null
            ? VideoThumbnailWidget(video: video)
            : Container(
                color: VineTheme.cardBackground,
                child: Icon(
                  Icons.videocam,
                  size: 40,
                  color: VineTheme.secondaryText,
                ),
              ),
      ),
      // Play button overlay
      Center(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: VineTheme.darkOverlay,
            shape: BoxShape.circle,
          ),
          child: Semantics(
            identifier: 'play_button',
            child: Icon(
              Icons.play_arrow,
              size: 24,
              color: VineTheme.whiteText,
              semanticLabel: 'Play video',
            ),
          ),
        ),
      ),
    ],
  );
}

class _VideoStats extends StatelessWidget {
  const _VideoStats({required this.video});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    // Show combined likes (original Vine likes + Nostr reactions)
    // nostrLikeCount is populated by VideoEventService when videos are loaded
    final totalLikes = video.totalLikes;
    final originalLoops = video.originalLoops;

    return Row(
      children: [
        Icon(Icons.favorite, size: 10, color: VineTheme.likeRed),
        const SizedBox(width: 6),
        Text(
          StringUtils.formatCompactNumber(totalLikes),
          style: TextStyle(color: VineTheme.secondaryText, fontSize: 9),
        ),
        if (originalLoops != null && originalLoops > 0) ...[
          const SizedBox(width: 6),
          Icon(Icons.repeat, size: 10, color: VineTheme.secondaryText),
          const SizedBox(width: 2),
          Text(
            StringUtils.formatCompactNumber(originalLoops),
            style: TextStyle(color: VineTheme.secondaryText, fontSize: 9),
          ),
        ],
      ],
    );
  }
}
