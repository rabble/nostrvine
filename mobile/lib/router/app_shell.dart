// ABOUTME: AppShell widget providing bottom navigation and dynamic header
// ABOUTME: Header title changes based on route with Pacifico font, includes camera button

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/vine_drawer.dart';
import 'package:openvine/widgets/environment_indicator.dart';
import 'package:openvine/providers/active_video_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/utils/npub_hex.dart';
import 'page_context_provider.dart';
import 'route_utils.dart';
import 'nav_extensions.dart';
import 'last_tab_position_provider.dart';
import 'tab_history_provider.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.child, required this.currentIndex});

  final Widget child;
  final int currentIndex;

  String _titleFor(WidgetRef ref) {
    final ctx = ref.watch(pageContextProvider).asData?.value;
    switch (ctx?.type) {
      case RouteType.home:
        return 'Home';
      case RouteType.explore:
        return 'Explore';
      case RouteType.notifications:
        return 'Notifications';
      case RouteType.hashtag:
        final raw = ctx?.hashtag ?? '';
        return raw.isEmpty ? '#—' : '#$raw';
      case RouteType.profile:
        final npub = ctx?.npub ?? '';
        if (npub == 'me') {
          return 'My Profile';
        }
        // Get user profile to show their display name
        final userIdHex = npubToHexOrNull(npub);
        if (userIdHex != null) {
          final profileAsync = ref.watch(fetchUserProfileProvider(userIdHex));
          final displayName = profileAsync.value?.displayName;
          if (displayName != null && !displayName.startsWith('npub1')) {
            return displayName;
          }
        }
        return 'Profile';
      case RouteType.search:
        return 'Search';
      default:
        return '';
    }
  }

  /// Maps tab index to RouteType
  RouteType _routeTypeForTab(int index) {
    switch (index) {
      case 0:
        return RouteType.home;
      case 1:
        return RouteType.explore;
      case 2:
        return RouteType.notifications;
      case 3:
        return RouteType.profile;
      default:
        return RouteType.home;
    }
  }

  /// Maps RouteType to tab index
  /// Returns null if not a main tab route
  int? _tabIndexFromRouteType(RouteType type) {
    switch (type) {
      case RouteType.home:
        return 0;
      case RouteType.explore:
      case RouteType.hashtag: // Hashtag is part of explore tab
        return 1;
      case RouteType.notifications:
        return 2;
      case RouteType.profile:
        return 3;
      default:
        return null; // Not a main tab route
    }
  }

  /// Handles tab tap - navigates to last known position in that tab
  void _handleTabTap(BuildContext context, WidgetRef ref, int tabIndex) {
    final routeType = _routeTypeForTab(tabIndex);
    final lastIndex = ref
        .read(lastTabPositionProvider.notifier)
        .getPosition(routeType);

    // Log user interaction
    Log.info(
      '👆 User tapped bottom nav: tab=$tabIndex (${_tabName(tabIndex)})',
      name: 'Navigation',
      category: LogCategory.ui,
    );

    // Pop any pushed routes (like CuratedListFeedScreen, UserListPeopleScreen)
    // that were pushed via Navigator.push() on top of the shell
    // Only pop if there are actually pushed routes to avoid interfering with GoRouter
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      // There are pushed routes - pop them before navigating
      // This ensures we return to the shell before GoRouter navigation
      navigator.popUntil((route) => route.isFirst);
    }

    // Navigate to last position in that tab
    // GoRouter handles navigation state, but we need to clear pushed routes first
    switch (tabIndex) {
      case 0:
        context.goHome(lastIndex ?? 0); // Home always has an index
        break;
      case 1:
        // Always reset to grid mode (null) when tapping Explore tab
        // This prevents the "No videos available" bug when returning from another tab
        context.goExplore(null);
        break;
      case 2:
        context.goNotifications(
          lastIndex ?? 0,
        ); // Notifications always has an index
        break;
      case 3:
        // Always navigate to current user's profile when tapping Profile tab
        // Navigation system will resolve 'me' to actual npub
        context.goProfileGrid('me');
        break;
    }
  }

  String _tabName(int index) {
    switch (index) {
      case 0:
        return 'Home';
      case 1:
        return 'Explore';
      case 2:
        return 'Notifications';
      case 3:
        return 'Profile';
      default:
        return 'Unknown';
    }
  }

  /// Builds the header title - tappable for Explore and Hashtag routes to navigate back
  Widget _buildTappableTitle(
    BuildContext context,
    WidgetRef ref,
    String title,
  ) {
    final ctx = ref.watch(pageContextProvider).asData?.value;
    final routeType = ctx?.type;

    // Check if title should be tappable (Explore-related routes)
    final isTappable =
        routeType == RouteType.explore || routeType == RouteType.hashtag;

    final titleWidget = Text(
      title,
      // Use Pacifico font only for 'Divine' on home feed, system font elsewhere
      style: title == 'Divine'
          ? GoogleFonts.pacifico(
              textStyle: const TextStyle(fontSize: 24, letterSpacing: 0.2),
            )
          : const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    if (!isTappable) {
      return titleWidget;
    }

    return GestureDetector(
      onTap: () {
        Log.info(
          '👆 User tapped header title: $title',
          name: 'Navigation',
          category: LogCategory.ui,
        );
        // Pop any pushed routes first (like CuratedListFeedScreen)
        // Only pop if there are actually pushed routes
        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.popUntil((route) => route.isFirst);
        }
        // Navigate to main explore view
        context.goExplore(null);
      },
      child: titleWidget,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = _titleFor(ref);

    // Initialize auto-cleanup provider to ensure only one video plays at a time
    ref.watch(videoControllerAutoCleanupProvider);

    // Initialize relay statistics bridge to record connection events
    ref.watch(relayStatisticsBridgeProvider);

    // Watch page context to determine if back button should show
    final pageCtxAsync = ref.watch(pageContextProvider);
    final showBackButton = pageCtxAsync.maybeWhen(
      data: (ctx) {
        if (ctx.type == RouteType.hashtag || ctx.type == RouteType.search) {
          return true;
        }

        if (ctx.type == RouteType.explore ||
            ctx.type == RouteType.notifications) {
          return true;
        }

        if (ctx.type == RouteType.profile) {
          final authService = ref.read(authServiceProvider);
          final currentNpub = authService.currentNpub;

          return ctx.npub != currentNpub;
        }

        return false;
      },
      orElse: () => false,
    );

    // Get environment config for app bar styling
    final environment = ref.watch(currentEnvironmentProvider);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: getEnvironmentAppBarColor(environment),
        leading: showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  Log.info(
                    '👆 User tapped back button',
                    name: 'Navigation',
                    category: LogCategory.ui,
                  );

                  // Get current route context
                  final ctx = ref.read(pageContextProvider).asData?.value;
                  if (ctx == null) return;

                  // First, check if we're in a sub-route (hashtag, search, etc.)
                  // If so, navigate back to parent route
                  switch (ctx.type) {
                    case RouteType.hashtag:
                    case RouteType.search:
                      // Go back to explore
                      context.go('/explore');
                      return;

                    default:
                      break;
                  }

                  // For routes with videoIndex (feed mode), go to grid mode first
                  // This handles page-internal navigation before tab switching
                  // For explore: go to grid mode (null index)
                  // For notifications: go to index 0 (notifications always has an index)
                  // For other routes: go to grid mode (null index)
                  if (ctx.videoIndex != null && ctx.videoIndex != 0) {
                    RouteContext gridCtx;
                    if (ctx.type == RouteType.notifications) {
                      // Notifications always has an index, go to index 0
                      gridCtx = RouteContext(
                        type: ctx.type,
                        hashtag: ctx.hashtag,
                        searchTerm: ctx.searchTerm,
                        npub: ctx.npub,
                        videoIndex: 0,
                      );
                    } else {
                      // For explore and other routes, go to grid mode (null index)
                      gridCtx = RouteContext(
                        type: ctx.type,
                        hashtag: ctx.hashtag,
                        searchTerm: ctx.searchTerm,
                        npub: ctx.npub,
                        videoIndex: null,
                      );
                    }
                    final newRoute = buildRoute(gridCtx);
                    context.go(newRoute);
                    return;
                  }

                  // Check tab history for navigation
                  final tabHistory = ref.read(tabHistoryProvider.notifier);
                  final previousTab = tabHistory.getPreviousTab();

                  // If there's a previous tab in history, navigate to it
                  if (previousTab != null) {
                    // Navigate to previous tab
                    final previousRouteType = _routeTypeForTab(previousTab);
                    final lastIndex = ref
                        .read(lastTabPositionProvider.notifier)
                        .getPosition(previousRouteType);

                    // Remove current tab from history before navigating
                    tabHistory.navigateBack();

                    // Navigate to previous tab
                    switch (previousTab) {
                      case 0:
                        context.goHome(lastIndex ?? 0);
                        break;
                      case 1:
                        context.goExplore(lastIndex);
                        break;
                      case 2:
                        context.goNotifications(lastIndex ?? 0);
                        break;
                      case 3:
                        context.goProfileGrid('me');
                        break;
                    }
                    return;
                  }

                  // No previous tab - check if we're on a non-home tab
                  // If so, go to home first before exiting
                  final currentTab = _tabIndexFromRouteType(ctx.type);
                  if (currentTab != null && currentTab != 0) {
                    // Go to home first
                    context.go('/home/0');
                    return;
                  }

                  // Already at home with no history - let system handle exit
                },
              )
            : Builder(
                // Hamburger menu in upper left when no back button
                builder: (context) => IconButton(
                  key: const Key('menu-icon-button'),
                  tooltip: 'Menu',
                  icon: const Icon(Icons.menu),
                  onPressed: () {
                    Log.info(
                      '👆 User tapped menu button',
                      name: 'Navigation',
                      category: LogCategory.ui,
                    );

                    // Pause all videos when drawer opens
                    final visibilityManager = ref.read(
                      videoVisibilityManagerProvider,
                    );
                    visibilityManager.pauseAllVideos();

                    Scaffold.of(context).openDrawer();
                  },
                ),
              ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: _buildTappableTitle(context, ref, title)),
            const EnvironmentBadge(),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search),
            onPressed: () {
              Log.info(
                '👆 User tapped search button',
                name: 'Navigation',
                category: LogCategory.ui,
              );
              context.goSearch();
            },
          ),
          IconButton(
            tooltip: 'Open camera',
            icon: const Icon(Icons.photo_camera_outlined),
            onPressed: () {
              Log.info(
                '👆 User tapped camera button',
                name: 'Navigation',
                category: LogCategory.ui,
              );
              context.pushCamera();
            },
          ),
        ],
      ),
      drawer: const VineDrawer(),
      body: child,
      // Bottom nav visible for all shell routes (search, tabs, etc.)
      // For search (currentIndex=-1), no tab is highlighted
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: currentIndex.clamp(0, 3),
        onTap: (index) => _handleTabTap(context, ref, index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Explore'),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Notifications',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
