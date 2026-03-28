// ABOUTME: Extensions for AspectRatio enum with platform-specific behavior.
// ABOUTME: Centralizes the logic for full-screen vertical video display.

import 'dart:ui';

import 'package:divine_camera/divine_camera.dart' show DivineVideoQuality;
import 'package:models/models.dart' show AspectRatio;
import 'package:openvine/utils/platform_helpers.dart';

/// Extensions for [AspectRatio] with platform-specific display logic.
extension AspectRatioExtensions on AspectRatio {
  /// Whether this aspect ratio should use full-screen display.
  ///
  /// Returns `true` for vertical (9:16) videos on web and non-desktop
  /// platforms. On desktop, vertical videos are displayed with their intrinsic
  /// aspect ratio to avoid layout issues with the desktop window.
  bool get useFullScreen => this == AspectRatio.vertical && !isDesktopPlatform;

  /// Whether this aspect ratio should use full-screen display for the given
  /// [bodySize].
  ///
  /// Returns `true` when:
  /// - vertical + non-desktop, OR
  /// - vertical + desktop but screen is already 9/16 or narrower
  bool useFullScreenForSize(Size bodySize) {
    if (this != AspectRatio.vertical) return false;
    if (!isDesktopPlatform) return true;
    // On desktop, use fullscreen if screen already fits the target aspect ratio
    return bodySize.aspectRatio <= value;
  }
}

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
