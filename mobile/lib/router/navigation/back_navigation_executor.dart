// ABOUTME: Executes a BackAction against the router, shared by every caller
// ABOUTME: Split from the policy so the decision stays pure and testable

import 'package:go_router/go_router.dart';
import 'package:openvine/router/navigation/back_action.dart';
import 'package:openvine/router/providers/tab_history_provider.dart';

/// Carries out [action], returning whether the back press was handled.
///
/// A `false` return means the platform should handle the press — on Android
/// that closes the app, so only [BackUnhandled] (or a pop with nothing to
/// pop) may produce it.
bool executeBackAction(
  BackAction action, {
  required GoRouter router,
  required TabHistory tabHistory,
}) {
  switch (action) {
    case BackPop():
      if (!router.canPop()) return false;
      router.pop();
      return true;
    case BackGoTo(:final location, :final consumesTabHistory):
      if (consumesTabHistory) tabHistory.navigateBack();
      router.go(location);
      return true;
    case BackUnhandled():
      return false;
  }
}
