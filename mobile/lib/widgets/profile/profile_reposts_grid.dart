// ABOUTME: Grid widget displaying user's reposted videos on profile page
// ABOUTME: Shows 3-column grid with thumbnails and repost badge indicator

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/blocs/profile_reposted_videos/profile_reposted_videos_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/mixins/scroll_pagination_mixin.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:openvine/widgets/profile/profile_tab_empty_state.dart';
import 'package:openvine/widgets/profile/profile_tab_error_state.dart';
import 'package:openvine/widgets/profile/profile_tab_loading_more_sliver.dart';
import 'package:openvine/widgets/profile/profile_tab_loading_state.dart';
import 'package:openvine/widgets/profile/profile_tab_thumbnail.dart';
import 'package:unified_logger/unified_logger.dart';

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
          return ProfileTabErrorState(
            message: context.l10n.profileErrorLoadingReposts,
          );
        }

        final repostedVideos = state.videos;

        if (repostedVideos.isEmpty) {
          return ProfileTabEmptyState(
            title: context.l10n.profileNoRepostsTitle,
            subtitle: widget.isOwnProfile
                ? context.l10n.profileRepostsOwnEmpty
                : context.l10n.profileRepostsOtherEmpty,
          );
        }

        return CustomScrollView(
          physics: const ClampingScrollPhysics(),
          slivers: [
            SliverGrid(
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
            if (state.isLoadingMore) const ProfileTabLoadingMoreSliver(),
          ],
        );
      },
    );
  }
}

/// Individual repost tile in the grid with repost badge
class _RepostGridTile extends ConsumerWidget {
  const _RepostGridTile({
    required this.videoEvent,
    required this.index,
    required this.allVideos,
  });

  final VideoEvent videoEvent;
  final int index;
  final List<VideoEvent> allVideos;

  @override
  Widget build(BuildContext context, WidgetRef ref) => GestureDetector(
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
          removedIdsStream: ref.read(videoEventServiceProvider).removedVideoIds,
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
        child: ProfileTabThumbnail(
          thumbnailUrl: videoEvent.thumbnailUrl,
          blurhash: videoEvent.blurhash,
        ),
      ),
    ),
  );
}
