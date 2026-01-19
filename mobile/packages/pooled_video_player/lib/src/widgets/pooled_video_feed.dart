import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pooled_video_player/src/models/pooled_video.dart';
import 'package:pooled_video_player/src/services/video_controller_pool_manager.dart';

typedef VideoFeedItemBuilder =
    Widget Function(
      BuildContext context,
      PooledVideo video,
      int index,
      // Positional boolean for readability with 4 parameters.
      // ignore: avoid_positional_boolean_parameters
      bool isActive,
    );

typedef OnActiveVideoChanged =
    void Function(
      PooledVideo video,
      int index,
    );

/// Vertical scrolling video feed with automatic controller preloading.
class PooledVideoFeed extends StatefulWidget {
  const PooledVideoFeed({
    required this.videos,
    required this.itemBuilder,
    this.initialIndex = 0,
    this.onActiveVideoChanged,
    this.scrollDirection = Axis.vertical,
    super.key,
  });

  final List<PooledVideo> videos;

  final VideoFeedItemBuilder itemBuilder;

  final int initialIndex;

  final OnActiveVideoChanged? onActiveVideoChanged;

  final Axis scrollDirection;

  @override
  State<PooledVideoFeed> createState() => _PooledVideoFeedState();
}

class _PooledVideoFeedState extends State<PooledVideoFeed> {
  late PageController _pageController;
  int _currentIndex = 0;
  VideoControllerPoolManager? _pool;
  Timer? _debounceTimer;

  static const _prewarmDebounce = Duration(milliseconds: 150);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);

    if (VideoControllerPoolManager.isInitialized) {
      _pool = VideoControllerPoolManager.instance;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updatePoolState(_currentIndex);
    });
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);

    _setActiveVideoImmediate(index);

    _debounceTimer?.cancel();
    _debounceTimer = Timer(_prewarmDebounce, () {
      _prewarmAdjacentVideos(index);
    });

    if (index < widget.videos.length) {
      widget.onActiveVideoChanged?.call(widget.videos[index], index);
    }
  }

  void _setActiveVideoImmediate(int index) {
    if (_pool == null || index >= widget.videos.length) return;
    _pool!.setActiveVideo(widget.videos[index].id);
  }

  void _prewarmAdjacentVideos(int index) {
    if (_pool == null || index >= widget.videos.length) return;

    final videos = widget.videos;
    final prewarmIds = <String>[];

    if (index + 1 < videos.length) {
      final nextVideo = videos[index + 1];
      prewarmIds.add(nextVideo.id);
      unawaited(
        _pool!.acquireController(
          videoId: nextVideo.id,
          videoUrl: nextVideo.videoUrl,
        ),
      );
    }

    if (index - 1 >= 0) {
      final prevVideo = videos[index - 1];
      prewarmIds.add(prevVideo.id);
      unawaited(
        _pool!.acquireController(
          videoId: prevVideo.id,
          videoUrl: prevVideo.videoUrl,
        ),
      );
    }

    _pool!.setPrewarmVideos(prewarmIds);
  }

  void _updatePoolState(int index) {
    _setActiveVideoImmediate(index);
    _prewarmAdjacentVideos(index);
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _pageController,
      scrollDirection: widget.scrollDirection,
      onPageChanged: _onPageChanged,
      itemCount: widget.videos.length,
      itemBuilder: (context, index) {
        return widget.itemBuilder(
          context,
          widget.videos[index],
          index,
          index == _currentIndex,
        );
      },
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }
}
