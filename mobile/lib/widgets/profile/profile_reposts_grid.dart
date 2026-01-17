// ABOUTME: Grid widget displaying user's reposted videos on profile page
// ABOUTME: Shows 3-column grid with thumbnails and repost badge indicator

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/providers/profile_reposts_provider.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/screens/fullscreen_video_feed_screen.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Grid widget displaying user's reposted videos
class ProfileRepostsGrid extends ConsumerWidget {
  const ProfileRepostsGrid({required this.userIdHex, super.key});

  final String userIdHex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repostsAsync = ref.watch(profileRepostsProvider(userIdHex));

    return repostsAsync.when(
      data: (reposts) {
        if (reposts.isEmpty) {
          return const _RepostsEmptyState();
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
                  if (index >= reposts.length) {
                    return const SizedBox.shrink();
                  }

                  final videoEvent = reposts[index];
                  return _RepostGridTile(
                    videoEvent: videoEvent,
                    userIdHex: userIdHex,
                    index: index,
                  );
                }, childCount: reposts.length),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: VineTheme.vineGreen),
      ),
      error: (error, stack) =>
          Center(child: Text('Error loading reposts: $error')),
    );
  }
}

/// Empty state shown when user has no reposts
class _RepostsEmptyState extends StatelessWidget {
  const _RepostsEmptyState();

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
              Icon(Icons.repeat, color: Colors.grey, size: 64),
              SizedBox(height: 16),
              Text(
                'No Reposts Yet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Videos you repost will appear here',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

/// Individual repost tile in the grid with repost badge
class _RepostGridTile extends StatelessWidget {
  const _RepostGridTile({
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
        '🎯 ProfileRepostsGrid TAP: gridIndex=$index, '
        'videoId=${videoEvent.id}',
        category: LogCategory.video,
      );
      // Use ProfileRepostsFeedSource for reactive updates when loadMore fetches
      // new reposts
      context.pushVideoFeed(
        source: ProfileRepostsFeedSource(userIdHex),
        initialIndex: index,
      );
      Log.info(
        '✅ ProfileRepostsGrid: Called pushVideoFeed with '
        'ProfileRepostsFeedSource($userIdHex) at index $index',
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
              child: _RepostThumbnail(thumbnailUrl: videoEvent.thumbnailUrl),
            ),
          ),
          const Center(
            child: Icon(
              Icons.play_circle_filled,
              color: Colors.white70,
              size: 32,
            ),
          ),
          // Repost indicator badge
          Positioned(
            top: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(
                Icons.repeat,
                color: VineTheme.vineGreen,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Repost thumbnail with loading and error states
class _RepostThumbnail extends StatelessWidget {
  const _RepostThumbnail({required this.thumbnailUrl});

  final String? thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: thumbnailUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => const _RepostThumbnailPlaceholder(),
        errorWidget: (context, url, error) =>
            const _RepostThumbnailPlaceholder(),
      );
    }
    return const _RepostThumbnailPlaceholder();
  }
}

/// Gradient placeholder for repost thumbnails
class _RepostThumbnailPlaceholder extends StatelessWidget {
  const _RepostThumbnailPlaceholder();

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
