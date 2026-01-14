// ABOUTME: Enum for camera lens direction
// ABOUTME: Defines front and back camera options

/// Available camera lens directions.
enum DivineCameraLens {
  /// Front-facing camera (selfie camera).
  front,

  /// Back-facing camera (main camera).
  back
  ;

  /// Converts the lens direction to a string for platform communication.
  String toNativeString() {
    switch (this) {
      case DivineCameraLens.front:
        return 'front';
      case DivineCameraLens.back:
        return 'back';
    }
  }

  /// Creates a lens direction from a native string.
  static DivineCameraLens fromNativeString(String value) {
    switch (value) {
      case 'front':
        return DivineCameraLens.front;
      case 'back':
        return DivineCameraLens.back;
      default:
        return DivineCameraLens.back;
    }
  }

  /// Returns the opposite lens direction.
  DivineCameraLens get opposite {
    switch (this) {
      case DivineCameraLens.front:
        return DivineCameraLens.back;
      case DivineCameraLens.back:
        return DivineCameraLens.front;
    }
  }
}
