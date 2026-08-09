// ABOUTME: Direction of an undo/redo step through the video editor history
// ABOUTME: Biases which way a clip snapshot sync walks past orphaned entries

/// Direction an undo/redo navigation moved through the editor history.
enum ClipHistoryDirection {
  /// The history moved one entry backward.
  undo,

  /// The history moved one entry forward.
  redo,

  /// No navigation happened (init, add/remove layer).
  none,
}
