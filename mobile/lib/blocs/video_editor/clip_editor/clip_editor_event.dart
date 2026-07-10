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

// === MULTI-SELECT ===

/// Enter multi-select mode, optionally pre-selecting [initialClipId].
///
/// Exits single-clip editing mode. While multi-select is active, tapping a
/// clip toggles its membership in the selection.
class ClipEditorMultiSelectStarted extends ClipEditorEvent {
  const ClipEditorMultiSelectStarted([this.initialClipId]);

  final String? initialClipId;

  @override
  List<Object?> get props => [initialClipId];
}

/// Toggle a clip's membership in the multi-select selection.
class ClipEditorMultiSelectClipToggled extends ClipEditorEvent {
  const ClipEditorMultiSelectClipToggled(this.clipId);

  final String clipId;

  @override
  List<Object?> get props => [clipId];
}

/// Exit multi-select mode and clear the selection.
class ClipEditorMultiSelectCancelled extends ClipEditorEvent {
  const ClipEditorMultiSelectCancelled();
}

/// Remove every clip currently in the multi-select selection.
///
/// No-op when the selection would empty the timeline — at least one clip must
/// always remain.
class ClipEditorSelectedClipsRemoved extends ClipEditorEvent {
  const ClipEditorSelectedClipsRemoved();
}

/// Merge every clip currently in the multi-select selection into a single
/// rendered clip placed at the earliest selected position.
class ClipEditorSelectedClipsMergeRequested extends ClipEditorEvent {
  const ClipEditorSelectedClipsMergeRequested();
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

/// Request to split a clip at a split position.
///
/// Validates the split position and stops editing mode before split.
///
/// [clipId] and [splitPosition] bind the request to a specific clip and cut
/// point. They are captured at dispatch time so a queued split (the handler is
/// `sequential`) still targets the intended clip even if the user selects a
/// different clip or moves the playhead while an earlier split is rendering.
/// When omitted, the handler falls back to the current selection and
/// [ClipEditorState.splitPosition] (used by tests and any legacy caller).
class ClipEditorSplitRequested extends ClipEditorEvent {
  const ClipEditorSplitRequested({this.clipId, this.splitPosition});

  final String? clipId;
  final Duration? splitPosition;

  @override
  List<Object?> get props => [clipId, splitPosition];
}

// === TRIM ===

/// Update the trim boundaries of a clip.
///
/// Applies updated trim values to the target clip.
class ClipEditorTrimUpdated extends ClipEditorEvent {
  const ClipEditorTrimUpdated({
    required this.clipId,
    required this.isStart,
    required this.trimStart,
    required this.trimEnd,
  });

  /// ID of the clip being trimmed.
  final String clipId;

  /// Whether the start handle (left) is being dragged.
  ///
  /// `true` → left handle; `false` → right handle.
  final bool isStart;

  /// Offset from the beginning of the original clip.
  final Duration trimStart;

  /// Offset from the end of the original clip.
  final Duration trimEnd;

  @override
  List<Object?> get props => [clipId, isStart, trimStart, trimEnd];
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

// === AUDIO EXTRACTION ===

/// Request audio extraction for the currently selected clip.
///
/// The bloc handles the async service call, mutes the clip, and emits a
/// [ClipAudioExtractionResult] one-shot signal for the widget layer to
/// write history and surface errors.
///
/// [clipTitle] is the l10n-resolved title forwarded to the created
/// [AudioEvent] so the bloc stays free of Flutter/UI dependencies.
///
/// [clipId] binds the request to a specific clip, captured at dispatch time so
/// a queued extraction (the handler is `sequential`) still targets the intended
/// clip even if the user selects a different clip while an earlier extraction
/// is running. When omitted, the handler falls back to the current selection
/// (used by tests and any legacy caller).
class ClipEditorAudioExtractionRequested extends ClipEditorEvent {
  const ClipEditorAudioExtractionRequested({
    required this.clipTitle,
    this.clipId,
  });

  final String clipTitle;
  final String? clipId;

  @override
  List<Object?> get props => [clipTitle, clipId];
}

// === REVERSE ===

/// Request reverse rendering for the clip with [clipId].
class ClipEditorClipReverseRequested extends ClipEditorEvent {
  const ClipEditorClipReverseRequested({required this.clipId});

  final String clipId;

  @override
  List<Object?> get props => [clipId];
}

// === TRANSFORM ===

/// Request that the clip with [clipId] be re-rendered with [transform]
/// (crop / 90°-rotation / flip) baked into a new file.
class ClipEditorClipTransformRequested extends ClipEditorEvent {
  const ClipEditorClipTransformRequested({
    required this.clipId,
    required this.transform,
  });

  final String clipId;
  final ExportTransform transform;

  @override
  List<Object?> get props => [clipId, transform];
}

// === VOLUME ===

/// Update the volume of a clip by its ID.
///
/// [volume] is clamped to [0.0, 1.0] by the handler.
class ClipEditorClipVolumeChanged extends ClipEditorEvent {
  const ClipEditorClipVolumeChanged({
    required this.clipId,
    required this.volume,
  });

  final String clipId;
  final double volume;

  @override
  List<Object?> get props => [clipId, volume];
}

/// Set the same [volume] on every clip.
/// [volume] is clamped to [0.0, 1.0] by the handler.
class ClipEditorAllClipsVolumeChanged extends ClipEditorEvent {
  const ClipEditorAllClipsVolumeChanged({required this.volume});

  final double volume;

  @override
  List<Object?> get props => [volume];
}
