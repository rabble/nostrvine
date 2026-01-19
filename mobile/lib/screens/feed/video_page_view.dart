// ABOUTME: Reusable vertical PageView for video feeds
// ABOUTME: Encapsulates prefetch, controller management, and pagination logic

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/mixins/video_prefetch_mixin.dart';
import 'package:openvine/providers/individual_video_providers.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';

/// Reusable vertical PageView for displaying video feeds.
///
/// Encapsulates common logic shared between video feed screens:
/// - Vertical PageView with snap scrolling
/// - Video prefetching and controller pre-initialization
/// - Controller disposal for memory management
/// - Pagination triggers
/// - Active video state management via isActiveOverride
///
/// Usage:
/// ```dart
/// VideoPageView(
///   videos: myVideos,
///   initialIndex: 0,
///   onPageChanged: (index) => setState(() => _currentIndex = index),
///   onLoadMore: () => loadMoreVideos(),
///   contextTitle: 'My Feed',
/// )
/// ```
class VideoPageView extends ConsumerStatefulWidget {
  const VideoPageView({
    super.key,
    required this.videos,
    this.initialIndex = 0,
    this.onPageChanged,
    this.onLoadMore,
    this.contextTitle,
    this.isFullscreen = false,
    this.hasBottomNavigation = false,
    this.paginationThreshold = 2,
    this.keepControllersBefore = 1,
    this.keepControllersAfter = 2,
  });

  /// List of videos to display.
  final List<VideoEvent> videos;

  /// Initial video index to display.
  final int initialIndex;

  /// Called when the page changes. Use this to update external state.
  final ValueChanged<int>? onPageChanged;

  /// Called when user scrolls near the end to load more videos.
  final VoidCallback? onLoadMore;

  /// Context title shown in video overlay (e.g., "Home Feed", "Trending").
  final String? contextTitle;

  /// When true, adds extra padding for fullscreen mode (no bottom nav).
  final bool isFullscreen;

  /// Whether the screen has bottom navigation (affects padding).
  final bool hasBottomNavigation;

  /// Number of videos from end to trigger pagination.
  final int paginationThreshold;

  /// Number of video controllers to keep before current index.
  /// Lower values use less memory but may cause loading delays when scrolling back.
  final int keepControllersBefore;

  /// Number of video controllers to keep after current index.
  /// Lower values use less memory but may cause loading delays when scrolling forward.
  final int keepControllersAfter;

  @override
  ConsumerState<VideoPageView> createState() => _VideoPageViewState();
}

class _VideoPageViewState extends ConsumerState<VideoPageView>
    with VideoPrefetchMixin {
  late PageController _pageController;
  late int _currentIndex;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    // Handle empty videos list - clamp requires lower <= upper
    _currentIndex = widget.videos.isEmpty
        ? 0
        : widget.initialIndex.clamp(0, widget.videos.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _isInitialized = true;

    // Pre-initialize controllers for adjacent videos after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.videos.isEmpty) return;
      preInitializeControllers(
        ref: ref,
        currentIndex: _currentIndex,
        videos: widget.videos,
      );
    });
  }

  @override
  void didUpdateWidget(VideoPageView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If video list changed significantly, reset to valid index
    if (widget.videos.length != oldWidget.videos.length) {
      final newIndex = _currentIndex.clamp(
        0,
        widget.videos.isEmpty ? 0 : widget.videos.length - 1,
      );
      if (newIndex != _currentIndex) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _currentIndex = newIndex;
          });
        });
      }
    }
  }

  @override
  void deactivate() {
    // Pause current video when widget is deactivated (before dispose)
    _pauseCurrentVideo();
    super.deactivate();
  }

  @override
  void dispose() {
    _pageController.dispose();
    clearTrackedControllers();
    super.dispose();
  }

  void _pauseCurrentVideo() {
    if (widget.videos.isEmpty ||
        _currentIndex < 0 ||
        _currentIndex >= widget.videos.length) {
      return;
    }

    final video = widget.videos[_currentIndex];
    if (video.videoUrl == null) return;

    try {
      final controllerParams = VideoControllerParams(
        videoId: video.id,
        videoUrl: video.videoUrl!,
        videoEvent: video,
      );
      final controller = ref.read(
        individualVideoControllerProvider(controllerParams),
      );

      if (controller.value.isInitialized && controller.value.isPlaying) {
        safePause(controller, video.id);
      }
    } catch (_) {
      // Ignore errors during deactivation
    }
  }

  void _onPageChanged(int index) {
    // Defer setState to avoid "setState during build" errors
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_currentIndex != index) {
        setState(() {
          _currentIndex = index;
        });
      }
    });

    // Notify parent of page change
    widget.onPageChanged?.call(index);

    // Trigger pagination when near end
    if (widget.onLoadMore != null &&
        index >= widget.videos.length - widget.paginationThreshold) {
      widget.onLoadMore!();
    }

    // Prefetch, initialize, then dispose (in this order for smooth scrolling)
    if (widget.videos.isNotEmpty) {
      checkForPrefetch(currentIndex: index, videos: widget.videos);
      preInitializeControllers(
        ref: ref,
        currentIndex: index,
        videos: widget.videos,
        preInitBefore: 1,
        preInitAfter: 2,
      );
      // Use configurable keep range for memory management
      disposeControllersOutsideRange(
        ref: ref,
        currentIndex: index,
        videos: widget.videos,
        keepBefore: widget.keepControllersBefore,
        keepAfter: widget.keepControllersAfter,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.videos.isEmpty || !_isInitialized) {
      return const Center(
        child: Text(
          'No videos available',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return Container(
      color: Colors.black,
      child: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: widget.videos.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          if (index >= widget.videos.length) {
            return const SizedBox.shrink();
          }

          final video = widget.videos[index];
          final isActive = index == _currentIndex;

          return VideoFeedItem(
            key: ValueKey('video-page-view-${video.stableId}'),
            video: video,
            index: index,
            hasBottomNavigation: widget.hasBottomNavigation,
            contextTitle: widget.contextTitle,
            isActiveOverride: isActive,
            disableTapNavigation: true,
            isFullscreen: widget.isFullscreen,
          );
        },
      ),
    );
  }
}
