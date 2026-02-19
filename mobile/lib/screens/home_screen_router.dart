// ABOUTME: Router-driven HomeScreen using pooled_video_player for playback
// ABOUTME: PageView syncs with URL bidirectionally, shared PlayerPool manages
// ABOUTME: video lifecycle via VideoFeedController

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/fullscreen_feed/fullscreen_feed_bloc.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/mixins/async_value_ui_helpers_mixin.dart';
import 'package:openvine/mixins/page_controller_sync_mixin.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/home_screen_controllers.dart';
import 'package:openvine/providers/home_feed_provider.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:openvine/services/screen_analytics_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

/// Router-driven HomeScreen - PageView syncs with URL bidirectionally
class HomeScreenRouter extends ConsumerStatefulWidget {
  /// Route name for this screen.
  static const routeName = 'home';

  /// Path for this route.
  static const path = '/home';

  /// Path for this route with index.
  static const pathWithIndex = '/home/:index';

  /// Build path for a specific index.
  static String pathForIndex(int index) => '/home/$index';

  const HomeScreenRouter({super.key});

  @override
  ConsumerState<HomeScreenRouter> createState() => _HomeScreenRouterState();
}

class _HomeScreenRouterState extends ConsumerState<HomeScreenRouter>
    with PageControllerSyncMixin, AsyncValueUIHelpersMixin, RouteAware {
  PageController? _controller;
  int? _lastUrlIndex;
  int? _lastPrefetchIndex;
  int _currentPageIndex = 0;

  // -- Pooled video controller state --
  VideoFeedController? _feedController;
  List<VideoItem>? _lastPooledVideos;
  bool _isPausedByOverlay = false;
  bool _isPausedByNavigation = false;
  GoRouter? _router;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)!);

    // GoRouter listener to detect cross-navigator navigation (e.g. home →
    // profile-view). RouteAware alone doesn't work because the home screen
    // lives inside a nested Navigator (ShellRoute tab) while profile-view
    // is pushed on the root Navigator.
    if (_router == null) {
      _router = ref.read(goRouterProvider);
      _router!.routerDelegate.addListener(_onRouterLocationChanged);
    }
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_onRouterLocationChanged);
    routeObserver.unsubscribe(this);
    _feedController?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  // -- GoRouter location listener ------------------------------------------

  void _onRouterLocationChanged() {
    final location =
        _router?.routeInformationProvider.value.uri.toString() ?? '';
    final isOnHome = location.startsWith('/home');

    if (!isOnHome && !_isPausedByNavigation) {
      _isPausedByNavigation = true;
      _feedController?.pause();
      Log.debug(
        'Paused: navigated away from home ($location)',
        name: 'HomeScreenRouter',
        category: LogCategory.video,
      );
    } else if (isOnHome && _isPausedByNavigation) {
      _isPausedByNavigation = false;
      // Only resume if not also paused by an overlay (drawer, modal).
      if (!_isPausedByOverlay) {
        _feedController?.play();
      }
      Log.debug(
        'Resumed: navigated back to home ($location)',
        name: 'HomeScreenRouter',
        category: LogCategory.video,
      );
    }
  }

  // -- RouteAware callbacks (fallback for same-navigator pushes) -----------

  @override
  void didPushNext() {
    // Another route was pushed on top within the same navigator.
    _feedController?.pause();
    Log.debug(
      'Paused via RouteAware.didPushNext',
      name: 'HomeScreenRouter',
      category: LogCategory.video,
    );
  }

  @override
  void didPopNext() {
    // A route was popped back to us within the same navigator.
    if (!_isPausedByNavigation && !_isPausedByOverlay) {
      _feedController?.play();
    }
    Log.debug(
      'didPopNext fired (isPausedByNav=$_isPausedByNavigation, '
      'isPausedByOverlay=$_isPausedByOverlay)',
      name: 'HomeScreenRouter',
      category: LogCategory.video,
    );
  }

  // -- Hot-reload safety ---------------------------------------------------

  @override
  void reassemble() {
    super.reassemble();
    // During hot reload, media_kit native callbacks can fire on invalidated
    // Dart FFI handles. Stop all native playback and recreate the controller.
    PlayerPool.instance.stopAll();

    final oldController = _feedController;
    if (oldController != null) {
      final videos = List<VideoItem>.from(oldController.videos);
      final currentIndex = oldController.currentIndex;
      oldController.dispose();
      _feedController = _createFeedController(videos, currentIndex);
      _lastPooledVideos = videos;

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _feedController?.play();
        }
      });
    }
  }

  // -- VideoFeedController lifecycle ---------------------------------------

  /// Converts [VideoEvent]s to [VideoItem]s, filtering out null URLs.
  List<VideoItem> _toPooledVideos(List<VideoEvent> videos) {
    return videos
        .where((v) => v.videoUrl != null)
        .map((e) => VideoItem(id: e.id, url: e.videoUrl!))
        .toList();
  }

  /// Creates a [VideoFeedController] with loop enforcement.
  VideoFeedController _createFeedController(
    List<VideoItem> videos,
    int initialIndex,
  ) {
    return VideoFeedController(
      videos: videos,
      pool: PlayerPool.instance,
      initialIndex: initialIndex,
      preloadAhead: 2,
      preloadBehind: 1,
      positionCallback: (index, position) {
        // Loop enforcement — seek back to start after max duration.
        if (position >= maxPlaybackDuration && mounted) {
          _feedController?.seek(Duration.zero);
        }
      },
      positionCallbackInterval: const Duration(milliseconds: 100),
    );
  }

  /// Initializes the feed controller when videos first become available.
  void _initializeFeedController(List<VideoEvent> videos, int initialIndex) {
    if (_feedController != null) return;

    final pooledVideos = _toPooledVideos(videos);
    if (pooledVideos.isEmpty) return;

    _feedController = _createFeedController(pooledVideos, initialIndex);
    _lastPooledVideos = pooledVideos;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _feedController?.play();
      }
    });
  }

  /// Handles new videos from pagination by diffing and adding to controller.
  void _handleVideosChanged(List<VideoEvent> videos) {
    final controller = _feedController;
    if (controller == null || _lastPooledVideos == null) return;

    final pooledVideos = _toPooledVideos(videos);
    final newVideos = pooledVideos
        .where((v) => !_lastPooledVideos!.any((old) => old.id == v.id))
        .toList();

    if (newVideos.isNotEmpty) {
      controller.addVideos(newVideos);
    }
    _lastPooledVideos = pooledVideos;
  }

  /// Handles full refresh by disposing old controller and creating a new one.
  void _handleFullRefresh(List<VideoEvent> videos) {
    _feedController?.dispose();
    _feedController = null;
    _lastPooledVideos = null;
    _initializeFeedController(videos, 0);
  }

  // -- Overlay pause management --------------------------------------------

  void _handleOverlayChange(bool hasOverlay) {
    if (hasOverlay && !_isPausedByOverlay) {
      _isPausedByOverlay = true;
      _feedController?.pause();
      Log.debug(
        'Paused: overlay visible',
        name: 'HomeScreenRouter',
        category: LogCategory.video,
      );
    } else if (!hasOverlay && _isPausedByOverlay) {
      _isPausedByOverlay = false;
      // Only resume if not also paused by navigation.
      if (!_isPausedByNavigation) {
        _feedController?.play();
      }
      Log.debug(
        'Overlay dismissed (isPausedByNav=$_isPausedByNavigation)',
        name: 'HomeScreenRouter',
        category: LogCategory.video,
      );
    }
  }

  // -- Build ---------------------------------------------------------------

  static int _buildCount = 0;
  static DateTime? _lastBuildTime;

  @override
  Widget build(BuildContext context) {
    _buildCount++;
    final now = DateTime.now();
    final timeSinceLastBuild = _lastBuildTime != null
        ? now.difference(_lastBuildTime!).inMilliseconds
        : null;
    if (timeSinceLastBuild != null && timeSinceLastBuild < 100) {
      Log.warning(
        'HomeScreenRouter: RAPID REBUILD #$_buildCount! '
        'Only ${timeSinceLastBuild}ms since last build',
        name: 'HomeScreenRouter',
        category: LogCategory.video,
      );
    }
    _lastBuildTime = now;

    // Pause/resume when overlays (drawer, modals) are visible.
    final hasOverlay = ref.watch(hasVisibleOverlayProvider);
    _handleOverlayChange(hasOverlay);

    // Read the URL index synchronously from GoRouter instead of the
    // pageContextProvider stream. The stream oscillates during post-login
    // transitions (emitting stale /welcome/* locations after /home/0),
    // which prevents the home feed from ever loading.
    // HomeScreenRouter KNOWS it's the home screen — it's only mounted at
    // /home/:index — so it doesn't need route-type gating.
    final router = ref.read(goRouterProvider);
    final location = router.routeInformationProvider.value.uri.toString();
    final locationSegments = location
        .split('/')
        .where((s) => s.isNotEmpty)
        .toList();
    int urlIndex = 0;
    if (locationSegments.length > 1 && locationSegments[0] == 'home') {
      urlIndex = int.tryParse(locationSegments[1]) ?? 0;
      if (urlIndex < 0) urlIndex = 0;
    }

    // Watch homeFeedProvider directly — no route-type gate needed.
    final videosAsync = ref.watch(homeFeedProvider);

    return buildAsyncUI(
      videosAsync,
      onLoading: () => const Center(child: BrandedLoadingIndicator(size: 80)),
      onData: (state) {
        final videos = state.videos;

        if (state.lastUpdated == null && state.videos.isEmpty) {
          return const Center(child: BrandedLoadingIndicator(size: 80));
        }

        if (videos.isEmpty) {
          return const _EmptyHomeFeed();
        }

        ScreenAnalyticsService().markDataLoaded(
          'home_feed',
          dataMetrics: {'video_count': videos.length},
        );

        // Clamp URL index to valid range
        urlIndex = urlIndex.clamp(0, videos.length - 1);

        final itemCount = videos.length;

        // Initialize PageController once with URL index
        if (_controller == null) {
          final safeIndex = urlIndex.clamp(0, itemCount - 1);
          _controller = PageController(initialPage: safeIndex);
          _lastUrlIndex = safeIndex;
          _currentPageIndex = safeIndex;
        }

        // Initialize or update the pooled video feed controller
        if (_feedController == null) {
          _initializeFeedController(videos, _currentPageIndex);
        } else if (_lastPooledVideos != null) {
          _handleVideosChanged(videos);
        }

        // Sync controller when URL changes externally
        final shouldSyncNow = shouldSync(
          urlIndex: urlIndex,
          lastUrlIndex: _lastUrlIndex,
          controller: _controller,
          targetIndex: urlIndex.clamp(0, itemCount - 1),
        );

        if (shouldSyncNow) {
          Log.debug(
            'SYNCING PageController: urlIndex=$urlIndex, '
            'lastUrlIndex=$_lastUrlIndex, '
            'currentPage=${_controller?.page?.round()}',
            name: 'HomeScreenRouter',
            category: LogCategory.video,
          );
          _lastUrlIndex = urlIndex;
          syncPageController(
            controller: _controller!,
            targetIndex: urlIndex,
            itemCount: itemCount,
          );
          // Also sync the feed controller so the correct video plays
          _feedController?.onPageChanged(urlIndex);
        }

        // Prefetch profiles for adjacent videos (±1 index)
        if (urlIndex != _lastPrefetchIndex) {
          _lastPrefetchIndex = urlIndex;
          final safeIndex = urlIndex.clamp(0, itemCount - 1);
          final pubkeysToPrefetech = <String>[];

          if (safeIndex > 0) {
            pubkeysToPrefetech.add(videos[safeIndex - 1].pubkey);
          }
          if (safeIndex < itemCount - 1) {
            pubkeysToPrefetech.add(videos[safeIndex + 1].pubkey);
          }

          if (pubkeysToPrefetech.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              ref
                  .read(userProfileProvider.notifier)
                  .prefetchProfilesImmediately(pubkeysToPrefetech);
            });
          }
        }

        return VideoPoolProvider(
          pool: PlayerPool.instance,
          feedController: _feedController,
          child: RefreshIndicator(
            color: VineTheme.onPrimary,
            backgroundColor: VineTheme.vineGreen,
            semanticsLabel: 'searching for more videos',
            onRefresh: () async {
              await ref.read(homeRefreshControllerProvider).refresh();
              _handleFullRefresh(
                ref.read(homeFeedProvider).asData?.value.videos ?? [],
              );
            },
            child: PageView.builder(
              key: const Key('home-video-page-view'),
              itemCount: itemCount,
              controller: _controller,
              scrollDirection: Axis.vertical,
              onPageChanged: (newIndex) {
                setState(() {
                  _currentPageIndex = newIndex;
                });

                // Notify the pooled controller so it pauses old / plays
                // new video and updates the preload window.
                _feedController?.onPageChanged(newIndex);

                // Update URL for back navigation and deep linking
                if (newIndex != urlIndex) {
                  context.go(HomeScreenRouter.pathForIndex(newIndex));
                }

                // Trigger pagination near end
                if (newIndex >= itemCount - 2) {
                  ref.read(homePaginationControllerProvider).maybeLoadMore();
                }

                Log.debug(
                  'Page changed to index $newIndex '
                  '(${videos[newIndex].id})',
                  name: 'HomeScreenRouter',
                  category: LogCategory.video,
                );
              },
              itemBuilder: (context, index) {
                final isActive = index == _currentPageIndex;
                final video = videos[index];

                return ClipRRect(
                  child: _HomePooledVideoItem(
                    key: ValueKey('home-video-${video.id}'),
                    video: video,
                    index: index,
                    isActive: isActive,
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Per-item widgets (following _PooledFullscreenItem pattern)
// ---------------------------------------------------------------------------

/// Wraps a single video with its [VideoInteractionsBloc].
class _HomePooledVideoItem extends ConsumerWidget {
  const _HomePooledVideoItem({
    required this.video,
    required this.index,
    required this.isActive,
    super.key,
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
      child: _HomePooledVideoItemContent(
        video: video,
        index: index,
        isActive: isActive,
      ),
    );
  }
}

/// Renders a single video page using [PooledVideoPlayer].
class _HomePooledVideoItemContent extends StatelessWidget {
  const _HomePooledVideoItemContent({
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
      color: VineTheme.backgroundColor,
      child: PooledVideoPlayer(
        index: index,
        thumbnailUrl: video.thumbnailUrl,
        enableTapToPause: isActive,
        videoBuilder: (context, videoController, player) => _FittedVideoPlayer(
          videoController: videoController,
          isPortrait: isPortrait,
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
              hasBottomNavigation: true,
              hideFollowButtonIfFollowing: true,
            ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Video display helpers
// ---------------------------------------------------------------------------

class _FittedVideoPlayer extends StatelessWidget {
  const _FittedVideoPlayer({
    required this.videoController,
    this.isPortrait = true,
  });

  final VideoController videoController;
  final bool isPortrait;

  @override
  Widget build(BuildContext context) {
    final boxFit = isPortrait ? BoxFit.cover : BoxFit.contain;

    return Video(
      controller: videoController,
      fit: boxFit,
      // Transparent fill so the loading placeholder behind the Video widget
      // stays visible until the first video frame renders, preventing a
      // black flash during the loading -> playing transition.
      fill: Colors.transparent,
      filterQuality: FilterQuality.high,
      controls: NoVideoControls,
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
            errorBuilder: (_, __, ___) =>
                const ColoredBox(color: VineTheme.backgroundColor),
          )
        else
          const ColoredBox(color: VineTheme.backgroundColor),
        const Center(child: BrandedLoadingIndicator(size: 60)),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyHomeFeed extends StatelessWidget {
  const _EmptyHomeFeed();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.people_outline,
              size: 80,
              color: VineTheme.secondaryText,
            ),
            const SizedBox(height: 24),
            const Text(
              'Your Home Feed is Empty',
              style: TextStyle(
                fontSize: 22,
                color: VineTheme.whiteText,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Follow creators to see their videos here',
              style: TextStyle(fontSize: 16, color: VineTheme.secondaryText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => context.go(ExploreScreen.path),
              icon: const Icon(Icons.explore),
              label: const Text('Explore Videos'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
