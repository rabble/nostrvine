// ABOUTME: AppShell widget providing bottom navigation and dynamic header
// ABOUTME: Header title uses Bricolage Grotesque font, camera button in bottom nav

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:openvine/app_update/app_update.dart';
import 'package:openvine/blocs/dm/unread_count/dm_unread_count_cubit.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/notifications/view/notifications_page.dart';
import 'package:openvine/providers/active_video_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/classic_vines_provider.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/for_you_provider.dart';
import 'package:openvine/providers/relay_notifications_provider.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/inbox/inbox_page.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/screens/pure/search_screen_pure.dart';
import 'package:openvine/utils/camera_permission_check.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/npub_hex.dart';
import 'package:openvine/widgets/environment_indicator.dart';
import 'package:openvine/widgets/notification_badge.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:unified_logger/unified_logger.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.child, required this.currentIndex, super.key});

  final Widget child;
  final int currentIndex;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int get currentIndex => widget.currentIndex;
  Widget get child => widget.child;

  String _titleFor(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final ctx = ref.watch(pageContextProvider).asData?.value;
    switch (ctx?.type) {
      case RouteType.home:
        return l10n.navHome;
      case RouteType.explore:
        // When in feed mode (watching a video), show the tab name
        if (ctx?.videoIndex != null) {
          final tabIndex = ref.watch(exploreTabIndexProvider);
          // Build dynamic tab names based on which optional tabs are available
          // Order: [Classics], New Videos, Trending, [For You], Lists
          final forYouAvailable = ref.watch(forYouAvailableProvider);
          final classicsAvailable =
              ref.watch(classicVinesAvailableProvider).asData?.value ?? false;
          final tabNames = <String>[];
          if (classicsAvailable) tabNames.add(l10n.navExploreClassics);
          tabNames.addAll([l10n.navExploreNewVideos, l10n.navExploreTrending]);
          if (forYouAvailable) tabNames.add(l10n.navExploreForYou);
          tabNames.add(l10n.navExploreLists);
          if (tabIndex >= 0 && tabIndex < tabNames.length) {
            return tabNames[tabIndex];
          }
          return l10n.navExplore;
        }
        return l10n.navExplore;
      case RouteType.categoryGallery:
        return l10n.navExplore;
      case RouteType.notifications:
        return l10n.navNotifications;
      case RouteType.inbox:
        return l10n.navInbox;
      case RouteType.profile:
        final npub = ctx?.npub ?? '';
        if (npub == 'me') {
          return l10n.navMyProfile;
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
        return l10n.navProfile;
      case RouteType.search:
        return l10n.navSearch;
      default:
        return '';
    }
  }

  /// Maps tab index to RouteType
  RouteType _routeTypeForTab(int index) {
    return switch (index) {
      0 => RouteType.home,
      1 => RouteType.explore,
      2 => RouteType.notifications,
      3 => RouteType.profile,
      _ => RouteType.home,
    };
  }

  /// Maps RouteType to tab index
  /// Returns null if not a main tab route
  int? _tabIndexFromRouteType(RouteType type) {
    return switch (type) {
      RouteType.home => 0,
      RouteType.explore => 1,
      RouteType.notifications || RouteType.inbox => 2,
      RouteType.profile => 3,
      // Not a main tab route
      _ => null,
    };
  }

  /// Navigates to the given tab at its last known position.
  void _navigateToTab(BuildContext context, WidgetRef ref, int tabIndex) {
    final routeType = _routeTypeForTab(tabIndex);
    final lastIndex = ref
        .read(lastTabPositionProvider.notifier)
        .getPosition(routeType);

    switch (tabIndex) {
      case 0:
        context.go(VideoFeedPage.pathForIndex(lastIndex ?? 0));
      case 1:
        if (lastIndex != null) {
          context.go(ExploreScreen.pathForIndex(lastIndex));
        } else {
          context.go(ExploreScreen.path);
        }
      case 2:
        context.go(NotificationsPage.pathForIndex(lastIndex ?? 0));
      case 3:
        final authService = ref.read(authServiceProvider);
        final currentUserHex = authService.currentPublicKeyHex;
        if (currentUserHex != null) {
          final npub = NostrKeyUtils.encodePubKey(currentUserHex);
          context.go(ProfileScreenRouter.pathForNpub(npub));
        }
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
      '👆 User tapped bottom nav: tab=$tabIndex (${_tabName(context, tabIndex)})',
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
        return context.go(VideoFeedPage.pathForIndex(lastIndex ?? 0));
      case 1:
        // Always reset to grid mode (null) when tapping Explore tab
        // This prevents the "No videos available" bug when returning from another tab
        return context.go(ExploreScreen.path);
      case 2:
        return context.go(InboxPage.path);
      case 3:
        // Always navigate to current user's profile when tapping Profile tab
        final authService = ref.read(authServiceProvider);
        final currentUserHex = authService.currentPublicKeyHex;
        if (currentUserHex != null) {
          final npub = NostrKeyUtils.encodePubKey(currentUserHex);
          return context.go(ProfileScreenRouter.pathForNpub(npub));
        }
    }
  }

  String _tabName(BuildContext context, int index) {
    final l10n = context.l10n;
    return switch (index) {
      0 => l10n.navHome,
      1 => l10n.navExplore,
      2 => l10n.navInbox,
      3 => l10n.navProfile,
      _ => l10n.navUnknown,
    };
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
    final isTappable = routeType == RouteType.explore;

    final titleWidget = Text(
      title,
      // Use Pacifico font for 'Divine' branding, Bricolage Grotesque for other titles
      style: title == 'Divine'
          ? GoogleFonts.pacifico(
              textStyle: const TextStyle(fontSize: 24, letterSpacing: 0.2),
            )
          : VineTheme.titleLargeFont(),
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
        context.go(ExploreScreen.path);
      },
      child: titleWidget,
    );
  }

  /// Builds a tab button for the bottom navigation bar
  Widget _buildTabButton(
    BuildContext context,
    WidgetRef ref,
    String iconPath,
    int tabIndex,
    int currentIndex,
    String semanticIdentifier,
  ) {
    final isSelected = currentIndex == tabIndex;

    return Semantics(
      identifier: semanticIdentifier,
      child: GestureDetector(
        onTap: () => _handleTabTap(context, ref, tabIndex),
        child: Opacity(
          opacity: isSelected ? 1.0 : 0.5,
          child: Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(8),
            child: SvgPicture.asset(iconPath, width: 32, height: 32),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _titleFor(context, ref);

    // Initialize auto-cleanup provider to ensure only one video plays at a time
    ref.watch(videoControllerAutoCleanupProvider);

    // Initialize relay statistics bridge to record connection events
    ref.watch(relayStatisticsBridgeProvider);

    // Initialize relay set change bridge to refresh feeds when relays are added/removed
    ref.watch(relaySetChangeBridgeProvider);

    // Initialize Zendesk identity sync to keep user identity in sync with auth
    ref.watch(zendeskIdentitySyncProvider);

    // Initialize push notification sync to register FCM token on auth
    ref.watch(pushNotificationSyncProvider);

    // Start block/mute list sync once authenticated (handles post-reinstall login)
    ref.watch(blocklistSyncBridgeProvider);

    // Watch page context to determine if back button should show and if on search route
    final pageCtxAsync = ref.watch(pageContextProvider);

    // Check if on own profile grid view - if so, let ProfileScreenRouter render its own scaffold
    final isOwnProfileGrid = pageCtxAsync.maybeWhen(
      data: (ctx) {
        if (ctx.type != RouteType.profile) return false;
        if (ctx.videoIndex != null) return false; // Video mode uses shell
        final currentNpub = ref.read(authServiceProvider).currentNpub;
        return ctx.npub == 'me' || ctx.npub == currentNpub;
      },
      orElse: () => false,
    );

    // Own profile grid uses its own scaffold - just return the child
    if (isOwnProfileGrid) {
      return child;
    }

    // Inbox manages its own header (segmented toggle replaces app bar)
    final isInbox = pageCtxAsync.maybeWhen(
      data: (ctx) =>
          ctx.type == RouteType.inbox || ctx.type == RouteType.conversation,
      orElse: () => false,
    );

    final isSearchRoute = pageCtxAsync.maybeWhen(
      data: (ctx) => ctx.type == RouteType.search,
      orElse: () => false,
    );

    // Watch the newSearch feature flag
    final isNewSearchEnabled = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.newSearch),
    );

    // Explore grid mode manages its own header (search bar + tabs)
    // when the newSearch feature flag is enabled.
    final isExploreGrid =
        isNewSearchEnabled &&
        pageCtxAsync.maybeWhen(
          data: (ctx) => ctx.type == RouteType.explore
              ? ctx.videoIndex == null
              : currentIndex == 1,
          orElse: () => currentIndex == 1,
        );
    final showBackButton = pageCtxAsync.maybeWhen(
      data: (ctx) {
        final isSubRoute = ctx.type == RouteType.search;
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
      // Home tab uses FeedModeSwitch overlay (menu + mode dropdown + search)
      // instead of the standard AppBar, for full-screen video UX.
      // Inbox uses its own segmented toggle header.
      // Explore grid manages its own header (search bar + tabs).
      appBar: currentIndex == 0 || isInbox || isExploreGrid
          ? null
          : DiVineAppBar(
              titleWidget: _buildTappableTitle(context, ref, title),
              titleSuffix: const EnvironmentBadge(),
              backgroundColor: getEnvironmentAppBarColor(environment),
              showBackButton: showBackButton,
              onBackPressed: showBackButton
                  ? () {
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

                      // Check if we're in a sub-route (search, etc.)
                      // If so, navigate back appropriately
                      switch (ctx.type) {
                        // TODO(#2470): Remove search case when unified
                        // search/explore replaces the old search path.
                        case RouteType.search:
                          if (ctx.videoIndex != null) {
                            // Feed mode → go back to search grid
                            return context.go(
                              SearchScreenPure.pathForTerm(
                                term: ctx.searchTerm,
                              ),
                            );
                          }
                          // Grid mode → return to the originating tab
                          final lastTab =
                              ref
                                  .read(tabHistoryProvider.notifier)
                                  .getCurrentTab() ??
                              0;
                          _navigateToTab(context, ref, lastTab);
                          return;
                        default:
                          break;
                      }

                      // For routes with videoIndex (feed mode), go to grid mode first
                      // This handles page-internal navigation before tab switching
                      // For explore/profile: any videoIndex (including 0) should go to grid (null)
                      // For notifications: videoIndex > 0 should go to index 0

                      if (ctx.videoIndex != null) {
                        switch (ctx.type) {
                          case RouteType.explore:
                            // For Explore, grid mode is null
                            return context.go(ExploreScreen.path);
                          // For Profile, grid mode is null
                          case RouteType.profile:
                            return context.go(
                              ProfileScreenRouter.pathForNpub(ctx.npub ?? 'me'),
                            );
                          // For Notifications, index 0 is the base state
                          case RouteType.notifications when ctx.videoIndex != 0:
                            return context.go(
                              NotificationsPage.pathForIndex(0),
                            );
                          default:
                            break;
                        }
                      }

                      // Check tab history for navigation
                      final tabHistory = ref.read(tabHistoryProvider.notifier);
                      final previousTab = tabHistory.getPreviousTab();

                      // If there's a previous tab in history, navigate to it
                      if (previousTab != null) {
                        // Remove current tab from history before navigating
                        tabHistory.navigateBack();

                        _navigateToTab(context, ref, previousTab);
                        return;
                      }

                      // No previous tab - check if we're on a non-home tab
                      // If so, go to home first before exiting
                      final currentTab = _tabIndexFromRouteType(ctx.type);
                      if (currentTab != null && currentTab != 0) {
                        // Go to home first
                        return context.go(VideoFeedPage.pathForIndex(0));
                      }

                      // Already at home with no history - let system handle exit
                    }
                  : null,
              actions: isSearchRoute || isNewSearchEnabled
                  ? const []
                  : [
                      DiVineAppBarAction(
                        icon: SvgIconSource(DivineIconName.search.assetPath),
                        tooltip: context.l10n.navSearchTooltip,
                        onPressed: () {
                          Log.info(
                            '👆 User tapped search button',
                            name: 'Navigation',
                            category: LogCategory.ui,
                          );
                          context.go(SearchScreenPure.path);
                        },
                      ),
                    ],
            ),
      body: currentIndex == 0
          ? Column(
              children: [
                Expanded(child: child),
                const UpdateBanner(),
              ],
            )
          : child,
      // Bottom nav visible for all shell routes (search, tabs, etc.)
      // For search (currentIndex=-1), no tab is highlighted
      // PointerInterceptor ensures the bottom nav receives taps on web
      // even when HTML platform views (video elements) overlap the area.
      bottomNavigationBar: PointerInterceptor(
        intercepting: kIsWeb,
        child: Container(
          color: VineTheme.navGreen,
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: SafeArea(
            top: false,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildTabButton(
                  context,
                  ref,
                  DivineIconName.house.assetPath,
                  0,
                  currentIndex,
                  'home_tab',
                ),
                _buildTabButton(
                  context,
                  ref,
                  DivineIconName.compass.assetPath,
                  1,
                  currentIndex,
                  'explore_tab',
                ),
                // Camera button in center of bottom nav (hidden on web)
                if (!kIsWeb)
                  Semantics(
                    identifier: 'camera_button',
                    button: true,
                    label: context.l10n.navOpenCamera,
                    child: GestureDetector(
                      onTap: () {
                        Log.info(
                          '👆 User tapped camera button',
                          name: 'Navigation',
                          category: LogCategory.ui,
                        );
                        context.pushToCameraWithPermission();
                      },
                      child: Container(
                        width: 72,
                        height: 48,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: VineTheme.cameraButtonGreen,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: SvgPicture.asset(
                          DivineIconName.cameraRetro.assetPath,
                          width: 32,
                          height: 32,
                        ),
                      ),
                    ),
                  ),
                NotificationBadge(
                  count:
                      context.watch<DmUnreadCountCubit>().state +
                      ref.watch(relayNotificationUnreadCountProvider),
                  child: _buildTabButton(
                    context,
                    ref,
                    DivineIconName.chat.assetPath,
                    2,
                    currentIndex,
                    'inbox_tab',
                  ),
                ),
                _buildTabButton(
                  context,
                  ref,
                  DivineIconName.userCircle.assetPath,
                  3,
                  currentIndex,
                  'profile_tab',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
