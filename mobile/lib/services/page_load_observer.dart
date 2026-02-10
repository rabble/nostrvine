// ABOUTME: NavigatorObserver that tracks page load performance via ScreenAnalyticsService
// ABOUTME: Records screen load start on push, content visible after frame render, and cleanup on pop

import 'package:flutter/material.dart';
import 'package:openvine/services/screen_analytics_service.dart';
import 'package:openvine/utils/unified_logger.dart';

class PageLoadObserver extends NavigatorObserver {
  final ScreenAnalyticsService _analytics = ScreenAnalyticsService();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);

    if (route is PopupRoute) {
      return;
    }

    final screenName = _screenName(route);
    _analytics.startScreenLoad(screenName);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _analytics.markContentVisible(screenName);
    });

    Log.debug(
      'Page push tracked: $screenName',
      name: 'PageLoadObserver',
      category: LogCategory.ui,
    );
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);

    if (route is PopupRoute) {
      return;
    }

    final screenName = _screenName(route);
    _analytics.endScreen(screenName);

    Log.debug(
      'Page pop tracked: $screenName',
      name: 'PageLoadObserver',
      category: LogCategory.ui,
    );
  }

  String _screenName(Route<dynamic> route) {
    return route.settings.name ?? route.runtimeType.toString();
  }
}
