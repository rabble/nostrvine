import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_search/video_search_bloc.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/screens/search_results/widgets/section_header.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:openvine/widgets/user_name.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';
import 'package:rxdart/rxdart.dart';

/// Always-visible Videos section with a "Videos" header and optional
/// "See all" chevron.
///
/// Returns a [SliverMainAxisGroup] so the header and content participate
/// natively in the parent [CustomScrollView]'s sliver protocol.
class VideosSection extends StatelessWidget {
  const VideosSection({this.showAll = false, this.onSeeAll, super.key});

  /// When true, shows all results and hides the section header.
  final bool showAll;

  /// Called when the user taps the "Videos" header chevron.
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return SliverMainAxisGroup(
      slivers: [
        if (!showAll)
          SliverToBoxAdapter(
            child: SectionHeader(title: 'Videos', onTap: onSeeAll),
          ),
        const _VideosContent(),
      ],
    );
  }
}

class _VideosContent extends StatefulWidget {
  const _VideosContent();

  @override
  State<_VideosContent> createState() => _VideosContentState();
}

class _VideosContentState extends State<_VideosContent> {
  late final StreamController<List<VideoEvent>> _videosStreamController;

  @override
  void initState() {
    super.initState();
    _videosStreamController = StreamController<List<VideoEvent>>.broadcast();
  }

  @override
  void dispose() {
    _videosStreamController.close();
    super.dispose();
  }

  void _onVideoTap(List<VideoEvent> videos, int index) {
    context.push(
      PooledFullscreenVideoFeedScreen.path,
      extra: PooledFullscreenVideoFeedArgs(
        videosStream: _videosStreamController.stream.startWith(videos),
        initialIndex: index,
        onLoadMore: () => context.read<VideoSearchBloc>().add(
          const VideoSearchLoadMore(),
        ),
        contextTitle: 'Search Results',
        trafficSource: ViewTrafficSource.search,
        sourceDetail: context.read<VideoSearchBloc>().state.query,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<VideoSearchBloc, VideoSearchState>(
      listenWhen: (prev, curr) => prev.videos != curr.videos,
      listener: (context, state) {
        _videosStreamController.add(state.videos);
      },
      child: _VideosGrid(onVideoTap: _onVideoTap),
    );
  }
}

class _VideosGrid extends StatelessWidget {
  const _VideosGrid({required this.onVideoTap});

  final void Function(List<VideoEvent> videos, int index) onVideoTap;

  @override
  Widget build(BuildContext context) {
    final status = context.select(
      (VideoSearchBloc bloc) => bloc.state.status,
    );
    final videos = context.select(
      (VideoSearchBloc bloc) => bloc.state.videos,
    );

    if ((status == VideoSearchStatus.initial ||
            status == VideoSearchStatus.searching) &&
        videos.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Center(
            child: CircularProgressIndicator(color: VineTheme.vineGreen),
          ),
        ),
      );
    }

    if (videos.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth >= 600 ? 3 : 2;

    return SliverPadding(
      padding: const EdgeInsets.all(4),
      sliver: SliverMasonryGrid.count(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childCount: videos.length,
        itemBuilder: (context, index) {
          return SearchVideoTile(
            video: videos[index],
            onTap: () => onVideoTap(videos, index),
          );
        },
      ),
    );
  }
}

/// A video thumbnail tile for search results with author name overlay.
///
/// Shared between [VideosSection] (all-filter overview) and
/// [VideoSearchView] (dedicated videos-filter grid).
class SearchVideoTile extends StatelessWidget {
  const SearchVideoTile({
    required this.video,
    required this.onTap,
    super.key,
  });

  final VideoEvent video;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Stack(
          children: [
            VideoThumbnailWidget(video: video),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.only(
                  left: 8,
                  right: 8,
                  bottom: 6,
                  top: 24,
                ),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [VineTheme.transparent, VineTheme.scrim80],
                  ),
                ),
                child: UserName.fromPubKey(
                  video.pubkey,
                  embeddedName: video.authorName,
                  maxLines: 1,
                  style: const TextStyle(
                    color: VineTheme.whiteText,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    shadows: [
                      Shadow(
                        offset: Offset(0, 1),
                        blurRadius: 3,
                        color: VineTheme.scrim50,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
