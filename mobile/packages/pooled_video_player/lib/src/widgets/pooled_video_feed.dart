import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pooled_video_player/src/models/pooled_video.dart';
import 'package:pooled_video_player/src/services/video_controller_pool_manager.dart';
import 'package:pooled_video_player/src/widgets/video_pool_provider.dart';

/// Builder for video feed items.
typedef VideoFeedItemBuilder =
    Widget Function(
      BuildContext context,
      PooledVideo video,
      int index,
      // Positional boolean is acceptable here for readability.
      // ignore: avoid_positional_boolean_parameters
      bool isActive,
    );

/// Callback when active video changes.
typedef OnActiveVideoChanged = void Function(PooledVideo video, int index);

/// Vertical scrolling video feed with automatic controller preloading.
///
/// Prewarms 3 videos ahead and 1 behind for smooth scrolling.
class PooledVideoFeed extends StatefulWidget {
  /// Creates a pooled video feed widget.
  const PooledVideoFeed({
    required this.videos,
    required this.itemBuilder,
    this.initialIndex = 0,
    this.onActiveVideoChanged,
    this.scrollDirection = Axis.vertical,
    this.getCachedFile,
    super.key,
  });

  /// The list of videos to display in the feed.
  final List<PooledVideo> videos;

  /// Builder for each video item in the feed.
  final VideoFeedItemBuilder itemBuilder;

  /// The initial video index to display. Defaults to 0.
  final int initialIndex;

  /// Called when the active video changes due to scrolling.
  final OnActiveVideoChanged? onActiveVideoChanged;

  /// The scroll direction of the feed. Defaults to [Axis.vertical].
  final Axis scrollDirection;

  /// Optional cache lookup function for instant playback of cached videos.
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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_pool == null) {
      _initializePool();
    }
  }

  void _initializePool() {
    _pool = VideoPoolProvider.maybeOf(context);
    if (_pool == null) return;

    _immediatePrewarm(_currentIndex);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _updatePoolState(_currentIndex);
      }
    });
  }

  /// Prewarm current + next 3 videos on mount.
  void _immediatePrewarm(int index) {
    if (_pool == null || widget.videos.isEmpty) return;

    final videos = widget.videos;

    for (var i = index; i <= index + 3 && i < videos.length; i++) {
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

    // Prewarm next 3 videos
    for (var i = 1; i <= 3; i++) {
      final nextIndex = index + i;
      if (nextIndex < videos.length) {
        final nextVideo = videos[nextIndex];
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

    // Prewarm 1 previous video
    if (index - 1 >= 0) {
      final prevIndex = index - 1;
      final prevVideo = videos[prevIndex];
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

    if (_hasVideoListChanged(oldWidget.videos, widget.videos)) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(_prewarmDebounce, () {
        _prewarmAdjacentVideos(_currentIndex);
      });
    }
  }

  /// Check if the video list has changed (different length, content, or order).
  bool _hasVideoListChanged(
    List<PooledVideo> oldVideos,
    List<PooledVideo> newVideos,
  ) {
    return !listEquals(
      oldVideos.map((v) => v.id).toList(),
      newVideos.map((v) => v.id).toList(),
    );
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
