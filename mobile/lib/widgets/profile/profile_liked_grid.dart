// ABOUTME: Grid widget displaying user's liked videos on profile page
// ABOUTME: Shows 3-column grid with thumbnails and heart badge indicator

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/blocs/profile_liked_videos/profile_liked_videos_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/mixins/scroll_pagination_mixin.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:openvine/widgets/profile/profile_tab_empty_state.dart';
import 'package:openvine/widgets/profile/profile_tab_error_state.dart';
import 'package:openvine/widgets/profile/profile_tab_loading_more_sliver.dart';
import 'package:openvine/widgets/profile/profile_tab_loading_state.dart';
import 'package:openvine/widgets/profile/profile_tab_thumbnail.dart';
import 'package:unified_logger/unified_logger.dart';

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
  /// Resolved from [PrimaryScrollController] provided by [NestedScrollView].
  ScrollController? _primaryScrollController;

  @override
  ScrollController get paginationScrollController => _primaryScrollController!;

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
    return BlocBuilder<ProfileLikedVideosBloc, ProfileLikedVideosState>(
      builder: (context, state) {
        if (state.status == ProfileLikedVideosStatus.initial ||
            state.status == ProfileLikedVideosStatus.syncing ||
            state.status == ProfileLikedVideosStatus.loading) {
          return const ProfileTabLoadingState();
        }

        if (state.status == ProfileLikedVideosStatus.failure) {
          return ProfileTabErrorState(
            message: context.l10n.profileErrorLoadingLiked,
          );
        }

        final likedVideos = state.videos;

        if (likedVideos.isEmpty) {
          return ProfileTabEmptyState(
            title: context.l10n.profileNoLikedVideosTitle,
            subtitle: widget.isOwnProfile
                ? context.l10n.profileLikedOwnEmpty
                : context.l10n.profileLikedOtherEmpty,
          );
        }

        return CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            SliverGrid(
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
            if (state.isLoadingMore) const ProfileTabLoadingMoreSliver(),
          ],
        );
      },
    );
  }
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
          child: ProfileTabThumbnail(thumbnailUrl: videoEvent.thumbnailUrl),
        ),
      ),
    ),
  );
}
