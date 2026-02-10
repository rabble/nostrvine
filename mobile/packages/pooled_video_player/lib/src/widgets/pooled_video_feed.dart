import 'package:flutter/material.dart';

import 'package:pooled_video_player/src/controllers/player_pool.dart';
import 'package:pooled_video_player/src/controllers/video_feed_controller.dart';
import 'package:pooled_video_player/src/models/video_item.dart';
import 'package:pooled_video_player/src/widgets/video_pool_provider.dart';

/// Builder for video feed items.
typedef VideoFeedItemBuilder =
    Widget Function(
      BuildContext context,
      VideoItem video,
      int index, {
      required bool isActive,
    });

/// Callback when active video changes.
typedef OnActiveVideoChanged = void Function(VideoItem video, int index);

/// Vertical/horizontal scrolling video feed with automatic preloading.
class PooledVideoFeed extends StatefulWidget {
  /// Creates a pooled video feed widget.
  ///
  /// If [pool] is not provided, uses [PlayerPool.instance].
  const PooledVideoFeed({
    required this.videos,
    required this.itemBuilder,
    this.pool,
    this.controller,
    this.initialIndex = 0,
    this.scrollDirection = Axis.vertical,
    this.preloadAhead = 2,
    this.preloadBehind = 1,
    this.onActiveVideoChanged,
    this.onNearEnd,
    this.nearEndThreshold = 3,
    super.key,
  });

  /// The shared player pool. If null, uses [PlayerPool.instance].
  final PlayerPool? pool;

  /// The list of videos to display.
  final List<VideoItem> videos;

  /// External controller for full control over video management.
  final VideoFeedController? controller;

  /// Builder for each video item in the feed.
  final VideoFeedItemBuilder itemBuilder;

  /// The initial video index to display.
  final int initialIndex;

  /// The scroll direction of the feed.
  final Axis scrollDirection;

  /// Number of videos to preload ahead.
  final int preloadAhead;

  /// Number of videos to preload behind.
  final int preloadBehind;

  /// Called when the active video changes.
  final OnActiveVideoChanged? onActiveVideoChanged;

  /// Called when the user is near the end of the list.
  final void Function(int index)? onNearEnd;

  /// How many videos from the end should trigger [onNearEnd].
  final int nearEndThreshold;

  @override
  State<PooledVideoFeed> createState() => PooledVideoFeedState();
}

/// State for [PooledVideoFeed].
class PooledVideoFeedState extends State<PooledVideoFeed> {
  late VideoFeedController _controller;
  late PageController _pageController;
  late PlayerPool _effectivePool;
  bool _ownsController = false;
  int _currentIndex = 0;
  int _videoCount = 0;

  /// The feed controller.
  VideoFeedController get controller => _controller;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);

    // Use provided pool or fall back to singleton
    _effectivePool = widget.pool ?? PlayerPool.instance;

    if (widget.controller != null) {
      _controller = widget.controller!;
      _ownsController = false;
    } else {
      _controller = VideoFeedController(
        videos: widget.videos,
        pool: _effectivePool,
        initialIndex: _currentIndex,
        preloadAhead: widget.preloadAhead,
        preloadBehind: widget.preloadBehind,
      );
      _ownsController = true;
    }

    _videoCount = _controller.videoCount;
    _controller.addListener(_onControllerChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _controller.play();
      }
    });
  }

  void _onControllerChanged() {
    if (_controller.videoCount != _videoCount) {
      setState(() {
        _videoCount = _controller.videoCount;
      });
    }
  }

  @override
  void didUpdateWidget(PooledVideoFeed oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.controller != null &&
        widget.controller != oldWidget.controller) {
      _controller.removeListener(_onControllerChanged);
      if (_ownsController) {
        _controller.dispose();
      }
      _controller = widget.controller!;
      _ownsController = false;
      _videoCount = _controller.videoCount;
      _controller.addListener(_onControllerChanged);
    }

    if (_ownsController && widget.videos != oldWidget.videos) {
      final newVideos = widget.videos
          .where((v) => !oldWidget.videos.contains(v))
          .toList();
      if (newVideos.isNotEmpty) {
        _controller.addVideos(newVideos);
      }
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    _controller.onPageChanged(index);

    if (index < _controller.videoCount) {
      widget.onActiveVideoChanged?.call(_controller.videos[index], index);
    }

    final distanceFromEnd = _controller.videoCount - index - 1;
    if (distanceFromEnd <= widget.nearEndThreshold) {
      widget.onNearEnd?.call(index);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _pageController.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VideoPoolProvider(
      pool: _effectivePool,
      feedController: _controller,
      child: PageView.builder(
        controller: _pageController,
        scrollDirection: widget.scrollDirection,
        onPageChanged: _onPageChanged,
        itemCount: _videoCount,
        itemBuilder: (context, index) {
          return widget.itemBuilder(
            context,
            _controller.videos[index],
            index,
            isActive: index == _currentIndex,
          );
        },
      ),
    );
  }
}
