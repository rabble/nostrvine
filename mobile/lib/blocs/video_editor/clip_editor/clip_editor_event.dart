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

// === CLIP SELECTION ===

/// Select a clip by its index in the clip list.
///
/// Updates the selected clip index, resets split position, and logs the
/// playback offset based on previous clips' durations.
class ClipEditorClipSelected extends ClipEditorEvent {
  const ClipEditorClipSelected(this.index);

  final int index;

  @override
  List<Object?> get props => [index];
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

// === SPLIT ===

/// Atomically replace the original clip with two split halves.
///
/// Finds the clip by [sourceClipId], replaces it with [startClip],
/// and inserts [endClip] right after.
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
/// Validates the split position and stops editing mode before split.
class ClipEditorSplitRequested extends ClipEditorEvent {
  const ClipEditorSplitRequested();
}

// === TRIM ===

/// Update the trim boundaries of a clip.
///
/// Applies updated trim values to the target clip.
class ClipEditorTrimUpdated extends ClipEditorEvent {
  const ClipEditorTrimUpdated({
    required this.clipId,
    required this.trimStart,
    required this.trimEnd,
  });

  /// ID of the clip being trimmed.
  final String clipId;

  /// Offset from the beginning of the original clip.
  final Duration trimStart;

  /// Offset from the end of the original clip.
  final Duration trimEnd;

  @override
  List<Object?> get props => [clipId, trimStart, trimEnd];
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
