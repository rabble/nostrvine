// ABOUTME: Pooled video player version of the home feed screen
// ABOUTME: Uses pooled_video_player package for memory-efficient video playback
// ABOUTME: Displays videos from users you follow with vertical swipe navigation

import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/home_feed_provider.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

/// Pooled video player version of the home feed screen.
///
/// This screen uses the `pooled_video_player` package for memory-efficient
/// video playback. It displays videos from users you follow with vertical
/// swipe navigation.
///
/// Architecture: Uses Riverpod directly (no BLoC wrapper) since we own the
/// data source via [homeFeedProvider].
///
/// Key features:
/// - Managed player pool for memory efficiency
/// - Automatic preloading of adjacent videos
/// - App lifecycle management (pause on background)
/// - URL-based routing for tab state
/// - Empty state for users not following anyone
/// - End-of-feed card when all videos viewed
class PooledHomeFeedScreen extends ConsumerStatefulWidget {
  const PooledHomeFeedScreen({super.key});

  /// Route path for this screen.
  static const path = '/home';

  @override
  ConsumerState<PooledHomeFeedScreen> createState() =>
      _PooledHomeFeedScreenState();
}

class _PooledHomeFeedScreenState extends ConsumerState<PooledHomeFeedScreen>
    with WidgetsBindingObserver {
  bool _isActive = true;

  // Cache last known videos to prevent destroying the video feed content
  // during provider refresh cycles. The home feed provider emits an
  // intermediate empty state at the start of each build() which would
  // otherwise tear down and recreate the VideoFeedController, creating
  // multiple native video textures simultaneously (crashes iOS).
  List<VideoEvent>? _lastKnownVideos;
  bool _lastHasMoreContent = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Platform-aware lifecycle handling
    final isDesktop =
        Platform.isMacOS || Platform.isWindows || Platform.isLinux;

    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _setFeedActive(false);
      case AppLifecycleState.inactive:
        // Only pause for inactive on mobile platforms
        if (!isDesktop) {
          _setFeedActive(false);
        }
      case AppLifecycleState.resumed:
        _setFeedActive(true);
    }
  }

  void _setFeedActive(bool active) {
    if (_isActive == active) return;
    setState(() => _isActive = active);
  }

  @override
  Widget build(BuildContext context) {
    final feedAsync = ref.watch(homeFeedProvider);
    final onLoadMore = ref.read(homeFeedProvider.notifier).loadMore;

    return feedAsync.when(
      loading: () {
        // Keep showing cached content during provider refresh
        final cached = _lastKnownVideos;
        if (cached != null && cached.isNotEmpty) {
          return _PooledHomeFeedContent(
            videos: cached,
            isActive: _isActive,
            hasMoreContent: _lastHasMoreContent,
            onLoadMore: onLoadMore,
          );
        }
        return const _HomeFeedLoadingState();
      },
      error: (error, _) => _HomeFeedErrorState(
        error: error.toString(),
        onRetry: () => ref.invalidate(homeFeedProvider),
      ),
      data: (feedState) {
        if (feedState.videos.isEmpty && feedState.isInitialLoad) {
          // Keep showing cached content during provider rebuild
          final cached = _lastKnownVideos;
          if (cached != null && cached.isNotEmpty) {
            return _PooledHomeFeedContent(
              videos: cached,
              isActive: _isActive,
              hasMoreContent: _lastHasMoreContent,
              onLoadMore: onLoadMore,
            );
          }
          return const _HomeFeedLoadingState();
        }

        if (feedState.videos.isEmpty) {
          _lastKnownVideos = null;
          final followRepository = ref.read(followRepositoryProvider);
          final isFollowing = (followRepository?.followingCount ?? 0) > 0;
          return _HomeFeedEmptyState(isFollowingAnyone: isFollowing);
        }

        final videosWithUrl = feedState.videos
            .where((v) => v.videoUrl != null)
            .toList();

        if (videosWithUrl.isEmpty) {
          _lastKnownVideos = null;
          final followRepository = ref.read(followRepositoryProvider);
          final isFollowing = (followRepository?.followingCount ?? 0) > 0;
          return _HomeFeedEmptyState(isFollowingAnyone: isFollowing);
        }

        // Cache for future refresh cycles
        _lastKnownVideos = videosWithUrl;
        _lastHasMoreContent = feedState.hasMoreContent;

        return _PooledHomeFeedContent(
          videos: videosWithUrl,
          isActive: _isActive,
          hasMoreContent: feedState.hasMoreContent,
          onLoadMore: onLoadMore,
        );
      },
    );
  }
}

