// ABOUTME: Grid widget displaying user's liked videos on profile page
// ABOUTME: Shows 3-column grid with thumbnails and heart badge indicator

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/profile_liked_videos_provider.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Grid widget displaying user's liked videos
class ProfileLikedGrid extends ConsumerWidget {
  const ProfileLikedGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likedVideosAsync = ref.watch(profileLikedVideosProvider);

    return likedVideosAsync.when(
      data: (likedVideos) {
        if (likedVideos.isEmpty) {
          return const _LikedEmptyState();
        }

        return CustomScrollView(
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
                  return _LikedGridTile(videoEvent: videoEvent, index: index);
                }, childCount: likedVideos.length),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: VineTheme.vineGreen),
      ),
      error: (error, stack) => Center(
        child: Text(
          'Error loading liked videos: $error',
          style: const TextStyle(color: Colors.white),
        ),
      ),
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
  const _LikedGridTile({required this.videoEvent, required this.index});

  final VideoEvent videoEvent;
  final int index;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      Log.info(
        'ProfileLikedGrid TAP: gridIndex=$index, videoId=${videoEvent.id}',
        category: LogCategory.video,
      );
      // Navigate to liked videos feed at this index
      context.goLikedVideos(index);
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
