// ABOUTME: Generic fullscreen video feed screen (no bottom nav)
// ABOUTME: Displays videos with swipe navigation, used from profile/hashtag grids

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/mixins/video_prefetch_mixin.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/individual_video_providers.dart';
import 'package:openvine/providers/profile_feed_provider.dart';
import 'package:openvine/providers/profile_reposts_provider.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:openvine/widgets/share_video_menu.dart';
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
/// Note: This source does NOT support reactive updates when loadMore fetches
/// new videos. Use this for hashtag feeds or other sources that don't have a
/// family provider.
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
    this.trafficSource = ViewTrafficSource.unknown,
  });

  final VideoFeedSource source;
  final int initialIndex;
  final String? contextTitle;
  final ViewTrafficSource trafficSource;
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
  /// Route name for this screen.
  static const routeName = 'video-feed';

  /// Path for this route.
  static const path = '/video-feed';

  const FullscreenVideoFeedScreen({
    required this.source,
    required this.initialIndex,
    this.contextTitle,
    this.trafficSource = ViewTrafficSource.unknown,
    super.key,
  });

  final VideoFeedSource source;
  final int initialIndex;
  final String? contextTitle;
  final ViewTrafficSource trafficSource;

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
    // We'll initialize the page controller once we have videos from the
    // provider
    _currentIndex = widget.initialIndex;
  }

  @override
  void deactivate() {
    // Pause video when widget is deactivated (before dispose).
    // IMPORTANT: We must defer the pause to after the current frame to avoid
    // "setState() called during build" errors. This happens because pause()
    // notifies ValueListenableBuilder listeners synchronously, which triggers
    // rebuilds during the widget tree teardown phase.
    //
    // We capture the video info now (while ref is still valid) and defer
    // the actual pause operation.
    _schedulePauseCurrentVideo();
    super.deactivate();
  }

  /// Schedule pause for after the current frame to avoid build conflicts
  void _schedulePauseCurrentVideo() {
    final videos = _readCurrentVideos();
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

    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    // Defer the pause to after the current frame
    final videoId = video.id;
    final controllerToClose = controller;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (controllerToClose.value.isPlaying) {
        safePause(controllerToClose, videoId);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  _ResolvedFullscreenFeedState _watchFeedState() {
    final source = widget.source;
    switch (source) {
      case ProfileFeedSource(:final userId):
        final feedState = ref.watch(profileFeedProvider(userId));
        final value = feedState.asData?.value;
        return _ResolvedFullscreenFeedState(
          videos: value?.videos ?? const [],
          supportsLoadMore: true,
          hasMoreContent: value?.hasMoreContent ?? false,
          isLoadingMore: value?.isLoadingMore ?? false,
        );
      case ProfileRepostsFeedSource(:final userId):
        final repostsState = ref.watch(profileRepostsProvider(userId));
        final profileFeedState = ref.watch(profileFeedProvider(userId));
        final profileFeedValue = profileFeedState.asData?.value;
        return _ResolvedFullscreenFeedState(
          videos: repostsState.asData?.value ?? const [],
          supportsLoadMore: true,
          hasMoreContent: profileFeedValue?.hasMoreContent ?? false,
          isLoadingMore: profileFeedValue?.isLoadingMore ?? false,
        );
      case LikedVideosFeedSource(:final videos):
        return _ResolvedFullscreenFeedState(
          videos: videos,
          supportsLoadMore: false,
          hasMoreContent: false,
          isLoadingMore: false,
        );
      case StaticFeedSource(:final videos, :final onLoadMore):
        final supportsLoadMore = onLoadMore != null;
        return _ResolvedFullscreenFeedState(
          videos: videos,
          supportsLoadMore: supportsLoadMore,
          // Static sources don't expose hasMore; if loadMore exists, allow it.
          hasMoreContent: supportsLoadMore,
          isLoadingMore: false,
        );
    }
  }

  List<VideoEvent> _readCurrentVideos() {
    final source = widget.source;
    switch (source) {
      case ProfileFeedSource(:final userId):
        return ref.read(profileFeedProvider(userId)).asData?.value.videos ?? [];
      case ProfileRepostsFeedSource(:final userId):
        return ref.read(profileRepostsProvider(userId)).asData?.value ?? [];
      case LikedVideosFeedSource(:final videos):
        return videos;
      case StaticFeedSource(:final videos):
        return videos;
    }
  }

  /// Trigger load more for the appropriate source
  Future<void> _loadMore() async {
    final source = widget.source;
    switch (source) {
      case ProfileFeedSource(:final userId):
        await ref.read(profileFeedProvider(userId).notifier).loadMore();
        return;
      case ProfileRepostsFeedSource(:final userId):
        // Reposts come from the same profile feed, so load more from there
        await ref.read(profileFeedProvider(userId).notifier).loadMore();
        return;
      case LikedVideosFeedSource():
        // Liked videos are static - no pagination support
        return;
      case StaticFeedSource(:final onLoadMore):
        // Static source uses callback for loading more
        onLoadMore?.call();
        return;
    }
  }

  void _onPageChanged(
    int newIndex,
    List<VideoEvent> videos, {
    required bool supportsLoadMore,
    required bool hasMoreContent,
  }) {
    setState(() {
      _currentIndex = newIndex;
    });

    final isAtEnd = newIndex >= videos.length - 1;

    if (supportsLoadMore && hasMoreContent && isAtEnd) {
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

  /// Build the Edit button for the AppBar (only shown for owned videos)
  Widget? _buildEditButton(List<VideoEvent> videos) {
    // Check feature flag
    final featureFlagService = ref.watch(featureFlagServiceProvider);
    final isEditorEnabled = featureFlagService.isEnabled(
      FeatureFlag.enableVideoEditorV1,
    );

    if (!isEditorEnabled) {
      return null;
    }

    // Get current video
    if (_currentIndex < 0 || _currentIndex >= videos.length) {
      return null;
    }
    final currentVideo = videos[_currentIndex];

    // Check ownership
    final authService = ref.watch(authServiceProvider);
    final currentUserPubkey = authService.currentPublicKeyHex;
    final isOwnVideo =
        currentUserPubkey != null && currentUserPubkey == currentVideo.pubkey;

    if (!isOwnVideo) {
      return null;
    }

    // Return edit button with same styling as back button
    return Padding(
      padding: const EdgeInsets.only(right: 16),
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
        icon: Container(
          width: 48,
          height: 48,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
          ),
          child: SvgPicture.asset(
            'assets/icon/content-controls/pencil.svg',
            width: 32,
            height: 32,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
        ),
        onPressed: () {
          showEditDialogForVideo(context, currentVideo);
        },
        tooltip: 'Edit video',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final feedState = _watchFeedState();
    final videos = feedState.videos;

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
          scrolledUnderElevation: 0,
          toolbarHeight: 72,
          leadingWidth: 80,
          leading: IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Container(
              width: 48,
              height: 48,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
              ),
              child: SvgPicture.asset(
                'assets/icon/CaretLeft.svg',
                width: 32,
                height: 32,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
                semanticsLabel: 'Close video player',
              ),
            ),
            onPressed: context.pop,
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    // Build edit button (may be null if not owned or feature disabled)
    final editButton = _buildEditButton(videos);

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 72,
        leadingWidth: 80,
        forceMaterialTransparency: true,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: SvgPicture.asset(
              'assets/icon/CaretLeft.svg',
              width: 32,
              height: 32,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
              semanticsLabel: 'Close video player',
            ),
          ),
          onPressed: context.pop,
        ),
        actions: (_currentIndex < videos.length && editButton != null)
            ? [editButton]
            : null,
      ),
      body: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        itemCount: videos.length,
        onPageChanged: (index) => _onPageChanged(
          index,
          videos,
          supportsLoadMore: feedState.supportsLoadMore,
          hasMoreContent: feedState.hasMoreContent,
        ),
        itemBuilder: (context, index) {
          final video = videos[index];
          return VideoFeedItem(
            key: ValueKey('video-${video.stableId}'),
            video: video,
            index: index,
            hasBottomNavigation: false,
            contextTitle: widget.contextTitle,
            // Use isActiveOverride since this screen manages its own active
            // state (not using URL-based routing for video index)
            isActiveOverride: index == _currentIndex,
            disableTapNavigation: true,
            // Fullscreen mode - add extra padding to avoid back button
            isFullscreen: true,
            trafficSource: widget.trafficSource,
          );
        },
      ),
    );
  }
}

class _ResolvedFullscreenFeedState {
  const _ResolvedFullscreenFeedState({
    required this.videos,
    required this.supportsLoadMore,
    required this.hasMoreContent,
    required this.isLoadingMore,
  });

  final List<VideoEvent> videos;
  final bool supportsLoadMore;
  final bool hasMoreContent;
  final bool isLoadingMore;
}
