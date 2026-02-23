// ABOUTME: Router-driven HomeScreen using pooled_video_player (media_kit)
// ABOUTME: Matches explore feed architecture for consistent video playback

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/mixins/async_value_ui_helpers_mixin.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/home_feed_provider.dart';
import 'package:openvine/providers/home_screen_controllers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/services/screen_analytics_service.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/pooled_video_metrics_tracker.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

/// Router-driven HomeScreen - uses pooled_video_player for playback
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
    with AsyncValueUIHelpersMixin {
  VideoFeedController? _controller;
  List<VideoItem>? _lastPooledVideos;
  bool _isHomeFocused = true;
  int? _lastPrefetchIndex;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      // Listen to route changes to detect tab switches.
      // Uses ref.listenManual (imperative) instead of ref.watch (reactive) to
      // avoid triggering full rebuilds on every URL change (swipe).
      // Only updates local state when the focused-tab status actually changes.
      ref.listenManual(pageContextProvider, (prev, next) {
        if (!mounted) return;
        final ctx = next.asData?.value;
        // Skip loading/error states — don't pause on transient nulls
        if (ctx == null) return;
        final focused = ctx.type == RouteType.home;
        if (focused != _isHomeFocused) {
          _isHomeFocused = focused;
          // Pause/resume pooled player based on tab visibility
          _controller?.setActive(active: focused);
          setState(() {});
        }
      });
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// Read URL index synchronously from GoRouter.
  int _readUrlIndex() {
    final router = ref.read(goRouterProvider);
    final location = router.routeInformationProvider.value.uri.toString();
    final segments = location.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.length > 1 && segments[0] == 'home') {
      final idx = int.tryParse(segments[1]) ?? 0;
      return idx < 0 ? 0 : idx;
    }
    return 0;
  }

  /// Convert VideoEvents to VideoItems for the pooled player.
  List<VideoItem> _toPooledVideos(List<VideoEvent> videos) {
    return videos
        .where((v) => v.videoUrl != null)
        .map((e) => VideoItem(id: e.id, url: e.videoUrl!))
        .toList();
  }

  /// Initialize or update the VideoFeedController.
  void _ensureController(List<VideoItem> pooledVideos, int initialIndex) {
    if (_controller == null) {
      final safeIndex = initialIndex.clamp(0, pooledVideos.length - 1);
      _controller = VideoFeedController(
        videos: pooledVideos,
        pool: PlayerPool.instance,
        initialIndex: safeIndex,
      );
      _lastPooledVideos = pooledVideos;
      _controller!.setActive(active: _isHomeFocused);
      return;
    }

    // Handle new videos from pagination/refresh
    if (_lastPooledVideos != null) {
      final newVideos = pooledVideos
          .where((v) => !_lastPooledVideos!.any((old) => old.id == v.id))
          .toList();
      if (newVideos.isNotEmpty) {
        _controller!.addVideos(newVideos);
      }
    }
    _lastPooledVideos = pooledVideos;
  }

  @override
  Widget build(BuildContext context) {
    final urlIndex = _readUrlIndex();

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

        final pooledVideos = _toPooledVideos(videos);
        if (pooledVideos.isEmpty) {
          return const _EmptyHomeFeed();
        }

        final safeUrlIndex = urlIndex.clamp(0, pooledVideos.length - 1);

        // Initialize or update controller
        _ensureController(pooledVideos, safeUrlIndex);

        return RefreshIndicator(
          color: VineTheme.onPrimary,
          backgroundColor: VineTheme.vineGreen,
          semanticsLabel: 'searching for more videos',
          onRefresh: () => ref.read(homeRefreshControllerProvider).refresh(),
          child: PooledVideoFeed(
            key: const Key('home-video-page-view'),
            videos: pooledVideos,
            controller: _controller,
            initialIndex: safeUrlIndex,
            onActiveVideoChanged: (video, index) {
              // Update URL when swiping — deferred to avoid triggering a
              // rebuild of HomeScreenRouter during the swipe animation.
              if (index != urlIndex) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  context.go(HomeScreenRouter.pathForIndex(index));
                });
              }

              // Prefetch profiles for adjacent videos
              _prefetchProfiles(videos, index);

              Log.debug(
                'Home page changed to index $index (${video.id})',
                name: 'HomeScreenRouter',
                category: LogCategory.video,
              );
            },
            onNearEnd: (index) {
              // Load more when reaching the end
              final isAtEnd = index >= videos.length - 1;
              if (state.hasMoreContent && isAtEnd) {
                ref.read(homePaginationControllerProvider).maybeLoadMore();
              }
            },
            nearEndThreshold: 1,
            itemBuilder: (context, video, index, {required isActive}) {
              // Only mark video as active when home tab is focused.
              final effectiveActive = _isHomeFocused && isActive;
              final originalEvent = videos[index];

              return _HomePooledItem(
                video: originalEvent,
                index: index,
                isActive: effectiveActive,
              );
            },
          ),
        );
      },
    );
  }

  void _prefetchProfiles(List<VideoEvent> videos, int index) {
    if (index == _lastPrefetchIndex) return;
    _lastPrefetchIndex = index;

    final safeIndex = index.clamp(0, videos.length - 1);
    final pubkeys = <String>[];

    if (safeIndex > 0) {
      pubkeys.add(videos[safeIndex - 1].pubkey);
    }
    if (safeIndex < videos.length - 1) {
      pubkeys.add(videos[safeIndex + 1].pubkey);
    }

    if (pubkeys.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(userProfileProvider.notifier)
            .prefetchProfilesImmediately(pubkeys);
      });
    }
  }
}

/// Individual home feed item using pooled video player.
class _HomePooledItem extends ConsumerWidget {
  const _HomePooledItem({
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
      child: _HomePooledItemContent(
        video: video,
        index: index,
        isActive: isActive,
      ),
    );
  }
}

class _HomePooledItemContent extends StatelessWidget {
  const _HomePooledItemContent({
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
        videoBuilder: (context, videoController, player) =>
            PooledVideoMetricsTracker(
              key: ValueKey('metrics-${video.id}'),
              video: video,
              player: player,
              isActive: isActive,
              trafficSource: ViewTrafficSource.home,
              child: _FittedVideoPlayer(
                videoController: videoController,
                isPortrait: isPortrait,
              ),
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
              hasBottomNavigation: false,
              contextTitle: '',
              hideFollowButtonIfFollowing: true,
            ),
      ),
    );
  }
}

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
            errorBuilder: (_, __, ___) => const ColoredBox(color: Colors.black),
          )
        else
          const ColoredBox(color: Colors.black),
        const Center(child: BrandedLoadingIndicator(size: 60)),
      ],
    );
  }
}

class _EmptyHomeFeed extends StatelessWidget {
  const _EmptyHomeFeed();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, size: 80, color: Colors.grey),
            const SizedBox(height: 24),
            const Text(
              'Your Home Feed is Empty',
              style: TextStyle(
                fontSize: 22,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Follow creators to see their videos here',
              style: TextStyle(fontSize: 16, color: Colors.grey),
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
