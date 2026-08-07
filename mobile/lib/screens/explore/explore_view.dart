// ABOUTME: Explore view — owns the tab bar/controller and delegates tab
// ABOUTME: configuration to ExploreTabsCubit and content to tab widgets.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/explore_tabs/explore_tabs_cubit.dart';
import 'package:openvine/blocs/featured_tabs/featured_tabs_cubit.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/mixins/reduced_motion_tab_controller_mixin.dart';
import 'package:openvine/providers/classic_vines_provider.dart';
import 'package:openvine/providers/for_you_provider.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/providers/tab_visibility_provider.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/explore/explore_screen.dart';
import 'package:openvine/screens/explore/widgets/explore_feed_content.dart';
import 'package:openvine/screens/explore/widgets/explore_tab_bar.dart';
import 'package:openvine/screens/explore/widgets/explore_tab_view.dart';
import 'package:openvine/screens/search_results/view/search_results_page.dart';
import 'package:openvine/utils/nostr_apps_platform_support.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/nav_rounded_shell.dart';
import 'package:unified_logger/unified_logger.dart';

/// The explore screen body. Provided an [ExploreTabsCubit] by [ExploreScreen].
class ExploreView extends ConsumerStatefulWidget {
  /// Creates the explore view, optionally selecting [initialTabName].
  const ExploreView({this.initialTabName, this.initialTabSlug, super.key});

  /// Optional tab name to select on first build.
  final String? initialTabName;

  /// Raw URL slug, resolved against the featured tab once its configuration
  /// arrives. Unmatched slugs leave the default tab selected.
  final String? initialTabSlug;

  @override
  ConsumerState<ExploreView> createState() => _ExploreViewState();
}

