/// Camera flash mode options.
enum DivineFlashMode {
  /// Auto flash mode.
  auto,

  /// Torch (always on) mode.
  torch,

  /// Flash off mode.
  off;

  /// Path to SVG asset representing the flash mode.
  String get iconPath => switch (this) {
    .off => 'assets/icon/flash_off.svg',
    .torch => 'assets/icon/flash_on.svg',
    .auto => 'assets/icon/flash_auto.svg',
  };
}
