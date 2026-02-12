// ABOUTME: Extensions for AspectRatio enum with platform-specific behavior.
// ABOUTME: Centralizes the logic for full-screen vertical video display.

import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:models/models.dart' show AspectRatio;
import 'package:openvine/platform_io.dart';

/// Extensions for [AspectRatio] with platform-specific display logic.
extension AspectRatioExtensions on AspectRatio {
  /// Whether this aspect ratio should use full-screen display.
  ///
  /// Returns `true` for vertical (9:16) videos on web and non-macOS platforms.
  /// On macOS, vertical videos are displayed with their intrinsic aspect ratio
  /// to avoid layout issues with the desktop window.
  bool get useFullScreen =>
      this == AspectRatio.vertical && (kIsWeb || !Platform.isMacOS);

  /// Whether this aspect ratio should use full-screen display for the given
  /// [bodySize].
  ///
  /// Returns `true` when:
  /// - vertical + (web or not macOS), OR
  /// - vertical + macOS but screen is already 9/16 or narrower
  bool useFullScreenForSize(Size bodySize) {
    if (this != AspectRatio.vertical) return false;
    if (kIsWeb || !Platform.isMacOS) return true;
    // On macOS, use fullscreen if screen already fits the target aspect ratio
    return bodySize.aspectRatio <= value;
  }
}
