import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_search/video_search_bloc.dart';
import 'package:openvine/mixins/scroll_pagination_mixin.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/screens/search_results/widgets/videos_section.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:rxdart/rxdart.dart';

/// Full paginated video grid for the "Videos" search results filter.
///
/// Mirrors [UserSearchView] — uses [ScrollPaginationMixin] for infinite scroll
/// and dispatches [VideoSearchLoadMore] when nearing the bottom.
class VideoSearchView extends StatelessWidget {
  const VideoSearchView({super.key});

  @override
  Widget build(BuildContext context) {
    final videos = context.select(
      (VideoSearchBloc bloc) => bloc.state.videos,
    );
    final hasMore = context.select(
      (VideoSearchBloc bloc) => bloc.state.hasMore,
    );
    final isLoadingMore = context.select(
      (VideoSearchBloc bloc) => bloc.state.isLoadingMore,
    );

    return _VideoSearchGrid(
      videos: videos,
      hasMore: hasMore,
      isLoadingMore: isLoadingMore,
    );
  }
}

class _VideoSearchGrid extends StatefulWidget {
  const _VideoSearchGrid({
    required this.videos,
    required this.hasMore,
    required this.isLoadingMore,
  });

  final List<VideoEvent> videos;
  final bool hasMore;
  final bool isLoadingMore;

  @override
  State<_VideoSearchGrid> createState() => _VideoSearchGridState();
}

class _VideoSearchGridState extends State<_VideoSearchGrid>
    with ScrollPaginationMixin {
  final _scrollController = ScrollController();
  late final StreamController<List<VideoEvent>> _videosStreamController;
  late final StreamController<bool> _hasMoreStreamController;

  @override
  ScrollController get paginationScrollController => _scrollController;

  @override
  bool canLoadMore() => widget.hasMore && !widget.isLoadingMore;

  @override
  FutureOr<void> onLoadMore() {
    context.read<VideoSearchBloc>().add(const VideoSearchLoadMore());
  }

  @override
  void initState() {
    super.initState();
    initPagination();
    _videosStreamController = StreamController<List<VideoEvent>>.broadcast();
    _hasMoreStreamController = StreamController<bool>.broadcast();
  }

  @override
  void didUpdateWidget(_VideoSearchGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videos != widget.videos) {
      _videosStreamController.add(widget.videos);
    }
    if (oldWidget.hasMore != widget.hasMore) {
      _hasMoreStreamController.add(widget.hasMore);
    }
  }

  @override
  void dispose() {
    disposePagination();
    _videosStreamController.close();
    _hasMoreStreamController.close();
    _scrollController.dispose();
    super.dispose();
  }

  void _onVideoTap(int index) {
    context.push(
      PooledFullscreenVideoFeedScreen.path,
      extra: PooledFullscreenVideoFeedArgs(
        videosStream: _videosStreamController.stream.startWith(widget.videos),
        initialIndex: index,
        onLoadMore: () => context.read<VideoSearchBloc>().add(
          const VideoSearchLoadMore(),
        ),
        hasMoreStream: _hasMoreStreamController.stream.startWith(
          widget.hasMore,
        ),
        contextTitle: 'Search Results',
        trafficSource: ViewTrafficSource.search,
        sourceDetail: context.read<VideoSearchBloc>().state.query,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.videos.isEmpty) {
      return const Center(
        child: Text(
          'No videos found',
          style: TextStyle(color: VineTheme.lightText),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final crossAxisCount = screenWidth >= 600 ? 3 : 2;
    final itemCount = widget.videos.length + (widget.isLoadingMore ? 1 : 0);

    return MasonryGridView.count(
      controller: _scrollController,
      padding: const EdgeInsets.all(4),
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        if (index >= widget.videos.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: CircularProgressIndicator(color: VineTheme.vineGreen),
            ),
          );
        }
        return SearchVideoTile(
          video: widget.videos[index],
          onTap: () => _onVideoTap(index),
        );
      },
    );
  }
}
