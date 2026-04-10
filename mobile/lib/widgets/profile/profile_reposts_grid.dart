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
import 'package:openvine/widgets/profile/profile_tab_empty_state.dart';
import 'package:openvine/widgets/profile/profile_tab_error_state.dart';
import 'package:openvine/widgets/profile/profile_tab_loading_more_sliver.dart';
import 'package:openvine/widgets/profile/profile_tab_loading_state.dart';
import 'package:openvine/widgets/profile/profile_tab_thumbnail.dart';

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
          return const ProfileTabLoadingState();
        }

        if (state.status == ProfileRepostedVideosStatus.failure) {
          return const ProfileTabErrorState(
            message: 'Error loading reposted videos',
          );
        }

        final repostedVideos = state.videos;

        if (repostedVideos.isEmpty) {
          return ProfileTabEmptyState(
            icon: DivineIconName.repeat,
            title: 'No Reposts Yet',
            subtitle: widget.isOwnProfile
                ? 'Videos you repost will appear here'
                : 'Videos they repost will appear here',
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
            if (state.isLoadingMore) const ProfileTabLoadingMoreSliver(),
          ],
        );
      },
    );
  }
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
        child: ProfileTabThumbnail(thumbnailUrl: videoEvent.thumbnailUrl),
      ),
    ),
  );
}
