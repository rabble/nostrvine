// ABOUTME: Grid widget displaying user's videos on profile page
// ABOUTME: Shows 3-column grid with thumbnails, handles empty state and navigation

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/profile_feed_provider.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/screens/fullscreen_video_feed_screen.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Grid widget displaying user's videos on their profile
class ProfileVideosGrid extends ConsumerWidget {
  const ProfileVideosGrid({
    required this.videos,
    required this.userIdHex,
    super.key,
  });

  final List<VideoEvent> videos;
  final String userIdHex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (videos.isEmpty) {
      return _ProfileVideosEmptyState(
        userIdHex: userIdHex,
        isOwnProfile:
            ref.read(authServiceProvider).currentPublicKeyHex == userIdHex,
        onRefresh: () =>
            ref.read(profileFeedProvider(userIdHex).notifier).loadMore(),
      );
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
              if (index >= videos.length) {
                return const _VideoGridLoadingTile();
              }

              final videoEvent = videos[index];
              return _VideoGridTile(
                videoEvent: videoEvent,
                userIdHex: userIdHex,
                index: index,
              );
            }, childCount: videos.length),
          ),
        ),
      ],
    );
  }
}

/// Empty state shown when user has no videos
class _ProfileVideosEmptyState extends StatelessWidget {
  const _ProfileVideosEmptyState({
    required this.userIdHex,
    required this.isOwnProfile,
    required this.onRefresh,
  });

  final String userIdHex;
  final bool isOwnProfile;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_outlined, color: Colors.grey, size: 64),
              const SizedBox(height: 16),
              const Text(
                'No Videos Yet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isOwnProfile
                    ? 'Share your first video to see it here'
                    : "This user hasn't shared any videos yet",
                style: const TextStyle(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 32),
              IconButton(
                onPressed: onRefresh,
                icon: const Icon(
                  Icons.refresh,
                  color: VineTheme.vineGreen,
                  size: 28,
                ),
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

/// Loading tile shown while more videos are being fetched
class _VideoGridLoadingTile extends StatelessWidget {
  const _VideoGridLoadingTile();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: VineTheme.cardBackground,
      borderRadius: BorderRadius.circular(4),
    ),
    child: const Center(
      child: CircularProgressIndicator(
        color: VineTheme.vineGreen,
        strokeWidth: 2,
      ),
    ),
  );
}

/// Individual video tile in the grid
class _VideoGridTile extends StatelessWidget {
  const _VideoGridTile({
    required this.videoEvent,
    required this.userIdHex,
    required this.index,
  });

  final VideoEvent videoEvent;
  final String userIdHex;
  final int index;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () {
      Log.info(
        '🎯 ProfileVideosGrid TAP: gridIndex=$index, '
        'videoId=${videoEvent.id}',
        category: LogCategory.video,
      );
      // Use ProfileFeedSource for reactive updates when loadMore fetches new videos
      context.pushVideoFeed(
        source: ProfileFeedSource(userIdHex),
        initialIndex: index,
      );
      Log.info(
        '✅ ProfileVideosGrid: Called pushVideoFeed with ProfileFeedSource($userIdHex) at index $index',
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
              child: _VideoThumbnail(thumbnailUrl: videoEvent.thumbnailUrl),
            ),
          ),
          const Center(
            child: Icon(
              Icons.play_circle_filled,
              color: Colors.white70,
              size: 32,
            ),
          ),
        ],
      ),
    ),
  );
}

/// Video thumbnail with loading and error states
class _VideoThumbnail extends StatelessWidget {
  const _VideoThumbnail({required this.thumbnailUrl});

  final String? thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: thumbnailUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => const _ThumbnailPlaceholder(),
        errorWidget: (context, url, error) => const _ThumbnailPlaceholder(),
      );
    }
    return const _ThumbnailPlaceholder();
  }
}

/// Gradient placeholder for thumbnails
class _ThumbnailPlaceholder extends StatelessWidget {
  const _ThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(4),
      gradient: LinearGradient(
        colors: [
          VineTheme.vineGreen.withValues(alpha: 0.3),
          Colors.blue.withValues(alpha: 0.3),
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
