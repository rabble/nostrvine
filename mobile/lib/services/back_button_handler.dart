// ABOUTME: Platform channel handler for Android back button interception
// ABOUTME: Routes back button presses from native Android to GoRouter navigation

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/router/tab_history_provider.dart';
import 'package:openvine/router/last_tab_position_provider.dart';
import 'package:openvine/providers/app_providers.dart';

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
        _router!.go('/explore');
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
          _router!.go('/home/${lastIndex ?? 0}');
          break;
        case 1:
          if (lastIndex != null) {
            _router!.go('/explore/$lastIndex');
          } else {
            _router!.go('/explore');
          }
          break;
        case 2:
          _router!.go('/notifications/${lastIndex ?? 0}');
          break;
        case 3:
          // Get current user's npub for profile
          final authService = _ref.read(authServiceProvider);
          final currentNpub = authService.currentNpub;
          if (currentNpub != null) {
            _router!.go('/profile/$currentNpub');
          } else {
            _router!.go('/home/0');
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
      _router!.go('/home/0');
      return true; // Handled
    }

    // Already at home with no history - let system exit app
    return false; // Not handled - let Android exit app
  }

  /// Maps tab index to RouteType
  static RouteType _routeTypeForTab(int index) {
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
  static int? _tabIndexFromRouteType(RouteType type) {
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
}
