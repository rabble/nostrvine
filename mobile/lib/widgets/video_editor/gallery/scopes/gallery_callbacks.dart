// ABOUTME: Callback container for gallery interactions
// ABOUTME: Provides callbacks via InheritedWidget to avoid prop drilling

import 'package:flutter/material.dart';

/// Container for all gallery interaction callbacks.
///
/// This class groups related callbacks to avoid passing them
/// individually through multiple widget layers.
class GalleryCallbacks {
  const GalleryCallbacks({
    required this.onStartReordering,
    required this.onReorderCancel,
    required this.onReorderEvent,
    required this.onPageChanged,
  });

  /// Called when user long-presses to start reordering.
  final VoidCallback onStartReordering;

  /// Called when reorder is cancelled or completed.
  final VoidCallback onReorderCancel;

  /// Called on pointer move during reordering.
  final void Function(PointerMoveEvent event, BoxConstraints constraints)
  onReorderEvent;

  /// Called when the visible page changes.
  final ValueChanged<int> onPageChanged;
}

/// InheritedWidget that provides [GalleryCallbacks] to descendant widgets.
///
/// Use [GalleryCallbacksScope.of(context)] to access callbacks
/// without passing them through constructors.
class GalleryCallbacksScope extends InheritedWidget {
  const GalleryCallbacksScope({
    required this.callbacks,
    required super.child,
    super.key,
  });

  final GalleryCallbacks callbacks;

  /// Returns the [GalleryCallbacks] from the nearest ancestor.
  ///
  /// Throws if no [GalleryCallbacksScope] is found in the widget tree.
  static GalleryCallbacks of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<GalleryCallbacksScope>();
    assert(scope != null, 'No GalleryCallbacksScope found in context');
    return scope!.callbacks;
  }

  /// Returns the [GalleryCallbacks] without registering for rebuilds.
  ///
  /// Use this when you only need to call a callback and don't need
  /// to rebuild when callbacks change.
  static GalleryCallbacks read(BuildContext context) {
    final scope = context
        .getInheritedWidgetOfExactType<GalleryCallbacksScope>();
    assert(scope != null, 'No GalleryCallbacksScope found in context');
    return scope!.callbacks;
  }

  @override
  bool updateShouldNotify(GalleryCallbacksScope oldWidget) {
    return callbacks != oldWidget.callbacks;
  }
}
