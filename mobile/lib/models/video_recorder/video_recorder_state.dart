// ABOUTME: Recording state enum for video recording flow
// ABOUTME: Tracks idle, recording, and error states during video capture

/// Recording state for Vine-style segmented recording
enum VideoRecorderState {
  /// Camera preview active, not recording
  idle,

  /// Currently recording a segment
  recording,

  /// Error state
  error,
}
