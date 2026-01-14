// ABOUTME: Enum for camera flash modes
// ABOUTME: Defines available flash options for camera operations

/// Available flash modes for the camera.
enum DivineCameraFlashMode {
  /// Flash is always off.
  off,

  /// Flash fires automatically when needed.
  auto,

  /// Flash is always on.
  on,

  /// Torch mode - continuous light for video recording.
  torch
  ;

  /// Converts the flash mode to a string for platform communication.
  String toNativeString() {
    switch (this) {
      case DivineCameraFlashMode.off:
        return 'off';
      case DivineCameraFlashMode.auto:
        return 'auto';
      case DivineCameraFlashMode.on:
        return 'on';
      case DivineCameraFlashMode.torch:
        return 'torch';
    }
  }

  /// Creates a flash mode from a native string.
  static DivineCameraFlashMode fromNativeString(String value) {
    switch (value) {
      case 'off':
        return DivineCameraFlashMode.off;
      case 'auto':
        return DivineCameraFlashMode.auto;
      case 'on':
        return DivineCameraFlashMode.on;
      case 'torch':
        return DivineCameraFlashMode.torch;
      default:
        return DivineCameraFlashMode.off;
    }
  }
}
