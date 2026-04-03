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
    this.onScrollOffsetChanged,
    this.maxLoopDuration,
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

  /// Maximum playback duration before automatically seeking back to zero.
  final Duration? maxLoopDuration;

  /// Called continuously as the feed scrolls with the fractional page position.
  ///
  /// The value is the current page as a double (e.g. 1.7 means 70% scrolled
  /// from page 1 toward page 2). Useful for computing per-item scroll fraction
  /// without changing the [itemBuilder] signature.
  final void Function(double page)? onScrollOffsetChanged;

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

  /// Animate the page view to [index].
  ///
  /// Used by overlay widgets (e.g., slow-load skip) that need to scroll
  /// the feed programmatically. Triggers the page-changed callback as a
  /// side effect.
  Future<void> animateToPage(int index) => _pageController.animateToPage(
    index,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeInOut,
  );

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _pageController.addListener(_onScrollChanged);

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
        maxLoopDuration: widget.maxLoopDuration,
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

  void _onScrollChanged() {
    final page = _pageController.page;
    if (page == null) return;
    widget.onScrollOffsetChanged?.call(page);

    // Update active index only when the page is fully visible
    // (fractional part ≈ 0).
    final rounded = page.round();
    if ((page - rounded).abs() < 0.001 &&
        rounded != _currentIndex &&
        rounded >= 0 &&
        rounded < _controller.videoCount) {
      setState(() => _currentIndex = rounded);
      widget.onActiveVideoChanged?.call(
        _controller.videos[rounded],
        rounded,
      );
    }
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
    _controller.onPageChanged(index);

    final distanceFromEnd = _controller.videoCount - index - 1;
    if (distanceFromEnd <= widget.nearEndThreshold) {
      widget.onNearEnd?.call(index);
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    // During hot reload, native callbacks can fire on invalidated
    // Dart FFI handles, causing "Callback invoked after it has been deleted".
    // Stop all native playback and recreate the controller to prevent this.
    _effectivePool.stopAll();

    if (_ownsController) {
      _controller
        ..removeListener(_onControllerChanged)
        ..dispose();
      _controller = VideoFeedController(
        videos: widget.videos,
        pool: _effectivePool,
        initialIndex: _currentIndex,
        preloadAhead: widget.preloadAhead,
        preloadBehind: widget.preloadBehind,
        maxLoopDuration: widget.maxLoopDuration,
      );
      _videoCount = _controller.videoCount;
      _controller.addListener(_onControllerChanged);

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _controller.play();
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _pageController
      ..removeListener(_onScrollChanged)
      ..dispose();
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
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification.depth == 0 &&
              notification is ScrollUpdateNotification) {
            final metrics = notification.metrics as PageMetrics;
            final page = metrics.page!;
            final nearest = page.round();
            // Only trigger when the page is ≥99% visible.
            if ((page - nearest).abs() < 0.01 && nearest != _currentIndex) {
              _onPageChanged(nearest);
            }
          }
          return false;
        },
        child: PageView.builder(
          // Builds ±1 off-screen pages so thumbnails in the loading
          // placeholder are precached before the user swipes.
          allowImplicitScrolling: true,
          physics: const _SnapScrollPhysics(),
          controller: _pageController,
          scrollDirection: widget.scrollDirection,
          itemCount: _videoCount,
          itemBuilder: (context, index) {
            final videos = _controller.videos;
            if (index < 0 || index >= videos.length) {
              debugPrint(
                'PooledVideoFeed: INDEX OUT OF BOUNDS! '
                'index=$index, videos.length=${videos.length}, '
                '_videoCount=$_videoCount, '
                'controller.videoCount=${_controller.videoCount}',
              );
              return const ColoredBox(color: Color(0xFF000000));
            }
            return widget.itemBuilder(
              context,
              videos[index],
              index,
              isActive: index == _currentIndex,
            );
          },
        ),
      ),
    );
  }
}

/// no edge bounce, fast spring, and a low page-turn threshold (~10%).
class _SnapScrollPhysics extends PageScrollPhysics {
  const _SnapScrollPhysics() : super(parent: const ClampingScrollPhysics());

  /// Fraction of a page the user must drag before the feed commits
  /// to the next/previous page (without velocity).
  static const double _pageTurnThreshold = 0.1;

  @override
  _SnapScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return const _SnapScrollPhysics();
  }

  @override
  double get minFlingVelocity => 50;

  @override
  double get minFlingDistance => 1;

  @override
  double get dragStartDistanceMotionThreshold => 1;

  /// Critically damped spring — no bounce, snappy settle.
  @override
  SpringDescription get spring => const SpringDescription(
    mass: 0.3,
    stiffness: 150,
    damping: 13.5,
  );

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    // At the edges, defer to ClampingScrollPhysics (no bounce).
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }

    final tolerance = toleranceFor(position);
    final page = (position as PageMetrics).page!;
    final currentFloor = page.floor();
    final fraction = page - currentFloor;

    int targetPage;

    if (velocity.abs() > tolerance.velocity) {
      // Any detectable fling velocity commits in that direction.
      targetPage = velocity < 0 ? (page - 0.01).floor() : (page + 0.01).ceil();
    } else if (fraction >= _pageTurnThreshold && fraction <= 0.5) {
      // Slow drag forward past threshold → commit forward.
      targetPage = currentFloor + 1;
    } else if (fraction > 0.5 && fraction < (1.0 - _pageTurnThreshold)) {
      // Slow drag backward past threshold → commit backward.
      targetPage = currentFloor;
    } else if (fraction > 0.5) {
      // Near the next page but below backward threshold → snap forward.
      targetPage = currentFloor + 1;
    } else {
      // Below forward threshold → snap back.
      targetPage = currentFloor;
    }

    final maxPage = (position.maxScrollExtent / position.viewportDimension)
        .round();
    targetPage = targetPage.clamp(0, maxPage);

    final targetPixels = targetPage * position.viewportDimension;

    if ((targetPixels - position.pixels).abs() < tolerance.distance) {
      return null;
    }

    return ScrollSpringSimulation(
      spring,
      position.pixels,
      targetPixels,
      velocity,
      tolerance: tolerance,
    );
  }
}
