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

  /// Icon representing the flash mode.
  DivineIconName get icon => switch (this) {
    .off => .lightningSlash,
    .torch => .lightning,
    .auto => .lightningA,
  };
}
