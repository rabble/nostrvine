// ABOUTME: Explore screen with proper Vine theme and video grid functionality
// ABOUTME: Pure Riverpod architecture for video discovery with grid/feed modes

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/mixins/grid_prefetch_mixin.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/classic_vines_provider.dart';
import 'package:openvine/providers/for_you_provider.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/providers/tab_visibility_provider.dart';
import 'package:openvine/providers/video_events_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/apps/apps_directory_screen.dart';
import 'package:openvine/screens/curated_list_feed_screen.dart';
import 'package:openvine/screens/discover_lists_screen.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/screens/hashtag_feed_screen.dart';
import 'package:openvine/screens/search_results/view/search_results_page.dart';
import 'package:openvine/screens/user_list_people_screen.dart';
import 'package:openvine/services/error_analytics_tracker.dart';
import 'package:openvine/services/feed_performance_tracker.dart';
import 'package:openvine/services/screen_analytics_service.dart';
import 'package:openvine/services/top_hashtags_service.dart';
import 'package:openvine/utils/nostr_apps_platform_support.dart';
import 'package:openvine/utils/video_controller_cleanup.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/categories_tab.dart';
import 'package:openvine/widgets/classic_vines_tab.dart';
import 'package:openvine/widgets/for_you_tab.dart';
import 'package:openvine/widgets/list_card.dart';
import 'package:openvine/widgets/new_videos_tab.dart';
import 'package:openvine/widgets/popular_videos_tab.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:rxdart/rxdart.dart' show StartWithExtension;
import 'package:unified_logger/unified_logger.dart';

/// Pure ExploreScreen using revolutionary Riverpod architecture
class ExploreScreen extends ConsumerStatefulWidget {
  /// Route name for this screen.
  static const routeName = 'explore';

  /// Path for this route (grid mode).
  static const path = '/explore';

  /// Path for this route with index (feed mode).
  static const pathWithIndex = '/explore/:index';

  /// Build path for grid mode or specific index.
  static String pathForIndex(int? index) =>
      index == null ? path : '$path/$index';

  const ExploreScreen({super.key});

