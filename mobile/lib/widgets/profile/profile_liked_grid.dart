// ABOUTME: Grid widget displaying user's liked videos on profile page
// ABOUTME: Shows 3-column grid with thumbnails and heart badge indicator

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/profile_liked_videos/profile_liked_videos_bloc.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/screens/fullscreen_video_feed_screen.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Grid widget displaying user's liked videos
///
/// Requires [ProfileLikedVideosBloc] to be provided in the widget tree.
class ProfileLikedGrid extends StatefulWidget {
  const ProfileLikedGrid({super.key});

  @override
  State<ProfileLikedGrid> createState() => _ProfileLikedGridState();
}

class _ProfileLikedGridState extends State<ProfileLikedGrid> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileLikedVideosBloc, ProfileLikedVideosState>(
      builder: (context, state) {
        if (state.status == ProfileLikedVideosStatus.initial ||
            state.status == ProfileLikedVideosStatus.syncing ||
            state.status == ProfileLikedVideosStatus.loading) {
          return const Center(
            child: CircularProgressIndicator(color: VineTheme.vineGreen),
          );
        }

        if (state.status == ProfileLikedVideosStatus.failure) {
          return const Center(
            child: Text(
              'Error loading liked videos',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        final likedVideos = state.videos;

        if (likedVideos.isEmpty) {
          return const _LikedEmptyState();
        }

        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            // Trigger load more when near the bottom
            if (notification is ScrollUpdateNotification) {
              final pixels = notification.metrics.pixels;
              final maxExtent = notification.metrics.maxScrollExtent;
              // Load more when within 200 pixels of the bottom
              if (pixels >= maxExtent - 200 &&
                  state.hasMoreContent &&
                  !state.isLoadingMore) {
                context.read<ProfileLikedVideosBloc>().add(
                  const ProfileLikedVideosLoadMoreRequested(),
                );
              }
            }
            return false;
          },
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(2),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                    childAspectRatio: 1,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    if (index >= likedVideos.length) {
                      return const SizedBox.shrink();
                    }

                    final videoEvent = likedVideos[index];
                    return _LikedGridTile(
                      videoEvent: videoEvent,
                      index: index,
                      allVideos: likedVideos,
                    );
                  }, childCount: likedVideos.length),
                ),
              ),
              // Loading indicator at the bottom
              if (state.isLoadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: CircularProgressIndicator(
                        color: VineTheme.vineGreen,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Empty state shown when user has no liked videos
class _LikedEmptyState extends StatelessWidget {
  const _LikedEmptyState();

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.favorite_border, color: Colors.grey, size: 64),
              SizedBox(height: 16),
              Text(
                'No Liked Videos Yet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Videos you like will appear here',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

/// Individual liked video tile in the grid with heart badge
class _LikedGridTile extends StatelessWidget {
  const _LikedGridTile({
    required this.videoEvent,
    required this.index,
    required this.allVideos,
  });

  final VideoEvent videoEvent;
  final int index;
  final List<VideoEvent> allVideos;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      Log.info(
        '🎯 ProfileLikedGrid TAP: gridIndex=$index, '
        'videoId=${videoEvent.id}',
        category: LogCategory.video,
      );
      // Use LikedVideosFeedSource for fullscreen playback
      context.pushVideoFeed(
        source: LikedVideosFeedSource(allVideos),
        initialIndex: index,
      );
      Log.info(
        '✅ ProfileLikedGrid: Called pushVideoFeed with '
        'LikedVideosFeedSource at index $index',
        category: LogCategory.video,
      );
    },
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: VineTheme.cardBackground,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: _LikedThumbnail(thumbnailUrl: videoEvent.thumbnailUrl),
            ),
          ),
          const Center(
            child: Icon(
              Icons.play_circle_filled,
              color: Colors.white70,
              size: 32,
            ),
          ),
          // Heart indicator badge
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.favorite, color: Colors.red, size: 16),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Liked video thumbnail with loading and error states
class _LikedThumbnail extends StatelessWidget {
  const _LikedThumbnail({required this.thumbnailUrl});

  final String? thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: thumbnailUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => const _LikedThumbnailPlaceholder(),
        errorWidget: (context, url, error) =>
            const _LikedThumbnailPlaceholder(),
      );
    }
    return const _LikedThumbnailPlaceholder();
  }
}

/// Gradient placeholder for liked video thumbnails
class _LikedThumbnailPlaceholder extends StatelessWidget {
  const _LikedThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(4),
      gradient: LinearGradient(
        colors: [
          Colors.red.withValues(alpha: 0.3),
          Colors.pink.withValues(alpha: 0.3),
        ],
      ),
    ),
    child: const Center(
      child: Icon(
        Icons.play_circle_outline,
        color: VineTheme.whiteText,
        size: 24,
      ),
    ),
  );
}