/// Content widget managing the VideoFeedController lifecycle.
///
/// Works directly with Riverpod - no BLoC intermediary needed.
class _PooledHomeFeedContent extends StatefulWidget {
  const _PooledHomeFeedContent({
    required this.videos,
    required this.isActive,
    required this.hasMoreContent,
    required this.onLoadMore,
  });

  final List<VideoEvent> videos;
  final bool isActive;
  final bool hasMoreContent;
  final VoidCallback onLoadMore;

  @override
  State<_PooledHomeFeedContent> createState() => _PooledHomeFeedContentState();
}

class _PooledHomeFeedContentState extends State<_PooledHomeFeedContent> {
  VideoFeedController? _controller;
  List<VideoItem>? _lastPooledVideos;
  int _currentIndex = 0;

  List<VideoItem> get _pooledVideos =>
      widget.videos.map((v) => VideoItem(id: v.id, url: v.videoUrl!)).toList();

  @override
  void initState() {
    super.initState();
    _initializeController();
  }

  @override
  void didUpdateWidget(_PooledHomeFeedContent oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle active state changes (app lifecycle)
    if (oldWidget.isActive != widget.isActive) {
      _controller?.setActive(active: widget.isActive);
    }

    // Handle new videos from pagination
    if (oldWidget.videos.length != widget.videos.length) {
      _handleVideosChanged();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _initializeController() {
    final pooledVideos = _pooledVideos;
    if (pooledVideos.isEmpty) return;

    _controller = VideoFeedController(
      videos: pooledVideos,
      pool: PlayerPool.instance,
      initialIndex: _currentIndex,
      positionCallbackInterval: const Duration(milliseconds: 100),
    );
    _lastPooledVideos = pooledVideos;
  }

  void _handleVideosChanged() {
    final controller = _controller;
    if (controller == null || _lastPooledVideos == null) return;

    final currentPooled = _pooledVideos;
    final newVideos = currentPooled
        .where((v) => !_lastPooledVideos!.any((old) => old.id == v.id))
        .toList();

    if (newVideos.isNotEmpty) {
      controller.addVideos(newVideos);
    }
    _lastPooledVideos = currentPooled;
  }

  void _onActiveVideoChanged(VideoItem video, int index) {
    // Track current index for controller re-initialization if the widget
    // is recreated (e.g., after provider refresh cycle). No setState needed —
    // PooledVideoFeed manages its own scroll state internally, and calling
    // setState here would trigger an unnecessary parent rebuild that creates
    // a second PooledVideoFeedState.build() per scroll. The fullscreen feed
    // avoids this by dispatching a BLoC event instead.
    _currentIndex = index;
  }

  void _onNearEnd(int index) {
    widget.onLoadMore();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const _HomeFeedLoadingState();
    }

    // Add end card if no more content
    final showEndCard = !widget.hasMoreContent;

    return PooledVideoFeed(
      videos: _pooledVideos,
      controller: _controller,
      initialIndex: _currentIndex,
      onActiveVideoChanged: _onActiveVideoChanged,
      onNearEnd: _onNearEnd,
      nearEndThreshold: 2,
      itemBuilder: (context, video, index, {required isActive}) {
        // Show end card after last video
        if (showEndCard && index == widget.videos.length) {
          return const _EndOfFeedCard();
        }

        final originalEvent = widget.videos[index];
        return _PooledHomeFeedItem(
          video: originalEvent,
          index: index,
          isActive: isActive && widget.isActive,
        );
      },
    );
  }
}

/// Individual video item in the home feed.
class _PooledHomeFeedItem extends ConsumerWidget {
  const _PooledHomeFeedItem({
    required this.video,
    required this.index,
    required this.isActive,
  });

  final VideoEvent video;
  final int index;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likesRepository = ref.read(likesRepositoryProvider);
    final commentsRepository = ref.read(commentsRepositoryProvider);
    final repostsRepository = ref.read(repostsRepositoryProvider);

    final addressableId = video.addressableId;

