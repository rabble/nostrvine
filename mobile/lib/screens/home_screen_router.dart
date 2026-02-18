// ABOUTME: Router-driven HomeScreen implementation (clean room)
// ABOUTME: Pure presentation with no lifecycle mutations - URL is source of truth

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/mixins/async_value_ui_helpers_mixin.dart';
import 'package:openvine/mixins/page_controller_sync_mixin.dart';
import 'package:openvine/mixins/video_prefetch_mixin.dart';
import 'package:openvine/providers/home_screen_controllers.dart';
import 'package:openvine/providers/home_feed_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:openvine/services/screen_analytics_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';

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
    with VideoPrefetchMixin, PageControllerSyncMixin, AsyncValueUIHelpersMixin {
  PageController? _controller;
  int? _lastUrlIndex;
  int? _lastPrefetchIndex;
  int _currentPageIndex = 0;

  @override
  void initState() {
    super.initState();

    final videosAsync = ref.read(homeFeedProvider);

    // Pre-initialize controllers on next frame (don't redirect - respect URL)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Initial build pre initialization
      videosAsync.whenData((state) {
        preInitializeControllers(
          ref: ref,
          currentIndex: 0,
          videos: state.videos,
          preInitBefore: 0,
          preInitAfter: 1,
        );
      });
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

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
        '⚠️ HomeScreenRouter: RAPID REBUILD #$_buildCount! Only ${timeSinceLastBuild}ms since last build',
        name: 'HomeScreenRouter',
        category: LogCategory.video,
      );
    }
    _lastBuildTime = now;

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
    // videosForHomeRouteProvider gates on pageContextProvider which
    // oscillates during post-login, causing the feed to never load.
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

        // Initialize controller once with URL index
        if (_controller == null) {
          final safeIndex = urlIndex.clamp(0, itemCount - 1);
          _controller = PageController(initialPage: safeIndex);
          _lastUrlIndex = safeIndex;
          _currentPageIndex = safeIndex;
        }

        // Sync controller when URL changes externally (back/forward/deeplink)
        final shouldSyncNow = shouldSync(
          urlIndex: urlIndex,
          lastUrlIndex: _lastUrlIndex,
          controller: _controller,
          targetIndex: urlIndex.clamp(0, itemCount - 1),
        );

        if (shouldSyncNow) {
          Log.debug(
            '🔄 SYNCING PageController: urlIndex=$urlIndex, lastUrlIndex=$_lastUrlIndex, currentPage=${_controller?.page?.round()}',
            name: 'HomeScreenRouter',
            category: LogCategory.video,
          );
          _lastUrlIndex = urlIndex;
          syncPageController(
            controller: _controller!,
            targetIndex: urlIndex,
            itemCount: itemCount,
          );
        }

        // Prefetch profiles for adjacent videos (±1 index) only when URL index changes
        if (urlIndex != _lastPrefetchIndex) {
          _lastPrefetchIndex = urlIndex;
          final safeIndex = urlIndex.clamp(0, itemCount - 1);
          final pubkeysToPrefetech = <String>[];

          // Prefetch previous video's profile
          if (safeIndex > 0) {
            pubkeysToPrefetech.add(videos[safeIndex - 1].pubkey);
          }

          // Prefetch next video's profile
          if (safeIndex < itemCount - 1) {
            pubkeysToPrefetech.add(videos[safeIndex + 1].pubkey);
          }

          // Schedule prefetch for next frame to avoid doing work during build
          if (pubkeysToPrefetech.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              ref
                  .read(userProfileProvider.notifier)
                  .prefetchProfilesImmediately(pubkeysToPrefetech);
            });
          }
        }

        return RefreshIndicator(
          color: VineTheme.onPrimary,
          backgroundColor: VineTheme.vineGreen,
          semanticsLabel: 'searching for more videos',
          onRefresh: () => ref.read(homeRefreshControllerProvider).refresh(),
          child: PageView.builder(
            key: const Key('home-video-page-view'),
            itemCount: videos.length,
            controller: _controller,
            scrollDirection: Axis.vertical,
            onPageChanged: (newIndex) {
              // Update current page state to trigger rebuild with correct
              // isActive values for all visible VideoFeedItems.
              // Without this, itemBuilder never re-runs after swipe because
              // nothing watched by this widget changes on scroll.
              setState(() {
                _currentPageIndex = newIndex;
              });

              // Update URL for back navigation and deep linking
              if (newIndex != urlIndex) {
                context.go(HomeScreenRouter.pathForIndex(newIndex));
              }

              // Trigger pagination near end
              if (newIndex >= itemCount - 2) {
                ref.read(homePaginationControllerProvider).maybeLoadMore();
              }

              // Prefetch videos around current index
              checkForPrefetch(currentIndex: newIndex, videos: videos);

              // Pre-initialize controller for next video only (minimize
              // concurrent decoders to avoid OOM on memory-constrained
              // Android devices)
              preInitializeControllers(
                ref: ref,
                currentIndex: newIndex,
                videos: videos,
                preInitBefore: 0,
                preInitAfter: 1,
              );

              // Dispose controllers outside a tight range to free memory.
              // Android devices have limited heap (~192MB) and each
              // ExoPlayer instance consumes significant native memory.
              disposeControllersOutsideRange(
                ref: ref,
                currentIndex: newIndex,
                videos: videos,
                keepBefore: 2,
                keepAfter: 3,
              );

              Log.debug(
                '📄 Page changed to index $newIndex (${videos[newIndex].id}...)',
                name: 'HomeScreenRouter',
                category: LogCategory.video,
              );
            },
            itemBuilder: (context, index) {
              final isActive = index == _currentPageIndex;

              return ClipRRect(
                child: VideoFeedItem(
                  key: ValueKey('video-${videos[index].id}'),
                  video: videos[index],
                  index: index,
                  hasBottomNavigation: false,
                  forceShowOverlay: true,
                  contextTitle: '', // Home feed has no context title
                  hideFollowButtonIfFollowing:
                      true, // Home feed only shows followed users
                  isActiveOverride: isActive,
                ),
              );
            },
          ),
        );
      },
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
