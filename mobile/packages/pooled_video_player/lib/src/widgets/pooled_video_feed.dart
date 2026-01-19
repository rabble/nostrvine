import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pooled_video_player/src/models/pooled_video.dart';
import 'package:pooled_video_player/src/services/video_controller_pool_manager.dart';

/// Builder for feed items with video, index, and active state.
typedef VideoFeedItemBuilder =
    Widget Function(
      BuildContext context,
      PooledVideo video,
      int index,
      // Its much easier to maintain readability with a positional boolean here
      // ignore: avoid_positional_boolean_parameters
      bool isActive,
    );

/// Callback for when the active video changes
typedef OnActiveVideoChanged =
    void Function(
      PooledVideo video,
      int index,
    );

/// Vertical scrolling video feed with automatic controller preloading.
///
/// ```dart
/// PooledVideoFeed(
///   videos: myVideos,
///   itemBuilder: (context, video, index, isActive) {
///     return MyCustomVideoItem(video: video, isActive: isActive);
///   },
/// )
/// ```
class PooledVideoFeed extends StatefulWidget {
  const PooledVideoFeed({
    required this.videos,
    required this.itemBuilder,
    this.initialIndex = 0,
    this.onActiveVideoChanged,
    this.scrollDirection = Axis.vertical,
    super.key,
  });

  /// List of videos to display (any PooledVideo implementation)
  final List<PooledVideo> videos;

  /// Builder for each video item
  final VideoFeedItemBuilder itemBuilder;

  /// Initial video index to start from
  final int initialIndex;

  /// Callback when the active video changes
  final OnActiveVideoChanged? onActiveVideoChanged;

  /// Scroll direction (vertical or horizontal)
  final Axis scrollDirection;

  @override
  State<PooledVideoFeed> createState() => _PooledVideoFeedState();
}

class _PooledVideoFeedState extends State<PooledVideoFeed> {
  late PageController _pageController;
  int _currentIndex = 0;
  VideoControllerPoolManager? _pool;
  Timer? _debounceTimer;

  /// Debounce duration for prewarm calls during rapid scrolling
  static const _prewarmDebounce = Duration(milliseconds: 150);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);

    if (VideoControllerPoolManager.isInitialized) {
      _pool = VideoControllerPoolManager.instance;
    }

    // Initial preload after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updatePoolState(_currentIndex);
    });
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);

    // Immediately set active video (no debounce - this is critical for playback)
    _setActiveVideoImmediate(index);

    // Debounce prewarm to prevent queue buildup during rapid scrolling
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_prewarmDebounce, () {
      _prewarmAdjacentVideos(index);
    });

    // Notify consumers
    if (index < widget.videos.length) {
      widget.onActiveVideoChanged?.call(widget.videos[index], index);
    }
  }

  /// Set active video immediately (no debounce)
  void _setActiveVideoImmediate(int index) {
    if (_pool == null || index >= widget.videos.length) return;
    _pool!.setActiveVideo(widget.videos[index].id);
  }

  /// Prewarm adjacent videos (debounced to prevent queue buildup)
  void _prewarmAdjacentVideos(int index) {
    if (_pool == null || index >= widget.videos.length) return;

    final videos = widget.videos;
    final prewarmIds = <String>[];

    // Next video (higher priority) - actively request controller
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

    // Previous video (lower priority) - actively request controller
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
