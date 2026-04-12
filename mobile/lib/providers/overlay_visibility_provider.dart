// ABOUTME: Provider for tracking overlay visibility (settings, modals)
// ABOUTME: Videos should pause when overlays are visible

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:unified_logger/unified_logger.dart';

part 'overlay_visibility_provider.g.dart';

/// State class to track which overlays are currently visible
class OverlayVisibilityState {
  const OverlayVisibilityState({
    this.isPageOpen = false,
    this.isBottomSheetOpen = false,
  });

  /// Full-screen page overlay (e.g., settings, profile).
  /// When open, all video players are released.
  final bool isPageOpen;

  /// Bottom sheet overlay (e.g., comments, share).
  /// When open, only the current player is paused but retained.
  final bool isBottomSheetOpen;

  /// Returns true if any overlay that should pause videos is visible
  bool get hasVisibleOverlay => isPageOpen || isBottomSheetOpen;

  /// Returns true if only lightweight overlays are open (bottom sheet).
  /// These overlays retain the current player for instant resume.
  /// Returns false if a full-screen page is open (requires full player release).
  bool get shouldRetainPlayer => isBottomSheetOpen && !isPageOpen;

  OverlayVisibilityState copyWith({bool? isPageOpen, bool? isBottomSheetOpen}) {
    return OverlayVisibilityState(
      isPageOpen: isPageOpen ?? this.isPageOpen,
      isBottomSheetOpen: isBottomSheetOpen ?? this.isBottomSheetOpen,
    );
  }

  @override
  String toString() =>
      'OverlayVisibilityState(page=$isPageOpen, '
      'bottomSheet=$isBottomSheetOpen)';
}

/// Notifier for managing overlay visibility state
@Riverpod(keepAlive: true)
class OverlayVisibility extends _$OverlayVisibility {
  @override
  OverlayVisibilityState build() => const OverlayVisibilityState();

  /// Set page overlay state (full-screen overlays like settings).
  /// When a page is open, all video players will be released.
  void setPageOpen(bool isOpen) {
    if (state.isPageOpen != isOpen) {
      Log.info(
        'Page ${isOpen ? 'opened' : 'closed'}',
        name: 'OverlayVisibility',
        category: LogCategory.ui,
      );
      state = state.copyWith(isPageOpen: isOpen);
    }
  }

  /// Set bottom sheet overlay state.
  /// When a bottom sheet is open, only the current player is paused.
  void setBottomSheetOpen(bool isOpen) {
    if (state.isBottomSheetOpen != isOpen) {
      Log.info(
        'BottomSheet ${isOpen ? 'opened' : 'closed'}',
        name: 'OverlayVisibility',
        category: LogCategory.ui,
      );
      state = state.copyWith(isBottomSheetOpen: isOpen);
    }
  }
}

/// Convenience provider that returns true if any overlay is visible
final hasVisibleOverlayProvider = Provider<bool>((ref) {
  final state = ref.watch(overlayVisibilityProvider);
  return state.hasVisibleOverlay;
});
