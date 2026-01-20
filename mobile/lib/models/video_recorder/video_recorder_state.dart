/// Recording state for Vine-style segmented recording
enum VideoRecorderState {
  /// Camera preview active, not recording
  idle,

  /// Currently recording a segment
  recording,

  /// Error state
  error,
}