class _ExploreViewState extends ConsumerState<ExploreView>
    with TickerProviderStateMixin, ReducedMotionTabControllerMixin {
  // Feed mode and videos are derived from URL + providers - no internal state.

  /// Launch slug that matched no compiled tab name; kept until the featured
  /// configuration arrives so a deep link can still land on it.
  String? _pendingFeaturedSlug;

  ExploreTabsCubit get _tabs => context.read<ExploreTabsCubit>();
  ExploreTabsState get _tabsState => _tabs.state;

  @override
  int get tabCount => _tabsState.tabCount;

  @override
  int get initialTabIndex => _indexForTabName();

  /// Index the controller should open on, resolved by name.
  ///
  /// [previousTabName] is the tab the user was on before a rebuild (resolved
  /// while the old availability flags were still in effect). Resolution order:
  /// [ExploreView.initialTabName] > previous tab > persisted tab > default.
  /// Falls back by name — never by raw index, because indices shift when
  /// optional tabs appear or disappear.
  int _indexForTabName({String? previousTabName}) {
    final targetTabName =
        widget.initialTabName ??
        previousTabName ??
        ref.read(exploreTabNameProvider);
    final index = _tabsState.indexForName(targetTabName);

    Log.info(
      '🎯 ExploreScreen: Using tab "$targetTabName" -> index $index',
      name: 'ExploreScreen',
      category: LogCategory.ui,
    );

    return index;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    syncTabController();
  }

  @override
  void initState() {
    super.initState();

    // Only a slug the compiled tab names did not claim can be the featured
    // one; anything else was already resolved into initialTabName.
    if (widget.initialTabName == null) {
      _pendingFeaturedSlug = widget.initialTabSlug;
    }

    // Track Explore-specific data load completion from child tabs.
    _tabs.trackScreenLoad();

    // Load top hashtags for trending navigation
    _loadHashtags();

    // Listen for tab changes - no need to clear active video (router-driven).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return; // Don't use ref if widget is disposed

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

  /// Returns the featured tab name when the launch URL named its configured
  /// slug.
  String? _resolvePendingFeaturedSlug(FeaturedTabConfig? featuredTab) {
    final slug = _pendingFeaturedSlug;
    if (slug == null || featuredTab == null) return null;
    return slug == featuredTab.slug ? exploreFeaturedTabName : null;
  }

  void _consumePendingFeaturedSlug() {
    _pendingFeaturedSlug = null;
  }

  Future<void> _loadHashtags() async {
    await _tabs.loadHashtags();
    // Trigger UI update to show loaded hashtags immediately
    if (mounted) {
      setState(() {});
    }
  }

  void _openSearchPage() {
    context.push(
      SearchResultsPage.pathForEmptyQuery(requestFocusOnMount: true),
    );
  }

  @override
  void onTabChanged() {
    if (!mounted) return;

    final index = tabController.index;
    final tabName = _tabsState.nameForIndex(index);

    // Persist the selected tab by stable name because optional tabs can shift
    // raw indices while Explore is alive.
    ref.read(exploreTabNameProvider.notifier).state = tabName;

    // Track tab change
    _tabs.trackTabChange(tabName);

    // Exit feed or hashtag mode when user switches tabs
    _resetToDefaultState();
  }

  void _resetToDefaultState() {
    if (!mounted) return;

    final pageContext = ref.read(pageContextProvider);
    final shouldReset =
        pageContext.whenOrNull(data: (ctx) => ctx.videoIndex != null) ?? false;

    if (shouldReset) {
      // Navigate back to grid mode (no videoIndex) — URL drives UI state.
      // TabController's index persists across route changes.
      context.go(ExploreScreen.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(exploreTabVideoUpdateListenerProvider);

    // Watch tab availability and rebuild the controller when it changes.
    final classicsAvailable =
        ref.watch(classicVinesAvailableProvider).asData?.value ?? false;
    final forYouAvailable = ref.watch(forYouAvailableProvider);
    final appsAvailable =
        nostrAppsSandboxSupported &&
        ref.watch(isFeatureEnabledProvider(FeatureFlag.integratedApps));

    final featuredTab = context.select(
      (FeaturedTabsCubit cubit) => cubit.state.tab,
    );

    final previousState = _tabsState;
    _tabs.updateAvailability(
      classicsAvailable: classicsAvailable,
      forYouAvailable: forYouAvailable,
      appsAvailable: appsAvailable,
      featuredTab: featuredTab,
    );

    if (_tabsState != previousState) {
      // Resolve the current tab name using the PREVIOUS state, because indices
      // are about to shift.
      final previousTabName = previousState.nameForIndex(tabController.index);
      // A deep link to the configured featured slug can only resolve once the
      // configuration has arrived, so honour it on the rebuild that adds the
      // tab rather than on first build.
      final shouldConsumePendingFeaturedSlug =
          _pendingFeaturedSlug != null && featuredTab != null;
      final resolvedFeaturedSlug = _resolvePendingFeaturedSlug(featuredTab);
      syncTabController(
        index: _indexForTabName(
          previousTabName: resolvedFeaturedSlug ?? previousTabName,
        ),
      );
      if (shouldConsumePendingFeaturedSlug) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _consumePendingFeaturedSlug();
        });
      }
    }

    // Derive feed mode from URL
    final isInFeedMode =
        ref
            .watch(pageContextProvider)
            .whenOrNull(
              data: (ctx) =>
                  ctx.type == RouteType.explore && ctx.videoIndex != null,
            ) ??
        false;

    // Hide tabs when in feed mode (watching a video)
    if (isInFeedMode) {
      return _buildContent();
    }

    return NavRoundedShell(
      child: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DivineSearchBar(
                hintText: context.l10n.exploreSearchHint,
                readOnly: true,
                onTap: _openSearchPage,
                semanticIdentifier: SemanticIds.exploreSearchBar,
              ),
            ),
          ),
          // Inner top radius is 2 px larger than the outer shell corners (30)
          // so the tabs container visibly sits inside the nav-rounded shell.
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(VineTheme.shellInnerCornerRadius),
              ),
              child: ColoredBox(
                color: context.vineColors.surfaceContainerHigh,
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    ExploreTabBar(
                      controller: tabController,
                      tabsState: _tabsState,
                      onTap: _onTabTap,
                    ),
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

  void _onTabTap(int index) {
    // Tapping the active tab exits feed/hashtag mode; otherwise switching tabs
    // resets to grid mode if needed.
    if (index == tabController.index) {
      final isInFeedMode =
          ref
              .read(pageContextProvider)
              .whenOrNull(data: (ctx) => ctx.videoIndex != null) ??
          false;
      if (isInFeedMode) {
        _resetToDefaultState();
      }
    } else {
      _resetToDefaultState();
    }
  }

  Widget _buildContent() {
    // Derive mode from URL (single source of truth) instead of internal state.
    return ref
        .watch(pageContextProvider)
        .when(
          data: (ctx) {
            final isInFeedMode =
                ctx.type == RouteType.explore && ctx.videoIndex != null;

            if (isInFeedMode) {
              return ExploreFeedContent(
                key: const Key('explore-feed'),
                startIndex: ctx.videoIndex ?? 0,
              );
            }

            return ExploreTabView(
              controller: tabController,
              tabsState: _tabsState,
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
}
