// ABOUTME: AppShell widget providing bottom navigation and dynamic header
// ABOUTME: Header title uses Bricolage Grotesque font, camera button in bottom nav

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:openvine/app_update/app_update.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/notifications/view/notifications_page.dart';
import 'package:openvine/providers/active_video_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/classic_vines_provider.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/for_you_provider.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/providers/shell_obscured_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/explore/explore_screen.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/npub_hex.dart';
import 'package:openvine/widgets/environment_indicator.dart';
import 'package:openvine/widgets/environment_indicator_line.dart';
import 'package:openvine/widgets/vine_bottom_nav.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:unified_logger/unified_logger.dart';

/// Duration of the cross-fade applied when switching between bottom-nav tabs.
/// Kept short so tab switches stay snappy.
const Duration _kTabFadeDuration = Duration(milliseconds: 120);

/// Shell chrome (app bar + bottom nav) wrapped around the [StatefulShellRoute]
/// branch container.
///
/// [child] is the `StatefulNavigationShell` (rendered via
/// [AppShellBranchContainer]); [currentIndex] is its active branch. AppShell
/// itself no longer animates the tab switch — the cross-fade lives in
/// [AppShellBranchContainer], which keeps every branch alive.
class AppShell extends ConsumerStatefulWidget {
  const AppShell({required this.child, required this.currentIndex, super.key});

  final Widget child;
  final int currentIndex;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with RouteAware {
  int get currentIndex => widget.currentIndex;
  Widget get child => widget.child;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Observe the root navigator so the home feed knows when a full-screen
    // route (profile, fullscreen video, recorder) covers the shell. The
    // subscription is keyed on the shell's own route, so didPopNext only fires
    // when the route directly above the shell is popped — not when a route
    // above another pushed route closes.
    final route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    super.dispose();
  }

