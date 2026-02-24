// ABOUTME: Platform channel handler for Android back button interception
// ABOUTME: Routes back button presses from native Android to GoRouter navigation

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/screens/home_screen_router.dart';
import 'package:openvine/screens/notifications_screen.dart';
import 'package:openvine/screens/profile_screen_router.dart';

class BackButtonHandler {
  static const MethodChannel _channel = MethodChannel(
    'org.openvine/navigation',
  );
  static GoRouter? _router;
  static dynamic _ref;

  static void initialize(GoRouter router, dynamic ref) {
    _router = router;
    _ref = ref;

    // Only set up platform channel on Android
    if (!kIsWeb && Platform.isAndroid) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onBackPressed') {
          return await _handleBackButton();
        }
        return false;
      });
    }
  }

  static Future<bool> _handleBackButton() async {
    if (_router == null || _ref == null) {
      return false;
    }

    // Get current route context
    final ctxAsync = _ref.read(pageContextProvider);
    final ctx = ctxAsync.value;
    if (ctx == null) {
      return false;
    }

    // First, check if we're in a sub-route (hashtag, search, etc.)
    // If so, navigate back to parent route
    switch (ctx.type) {
      case RouteType.hashtag:
      case RouteType.search:
        // Go back to explore
        _router!.go(ExploreScreen.path);
        return true; // Handled
      case RouteType.videoRecorder:
      case RouteType.videoClipEditor:
      case RouteType.videoEditor:
      case RouteType.videoMetadata:
        // Pop the video editing flow screens
        _router!.pop();
        return true; // Handled
      default:
        break;
    }

    // For routes with videoIndex (feed mode), go to grid mode first
    // This handles page-internal navigation before tab switching
    // For explore: go to grid mode (null index)
    // For notifications: go to index 0 (notifications always has an index)
    // For other routes: go to grid mode (null index)
    if (ctx.videoIndex != null && ctx.videoIndex != 0) {
      // For explore, profile, and other routes, go to grid mode (null index)
      final newRoute = switch (ctx.type) {
        RouteType.notifications => NotificationsScreen.pathForIndex(0),
        RouteType.explore => ExploreScreen.path,
        RouteType.profile => ProfileScreenRouter.pathForNpub(ctx.npub ?? 'me'),
        RouteType.home => HomeScreenRouter.pathForIndex(0),
        _ => ExploreScreen.path,
      };

      _router!.go(newRoute);
      return true; // Handled
    }

    // Check tab history for navigation
    final tabHistory = _ref.read(tabHistoryProvider.notifier);
    final previousTab = tabHistory.getPreviousTab();

    // If there's a previous tab in history, navigate to it
    if (previousTab != null) {
      // Navigate to previous tab
      final previousRouteType = _routeTypeForTab(previousTab);
      final lastIndex = _ref
          .read(lastTabPositionProvider.notifier)
          .getPosition(previousRouteType);

      // Remove current tab from history before navigating
      tabHistory.navigateBack();

      // Navigate to previous tab
      switch (previousTab) {
        case 0:
          _router!.go(HomeScreenRouter.pathForIndex(lastIndex ?? 0));
          break;
        case 1:
          if (lastIndex != null) {
            _router!.go(ExploreScreen.pathForIndex(lastIndex));
          } else {
            _router!.go(ExploreScreen.path);
          }
          break;
        case 2:
          _router!.go(NotificationsScreen.pathForIndex(lastIndex ?? 0));
          break;
        case 3:
          // Get current user's npub for profile
          final authService = _ref.read(authServiceProvider);
          final currentNpub = authService.currentNpub;
          if (currentNpub != null) {
            _router!.go(ProfileScreenRouter.pathForNpub(currentNpub));
          } else {
            _router!.go(HomeScreenRouter.pathForIndex(0));
          }
          break;
      }
      return true; // Handled
    }

    // No previous tab - check if we're on a non-home tab
    // If so, go to home first before exiting
    final currentTab = _tabIndexFromRouteType(ctx.type);
    if (currentTab != null && currentTab != 0) {
      // Go to home first
      _router!.go(HomeScreenRouter.pathForIndex(0));
      return true; // Handled
    }

    // Already at home with no history - let system exit app
    return false; // Not handled - let Android exit app
  }

  /// Maps tab index to RouteType
  static RouteType _routeTypeForTab(int index) {
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
  static int? _tabIndexFromRouteType(RouteType type) {
    return switch (type) {
      RouteType.home => 0,
      // Hashtag is part of explore tab
      RouteType.explore || RouteType.hashtag => 1,
      RouteType.notifications => 2,
      RouteType.profile => 3,
      // Not a main tab route
      _ => null,
    };
  }
}
