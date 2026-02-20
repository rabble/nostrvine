// ABOUTME: Grid widget displaying user's reposted videos on profile page
// ABOUTME: Shows 3-column grid with thumbnails and repost badge indicator

import 'package:cached_network_image/cached_network_image.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/blocs/profile_reposted_videos/profile_reposted_videos_bloc.dart';
import 'package:openvine/screens/fullscreen_video_feed_screen.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Grid widget displaying user's reposted videos
///
/// Requires [ProfileRepostedVideosBloc] to be provided in the widget tree.
class ProfileRepostsGrid extends StatelessWidget {
  const ProfileRepostsGrid({required this.isOwnProfile, super.key});

  /// Whether this is the current user's own profile.
  final bool isOwnProfile;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileRepostedVideosBloc, ProfileRepostedVideosState>(
      builder: (context, state) {
        if (state.status == ProfileRepostedVideosStatus.initial ||
            state.status == ProfileRepostedVideosStatus.syncing ||
            state.status == ProfileRepostedVideosStatus.loading) {
          return const Center(
            child: CircularProgressIndicator(color: VineTheme.vineGreen),
          );
        }

        if (state.status == ProfileRepostedVideosStatus.failure) {
          return const Center(
            child: Text(
              'Error loading reposted videos',
              style: TextStyle(color: Colors.white),
            ),
          );
        }

        final repostedVideos = state.videos;

        if (repostedVideos.isEmpty) {
          return _RepostsEmptyState(isOwnProfile: isOwnProfile);
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
                context.read<ProfileRepostedVideosBloc>().add(
                  const ProfileRepostedVideosLoadMoreRequested(),
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
                    if (index >= repostedVideos.length) {
                      return const SizedBox.shrink();
                    }

                    final videoEvent = repostedVideos[index];
                    return _RepostGridTile(
                      videoEvent: videoEvent,
                      index: index,
                      allVideos: repostedVideos,
                    );
                  }, childCount: repostedVideos.length),
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

/// Empty state shown when user has no reposts
class _RepostsEmptyState extends StatelessWidget {
  const _RepostsEmptyState({required this.isOwnProfile});

  /// Whether this is the current user's own profile.
  final bool isOwnProfile;

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
              const Icon(Icons.repeat, color: Colors.grey, size: 64),
              const SizedBox(height: 16),
              const Text(
                'No Reposts Yet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isOwnProfile
                    ? 'Videos you repost will appear here'
                    : 'Videos they repost will appear here',
                style: const TextStyle(color: Colors.grey, fontSize: 14),
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
        '🎯 ProfileRepostsGrid TAP: gridIndex=$index, '
        'videoId=${videoEvent.id}',
        category: LogCategory.video,
      );

      context.push(
        FullscreenVideoFeedScreen.path,
        extra: FullscreenVideoFeedArgs(
          source: StaticFeedSource(allVideos),
          initialIndex: index,
        ),
      );

      Log.info(
        '✅ ProfileRepostsGrid: Called pushVideoFeed with StaticFeedSource at '
        'index $index',
        category: LogCategory.video,
      );
    },
    child: ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: DecoratedBox(
        decoration: BoxDecoration(color: VineTheme.cardBackground),
        child: _RepostThumbnail(thumbnailUrl: videoEvent.thumbnailUrl),
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

/// Flat color placeholder for repost thumbnails
class _RepostThumbnailPlaceholder extends StatelessWidget {
  const _RepostThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(4),
      color: VineTheme.surfaceContainer,
    ),
  );
}