  void _setShellObscured({required bool obscured}) {
    // RouteAware callbacks can fire mid-frame; defer the provider write so it
    // never lands during this shell's own build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(shellObscuredProvider.notifier).setObscured(obscured: obscured);
    });
  }

  // Resets the flag whenever a fresh shell mounts. Without this, a stale
  // `true` survives when the shell is removed while covered and later
  // re-shown without a pop event reaching it (e.g. sign-out navigates to
  // /welcome, then the user returns home) — the home feed would stay paused.
  @override
  void didPush() => _setShellObscured(obscured: false);

  @override
  void didPushNext() => _setShellObscured(obscured: true);

  @override
  void didPopNext() => _setShellObscured(obscured: false);

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

  @override
  Widget build(BuildContext context) {
    final title = _titleFor(context, ref);

    // Publish the authoritative active branch (navigationShell.currentIndex)
    // so backgrounded tab screens can pause off it. Deferred to a post-frame
    // callback because a provider must not be mutated during build. This is
    // the platform-agnostic source — the URL-derived pageContext can lag on
    // web for StatefulShellRoute branch switches, which left the home feed
    // playing on other tabs there.
    final activeIndex = currentIndex;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = ref.read(activeBranchIndexProvider.notifier);
      if (notifier.state != activeIndex) notifier.state = activeIndex;
    });

    // Initialize auto-cleanup provider to ensure only one video plays at a time
    ref.watch(videoControllerAutoCleanupProvider);

    // Transitional scaffold: records relay connection events for analytics.
    // TODO(#4338): remove when relay management moves to a dedicated cubit/service.
    ref.watch(relayStatisticsBridgeProvider);

    // Transitional scaffold: refreshes feeds when the relay set changes.
    // TODO(#4338): remove when feed refresh is driven by a relay event stream in a cubit.
    ref.watch(relaySetChangeBridgeProvider);

    // Initialize Zendesk identity sync to keep user identity in sync with auth
    ref.watch(zendeskIdentitySyncProvider);

    // Transitional scaffold: syncs notification preferences on auth change.
    // TODO(#4338): remove when NotificationPreferencesCubit owns this lifecycle.
    ref.watch(notificationPreferencesDirtySyncBridgeProvider);
    ref.watch(pushNotificationSyncProvider);

    // Transitional scaffold: syncs block/mute list after login.
    // TODO(#4338): remove when BlocklistCubit owns post-login sync.
    ref.watch(blocklistSyncBridgeProvider);

    // Watch page context to determine if back button should show and if on search route
    final pageCtxAsync = ref.watch(pageContextProvider);

    // Own profile grid renders its own scrollable header (avatar + stats), so
    // AppShell suppresses its app bar for it — like home / inbox / explore grid.
    final isOwnProfileGrid = pageCtxAsync.maybeWhen(
      data: (ctx) {
        if (ctx.type != RouteType.profile) return false;
        if (ctx.videoIndex != null) return false; // Video mode uses the app bar
        final currentNpub = ref.read(authServiceProvider).currentNpub;
        return ctx.npub == 'me' || ctx.npub == currentNpub;
      },
      orElse: () => false,
    );

    // Inbox manages its own header (segmented toggle replaces app bar)
    final isInbox = pageCtxAsync.maybeWhen(
      data: (ctx) =>
          ctx.type == RouteType.inbox || ctx.type == RouteType.conversation,
      orElse: () => false,
    );

    // Explore grid mode manages its own header (search bar + tabs).
    final isExploreGrid = pageCtxAsync.maybeWhen(
      data: (ctx) => ctx.type == RouteType.explore
          ? ctx.videoIndex == null
          : currentIndex == 1,
      orElse: () => currentIndex == 1,
    );
    final showBackButton = pageCtxAsync.maybeWhen(
      data: (ctx) {
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

        return isExploreVideo ||
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
      // Own profile grid renders its own scrollable header.
      appBar: currentIndex == 0 || isInbox || isExploreGrid || isOwnProfileGrid
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
            ),
      // Keep the branch container in the same slot regardless of tab so
      // switching to/from home never reparents it (which would relayout all
      // four kept-alive branches). The UpdateBanner only shows on home.
      body: Column(
        children: [
          Expanded(child: child),
          if (currentIndex == 0) const UpdateBanner(),
        ],
      ),
      // Bottom nav visible for all shell routes (search, tabs, etc.).
      // PointerInterceptor ensures the bottom nav receives taps on web
      // even when HTML platform views (video elements) overlap the area.
      //
      // The nav itself lives in [VineBottomNav] so home / explore /
      // inbox / profile-router all render the same shared widget.
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const EnvironmentIndicatorLine(),
          PointerInterceptor(
            intercepting: kIsWeb,
            child: VineBottomNav(currentIndex: currentIndex),
          ),
        ],
      ),
    );
  }
}

/// Cross-fades between the [StatefulShellRoute] branch navigators.
///
/// Every branch stays mounted (state preserved); the active branch is fully
/// opaque and interactive, the others sit at opacity 0 with their tickers
/// paused, pointer events ignored, and — crucially — excluded from the
/// semantics and focus trees. `Opacity`/`IgnorePointer` alone do not hide a
/// subtree from screen readers or focus traversal, so without
/// [ExcludeSemantics]/[ExcludeFocus] the three hidden tabs would still be
/// announced and focusable. On a tab switch the outgoing branch fades out
/// while the incoming one fades in — a true cross-fade between two live tabs.
/// Within-tab navigation never reaches here (those are [NoTransitionPage]s
/// inside a single branch).
class AppShellBranchContainer extends StatelessWidget {
  const AppShellBranchContainer({
    required this.currentIndex,
    required this.children,
    super.key,
  });

  /// Index (in [children]) of the branch navigator to display.
  final int currentIndex;

  /// The branch navigators, one per [StatefulShellBranch], kept alive.
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : _kTabFadeDuration;
    return Stack(
      fit: StackFit.expand,
      children: List.generate(children.length, (index) {
        final isActive = index == currentIndex;
        return AnimatedOpacity(
          opacity: isActive ? 1 : 0,
          duration: duration,
          curve: Curves.easeInOut,
          child: ExcludeSemantics(
            excluding: !isActive,
            child: ExcludeFocus(
              excluding: !isActive,
              child: IgnorePointer(
                ignoring: !isActive,
                child: TickerMode(enabled: isActive, child: children[index]),
              ),
            ),
          ),
        );
      }),
    );
  }
}
