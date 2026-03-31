// ABOUTME: Grid widget displaying user's liked videos on profile page
// ABOUTME: Shows 3-column grid with thumbnails and heart badge indicator

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/blocs/profile_liked_videos/profile_liked_videos_bloc.dart';
import 'package:openvine/mixins/scroll_pagination_mixin.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/vine_cached_image.dart';

/// Grid widget displaying user's liked videos
///
/// Requires [ProfileLikedVideosBloc] to be provided in the widget tree.
class ProfileLikedGrid extends StatefulWidget {
  const ProfileLikedGrid({required this.isOwnProfile, super.key});

  /// Whether this is the current user's own profile.
  final bool isOwnProfile;

  @override
  State<ProfileLikedGrid> createState() => _ProfileLikedGridState();
}

class _ProfileLikedGridState extends State<ProfileLikedGrid>
    with ScrollPaginationMixin {
  final ScrollController _scrollController = ScrollController();

  @override
  ScrollController get paginationScrollController => _scrollController;

  @override
  bool canLoadMore() {
    final bloc = context.read<ProfileLikedVideosBloc>();
    return bloc.state.hasMoreContent && !bloc.state.isLoadingMore;
  }

  @override
  FutureOr<void> onLoadMore() {
    context.read<ProfileLikedVideosBloc>().add(
      const ProfileLikedVideosLoadMoreRequested(),
    );
  }

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
    return BlocBuilder<ProfileLikedVideosBloc, ProfileLikedVideosState>(
      builder: (context, state) {
        if (state.status == ProfileLikedVideosStatus.initial ||
            state.status == ProfileLikedVideosStatus.syncing ||
            state.status == ProfileLikedVideosStatus.loading) {
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

        if (state.status == ProfileLikedVideosStatus.failure) {
          return const CustomScrollView(
            slivers: [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    'Error loading liked videos',
                    style: TextStyle(color: VineTheme.whiteText),
                  ),
                ),
              ),
            ],
          );
        }

        final likedVideos = state.videos;

        if (likedVideos.isEmpty) {
          return _LikedEmptyState(isOwnProfile: widget.isOwnProfile);
        }

        return CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(4),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 4,
                  mainAxisSpacing: 4,
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

/// Empty state shown when user has no liked videos
class _LikedEmptyState extends StatelessWidget {
  const _LikedEmptyState({required this.isOwnProfile});

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
                const Icon(
                  Icons.favorite_border,
                  color: VineTheme.lightText,
                  size: 64,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No Liked Videos Yet',
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
                      ? 'Videos you like will appear here'
                      : 'Videos they like will appear here',
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
  Widget build(BuildContext context) => Semantics(
    label: 'liked_video_thumbnail_$index',
    child: GestureDetector(
      onTap: () {
        Log.info(
          '🎯 ProfileLikedGrid TAP: gridIndex=$index, '
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
          '✅ ProfileLikedGrid: Called pushVideoFeed with '
          'LikedVideosFeedSource at index $index',
          category: LogCategory.video,
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: DecoratedBox(
          decoration: const BoxDecoration(color: VineTheme.cardBackground),
          child: _LikedThumbnail(thumbnailUrl: videoEvent.thumbnailUrl),
        ),
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
      return VineCachedImage(
        imageUrl: thumbnailUrl!,
        placeholder: (context, url) => const _LikedThumbnailPlaceholder(),
        errorWidget: (context, url, error) =>
            const _LikedThumbnailPlaceholder(),
      );
    }
    return const _LikedThumbnailPlaceholder();
  }
}

/// Flat color placeholder for liked video thumbnails
class _LikedThumbnailPlaceholder extends StatelessWidget {
  const _LikedThumbnailPlaceholder();

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(4),
      color: VineTheme.surfaceContainer,
    ),
  );
}
