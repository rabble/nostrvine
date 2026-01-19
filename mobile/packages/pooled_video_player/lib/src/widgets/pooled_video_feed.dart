import 'dart:async';
import 'dart:io';

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
    this.getCachedFile,
    super.key,
  });

  final List<PooledVideo> videos;

  final VideoFeedItemBuilder itemBuilder;

  final int initialIndex;

  final OnActiveVideoChanged? onActiveVideoChanged;

  final Axis scrollDirection;

  /// Optional cache lookup function for instant playback of cached videos.
  /// When provided, the pool manager will use local file controllers for
  /// cached videos instead of re-fetching from network.
  final File? Function(String videoId)? getCachedFile;

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

      // Immediately start prewarming current + adjacent (no debounce).
      // With parallel initialization, both can init simultaneously.
      _immediatePrewarm(_currentIndex);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updatePoolState(_currentIndex);
    });
  }

  /// Immediately prewarm current and next videos without debounce.
  /// Called on mount to ensure first videos are ready ASAP.
  /// With parallel initialization, multiple can init simultaneously.
  void _immediatePrewarm(int index) {
    if (_pool == null || widget.videos.isEmpty) return;

    final videos = widget.videos;

    // Start current + next 3 videos initialization in parallel
    // This ensures smooth scrolling for short (7s) videos
    for (var i = index; i <= index + 3 && i < videos.length; i++) {
      // Register index for distance-aware eviction
      _pool!.registerVideoIndex(videos[i].id, i);
      unawaited(
        _pool!.acquireController(
          videoId: videos[i].id,
          videoUrl: videos[i].videoUrl,
          getCachedFile: widget.getCachedFile,
        ),
      );
    }
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
    _pool!.setActiveVideo(widget.videos[index].id, index: index);
  }

  void _prewarmAdjacentVideos(int index) {
    if (_pool == null || index >= widget.videos.length) return;

    final videos = widget.videos;
    final prewarmIds = <String>[];

    // Prewarm next 3 videos ahead (for short 7s videos, users scroll quickly)
    for (var i = 1; i <= 3; i++) {
      final nextIndex = index + i;
      if (nextIndex < videos.length) {
        final nextVideo = videos[nextIndex];
        // Register index for distance-aware eviction
        _pool!.registerVideoIndex(nextVideo.id, nextIndex);
        prewarmIds.add(nextVideo.id);
        unawaited(
          _pool!.acquireController(
            videoId: nextVideo.id,
            videoUrl: nextVideo.videoUrl,
            getCachedFile: widget.getCachedFile,
          ),
        );
      }
    }

    // Prewarm 1 previous video (for scrolling back)
    if (index - 1 >= 0) {
      final prevIndex = index - 1;
      final prevVideo = videos[prevIndex];
      // Register index for distance-aware eviction
      _pool!.registerVideoIndex(prevVideo.id, prevIndex);
      prewarmIds.add(prevVideo.id);
      unawaited(
        _pool!.acquireController(
          videoId: prevVideo.id,
          videoUrl: prevVideo.videoUrl,
          getCachedFile: widget.getCachedFile,
        ),
      );
    }

    _pool!.setPrewarmVideos(prewarmIds, currentIndex: index);
  }

  void _updatePoolState(int index) {
    _setActiveVideoImmediate(index);
    _prewarmAdjacentVideos(index);
  }

  @override
  void didUpdateWidget(PooledVideoFeed oldWidget) {
    super.didUpdateWidget(oldWidget);

    // When videos list changes (e.g., pagination loads more), re-prewarm
    // adjacent videos from current position to ensure smooth playback
    if (widget.videos.length != oldWidget.videos.length) {
      // Debounce to avoid excessive prewarming during rapid updates
      _debounceTimer?.cancel();
      _debounceTimer = Timer(_prewarmDebounce, () {
        _prewarmAdjacentVideos(_currentIndex);
      });
    }
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
