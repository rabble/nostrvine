// ABOUTME: Outcome of reconciling a clip snapshot from the editor history
// ABOUTME: Tells the caller to sync, skip, or step past an orphan-only entry

/// What to do with the clip snapshot read from the editor's current
/// undo/redo history entry.
enum ClipSnapshotSyncOp {
  /// Mirror the resolvable clips into the app clip state (normal path).
  sync,

  /// The entry carries no clip metadata at all — nothing to reconcile.
  skip,

  /// The entry's clips are all orphaned; step the editor history backward to
  /// the nearest state whose media still exists.
  stepBackward,

  /// As [stepBackward], but step forward.
  stepForward,
}
