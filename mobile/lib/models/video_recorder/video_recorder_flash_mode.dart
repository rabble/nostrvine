// ABOUTME: Flash mode enum for camera recording
// ABOUTME: Defines flash modes (auto, torch, off) with corresponding icon assets

import 'package:divine_ui/divine_ui.dart';

/// Camera flash mode options.
enum DivineFlashMode {
  /// Auto flash mode.
  auto,

  /// Torch (always on) mode.
  torch,

  /// Flash off mode.
  off;

  /// Path to SVG asset representing the flash mode.
  DivineIconName get iconPath => switch (this) {
    .off => .lightningSlash,
    .torch => .lightning,
    .auto => .lightningA,
  };
}
