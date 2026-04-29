// ABOUTME: Grid widget displaying user's saved (bookmarked) videos on profile page
// ABOUTME: Shows 3-column grid with thumbnails. Own profile only — bookmarks are private.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/blocs/profile_saved_videos/profile_saved_videos_bloc.dart';
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

/// Grid widget displaying the current user's saved (bookmarked) videos.
///
/// Requires [ProfileSavedVideosBloc] to be provided in the widget tree.
/// Only used on the viewer's own profile — bookmarks are private, so there
/// is no "other user's saved" variant.
class ProfileSavedGrid extends StatefulWidget {
  const ProfileSavedGrid({super.key});

  @override
  State<ProfileSavedGrid> createState() => _ProfileSavedGridState();
}

class _ProfileSavedGridState extends State<ProfileSavedGrid>
    with ScrollPaginationMixin {
  /// Resolved from [PrimaryScrollController] provided by [NestedScrollView].
  ScrollController? _primaryScrollController;

  @override
  ScrollController get paginationScrollController => _primaryScrollController!;

  @override
  bool canLoadMore() {
    final bloc = context.read<ProfileSavedVideosBloc>();
    return bloc.state.hasMoreContent && !bloc.state.isLoadingMore;
  }

  @override
  FutureOr<void> onLoadMore() {
    context.read<ProfileSavedVideosBloc>().add(
      const ProfileSavedVideosLoadMoreRequested(),
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
    return BlocBuilder<ProfileSavedVideosBloc, ProfileSavedVideosState>(
      builder: (context, state) {
        if (state.status == ProfileSavedVideosStatus.initial ||
            state.status == ProfileSavedVideosStatus.syncing ||
            state.status == ProfileSavedVideosStatus.loading) {
          return const ProfileTabLoadingState();
        }

        if (state.status == ProfileSavedVideosStatus.failure) {
          return ProfileTabErrorState(
            message: context.l10n.profileErrorLoadingSaved,
          );
        }

        final savedVideos = state.videos;

        if (savedVideos.isEmpty) {
          return ProfileTabEmptyState(
            title: context.l10n.profileNoSavedVideosTitle,
            subtitle: context.l10n.profileSavedOwnEmpty,
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
                if (index >= savedVideos.length) {
                  return const SizedBox.shrink();
                }

                final videoEvent = savedVideos[index];
                return _SavedGridTile(
                  videoEvent: videoEvent,
                  index: index,
                  allVideos: savedVideos,
                );
              }, childCount: savedVideos.length),
            ),
            if (state.isLoadingMore) const ProfileTabLoadingMoreSliver(),
          ],
        );
      },
    );
  }
}

/// Individual saved video tile in the grid.
class _SavedGridTile extends ConsumerWidget {
  const _SavedGridTile({
    required this.videoEvent,
    required this.index,
    required this.allVideos,
  });

  final VideoEvent videoEvent;
  final int index;
  final List<VideoEvent> allVideos;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Semantics(
    label: 'saved_video_thumbnail_$index',
    child: GestureDetector(
      onTap: () {
        Log.info(
          '🎯 ProfileSavedGrid TAP: gridIndex=$index, '
          'videoId=${videoEvent.id}',
          category: LogCategory.video,
        );
        context.push(
          PooledFullscreenVideoFeedScreen.path,
          extra: PooledFullscreenVideoFeedArgs(
            videosStream: Stream.value(allVideos),
            initialIndex: index,
            removedIdsStream: ref
                .read(videoEventServiceProvider)
                .removedVideoIds,
            trafficSource: ViewTrafficSource.profile,
          ),
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
    ),
  );
}
