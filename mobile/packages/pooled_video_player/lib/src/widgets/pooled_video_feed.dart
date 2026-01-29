import 'dart:async';

import 'package:flutter/material.dart';

import 'package:pooled_video_player/src/controllers/player_pool_manager.dart';
import 'package:pooled_video_player/src/controllers/video_feed_controller.dart';
import 'package:pooled_video_player/src/models/player_lease.dart';
import 'package:pooled_video_player/src/models/video_item.dart';
import 'package:pooled_video_player/src/widgets/video_pool_provider.dart';

/// Builder for video feed items.
///
/// Parameters:
/// - [context]: The build context
/// - [video]: The video item data
/// - [index]: The index in the feed
/// - [isActive]: Whether this is the currently visible video
typedef VideoFeedItemBuilder =
    Widget Function(
      BuildContext context,
      VideoItem video,
      int index, {
      required bool isActive,
    });

/// Callback when active video changes.
typedef OnActiveVideoChanged = void Function(VideoItem video, int index);

/// Callback when a video is tapped for navigation (e.g., to detail page).
///
/// Parameters:
/// - [video]: The video that was tapped
/// - [index]: The index of the video
/// - [lease]: The player lease (if available) for seamless handoff
typedef OnVideoTapped =
    void Function(
      VideoItem video,
      int index,
      PlayerLease? lease,
    );

/// Vertical/horizontal scrolling video feed with automatic controller preloading.
///
/// Handles prewarming videos ahead and behind for smooth scrolling.
/// Uses builder pattern for UI flexibility.
///
/// The feed requires [PlayerPoolManager] to be initialized. Initialize it once
/// at app startup:
/// ```dart
/// await PlayerPoolManager.initialize();
/// ```
///
/// Example:
/// ```dart
/// PooledVideoFeed(
///   feedId: 'main-feed',
///   videos: myVideos,
///   itemBuilder: (context, video, index, {required isActive}) {
///     return PooledVideoPlayer(
///       index: index,
///       videoBuilder: (context, videoController, player) => Video(
///         controller: videoController,
///         fit: BoxFit.cover,
///       ),
///     );
///   },
///   onActiveVideoChanged: (video, index) {
///     print('Now playing: ${video.title}');
///   },
///   onVideoTapped: (video, index, lease) {
///     // Navigate to detail page with seamless handoff
///     Navigator.push(context, MaterialPageRoute(
///       builder: (_) => VideoDetailPage(video: video, lease: lease),
///     ));
///   },
/// )
/// ```
class PooledVideoFeed extends StatefulWidget {
  /// Creates a pooled video feed widget.
  ///
  /// [PlayerPoolManager.initialize] must have been called before using
  /// this widget.
  const PooledVideoFeed({
    required this.feedId,
    required this.videos,
    required this.itemBuilder,
    this.controller,
    this.initialIndex = 0,
    this.scrollDirection = Axis.vertical,
    this.preloadAhead,
    this.preloadBehind,
    this.onActiveVideoChanged,
    this.onVideoTapped,
    this.onNearEnd,
    this.nearEndThreshold = 3,
    super.key,
  });

  /// Unique identifier for this feed.
  ///
  /// Must be unique across all feeds in the app. Used to track which
  /// players belong to which feed.
  final String feedId;

  /// The list of videos to display in this feed.
  final List<VideoItem> videos;

  /// External controller for full control over video management.
  ///
  /// If provided, the feed will use this controller instead of creating
  /// its own. The caller is responsible for disposing the controller.
  final VideoFeedController? controller;

  /// Builder for each video item in the feed.
  final VideoFeedItemBuilder itemBuilder;

  /// The initial video index to display. Defaults to 0.
  final int initialIndex;

  /// The scroll direction of the feed. Defaults to [Axis.vertical].
  final Axis scrollDirection;

  /// Number of videos to preload ahead. Defaults to config value.
  final int? preloadAhead;

  /// Number of videos to preload behind. Defaults to config value.
  final int? preloadBehind;

  /// Called when the active video changes due to scrolling.
  final OnActiveVideoChanged? onActiveVideoChanged;

  /// Called when a video is tapped.
  ///
  /// Use this to navigate to a detail page with seamless handoff.
  /// The [PlayerLease] can be used for uninterrupted playback.
  final OnVideoTapped? onVideoTapped;

  /// Called when the user is near the end of the list.
  /// Use this to trigger lazy loading of more videos.
  final void Function(int index)? onNearEnd;

  /// How many videos from the end should trigger [onNearEnd].
  final int nearEndThreshold;

  @override
  State<PooledVideoFeed> createState() => PooledVideoFeedState();
}

/// State for [PooledVideoFeed].
///
/// Exposes [controller] and [acceptReturnedLease] for advanced usage.
class PooledVideoFeedState extends State<PooledVideoFeed> {
  late VideoFeedController _controller;
  late PageController _pageController;
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

    if (widget.controller != null) {
      // Use provided controller
      _controller = widget.controller!;
      _ownsController = false;
    } else {
      // Create our own controller
      _controller = VideoFeedController(
        feedId: widget.feedId,
        videos: widget.videos,
        preloadAhead: widget.preloadAhead,
        preloadBehind: widget.preloadBehind,
      );
      _ownsController = true;
    }

    _videoCount = _controller.videoCount;
    _controller.addListener(_onControllerChanged);

    // Start playing the first video after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_controller.getPlayer(_currentIndex)?.play());
      }
    });
  }

  void _onControllerChanged() {
    // Only rebuild if video count changed (videos added/removed)
    if (_controller.videoCount != _videoCount) {
      setState(() {
        _videoCount = _controller.videoCount;
      });
    }
  }

  @override
  void didUpdateWidget(PooledVideoFeed oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If controller was provided externally and changed
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

    // If videos changed and we own the controller, add new videos
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

    // Notify active video changed callback
    if (index < _controller.videoCount) {
      widget.onActiveVideoChanged?.call(_controller.videos[index], index);
    }

    // Check if near end for lazy loading trigger
    final distanceFromEnd = _controller.videoCount - index - 1;
    if (distanceFromEnd <= widget.nearEndThreshold) {
      widget.onNearEnd?.call(index);
    }
  }

  /// Handle tap on a video for navigation with seamless handoff.
  void _onVideoTapped(int index) {
    if (widget.onVideoTapped == null) return;

    final video = _controller.videos[index];
    final lease = _controller.extractPlayerForHandoff(index);
    widget.onVideoTapped!(video, index, lease);
  }

  /// Accept a player lease being returned from a detail page.
  ///
  /// Call this when the user navigates back from a detail page to
  /// restore seamless playback in the feed.
  Future<void> acceptReturnedLease(int index, PlayerLease lease) async {
    await _controller.acceptPlayerFromHandoff(index, lease);
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
      feedController: _controller,
      child: PageView.builder(
        controller: _pageController,
        scrollDirection: widget.scrollDirection,
        onPageChanged: _onPageChanged,
        itemCount: _videoCount,
        itemBuilder: (context, index) {
          final itemWidget = widget.itemBuilder(
            context,
            _controller.videos[index],
            index,
            isActive: index == _currentIndex,
          );

          // Wrap with tap handler if onVideoTapped is provided
          if (widget.onVideoTapped != null) {
            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => _onVideoTapped(index),
              child: itemWidget,
            );
          }

          return itemWidget;
        },
      ),
    );
  }
}
