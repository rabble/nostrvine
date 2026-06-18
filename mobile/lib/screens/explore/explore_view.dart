// ABOUTME: Explore view — owns the tab bar/controller and delegates tab
// ABOUTME: configuration to ExploreTabsCubit and content to tab widgets.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/explore_tabs/explore_tabs_cubit.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
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
import 'package:openvine/utils/video_controller_cleanup.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/nav_rounded_shell.dart';
import 'package:unified_logger/unified_logger.dart';

/// The explore screen body. Provided an [ExploreTabsCubit] by [ExploreScreen].
class ExploreView extends ConsumerStatefulWidget {
  /// Creates the explore view, optionally selecting [initialTabName].
  const ExploreView({this.initialTabName, super.key});

  /// Optional tab name to select on first build.
  final String? initialTabName;

  @override
  ConsumerState<ExploreView> createState() => _ExploreViewState();
}

class _ExploreViewState extends ConsumerState<ExploreView>
    with TickerProviderStateMixin {
  TabController? _tabController;
  // Feed mode and videos are derived from URL + providers - no internal state.

  ExploreTabsCubit get _tabs => context.read<ExploreTabsCubit>();
  ExploreTabsState get _tabsState => _tabs.state;

  /// Build a new [TabController]. [previousTabName] is the name of the tab the
  /// user was on before a rebuild (resolved while the old availability flags
  /// were still in effect). Resolution order:
  /// [ExploreView.initialTabName] > [forceExploreTabNameProvider] >
  /// previous tab > default. Falls back to the default tab by name — never by
  /// raw index, because indices shift when optional tabs appear or disappear.
  void _initTabController({String? previousTabName}) {
    final forcedTabName = ref.read(forceExploreTabNameProvider);

    final targetTabName =
        widget.initialTabName ?? forcedTabName ?? previousTabName;
    final initialIndex = _tabsState.indexForName(
      targetTabName ?? exploreDefaultTabName,
    );

    if (targetTabName != null) {
      Log.info(
        '🎯 ExploreScreen: Using tab "$targetTabName" -> index $initialIndex',
        name: 'ExploreScreen',
        category: LogCategory.ui,
      );
    }

    _tabController = TabController(
      length: _tabsState.tabCount,
      vsync: this,
      initialIndex: initialIndex,
    );
    _tabController!.addListener(_onTabChanged);
  }

  @override
  void initState() {
    super.initState();

    _initTabController();

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

  Future<void> _loadHashtags() async {
    await _tabs.loadHashtags();
    // Trigger UI update to show loaded hashtags immediately
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController?.removeListener(_onTabChanged);
    _tabController?.dispose();
    super.dispose();
  }

  void _openSearchPage() {
    context.push(
      SearchResultsPage.pathForEmptyQuery(requestFocusOnMount: true),
    );
  }

  void _onTabChanged() {
    if (!mounted || _tabController == null) return;

    final index = _tabController!.index;
    final tabName = _tabsState.nameForIndex(index);

    // Check if there's a forced tab name
    final forcedName = ref.read(forceExploreTabNameProvider);
    if (forcedName != null && tabName != forcedName) {
      // User switched to a different tab than the forced one — clear the force.
      Log.info(
        '🎯 ExploreScreen: User changed tab from forced "$forcedName" to '
        '"$tabName", clearing force',
        name: 'ExploreScreen',
        category: LogCategory.ui,
      );
      ref.read(forceExploreTabNameProvider.notifier).state = null;
    }

    // Always persist the current index
    ref.read(exploreTabIndexProvider.notifier).state = index;

    // Track tab change
    _tabs.trackTabChange(tabName);

    // Exit feed or hashtag mode when user switches tabs
    _resetToDefaultState();
  }

  void _resetToDefaultState() {
    if (!mounted) return;

    final pageContext = ref.read(pageContextProvider);
    final wasInFeedMode =
        pageContext.whenOrNull(data: (ctx) => ctx.videoIndex != null) ?? false;
    final shouldReset =
        pageContext.whenOrNull(data: (ctx) => ctx.videoIndex != null) ?? false;

    if (shouldReset) {
      // Stop all video playback BEFORE navigating back to grid mode so videos
      // don't keep playing in the background when switching tabs.
      // videoControllerAutoCleanupProvider only triggers on route TYPE changes,
      // not when staying on the same route type (explore), so cleanup here.
      if (wasInFeedMode) {
        disposeAllVideoControllers(ref);
      }

      // Navigate back to grid mode (no videoIndex) — URL drives UI state.
      // TabController's index persists across route changes.
      context.go(ExploreScreen.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(exploreTabVideoUpdateListenerProvider);

    // Apply a forced tab name set before navigating to this screen.
    final forcedTabName = ref.watch(forceExploreTabNameProvider);
    if (forcedTabName != null && _tabController != null) {
      final targetIndex = _tabsState.indexForName(forcedTabName);
      if (_tabController!.index != targetIndex) {
        // Schedule tab change for after build (don't clear provider yet).
        Future(() {
          if (mounted && _tabController != null) {
            _tabController!.animateTo(targetIndex);
          }
        });
      }
    }

    // Watch tab availability and rebuild the controller when it changes.
    final classicsAvailable =
        ref.watch(classicVinesAvailableProvider).asData?.value ?? false;
    final forYouAvailable = ref.watch(forYouAvailableProvider);
    final appsAvailable =
        nostrAppsSandboxSupported &&
        ref.watch(isFeatureEnabledProvider(FeatureFlag.integratedApps));

    final previousState = _tabsState;
    _tabs.updateAvailability(
      classicsAvailable: classicsAvailable,
      forYouAvailable: forYouAvailable,
      appsAvailable: appsAvailable,
    );

    if (_tabsState != previousState) {
      // Resolve the current tab name using the PREVIOUS state, because indices
      // are about to shift.
      final previousTabName = previousState.nameForIndex(
        _tabController?.index ?? 0,
      );

      _tabController?.removeListener(_onTabChanged);
      final oldController = _tabController;
      _initTabController(previousTabName: previousTabName);
      oldController?.dispose();
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
                color: VineTheme.surfaceContainerHigh,
                child: Column(
                  children: [
                    const SizedBox(height: 12),
                    ExploreTabBar(
                      controller: _tabController,
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
    if (index == _tabController?.index) {
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
              controller: _tabController,
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
