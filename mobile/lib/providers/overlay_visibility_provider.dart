// ABOUTME: Provider for tracking overlay visibility (drawer, settings, modals)
// ABOUTME: Videos should pause when overlays are visible

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:openvine/utils/unified_logger.dart';

part 'overlay_visibility_provider.g.dart';

/// State class to track which overlays are currently visible
class OverlayVisibilityState {
  const OverlayVisibilityState({
    this.isDrawerOpen = false,
    this.isModalOpen = false,
  });

  final bool isDrawerOpen;
  final bool isModalOpen;

  /// Returns true if any overlay that should pause videos is visible
  bool get hasVisibleOverlay => isDrawerOpen || isModalOpen;

  OverlayVisibilityState copyWith({bool? isDrawerOpen, bool? isModalOpen}) {
    return OverlayVisibilityState(
      isDrawerOpen: isDrawerOpen ?? this.isDrawerOpen,
      isModalOpen: isModalOpen ?? this.isModalOpen,
    );
  }

  @override
  String toString() =>
      'OverlayVisibilityState(drawer=$isDrawerOpen, modal=$isModalOpen)';
}

/// Notifier for managing overlay visibility state
@Riverpod(keepAlive: true)
class OverlayVisibility extends _$OverlayVisibility {
  @override
  OverlayVisibilityState build() => const OverlayVisibilityState();

  void setDrawerOpen(bool isOpen) {
    if (state.isDrawerOpen != isOpen) {
      Log.info(
        '📱 Drawer ${isOpen ? 'opened' : 'closed'}',
        name: 'OverlayVisibility',
        category: LogCategory.ui,
      );
      state = state.copyWith(isDrawerOpen: isOpen);
    }
  }

  void setModalOpen(bool isOpen) {
    if (state.isModalOpen != isOpen) {
      Log.info(
        '📱 Modal ${isOpen ? 'opened' : 'closed'}',
        name: 'OverlayVisibility',
        category: LogCategory.ui,
      );
      state = state.copyWith(isModalOpen: isOpen);
    }
  }
}

/// Convenience provider that returns true if any overlay is visible
final hasVisibleOverlayProvider = Provider<bool>((ref) {
  final state = ref.watch(overlayVisibilityProvider);
  return state.hasVisibleOverlay;
});
