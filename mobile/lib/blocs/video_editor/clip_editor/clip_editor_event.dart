part of 'clip_editor_bloc.dart';

/// Base class for all clip editor events.
sealed class ClipEditorEvent extends Equatable {
  const ClipEditorEvent();

  @override
  List<Object?> get props => [];
}

// === CLIP DATA ===

/// Initialize the local clip list from an external source.
///
/// Typically called once when the editor screen opens, passing
/// the current clips from the Riverpod provider.
class ClipEditorInitialized extends ClipEditorEvent {
  const ClipEditorInitialized(this.clips);

  final List<DivineVideoClip> clips;

  @override
  List<Object?> get props => [clips];
}

/// Remove a clip by its ID.
class ClipEditorClipRemoved extends ClipEditorEvent {
  const ClipEditorClipRemoved(this.clipId);

  final String clipId;

  @override
  List<Object?> get props => [clipId];
}

/// Reorder a clip from [oldIndex] to [newIndex].
class ClipEditorClipReordered extends ClipEditorEvent {
  const ClipEditorClipReordered({
    required this.oldIndex,
    required this.newIndex,
  });

  final int oldIndex;
  final int newIndex;

  @override
  List<Object?> get props => [oldIndex, newIndex];
}

/// Insert a clip at a specific index.
class ClipEditorClipInserted extends ClipEditorEvent {
  const ClipEditorClipInserted({required this.index, required this.clip});

  final int index;
  final DivineVideoClip clip;

  @override
  List<Object?> get props => [index, clip];
}

/// Replace a clip with updated data (e.g. after split rendering).
class ClipEditorClipUpdated extends ClipEditorEvent {
  const ClipEditorClipUpdated({required this.clipId, required this.clip});

  final String clipId;
  final DivineVideoClip clip;

  @override
  List<Object?> get props => [clipId, clip];
}

// === UNDO / REDO ===

/// Undo the last clip mutation.
class ClipEditorUndoRequested extends ClipEditorEvent {
  const ClipEditorUndoRequested();
}

/// Redo the last undone clip mutation.
class ClipEditorRedoRequested extends ClipEditorEvent {
  const ClipEditorRedoRequested();
}

// === CLIP SELECTION ===

/// Select a clip by its index in the clip list.
///
/// Pauses playback, resets player ready state, and calculates the
/// playback offset based on previous clips' durations.
class ClipEditorClipSelected extends ClipEditorEvent {
  const ClipEditorClipSelected(this.index);

  final int index;

  @override
  List<Object?> get props => [index];
}

// === PLAYBACK CONTROL ===

/// Toggle between playing and paused states.
///
/// Ignored if the player is not yet ready and playback is requested.
class ClipEditorPlayPauseToggled extends ClipEditorEvent {
  const ClipEditorPlayPauseToggled();
}

/// Pause video playback.
class ClipEditorPlaybackPaused extends ClipEditorEvent {
  const ClipEditorPlaybackPaused();
}

/// Set whether the video player is ready for playback.
class ClipEditorPlayerReadyChanged extends ClipEditorEvent {
  const ClipEditorPlayerReadyChanged({required this.isReady});

  final bool isReady;

  @override
  List<Object?> get props => [isReady];
}

/// Mark that video has started playing (hides thumbnail).
class ClipEditorFirstPlaybackStarted extends ClipEditorEvent {
  const ClipEditorFirstPlaybackStarted();
}

/// Toggle audio mute state.
class ClipEditorMuteToggled extends ClipEditorEvent {
  const ClipEditorMuteToggled();
}

/// Update the current playback position.
///
/// In editing mode, uses absolute position within the clip.
/// In viewing mode, adds offset from previous clips.
class ClipEditorPositionUpdated extends ClipEditorEvent {
  const ClipEditorPositionUpdated({
    required this.clipId,
    required this.position,
  });

  final String clipId;
  final Duration position;

  @override
  List<Object?> get props => [clipId, position];
}

// === EDITING MODE ===

/// Enter editing mode for the currently selected clip.
class ClipEditorEditingStarted extends ClipEditorEvent {
  const ClipEditorEditingStarted();
}

/// Exit editing mode for the currently selected clip.
class ClipEditorEditingStopped extends ClipEditorEvent {
  const ClipEditorEditingStopped();
}

/// Toggle between editing and viewing mode.
class ClipEditorEditingToggled extends ClipEditorEvent {
  const ClipEditorEditingToggled();
}

/// Seek to a specific split position within the trim range.
class ClipEditorSplitPositionChanged extends ClipEditorEvent {
  const ClipEditorSplitPositionChanged(this.position);

  final Duration position;

  @override
  List<Object?> get props => [position];
}

// === REORDERING ===

/// Start clip reordering mode for drag-and-drop operations.
class ClipEditorReorderingStarted extends ClipEditorEvent {
  const ClipEditorReorderingStarted();
}

/// Stop clip reordering mode and reset delete zone state.
class ClipEditorReorderingStopped extends ClipEditorEvent {
  const ClipEditorReorderingStopped();
}

/// Update whether a clip is being dragged over the delete zone.
class ClipEditorDeleteZoneChanged extends ClipEditorEvent {
  const ClipEditorDeleteZoneChanged({required this.isOver});

  final bool isOver;

  @override
  List<Object?> get props => [isOver];
}

// === SPLIT ===

/// Atomically replace the original clip with two split halves.
///
/// Finds the clip by [sourceClipId], replaces it with [startClip],
/// and inserts [endClip] right after. Pushes one undo entry so
/// the entire split can be undone in a single step.
class ClipEditorOriginalClipReplaced extends ClipEditorEvent {
  const ClipEditorOriginalClipReplaced({
    required this.sourceClipId,
    required this.startClip,
    required this.endClip,
  });

  final String sourceClipId;
  final DivineVideoClip startClip;
  final DivineVideoClip endClip;

  @override
  List<Object?> get props => [sourceClipId, startClip, endClip];
}

/// Request to split the currently selected clip at the current split position.
///
/// Validates the split position, stops editing mode, and delegates the
/// actual split execution to the injected [SplitExecutor].
class ClipEditorSplitRequested extends ClipEditorEvent {
  const ClipEditorSplitRequested();
}

// === TRIM ===

/// Update the trim boundaries of a clip.
///
/// Pushes an undo entry on the first change of a drag gesture
/// (when [isStart] is true). Subsequent updates during the same
/// gesture are applied without additional undo entries.
class ClipEditorTrimUpdated extends ClipEditorEvent {
  const ClipEditorTrimUpdated({
    required this.clipId,
    required this.trimStart,
    required this.trimEnd,
    this.isStart = false,
  });

  /// ID of the clip being trimmed.
  final String clipId;

  /// Offset from the beginning of the original clip.
  final Duration trimStart;

  /// Offset from the end of the original clip.
  final Duration trimEnd;

  /// `true` on the first update of a drag gesture — triggers an undo push.
  final bool isStart;

  @override
  List<Object?> get props => [clipId, trimStart, trimEnd, isStart];
}

/// Signals that a trim handle drag gesture has started.
class ClipEditorTrimDragStarted extends ClipEditorEvent {
  const ClipEditorTrimDragStarted();

  @override
  List<Object?> get props => [];
}

/// Signals that a trim handle drag gesture has ended.
class ClipEditorTrimDragEnded extends ClipEditorEvent {
  const ClipEditorTrimDragEnded();

  @override
  List<Object?> get props => [];
}
