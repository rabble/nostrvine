// ABOUTME: Platform channel handler for Android back button interception
// ABOUTME: Routes back button presses from native Android to GoRouter navigation

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/navigation/back_navigation_executor.dart';
import 'package:openvine/router/navigation/back_navigation_policy.dart';
import 'package:openvine/router/navigation/tab_identity.dart';
import 'package:openvine/router/router.dart';

class BackButtonHandler {
  static const MethodChannel _channel = MethodChannel(
    'org.openvine/navigation',
  );
  static GoRouter? _router;
  static WidgetRef? _ref;

  static void initialize(GoRouter router, WidgetRef ref) {
    _router = router;
    _ref = ref;

    // Only set up platform channel on Android
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      _channel.setMethodCallHandler((call) async {
        if (call.method == 'onBackPressed') {
          return _handleBackButton();
        }
        return false;
      });
    }
  }

  /// Returns whether the press was consumed. A `false` return lets Android
  /// finish the activity, so it must mean there is genuinely nowhere left
  /// to go back to.
  static Future<bool> _handleBackButton() async {
    final router = _router;
    final ref = _ref;
    if (router == null || ref == null) return false;

    final routeContext = ref.read(pageContextProvider).value;
    final tabHistory = ref.read(tabHistoryProvider.notifier);
    final previousTab = tabHistory.getPreviousTab();

    return executeBackAction(
      resolveBackAction(
        context: routeContext,
        canPop: router.canPop(),
        previousTab: previousTab,
        lastIndexForPreviousTab: previousTab == null
            ? null
            : ref
                  .read(lastTabPositionProvider.notifier)
                  .recordedPosition(routeTypeForTab(previousTab)),
        // Only the profile tab needs an identity, and materialising
        // AuthService on every back press is not worth it.
        currentUserNpub: previousTab == 3
            ? ref.read(authServiceProvider).currentNpub
            : null,
      ),
      router: router,
      tabHistory: tabHistory,
    );
  }
}
