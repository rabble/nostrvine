// ABOUTME: Tracks tab navigation history for back button navigation
// ABOUTME: Maintains a stack of visited tabs, allows navigating back through tab history

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/router/navigation/tab_identity.dart';
import 'package:openvine/router/providers/providers.dart';
import 'package:unified_logger/unified_logger.dart';

/// Tab history provider that tracks visited tabs in order
/// Used for back button navigation to return to previous tabs
class TabHistory extends Notifier<List<int>> {
  @override
  List<int> build() {
    // Watch page context changes to track tab navigation
    ref.listen(pageContextProvider, (prev, next) {
      final ctx = next.asData?.value;
      if (ctx == null) return;

      // Only track routes a bottom-nav tab owns; ignore everything else.
      final tabIndex = tabIndexFromRouteType(ctx.type);
      if (tabIndex == null) return; // Not a main tab route

      // Get previous context to check if we're switching tabs
      final prevCtx = prev?.asData?.value;
      final prevTabIndex = prevCtx != null
          ? tabIndexFromRouteType(prevCtx.type)
          : null;

      // Only add to history if we're switching to a different tab
      // Don't add if we're already on the same tab (e.g., scrolling within home feed)
      if (prevTabIndex != null && prevTabIndex == tabIndex) {
        // Same tab - don't add to history
        return;
      }

      // Remove current tab from history if it exists (to avoid duplicates)
      // Then add it to the end
      final newHistory = List<int>.from(state);
      newHistory.remove(tabIndex);
      newHistory.add(tabIndex);

      Log.debug(
        'Tab history updated: ${newHistory.map(tabName).join(" → ")}',
        name: 'TabHistory',
        category: LogCategory.ui,
      );

      state = newHistory;
    });

    // Initialize with current tab (if available)
    final ctx = ref.read(pageContextProvider).asData?.value;
    if (ctx != null) {
      final tabIndex = tabIndexFromRouteType(ctx.type);
      if (tabIndex != null) {
        return [tabIndex];
      }
    }

    // Default to home tab
    return [0];
  }

  /// Get the previous tab in history (without removing it)
  /// Returns null if there's no previous tab
  int? getPreviousTab() {
    if (state.length <= 1) {
      return null; // No previous tab
    }
    return state[state.length - 2]; // Second to last tab
  }

  /// Navigate back to previous tab
  /// Returns true if navigation was handled, false if no previous tab (should exit app)
  bool navigateBack() {
    if (state.length <= 1) {
      // No previous tab - should exit app
      Log.debug(
        'No previous tab in history - should exit app',
        name: 'TabHistory',
        category: LogCategory.ui,
      );
      return false; // Not handled - let app exit
    }

    // Remove current tab from history
    final newHistory = List<int>.from(state);
    newHistory.removeLast(); // Remove current tab
    state = newHistory;

    // Get previous tab
    final previousTab = state.last;
    Log.debug(
      'Navigating back to tab: ${tabName(previousTab)}',
      name: 'TabHistory',
      category: LogCategory.ui,
    );

    return true; // Handled - navigation will be done by caller
  }

  /// Get the current tab index
  int? getCurrentTab() {
    if (state.isEmpty) return null;
    return state.last;
  }
}

final tabHistoryProvider = NotifierProvider<TabHistory, List<int>>(() {
  return TabHistory();
});
