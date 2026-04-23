// ABOUTME: Extensions for AspectRatio enum with platform-specific behavior.
// ABOUTME: Centralizes the logic for full-screen vertical video display.

import 'dart:ui';

import 'package:divine_camera/divine_camera.dart' show DivineVideoQuality;
import 'package:models/models.dart' show AspectRatio;

/// Extensions for [DivineVideoQuality] with aspect-ratio-aware resolution.
extension DivineVideoQualityAspectRatio on DivineVideoQuality {
  /// Returns the output resolution scaled to the given [aspectRatio].
  ///
  /// Keeps the short side (width) from [resolution] and adjusts the height
  /// to match the target ratio (e.g. 1080×1080 for square, 1080×1920 for
  /// 9:16 vertical).
  Size resolutionForAspectRatio(AspectRatio aspectRatio) {
    final shortSide = resolution.width;
    return Size(shortSide, shortSide / aspectRatio.value);
  }
}
