// ABOUTME: Calculation functions for gallery item positioning
// ABOUTME: Provides scale and offset calculations via InheritedWidget

import 'package:flutter/material.dart';

/// Container for gallery position calculation functions.
///
/// Groups scale and offset calculations to avoid passing them
/// as callback parameters through multiple widget layers.
class GalleryCalculations {
  const GalleryCalculations({
    required this.calculateScale,
    required this.calculateXOffset,
  });

  /// Calculates the scale factor for a clip at [index].
  final double Function(int index) calculateScale;

  /// Calculates the horizontal offset for a clip at [index].
  final double Function(int index) calculateXOffset;
}

/// InheritedWidget that provides [GalleryCalculations] to descendant widgets.
class GalleryCalculationsScope extends InheritedWidget {
  const GalleryCalculationsScope({
    required this.calculations,
    required super.child,
    super.key,
  });

  final GalleryCalculations calculations;

  /// Returns the [GalleryCalculations] from the nearest ancestor.
  static GalleryCalculations of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<GalleryCalculationsScope>();
    assert(scope != null, 'No GalleryCalculationsScope found in context');
    return scope!.calculations;
  }

  @override
  bool updateShouldNotify(GalleryCalculationsScope oldWidget) {
    // Calculations don't change identity, so we never need to notify
    return false;
  }
}
