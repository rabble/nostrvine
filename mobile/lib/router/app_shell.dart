// ABOUTME: AppShell widget providing bottom navigation and dynamic header
// ABOUTME: Uses StatefulNavigationShell for automatic tab state preservation

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/vine_drawer.dart';
import 'package:openvine/widgets/environment_indicator.dart';
import 'package:openvine/providers/active_video_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/utils/npub_hex.dart';
import 'page_context_provider.dart';
import 'route_utils.dart';
import 'nav_extensions.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

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

  /// Handles tab tap - uses StatefulNavigationShell.goBranch for state preservation
  void _handleTabTap(BuildContext context, WidgetRef ref, int tabIndex) {
    // Log user interaction
    Log.info(
      '👆 User tapped bottom nav: tab=$tabIndex (${_tabName(tabIndex)})',
      name: 'Navigation',
      category: LogCategory.ui,
    );

    // Pop any pushed routes (like CuratedListFeedScreen, UserListPeopleScreen)
    // that were pushed via Navigator.push() on top of the shell
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
    }

    // Use goBranch for automatic state preservation per tab
    // initialLocation: true navigates to the branch's initial route if already on this branch
    navigationShell.goBranch(
      tabIndex,
      initialLocation: tabIndex == navigationShell.currentIndex,
    );
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
      // Use Pacifico font for 'Divine' branding, Bricolage Grotesque for other titles
      style: title == 'Divine'
          ? GoogleFonts.pacifico(
              textStyle: const TextStyle(fontSize: 24, letterSpacing: 0.2),
            )
          : VineTheme.titleFont(),
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

    // Initialize Zendesk identity sync to keep user identity in sync with auth
    ref.watch(zendeskIdentitySyncProvider);

    // Watch page context to determine if back button should show and if on search route
    final pageCtxAsync = ref.watch(pageContextProvider);
    final isSearchRoute = pageCtxAsync.maybeWhen(
      data: (ctx) => ctx.type == RouteType.search,
      orElse: () => false,
    );
    final showBackButton = pageCtxAsync.maybeWhen(
      data: (ctx) {
        final isSubRoute =
            ctx.type == RouteType.hashtag || ctx.type == RouteType.search;
        final isExploreVideo =
            ctx.type == RouteType.explore && ctx.videoIndex != null;
        // Notifications base state is index 0, not null
        final isNotificationVideo =
            ctx.type == RouteType.notifications &&
            ctx.videoIndex != null &&
            ctx.videoIndex != 0;
        final isOtherUserProfile =
            ctx.type == RouteType.profile &&
            ctx.npub != ref.read(authServiceProvider).currentNpub;
        final isProfileVideo =
            ctx.type == RouteType.profile && ctx.videoIndex != null;

        return isSubRoute ||
            isExploreVideo ||
            isNotificationVideo ||
            isOtherUserProfile ||
            isProfileVideo;
      },
      orElse: () => false,
    );

    // Get environment config for app bar styling
    final environment = ref.watch(currentEnvironmentProvider);

    return Scaffold(
      onDrawerChanged: (isOpen) {
        // Track drawer visibility for video pause/resume
        ref.read(overlayVisibilityProvider.notifier).setDrawerOpen(isOpen);
      },
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 72,
        leadingWidth: 80,
        centerTitle: false,
        titleSpacing: 0,
        backgroundColor: getEnvironmentAppBarColor(environment),
        leading: showBackButton
            ? IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Container(
                  width: 48,
                  height: 48,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: VineTheme.iconButtonBackground,
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
                  ),
                ),
                onPressed: () {
                  Log.info(
                    '👆 User tapped back button',
                    name: 'Navigation',
                    category: LogCategory.ui,
                  );

                  // First, try to pop if there's something on the navigation stack
                  // This handles pushed routes (e.g., list → profile → back to list)
                  if (context.canPop()) {
                    Log.info(
                      '👈 Popping navigation stack',
                      name: 'Navigation',
                      category: LogCategory.ui,
                    );
                    context.pop();
                    return;
                  }

                  // Get current route context
                  final ctx = ref.read(pageContextProvider).asData?.value;
                  if (ctx == null) return;

                  // Check if we're in a sub-route (hashtag, search, etc.)
                  // If so, navigate back to parent route
                  switch (ctx.type) {
                    case RouteType.hashtag:
                    case RouteType.search:
                      // Go back to explore
                      context.goExplore();
                      return;

                    default:
                      break;
                  }

                  // For routes with videoIndex (feed mode), go to grid mode first
                  // This handles page-internal navigation before tab switching
                  // For explore/profile: any videoIndex (including 0) should go to grid (null)
                  // For notifications: videoIndex > 0 should go to index 0
                  if (ctx.videoIndex != null) {
                    // For Explore and Profile, grid mode is null
                    if (ctx.type == RouteType.explore ||
                        ctx.type == RouteType.profile) {
                      final gridCtx = RouteContext(
                        type: ctx.type,
                        hashtag: ctx.hashtag,
                        searchTerm: ctx.searchTerm,
                        npub: ctx.npub,
                        videoIndex: null,
                      );
                      final newRoute = buildRoute(gridCtx);
                      context.go(newRoute);
                      return;
                    }
                    // For Notifications, index 0 is the base state
                    if (ctx.type == RouteType.notifications &&
                        ctx.videoIndex != 0) {
                      final gridCtx = RouteContext(
                        type: ctx.type,
                        hashtag: ctx.hashtag,
                        searchTerm: ctx.searchTerm,
                        npub: ctx.npub,
                        videoIndex: 0,
                      );
                      final newRoute = buildRoute(gridCtx);
                      context.go(newRoute);
                      return;
                    }
                  }

                  // Check if we're on a non-home tab - go to home first
                  final currentTab = tabIndexForRouteType(ctx.type);
                  if (currentTab != null && currentTab != 0) {
                    context.goHome();
                    return;
                  }

                  // Already at home base state - let system handle exit
                },
              )
            : Builder(
                // Hamburger menu in upper left when no back button
                builder: (context) => IconButton(
                  key: const Key('menu-icon-button'),
                  tooltip: 'Menu',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Container(
                    width: 48,
                    height: 48,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: VineTheme.iconButtonBackground,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: SvgPicture.asset(
                      'assets/icon/menu.svg',
                      width: 32,
                      height: 32,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  onPressed: () {
                    Log.info(
                      '👆 User tapped menu button',
                      name: 'Navigation',
                      category: LogCategory.ui,
                    );
                    // Drawer open state is tracked via onDrawerChanged callback
                    // which triggers overlay visibility provider to pause videos
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
        actions: isSearchRoute
            ? null
            : [
                IconButton(
                  tooltip: 'Search',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Container(
                    width: 48,
                    height: 48,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: VineTheme.iconButtonBackground,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: SvgPicture.asset(
                      'assets/icon/search.svg',
                      width: 32,
                      height: 32,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  onPressed: () {
                    Log.info(
                      '👆 User tapped search button',
                      name: 'Navigation',
                      category: LogCategory.ui,
                    );
                    context.goSearch();
                  },
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Open camera',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Container(
                    width: 48,
                    height: 48,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: VineTheme.iconButtonBackground,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: SvgPicture.asset(
                      'assets/icon/camera.svg',
                      width: 32,
                      height: 32,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  onPressed: () {
                    Log.info(
                      '👆 User tapped camera button',
                      name: 'Navigation',
                      category: LogCategory.ui,
                    );
                    context.pushCamera();
                  },
                ),
                const SizedBox(width: 16),
              ],
      ),
      drawer: const VineDrawer(),
      body: navigationShell,
      // Bottom nav visible for all shell routes
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => _handleTabTap(context, ref, index),
        items: [
          BottomNavigationBarItem(
            icon: Semantics(
              identifier: 'home_tab',
              child: const Icon(Icons.home),
            ),
            label: 'Home',
          ),
        ],
      ),
    );
  }
}
