// ABOUTME: NavigatorObserver that stops videos when modals/dialogs are pushed
// ABOUTME: Only pauses for overlay routes that cover video content

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/utils/video_controller_cleanup.dart';
import 'package:unified_logger/unified_logger.dart';

class VideoStopNavigatorObserver extends NavigatorObserver {
  @override
  void didStartUserGesture(
    Route<dynamic> route,
    Route<dynamic>? previousRoute,
  ) {
    super.didStartUserGesture(route, previousRoute);

    // Skip disposal for popup routes (modals, bottom sheets, dialogs)
    // The overlayVisibilityProvider already handles pausing via activeVideoIdProvider
    if (route is PopupRoute) {
      return;
    }

    // Stop videos as soon as user starts navigation gesture
    // This fires BEFORE the new route is pushed
    _stopAllVideos('didStartUserGesture', route.settings.name);
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);

    // Skip disposal for popup routes (modals, bottom sheets, dialogs)
    // The overlayVisibilityProvider already handles pausing via activeVideoIdProvider
    if (route is PopupRoute) {
      Log.debug(
        '📱 Skipping video disposal for popup route: ${route.settings.name}',
        name: 'VideoStopNavigatorObserver',
        category: LogCategory.system,
      );
      return;
    }

    // Also stop on push for programmatic navigation (non-gesture)
    _stopAllVideos('didPush', route.settings.name);
  }

  void _stopAllVideos(String action, String? routeName) {
    try {
      // Capture navigator in a local variable to avoid race condition
      // where navigator becomes null between the null check and usage.
      final nav = navigator;
      if (nav?.context != null) {
        final container = ProviderScope.containerOf(nav!.context);

        // Stop videos immediately - no delay
        // This ensures videos stop BEFORE the new route builds
        disposeAllVideoControllers(container);
        Log.info(
          '📱 Navigation $action to route: ${routeName ?? 'unnamed'} - stopped all videos',
          name: 'VideoStopNavigatorObserver',
          category: LogCategory.system,
        );
      }
    } catch (e) {
      Log.error(
        'Failed to handle navigation: $e',
        name: 'VideoStopNavigatorObserver',
        category: LogCategory.system,
      );
    }
  }
}