    return BlocProvider<VideoInteractionsBloc>(
      create: (_) =>
          VideoInteractionsBloc(
              eventId: video.id,
              authorPubkey: video.pubkey,
              likesRepository: likesRepository,
              commentsRepository: commentsRepository,
              repostsRepository: repostsRepository,
              addressableId: addressableId,
            )
            ..add(const VideoInteractionsSubscriptionRequested())
            ..add(const VideoInteractionsFetchRequested()),
      child: _PooledHomeFeedItemContent(
        video: video,
        index: index,
        isActive: isActive,
      ),
    );
  }
}

class _PooledHomeFeedItemContent extends StatelessWidget {
  const _PooledHomeFeedItemContent({
    required this.video,
    required this.index,
    required this.isActive,
  });

  final VideoEvent video;
  final int index;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final isPortrait = video.dimensions != null ? video.isPortrait : true;

    return ColoredBox(
      color: Colors.black,
      child: PooledVideoPlayer(
        index: index,
        thumbnailUrl: video.thumbnailUrl,
        enableTapToPause: isActive,
        videoBuilder: (context, videoController, player) => Video(
          controller: videoController,
          fit: isPortrait ? BoxFit.cover : BoxFit.contain,
          filterQuality: FilterQuality.high,
          controls: NoVideoControls,
        ),
        loadingBuilder: (context) => _VideoLoadingPlaceholder(
          thumbnailUrl: video.thumbnailUrl,
          isPortrait: isPortrait,
        ),
        overlayBuilder: (context, videoController, player) =>
            VideoOverlayActions(
              video: video,
              isVisible: isActive,
              isActive: isActive,
              hasBottomNavigation: true, // Home feed has bottom nav
              hideFollowButtonIfFollowing: true, // Only shows followed users
            ),
      ),
    );
  }
}

/// Loading state for home feed.
class _HomeFeedLoadingState extends StatelessWidget {
  const _HomeFeedLoadingState();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(child: BrandedLoadingIndicator(size: 100)),
    );
  }
}

/// Error state for home feed.
class _HomeFeedErrorState extends StatelessWidget {
  const _HomeFeedErrorState({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Error loading videos',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

/// Empty state for home feed.
class _HomeFeedEmptyState extends StatelessWidget {
  const _HomeFeedEmptyState({required this.isFollowingAnyone});

  final bool isFollowingAnyone;

  @override
  Widget build(BuildContext context) {
    if (!isFollowingAnyone) {
      // Educational message about divine's non-algorithmic approach
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.people_outline,
                  size: 64,
                  color: Colors.white54,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Your Feed, Your Choice',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  "divine doesn't give you an algorithmic feed.\n"
                  'You choose who you follow.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                const Text(
                  'Start following viners to see their posts here,\n'
                  'or explore new content to discover creators.',
                  style: TextStyle(
                    color: Colors.white54,
                    fontSize: 14,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => context.go(ExploreScreen.path),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VineTheme.vineGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Explore Vines'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Standard empty state for users who are following people
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library_outlined, size: 64, color: Colors.white54),
            SizedBox(height: 16),
            Text(
              'No videos available',
              style: TextStyle(color: Colors.white, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text(
              'Check your connection and try again',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

/// End of feed card shown when user has viewed all available videos.
class _EndOfFeedCard extends StatelessWidget {
  const _EndOfFeedCard();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: VineTheme.vineGreen.withValues(alpha: 0.15),
                  ),
                  child: const Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: VineTheme.vineGreen,
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  "You've reached the end,\nmy friend",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Follow more viners to see more content',
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                OutlinedButton.icon(
                  onPressed: () => context.go(ExploreScreen.path),
                  icon: const Icon(Icons.explore_outlined),
                  label: const Text('Explore to find more videos'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: VineTheme.vineGreen,
                    side: const BorderSide(color: VineTheme.vineGreen),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoLoadingPlaceholder extends StatelessWidget {
  const _VideoLoadingPlaceholder({this.thumbnailUrl, this.isPortrait = true});

  final String? thumbnailUrl;
  final bool isPortrait;

  @override
  Widget build(BuildContext context) {
    final boxFit = isPortrait ? BoxFit.cover : BoxFit.contain;
    final url = thumbnailUrl;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (url != null && url.isNotEmpty)
          Image.network(
            url,
            fit: boxFit,
            alignment: Alignment.center,
            errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black),
          )
        else
          const ColoredBox(color: Colors.black),
        const Center(child: BrandedLoadingIndicator(size: 60)),
      ],
    );
  }
}