  @override
  ConsumerState<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends ConsumerState<ExploreScreen>
    with TickerProviderStateMixin, GridPrefetchMixin {
  TabController? _tabController;
  // Feed mode and videos are now derived from URL + providers - no internal state needed
  String? _hashtagMode; // When non-null, showing hashtag feed
  String? _customTitle; // Custom title to override default "Explore"

  // Search bar state
  final _searchController = TextEditingController();
  Timer? _searchDebounce;

  // Track classics availability to rebuild tabs when it changes
  bool _classicsAvailable = false;
  // Track For You availability (staging only)
  bool _forYouAvailable = false;
  // Track Integrated Apps feature flag
  bool _appsAvailable = false;

  // Analytics services
  final _screenAnalytics = ScreenAnalyticsService();
  final _feedTracker = FeedPerformanceTracker();
  final _errorTracker = ErrorAnalyticsTracker();

  /// Calculate tab count based on feature availability
  /// Base: New Videos, Trending, Categories, Lists = 4
  /// +1 if Classics available, +1 if For You available, +1 if Apps enabled
  int get _tabCount {
    int count = 4; // Base tabs: New Videos, Trending, Categories, Lists
    if (_classicsAvailable) count++;
    if (_forYouAvailable) count++;
    if (_appsAvailable) count++;
    return count;
  }

  /// Get the current tab names in order based on availability
  List<String> get _tabNames {
    final names = <String>[];
    if (_classicsAvailable) names.add('classics');
    names.addAll(['new', 'popular', 'categories']);
    if (_forYouAvailable) names.add('for_you');
    names.add('lists');
    if (_appsAvailable) names.add('apps');
    return names;
  }

  /// Convert a tab name to index based on current availability
  int _tabNameToIndex(String name) {
    final index = _tabNames.indexOf(name);
    return index >= 0 ? index : 1; // Default to index 1 if not found
  }

  /// Convert a tab index to name based on current availability
  String _tabIndexToName(int index) {
    final names = _tabNames;
    if (index >= 0 && index < names.length) {
      return names[index];
    }
    return 'popular'; // Default
  }

  void _initTabController() {
    // Check for forced tab NAME first (survives tab availability changes)
    // Don't clear it here - let it persist until user manually changes tabs
    final forcedTabName = ref.read(forceExploreTabNameProvider);
    int initialIndex;

    if (forcedTabName != null) {
      initialIndex = _tabNameToIndex(forcedTabName);
      Log.info(
        '🎯 ExploreScreen: Using forced tab "$forcedTabName" -> index $initialIndex',
        name: 'ExploreScreen',
        category: LogCategory.ui,
      );
    } else {
      // Fall back to saved index
      final savedTabIndex = ref.read(exploreTabIndexProvider);
      initialIndex = savedTabIndex.clamp(0, _tabCount - 1);
    }

    _tabController = TabController(
      length: _tabCount,
      vsync: this,
      initialIndex: initialIndex,
    );
    _tabController!.addListener(_onTabChanged);
  }

  @override
  void initState() {
    super.initState();

    _initTabController();
    _searchController.addListener(_onSearchChanged);

    // Track screen load
    _screenAnalytics.startScreenLoad('explore_screen');
    _screenAnalytics.trackScreenView('explore_screen');

    // Load top hashtags for trending navigation
    _loadHashtags();

    Log.info(
      '🎯 ExploreScreenPure: Initialized with revolutionary architecture',
      category: LogCategory.video,
    );

    // Listen for tab changes - no need to clear active video (router-driven now)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return; // Safety check: don't use ref if widget is disposed

      ref.listenManual(tabVisibilityProvider, (prev, next) {
        if (next != 2) {
          // This tab (Explore = tab 2) is no longer visible
          Log.info(
            '🔄 Tab 2 (Explore) hidden',
            name: 'ExploreScreen',
            category: LogCategory.ui,
          );
        }
      });
    });
  }

  Future<void> _loadHashtags() async {
    Log.info(
      '🏷️ ExploreScreen: Starting hashtag load',
      category: LogCategory.video,
    );
    await TopHashtagsService.instance.loadTopHashtags();
    final count = TopHashtagsService.instance.topHashtags.length;
    Log.info(
      '🏷️ ExploreScreen: Hashtags loaded: $count total, isLoaded=${TopHashtagsService.instance.isLoaded}',
      category: LogCategory.video,
    );

    // Trigger UI update to show loaded hashtags immediately
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    _tabController?.removeListener(_onTabChanged);
    _tabController?.dispose();
    super.dispose();

    Log.info(
      '🎯 ExploreScreenPure: Disposed cleanly',
      category: LogCategory.video,
    );
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    final query = _searchController.text.trim();
    if (query.length < 2) return;
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _searchController.clear();
      context.push(SearchResultsPage.pathForQuery(query));
    });
  }

  void _onTabChanged() {
    if (!mounted || _tabController == null) return;

    final index = _tabController!.index;
    final tabName = _tabIndexToName(index);

    Log.debug(
      '🎯 ExploreScreenPure: Switched to tab $index ($tabName)',
      category: LogCategory.video,
    );

    // Check if there's a forced tab name
    final forcedName = ref.read(forceExploreTabNameProvider);
    if (forcedName != null) {
      // If user switched to a different tab than the forced one, clear the force
      if (tabName != forcedName) {
        Log.info(
          '🎯 ExploreScreen: User changed tab from forced "$forcedName" to "$tabName", clearing force',
          name: 'ExploreScreen',
          category: LogCategory.ui,
        );
        ref.read(forceExploreTabNameProvider.notifier).state = null;
      }
      // If we're on the forced tab, don't clear it yet (might need it for rebuilds)
    }

    // Always persist the current index
    ref.read(exploreTabIndexProvider.notifier).state = index;

    // Track tab change
    _screenAnalytics.trackTabChange(
      screenName: 'explore_screen',
      tabName: tabName,
    );

    // Exit feed or hashtag mode when user switches tabs
    _resetToDefaultState();
  }

  void _resetToDefaultState() {
    if (!mounted) return;

    // Check current page context to see if we need to reset
    final pageContext = ref.read(pageContextProvider);
    final wasInFeedMode =
        pageContext.whenOrNull(data: (ctx) => ctx.videoIndex != null) ?? false;
    final shouldReset =
        pageContext.whenOrNull(
          data: (ctx) => ctx.videoIndex != null || _hashtagMode != null,
        ) ??
        false;

    if (shouldReset) {
      // CRITICAL: Stop all video playback BEFORE navigating back to grid mode
      // This prevents videos from playing in the background when switching tabs
      // videoControllerAutoCleanupProvider only triggers on route TYPE changes,
      // not when staying on the same route type (explore), so we must cleanup here
      if (wasInFeedMode) {
        Log.info(
          '🛑 ExploreScreen: Stopping video playback before exiting feed mode',
          name: 'ExploreScreen',
          category: LogCategory.video,
        );
        disposeAllVideoControllers(ref);
      }

      // Clear hashtag mode
      _hashtagMode = null;
      setCustomTitle(null); // Clear custom title

      // Navigate back to grid mode (no videoIndex) - URL will drive UI state
      // Note: This navigation resets to the grid view, preserving the current tab
      // because TabController's index persists across route changes
      context.go(ExploreScreen.path);

      Log.info(
        '🎯 ExploreScreenPure: Reset to default state',
        category: LogCategory.video,
      );
    }
  }

  // Public method that can be called when same tab is tapped
  void onTabTapped() {
    _resetToDefaultState();
  }

  void _enterFeedMode(List<VideoEvent> videos, int startIndex) {
    if (!mounted) return;

    // Pre-warm adjacent videos before navigation for faster playback
    prefetchAroundIndex(startIndex, videos);

    // Store video list in provider so it survives widget recreation
    ref.read(exploreTabVideosProvider.notifier).state = videos;

    // Navigate to update URL - URL will drive the UI state (no internal state needed!)
    // videoIndex maps directly to list index (0=first video, 1=second video)
    context.go(ExploreScreen.pathForIndex(startIndex));

    Log.info(
      '🎯 ExploreScreenPure: Entered feed mode at index $startIndex with ${videos.length} videos',
      category: LogCategory.video,
    );
  }

  void _enterHashtagMode(String hashtag) {
    if (!mounted) return;

    setState(() {
      _hashtagMode = hashtag;
    });

    setCustomTitle('#$hashtag');

    Log.info(
      '🎯 ExploreScreenPure: Entered hashtag mode for #$hashtag',
      category: LogCategory.video,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(exploreTabVideoUpdateListenerProvider);

    // Check for forced tab name (set before navigating to this screen)
    // This handles the case where ExploreScreen is already mounted in the shell
    // Don't clear the provider here - let it persist until user manually changes tabs
    final forcedTabName = ref.watch(forceExploreTabNameProvider);
    if (forcedTabName != null && _tabController != null) {
      final targetIndex = _tabNameToIndex(forcedTabName);
      if (_tabController!.index != targetIndex) {
        Log.info(
          '🎯 ExploreScreen: Applying forced tab "$forcedTabName" -> index $targetIndex (from build)',
          name: 'ExploreScreen',
          category: LogCategory.ui,
        );
        // Schedule tab change for after build (don't clear provider yet)
        Future(() {
          if (mounted && _tabController != null) {
            _tabController!.animateTo(targetIndex);
          }
        });
      }
    }

    // Watch classics availability and rebuild tabs if it changes
    final classicsAvailableAsync = ref.watch(classicVinesAvailableProvider);
    final newClassicsAvailable = classicsAvailableAsync.asData?.value ?? false;

    // Watch For You availability (staging only)
    final newForYouAvailable = ref.watch(forYouAvailableProvider);

    // Watch Integrated Apps feature flag (also requires platform support)
    final newAppsAvailable =
        nostrAppsSandboxSupported &&
        ref.watch(isFeatureEnabledProvider(FeatureFlag.integratedApps));

    // When availability changes, rebuild TabController synchronously
    final needsRebuild =
        _classicsAvailable != newClassicsAvailable ||
        _forYouAvailable != newForYouAvailable ||
        _appsAvailable != newAppsAvailable;

    if (needsRebuild) {
      Log.info(
        '🎯 ExploreScreen: Tab availability changed - '
        'classics: $_classicsAvailable -> $newClassicsAvailable, '
        'forYou: $_forYouAvailable -> $newForYouAvailable, '
        'apps: $_appsAvailable -> $newAppsAvailable',
        name: 'ExploreScreen',
        category: LogCategory.ui,
      );
      _classicsAvailable = newClassicsAvailable;
      _forYouAvailable = newForYouAvailable;
      _appsAvailable = newAppsAvailable;

      // Rebuild tab controller to match the new tab count
      // _initTabController handles forced tab name -> correct index conversion
      _tabController?.removeListener(_onTabChanged);
      _tabController?.dispose();
      _initTabController();
    }

    // Derive feed mode from URL
    final pageContext = ref.watch(pageContextProvider);
    final isInFeedMode =
        pageContext.whenOrNull(
          data: (ctx) =>
              ctx.type == RouteType.explore && ctx.videoIndex != null,
        ) ??
        false;

    // Hide tabs when in feed mode (watching a video)
    if (isInFeedMode) {
      return _buildContent();
    }

    // Show Column with search bar + TabBar + content in grid mode
    // surfaceBackground (#00150D) fills behind the rounded top corners
    return ColoredBox(
      color: VineTheme.surfaceBackground,
      child: Column(
        children: [
          // Top area: SafeArea + search bar on surfaceBackground
          // Search bar shown when newSearch feature flag is enabled
          SafeArea(
            bottom: false,
            child: ref.watch(isFeatureEnabledProvider(FeatureFlag.newSearch))
                ? Padding(
                    padding: const EdgeInsets.all(16),
                    child: DivineSearchBar(
                      controller: _searchController,
                      hintText: 'Search...',
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          // Tab bar + content with rounded top corners
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(32),
                topRight: Radius.circular(32),
              ),
              child: ColoredBox(
                color: VineTheme.surfaceContainerHigh,
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    // Tabs only visible in grid mode
                    // Material widget is required for TabBar ink splashes
                    // PointerInterceptor ensures tabs receive taps on web
                    PointerInterceptor(
                      intercepting: kIsWeb,
                      child: Material(
                        color: VineTheme.transparent,
                        child: Stack(
                          children: [
                            TabBar(
                              controller: _tabController,
                              isScrollable: true,
                              tabAlignment: TabAlignment.start,
                              padding: const EdgeInsetsDirectional.only(
                                start: 16,
                              ),
                              indicatorColor: VineTheme.tabIndicatorGreen,
                              indicatorWeight: 4,
                              indicatorSize: TabBarIndicatorSize.tab,
                              dividerColor: VineTheme.transparent,
                              labelColor: VineTheme.whiteText,
                              unselectedLabelColor: VineTheme.onSurfaceMuted55,
                              labelPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                              ),
                              labelStyle: VineTheme.titleMediumFont(),
                              unselectedLabelStyle: VineTheme.titleMediumFont(
                                color: VineTheme.onSurfaceMuted55,
                              ),
                              onTap: (index) {
                                // If tapping the currently active tab, reset to default state (exit feed/hashtag mode)
                                // But only if we're actually in feed or hashtag mode - otherwise do nothing
                                if (index == _tabController?.index) {
                                  final pageContext = ref.read(
                                    pageContextProvider,
                                  );
                                  final isInFeedMode =
                                      pageContext.whenOrNull(
                                        data: (ctx) => ctx.videoIndex != null,
                                      ) ??
                                      false;
                                  final isInHashtagMode = _hashtagMode != null;

                                  if (isInFeedMode || isInHashtagMode) {
                                    _resetToDefaultState();
                                  } else {
                                    Log.debug(
                                      '🎯 ExploreScreen: Already in grid mode for tab $index, ignoring tap',
                                      category: LogCategory.video,
                                    );
                                  }
                                } else {
                                  // Switching to a different tab - reset to grid mode if needed
                                  _resetToDefaultState();
                                }
                              },
                              tabs: [
                                if (_classicsAvailable)
                                  Tab(text: context.l10n.exploreTabClassics),
                                Tab(text: context.l10n.exploreTabNew),
                                Tab(text: context.l10n.exploreTabPopular),
                                Tab(text: context.l10n.exploreTabCategories),
                                if (_forYouAvailable)
                                  Tab(text: context.l10n.exploreTabForYou),
                                Tab(text: context.l10n.exploreTabLists),
                                if (_appsAvailable)
                                  Tab(
                                    text: context.l10n.exploreTabIntegratedApps,
                                  ),
                              ],
                            ),
                            // Right-edge fade gradient shim
                            const Positioned(
                              top: 0,
                              bottom: 0,
                              right: 0,
                              width: 24,
                              child: IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.centerRight,
                                      end: Alignment.centerLeft,
                                      colors: [
                                        VineTheme.surfaceContainerHigh,
                                        Color(0x00000A06),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Content changes based on mode
                    Expanded(child: _buildContent()),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    // Derive mode from URL (single source of truth) instead of internal state
    final pageContext = ref.watch(pageContextProvider);

    return pageContext.when(
      data: (ctx) {
        // Check if we're in feed mode by looking at URL's videoIndex parameter
        final bool isInFeedMode =
            ctx.type == RouteType.explore && ctx.videoIndex != null;

        if (isInFeedMode) {
          return _ExploreFeedContent(
            key: const Key('explore-feed'),
            startIndex: ctx.videoIndex ?? 0,
          );
        }

        // IMPORTANT: Clear hashtag mode when URL shows we're on main explore
        // This handles the case where user taps bottom nav "Explore" to go back
        if (ctx.type == RouteType.explore &&
            ctx.hashtag == null &&
            _hashtagMode != null) {
          Log.info(
            '🔄 Clearing hashtag mode: URL is main explore but _hashtagMode=$_hashtagMode',
            name: 'ExploreScreen',
            category: LogCategory.ui,
          );
          // Schedule the state clear for after this build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _hashtagMode = null;
                _customTitle = null;
              });
            }
          });
          // Still show the grid content this frame (not hashtag content)
        } else if (_hashtagMode != null) {
          Log.debug(
            '🏷️ Showing hashtag mode: $_hashtagMode',
            name: 'ExploreScreen',
            category: LogCategory.ui,
          );
          return _buildHashtagModeContent(_hashtagMode!);
        }

        // Default: show tab view with banner
        return Stack(
          children: [
            TabBarView(
              controller: _tabController,
              children: [
                if (_classicsAvailable) const ClassicVinesTab(),
                NewVideosTab(
                  screenAnalytics: _screenAnalytics,
                  feedTracker: _feedTracker,
                  errorTracker: _errorTracker,
                ),
                PopularVideosTab(
                  screenAnalytics: _screenAnalytics,
                  feedTracker: _feedTracker,
                  errorTracker: _errorTracker,
                ),
                const CategoriesTab(),
                if (_forYouAvailable) const ForYouTab(),
                _buildListsTab(),
                if (_appsAvailable) const AppsDirectoryScreen(embedded: true),
              ],
            ),
            // New videos banner (only show on New Videos and Trending tabs)
            // New Videos is at index 0 (or 1 if Classics available)
            // Trending is at index 1 (or 2 if Classics available)
            if (_tabController != null)
              Builder(
                builder: (context) {
                  final newVideosIndex = _classicsAvailable ? 1 : 0;
                  final trendingIndex = _classicsAvailable ? 2 : 1;
                  final currentIndex = _tabController!.index;
                  if (currentIndex == newVideosIndex ||
                      currentIndex == trendingIndex) {
                    return _buildNewVideosBanner();
                  }
                  return const SizedBox.shrink();
                },
              ),
          ],
        );
      },
      loading: () => const Center(child: BrandedLoadingIndicator()),
      error: (e, s) => Center(
        child: Text(
          context.l10n.exploreErrorPrefix(e),
          style: const TextStyle(color: VineTheme.likeRed),
        ),
      ),
    );
  }

  Widget _buildHashtagModeContent(String hashtag) {
    // Return hashtag feed with callback to enter feed mode inline
    return HashtagFeedScreen(
      hashtag: hashtag,
      embedded: true,
      onVideoTap: _enterFeedMode,
    );
  }

  Widget _buildListsTab() {
    // Load data but don't wait for everything - show UI progressively
    final allListsAsync = ref.watch(allListsProvider);

    // Always show the static UI elements immediately
    return RefreshIndicator(
      color: VineTheme.onPrimary,
      backgroundColor: VineTheme.vineGreen,
      onRefresh: () async {
        // Invalidate both providers to refresh
        ref.invalidate(userListsProvider);
        ref.invalidate(curatedListsProvider);
      },
      child: ListView(
        key: const Key('lists-tab-content'),
        children: [
          // Discover Lists button - ALWAYS VISIBLE
          Padding(
            padding: const EdgeInsets.all(16),
            child: DivineButton(
              leadingIcon: .search,
              label: context.l10n.exploreDiscoverLists,
              onPressed: () {
                Log.info(
                  'Tapped Discover Lists button',
                  category: LogCategory.ui,
                );
                // Stop any playing videos before navigating
                disposeAllVideoControllers(ref);
                context.push(DiscoverListsScreen.path);
              },
            ),
          ),

          // Help text - ALWAYS VISIBLE
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: VineTheme.cardBackground,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: VineTheme.vineGreen.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: VineTheme.vineGreen,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      context.l10n.exploreAboutLists,
                      style: const TextStyle(
                        color: VineTheme.whiteText,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  context.l10n.exploreAboutListsDescription,
                  style: const TextStyle(
                    color: VineTheme.primaryText,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.group,
                      color: VineTheme.vineGreen,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.explorePeopleLists,
                            style: const TextStyle(
                              color: VineTheme.whiteText,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.l10n.explorePeopleListsDescription,
                            style: const TextStyle(
                              color: VineTheme.secondaryText,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.video_library,
                      color: VineTheme.vineGreen,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.l10n.exploreVideoLists,
                            style: const TextStyle(
                              color: VineTheme.whiteText,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            context.l10n.exploreVideoListsDescription,
                            style: const TextStyle(
                              color: VineTheme.secondaryText,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // MY LISTS and PEOPLE LISTS - Show immediately when data available
          allListsAsync.when(
            skipLoadingOnRefresh: true,
            data: (data) {
              final userLists = data.userLists;
              final myLists = data.curatedLists.where((list) {
                // Lists without nostrEventId are local-only user lists
                return list.nostrEventId == null;
              }).toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // My Lists section
                  if (myLists.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.video_library,
                            color: VineTheme.vineGreen,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            context.l10n.exploreMyLists,
                            style: const TextStyle(
                              color: VineTheme.primaryText,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...myLists.map(
                      (curatedList) => CuratedListCard(
                        curatedList: curatedList,
                        onTap: () {
                          Log.info(
                            'Tapped my curated list: ${curatedList.name}',
                            category: LogCategory.ui,
                          );
                          // Stop any playing videos before navigating
                          disposeAllVideoControllers(ref);
                          context.push(
                            CuratedListFeedScreen.pathForId(curatedList.id),
                            extra: CuratedListRouteExtra(
                              listName: curatedList.name,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // People Lists section
                  if (userLists.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.group,
                            color: VineTheme.vineGreen,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            context.l10n.explorePeopleLists,
                            style: const TextStyle(
                              color: VineTheme.primaryText,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...userLists.map(
                      (userList) => UserListCard(
                        userList: userList,
                        onTap: () {
                          Log.info(
                            'Tapped user list: ${userList.name}',
                            category: LogCategory.ui,
                          );
                          // Stop any playing videos before navigating
                          disposeAllVideoControllers(ref);
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(
                              builder: (context) =>
                                  UserListPeopleScreen(userList: userList),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ],
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: BrandedLoadingIndicator(size: 60)),
            ),
            error: (error, stack) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                context.l10n.exploreErrorLoadingLists(error),
                style: const TextStyle(color: VineTheme.likeRed),
              ),
            ),
          ),

          // SUBSCRIBED LISTS - Load separately with its own loading state
          _buildSubscribedListsSection(),
        ],
      ),
    );
  }

  /// Build subscribed lists section with independent loading state
  Widget _buildSubscribedListsSection() {
    final allListsAsync = ref.watch(allListsProvider);
    final serviceAsync = ref.watch(curatedListsStateProvider);
    final service = ref.read(curatedListsStateProvider.notifier).service;
    // Wait for both to load subscribed lists
    if (!allListsAsync.hasValue || !serviceAsync.hasValue) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.playlist_add_check,
                  color: VineTheme.vineGreen,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  context.l10n.exploreSubscribedLists,
                  style: const TextStyle(
                    color: VineTheme.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Center(child: BrandedLoadingIndicator(size: 60)),
          ],
        ),
      );
    }

    final allCuratedLists = allListsAsync.value!.curatedLists;

    // Filter subscribed lists
    final subscribedLists = allCuratedLists.where((list) {
      return service?.isSubscribedToList(list.id) ?? false;
    }).toList();

    if (subscribedLists.isEmpty) {
      return const SizedBox.shrink(); // Don't show section if no subscribed lists
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(
                Icons.playlist_add_check,
                color: VineTheme.vineGreen,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.exploreSubscribedLists,
                style: const TextStyle(
                  color: VineTheme.primaryText,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        ...subscribedLists.map(
          (curatedList) => CuratedListCard(
            curatedList: curatedList,
            onTap: () {
              Log.info(
                'Tapped subscribed list: ${curatedList.name}',
                category: LogCategory.ui,
              );
              // Stop any playing videos before navigating
              disposeAllVideoControllers(ref);
              context.push(
                CuratedListFeedScreen.pathForId(curatedList.id),
                extra: CuratedListRouteExtra(listName: curatedList.name),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // Public methods expected by main.dart
  void onScreenVisible() {
    // Handle screen becoming visible
    Log.debug('🎯 ExploreScreen became visible', category: LogCategory.video);

    // Enable buffering to prevent jarring auto-updates while browsing
    ref.read(videoEventsProvider.notifier).enableBuffering();
  }

  void onScreenHidden() {
    // Handle screen becoming hidden
    Log.debug('🎯 ExploreScreen became hidden', category: LogCategory.video);

    // Disable buffering when hidden (so videos load normally when returning)
    ref.read(videoEventsProvider.notifier).disableBuffering();
  }

  String? get currentHashtag => _hashtagMode;
  String? get customTitle => _customTitle;

  void setCustomTitle(String? title) {
    if (_customTitle != title) {
      setState(() {
        _customTitle = title;
      });
      // Note: Title updates are now handled by router-driven app bar
    }
  }

  void showHashtagVideos(String hashtag) {
    Log.debug(
      '🎯 ExploreScreen showing hashtag videos: $hashtag',
      category: LogCategory.video,
    );
    _enterHashtagMode(hashtag);
  }

  /// Build banner that shows when new videos are buffered
  Widget _buildNewVideosBanner() {
    final bufferedCount = ref.watch(bufferedVideoCountProvider);

    if (bufferedCount == 0) {
      return const SizedBox.shrink();
    }

    return Positioned(
      top: 16,
      left: 0,
      right: 0,
      child: Center(
        child: Semantics(
          label: context.l10n.exploreLoadNewVideosLabel(bufferedCount),
          button: true,
          child: GestureDetector(
            onTap: () {
              // Load buffered videos
              ref.read(videoEventsProvider.notifier).loadBufferedVideos();
              Log.info(
                '🔄 ExploreScreen: Loaded $bufferedCount buffered videos',
                category: LogCategory.video,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: VineTheme.vineGreen,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: VineTheme.backgroundColor.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.arrow_upward,
                    color: VineTheme.backgroundColor,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.exploreNewVideosCount(bufferedCount),
                    style: const TextStyle(
                      color: VineTheme.backgroundColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Stateful widget that streams [exploreTabVideosProvider] updates into
/// [PooledFullscreenVideoFeedScreen] so pagination appends are visible.
class _ExploreFeedContent extends ConsumerStatefulWidget {
  const _ExploreFeedContent({required this.startIndex, super.key});

  final int startIndex;

  @override
  ConsumerState<_ExploreFeedContent> createState() =>
      _ExploreFeedContentState();
}

class _ExploreFeedContentState extends ConsumerState<_ExploreFeedContent> {
  late final StreamController<List<VideoEvent>> _streamController;
  List<VideoEvent>? _lastVideos;

  @override
  void initState() {
    super.initState();
    _streamController = StreamController<List<VideoEvent>>.broadcast();
  }

  @override
  void dispose() {
    _streamController.close();
    super.dispose();
  }

  void _pushVideos(List<VideoEvent> videos) {
    if (videos.isEmpty) return;
    if (identical(videos, _lastVideos)) return;
    _lastVideos = videos;
    if (!_streamController.isClosed) _streamController.add(videos);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(divineHostFilterVersionProvider);
    final videoEventService = ref.read(videoEventServiceProvider);
    final videos = videoEventService.filterVideoList(
      ref.watch(exploreTabVideosProvider) ?? const <VideoEvent>[],
    );

    if (videos.isEmpty) {
      return Center(
        child: Text('No videos available', style: VineTheme.bodyMediumFont()),
      );
    }

    _pushVideos(videos);

    final safeIndex = widget.startIndex.clamp(0, videos.length - 1);

    return PooledFullscreenVideoFeedScreen(
      videosStream: _streamController.stream.startWith(videos),
      initialIndex: safeIndex,
      contextTitle: '',
      onPageChanged: (index) => context.go(ExploreScreen.pathForIndex(index)),
    );
  }
}
