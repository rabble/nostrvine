// ABOUTME: Generic fullscreen video feed screen (no bottom nav)
// ABOUTME: Displays videos with swipe navigation, used from profile/hashtag grids

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/mixins/video_prefetch_mixin.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/individual_video_providers.dart';
import 'package:openvine/providers/profile_feed_provider.dart';
import 'package:openvine/providers/profile_reposts_provider.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:video_player/video_player.dart';

/// Represents the source of videos for the fullscreen feed.
/// This allows the screen to reactively watch the appropriate provider.
sealed class VideoFeedSource {
  const VideoFeedSource();
}

/// Profile feed source - original videos only (excludes reposts)
/// Watches profileFeedProvider and filters to only non-repost videos
class ProfileFeedSource extends VideoFeedSource {
  const ProfileFeedSource(this.userId);
  final String userId;
}

/// Profile reposts feed source - reposted videos from a specific user
/// Watches profileRepostsProvider for reactive updates
class ProfileRepostsFeedSource extends VideoFeedSource {
  const ProfileRepostsFeedSource(this.userId);
  final String userId;
}

/// Liked videos feed source - current user's liked videos
/// Uses a static list since liked videos come from BLoC state
class LikedVideosFeedSource extends VideoFeedSource {
  const LikedVideosFeedSource(this.videos);
  final List<VideoEvent> videos;
}

/// Static feed source - for cases where we just have a list of videos
/// Note: This source does NOT support reactive updates when loadMore fetches new videos
/// Use this for hashtag feeds or other sources that don't have a family provider
class StaticFeedSource extends VideoFeedSource {
  const StaticFeedSource(this.videos, {this.onLoadMore});
  final List<VideoEvent> videos;
  final VoidCallback? onLoadMore;
}

/// Arguments for navigating to FullscreenVideoFeedScreen
class FullscreenVideoFeedArgs {
  const FullscreenVideoFeedArgs({
    required this.source,
    required this.initialIndex,
    this.contextTitle,
  });

  final VideoFeedSource source;
  final int initialIndex;
  final String? contextTitle;
}

/// Generic fullscreen video feed screen.
///
/// This screen is pushed outside the shell route so it doesn't show
/// the bottom navigation bar. It provides a fullscreen video viewing
/// experience with swipe up/down navigation.
///
/// The screen watches the appropriate provider based on [source] to receive
/// reactive updates when new videos are loaded via pagination.
class FullscreenVideoFeedScreen extends ConsumerStatefulWidget {
  const FullscreenVideoFeedScreen({
    required this.source,
    required this.initialIndex,
    this.contextTitle,
    super.key,
  });

  final VideoFeedSource source;
  final int initialIndex;
  final String? contextTitle;

  @override
  ConsumerState<FullscreenVideoFeedScreen> createState() =>
      _FullscreenVideoFeedScreenState();
}

class _FullscreenVideoFeedScreenState
    extends ConsumerState<FullscreenVideoFeedScreen>
    with VideoPrefetchMixin {
  late PageController _pageController;
  late int _currentIndex;
  bool _initializedPageController = false;

  @override
  void initState() {
    super.initState();
    // We'll initialize the page controller once we have videos from the provider
    _currentIndex = widget.initialIndex;
  }

  @override
  void deactivate() {
    // Pause video when widget is deactivated (before dispose).
    // This is called before the widget is removed from the tree,
    // so ref is still safe to use here.
    _pauseCurrentVideo();
    super.deactivate();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Get videos from the appropriate source
  List<VideoEvent> _getVideos() {
    final source = widget.source;
    switch (source) {
      case ProfileFeedSource(:final userId):
        final feedState = ref.watch(profileFeedProvider(userId));
        return feedState.asData?.value.videos ?? [];
      case ProfileRepostsFeedSource(:final userId):
        final repostsState = ref.watch(profileRepostsProvider(userId));
        return repostsState.asData?.value ?? [];
      case LikedVideosFeedSource(:final videos):
        return videos;
      case StaticFeedSource(:final videos):
        return videos;
    }
  }

  /// Trigger load more for the appropriate source
  void _loadMore() {
    final source = widget.source;
    switch (source) {
      case ProfileFeedSource(:final userId):
        ref.read(profileFeedProvider(userId).notifier).loadMore();
      case ProfileRepostsFeedSource(:final userId):
        // Reposts come from the same profile feed, so load more from there
        ref.read(profileFeedProvider(userId).notifier).loadMore();
      case LikedVideosFeedSource():
        // Liked videos are static - no pagination support
        break;
      case StaticFeedSource(:final onLoadMore):
        // Static source uses callback for loading more
        onLoadMore?.call();
    }
  }

  /// Pause the currently active video to prevent background playback.
  /// Called when navigating away from this screen.
  void _pauseCurrentVideo() {
    final videos = _getVideos();
    if (_currentIndex < 0 || _currentIndex >= videos.length) {
      return;
    }

    final video = videos[_currentIndex];
    if (video.videoUrl == null) {
      return;
    }

    VideoPlayerController? controller;
    try {
      final controllerParams = VideoControllerParams(
        videoId: video.id,
        videoUrl: video.videoUrl!,
        videoEvent: video,
      );
      controller = ref.read(
        individualVideoControllerProvider(controllerParams),
      );
    } catch (e) {
      // Controller may not exist yet
      return;
    }

    if (controller == null ||
        !controller.value.isInitialized ||
        !controller.value.isPlaying) {
      return;
    }

    safePause(controller, video.id);
  }

  void _onPageChanged(int newIndex, List<VideoEvent> videos) {
    setState(() {
      _currentIndex = newIndex;
    });

    // Trigger pagination near end
    if (newIndex >= videos.length - 2) {
      _loadMore();
    }

    // Prefetch videos around current index
    checkForPrefetch(currentIndex: newIndex, videos: videos);

    // Pre-initialize controllers for adjacent videos
    preInitializeControllers(ref: ref, currentIndex: newIndex, videos: videos);

    // Dispose controllers outside the keep range to free memory
    disposeControllersOutsideRange(
      ref: ref,
      currentIndex: newIndex,
      videos: videos,
    );
  }

  @override
  Widget build(BuildContext context) {
    final videos = _getVideos();

    // Initialize page controller once we have videos
    if (!_initializedPageController && videos.isNotEmpty) {
      _currentIndex = widget.initialIndex.clamp(0, videos.length - 1);
      _pageController = PageController(initialPage: _currentIndex);
      _initializedPageController = true;

      // Pre-initialize controllers for adjacent videos
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        preInitializeControllers(
          ref: ref,
          currentIndex: _currentIndex,
          videos: videos,
        );
      });
    }

    // Show loading state if we don't have videos yet
    if (videos.isEmpty || !_initializedPageController) {
      return Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: context.pop,
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        forceMaterialTransparency: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: context.pop,
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: videos.length,
        onPageChanged: (index) => _onPageChanged(index, videos),
        itemBuilder: (context, index) {
          if (index >= videos.length) return const SizedBox.shrink();

          final video = videos[index];
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
