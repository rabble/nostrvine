// ABOUTME: Grid widget displaying user's reposted videos on profile page
// ABOUTME: Shows 3-column grid with thumbnails and repost badge indicator

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/blocs/profile_reposted_videos/profile_reposted_videos_bloc.dart';
import 'package:openvine/mixins/scroll_pagination_mixin.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

/// Grid widget displaying user's reposted videos
///
/// Requires [ProfileRepostedVideosBloc] to be provided in the widget tree.
class ProfileRepostsGrid extends StatefulWidget {
  const ProfileRepostsGrid({required this.isOwnProfile, super.key});

  /// Whether this is the current user's own profile.
  final bool isOwnProfile;

  @override
  State<ProfileRepostsGrid> createState() => _ProfileRepostsGridState();
}

class _ProfileRepostsGridState extends State<ProfileRepostsGrid>
    with ScrollPaginationMixin {
  /// Resolved from [PrimaryScrollController] provided by [NestedScrollView].
  ScrollController? _primaryScrollController;

  @override
  ScrollController get paginationScrollController => _primaryScrollController!;

  @override
  bool canLoadMore() {
    final bloc = context.read<ProfileRepostedVideosBloc>();
    return bloc.state.hasMoreContent && !bloc.state.isLoadingMore;
  }

  @override
  FutureOr<void> onLoadMore() {
    context.read<ProfileRepostedVideosBloc>().add(
      const ProfileRepostedVideosLoadMoreRequested(),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final primary = PrimaryScrollController.of(context);
    if (_primaryScrollController != primary) {
      if (_primaryScrollController != null) disposePagination();
      _primaryScrollController = primary;
      initPagination();
    }
  }

  @override
  void dispose() {
    disposePagination();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileRepostedVideosBloc, ProfileRepostedVideosState>(
      builder: (context, state) {
        if (state.status == ProfileRepostedVideosStatus.initial ||
            state.status == ProfileRepostedVideosStatus.syncing ||
            state.status == ProfileRepostedVideosStatus.loading) {
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

        if (state.status == ProfileRepostedVideosStatus.failure) {
          return const CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    'Error loading reposted videos',
                    style: TextStyle(color: VineTheme.whiteText),
                  ),
                ),
              ),
            ],
          );
        }

        final repostedVideos = state.videos;

        if (repostedVideos.isEmpty) {
          return _RepostsEmptyState(isOwnProfile: widget.isOwnProfile);
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.repeat, color: VineTheme.lightText, size: 64),
                const SizedBox(height: 16),
                const Text(
                  'No Reposts Yet',
                  textAlign: .center,
                  style: TextStyle(
                    color: VineTheme.whiteText,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isOwnProfile
                      ? 'Videos you repost will appear here'
                      : 'Videos they repost will appear here',
                  textAlign: .center,
                  style: const TextStyle(
                    color: VineTheme.lightText,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
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
        PooledFullscreenVideoFeedScreen.path,
        extra: PooledFullscreenVideoFeedArgs(
          videosStream: Stream.value(allVideos),
          initialIndex: index,
          trafficSource: ViewTrafficSource.profile,
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
        decoration: const BoxDecoration(color: VineTheme.cardBackground),
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
      return VineCachedImage(
        imageUrl: thumbnailUrl!,
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
