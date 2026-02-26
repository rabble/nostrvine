// ABOUTME: Grid widget displaying user's collab videos on profile page
// ABOUTME: Shows 3-column grid with thumbnails for videos where user
// ABOUTME: is tagged as a collaborator

import 'package:cached_network_image/cached_network_image.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/blocs/profile_collab_videos/profile_collab_videos_bloc.dart';
import 'package:openvine/mixins/grid_prefetch_mixin.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Grid widget displaying user's collab videos.
///
/// Requires [ProfileCollabVideosBloc] to be provided in the widget tree.
class ProfileCollabsGrid extends StatefulWidget {
  const ProfileCollabsGrid({required this.isOwnProfile, super.key});

  /// Whether this is the current user's own profile.
  final bool isOwnProfile;

  @override
  State<ProfileCollabsGrid> createState() => _ProfileCollabsGridState();
}

class _ProfileCollabsGridState extends State<ProfileCollabsGrid>
    with GridPrefetchMixin {
  List<VideoEvent>? _lastPrefetchedVideos;

  void _prefetchIfNeeded(List<VideoEvent> videos) {
    if (videos.isEmpty || videos == _lastPrefetchedVideos) return;
    _lastPrefetchedVideos = videos;
    prefetchGridVideos(videos);
  }

  void _onVideoTapped(int index, List<VideoEvent> allVideos) {
    Log.info(
      'ProfileCollabsGrid TAP: gridIndex=$index, '
      'videoId=${allVideos[index].id}',
      category: LogCategory.video,
    );

    // Pre-warm adjacent videos before navigation
    prefetchAroundIndex(index, allVideos);

    context.push(
      PooledFullscreenVideoFeedScreen.path,
      extra: PooledFullscreenVideoFeedArgs(
        videosStream: Stream.value(allVideos),
        initialIndex: index,
        trafficSource: ViewTrafficSource.profile,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCollabVideosBloc, ProfileCollabVideosState>(
      builder: (context, state) {
        if (state.status == ProfileCollabVideosStatus.initial ||
            state.status == ProfileCollabVideosStatus.loading) {
          return const CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: VineTheme.vineGreen),
                ),
              ),
            ],
          );
        }

        if (state.status == ProfileCollabVideosStatus.failure) {
          return const CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    'Error loading collab videos',
                    style: TextStyle(color: VineTheme.whiteText),
                  ),
                ),
              ),
            ],
          );
        }

        final collabVideos = state.videos;

        if (collabVideos.isEmpty) {
          return _CollabsEmptyState(isOwnProfile: widget.isOwnProfile);
        }

        // Prefetch visible grid videos
        _prefetchIfNeeded(collabVideos);

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
                context.read<ProfileCollabVideosBloc>().add(
                  const ProfileCollabVideosLoadMoreRequested(),
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
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    if (index >= collabVideos.length) {
                      return const SizedBox.shrink();
                    }

                    final videoEvent = collabVideos[index];
                    return _CollabGridTile(
                      videoEvent: videoEvent,
                      index: index,
                      onTap: () => _onVideoTapped(index, collabVideos),
                    );
                  }, childCount: collabVideos.length),
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

/// Empty state shown when user has no collab videos.
class _CollabsEmptyState extends StatelessWidget {
  const _CollabsEmptyState({required this.isOwnProfile});

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
              const Icon(
                Icons.people_outline,
                color: VineTheme.onSurfaceMuted,
                size: 64,
              ),
              const SizedBox(height: 16),
              const Text(
                'No Collabs Yet',
                style: TextStyle(
                  color: VineTheme.whiteText,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isOwnProfile
                    ? 'Videos you collaborate on will appear here'
                    : 'Videos they collaborate on will appear here',
                style: const TextStyle(
                  color: VineTheme.onSurfaceMuted,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

/// Individual collab tile in the grid.
class _CollabGridTile extends StatelessWidget {
  const _CollabGridTile({
    required this.videoEvent,
    required this.index,
    required this.onTap,
  });

  final VideoEvent videoEvent;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: DecoratedBox(
        decoration: const BoxDecoration(color: VineTheme.cardBackground),
        child: _CollabThumbnail(thumbnailUrl: videoEvent.thumbnailUrl),
      ),
    ),
  );
}

/// Collab thumbnail with loading and error states.
class _CollabThumbnail extends StatelessWidget {
  const _CollabThumbnail({required this.thumbnailUrl});

  final String? thumbnailUrl;

  @override
  Widget build(BuildContext context) {
    if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: thumbnailUrl!,
        fit: BoxFit.cover,
        placeholder: (context, url) => const _CollabThumbnailPlaceholder(),
        errorWidget: (context, url, error) =>
            const _CollabThumbnailPlaceholder(),
      );
    }
    return const _CollabThumbnailPlaceholder();
  }
}

/// Flat color placeholder for collab thumbnails.
class _CollabThumbnailPlaceholder extends StatelessWidget {
  const _CollabThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(4),
      color: VineTheme.surfaceContainer,
    ),
  );
}
