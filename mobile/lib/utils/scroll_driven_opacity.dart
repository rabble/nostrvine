// ABOUTME: Shared utility for computing scroll-driven overlay opacity.
// ABOUTME: Used by both the home feed and fullscreen feed overlays.

import 'dart:ui' show lerpDouble;

// Scroll-fraction constants for overlay opacity during page transitions.
//
// Opacity is scroll-driven: it changes continuously as the page scrolls,
// tracking the finger position rather than running on a separate timer.
// A small transition band around each threshold gives a smooth cross-fade.

/// Fraction scrolled away below which the overlay is fully visible.
const double kOverlayFullOpacityThreshold = 0.1;

/// Fraction scrolled away above which the overlay is fully hidden.
const double kOverlayHideThreshold = 0.5;

/// Opacity while in the dimmed band between the two thresholds.
const double kOverlayDimmedOpacity = 0.5;

/// Half-width of the smooth cross-fade zone around each threshold.
///
/// e.g. 0.03 → full↔dim transition spans 7 %–13 %, dim↔hidden spans 47 %–53 %.
const double kOverlayFadeHalfWidth = 0.03;

/// Maps [distance] (0–1 fraction scrolled away from an item) to overlay
/// opacity using smooth linear interpolation around each threshold.
double scrollDrivenOpacity(double distance) {
  const dimLo = kOverlayFullOpacityThreshold - kOverlayFadeHalfWidth;
  const dimHi = kOverlayFullOpacityThreshold + kOverlayFadeHalfWidth;
  const hideLo = kOverlayHideThreshold - kOverlayFadeHalfWidth;
  const hideHi = kOverlayHideThreshold + kOverlayFadeHalfWidth;

  if (distance <= dimLo) return 1.0;
  if (distance <= dimHi) {
    return lerpDouble(
      1.0,
      kOverlayDimmedOpacity,
      (distance - dimLo) / (dimHi - dimLo),
    )!;
  }
  if (distance <= hideLo) return kOverlayDimmedOpacity;
  if (distance <= hideHi) {
    return lerpDouble(
      kOverlayDimmedOpacity,
      0.0,
      (distance - hideLo) / (hideHi - hideLo),
    )!;
  }
  return 0.0;
}
