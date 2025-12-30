// ABOUTME: Generic fullscreen video feed screen (no bottom nav)
// ABOUTME: Displays videos with swipe navigation, used from profile/hashtag grids

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/mixins/video_prefetch_mixin.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';

/// Arguments for navigating to FullscreenVideoFeedScreen
class FullscreenVideoFeedArgs {
  const FullscreenVideoFeedArgs({
    required this.videos,
    required this.initialIndex,
    this.contextTitle,
    this.onLoadMore,
  });

  final List<VideoEvent> videos;
  final int initialIndex;
  final String? contextTitle;
  final VoidCallback? onLoadMore;
}

/// Generic fullscreen video feed screen.
///
/// This screen is pushed outside the shell route so it doesn't show
/// the bottom navigation bar. It provides a fullscreen video viewing
/// experience with swipe up/down navigation.
class FullscreenVideoFeedScreen extends ConsumerStatefulWidget {
  const FullscreenVideoFeedScreen({
    required this.videos,
    required this.initialIndex,
    this.contextTitle,
    this.onLoadMore,
    super.key,
  });

  final List<VideoEvent> videos;
  final int initialIndex;
  final String? contextTitle;
  final VoidCallback? onLoadMore;

  @override
  ConsumerState<FullscreenVideoFeedScreen> createState() =>
      _FullscreenVideoFeedScreenState();
}

class _FullscreenVideoFeedScreenState
    extends ConsumerState<FullscreenVideoFeedScreen> with VideoPrefetchMixin {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.videos.length - 1);
    _pageController = PageController(initialPage: _currentIndex);

    // Pre-initialize controllers for adjacent videos
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      preInitializeControllers(
        ref: ref,
        currentIndex: _currentIndex,
        videos: widget.videos,
      );
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int newIndex) {
    setState(() {
      _currentIndex = newIndex;
    });

    // Trigger pagination near end
    if (newIndex >= widget.videos.length - 2) {
      widget.onLoadMore?.call();
    }

    // Prefetch videos around current index
    checkForPrefetch(currentIndex: newIndex, videos: widget.videos);

    // Pre-initialize controllers for adjacent videos
    preInitializeControllers(
      ref: ref,
      currentIndex: newIndex,
      videos: widget.videos,
    );

    // Dispose controllers outside the keep range to free memory
    disposeControllersOutsideRange(
      ref: ref,
      currentIndex: newIndex,
      videos: widget.videos,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: widget.videos.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          if (index >= widget.videos.length) return const SizedBox.shrink();

          final video = widget.videos[index];
          return VideoFeedItem(
            key: ValueKey('video-${video.stableId}'),
            video: video,
            index: index,
            hasBottomNavigation: false,
            contextTitle: widget.contextTitle,
            // Use isActiveOverride since this screen manages its own active state
            // (not using URL-based routing for video index)
            isActiveOverride: index == _currentIndex,
            disableTapNavigation: true,
            // Fullscreen mode - add extra padding to avoid back button
            isFullscreen: true,
          );
        },
      ),
    );
  }
}
