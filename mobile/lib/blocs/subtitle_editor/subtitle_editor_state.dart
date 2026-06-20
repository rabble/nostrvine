part of 'subtitle_editor_cubit.dart';

/// Loading and editing status for the subtitle editor.
enum SubtitleEditorStatus {
  /// Initial cue-load is in progress.
  loading,

  /// Auto-transcription is not yet available; polling is expected.
  processing,

  /// Cues are loaded and ready to edit.
  ready,

  /// Edited cues are being published.
  saving,

  /// Publish completed successfully.
  success,

  /// An operation failed; check [addError] for details.
  failure,
}

/// A single subtitle cue whose text may be edited.
///
/// Timing is read-only; only [text] can be changed by the editor.
class EditableCue extends Equatable {
  /// Creates an editable cue.
  const EditableCue({
    required this.start,
    required this.end,
    required this.text,
  });

  /// Converts a [SubtitleCue] to an [EditableCue].
  factory EditableCue.fromCue(SubtitleCue cue) =>
      EditableCue(start: cue.start, end: cue.end, text: cue.text);

  /// Start time in milliseconds (read-only).
  final int start;

  /// End time in milliseconds (read-only).
  final int end;

  /// The subtitle text content.
  final String text;

  /// Converts back to a [SubtitleCue] for publishing.
  SubtitleCue toCue() => SubtitleCue(start: start, end: end, text: text);

  /// Returns a copy with [text] replaced.
  EditableCue copyWith({String? text}) =>
      EditableCue(start: start, end: end, text: text ?? this.text);

  /// `M:SS` label derived from [start] for display purposes.
  String get timestampLabel {
    final totalSeconds = start ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  List<Object?> get props => [start, end, text];
}

/// State for [SubtitleEditorCubit].
class SubtitleEditorState extends Equatable {
  /// Creates the initial state.
  const SubtitleEditorState({
    this.status = SubtitleEditorStatus.loading,
    this.cues = const [],
    this.isDirty = false,
  });

  /// Current editor status.
  final SubtitleEditorStatus status;

  /// The editable cues loaded from the subtitle track.
  final List<EditableCue> cues;

  /// Whether [cues] have been modified since the last save or load.
  final bool isDirty;

  /// Returns a copy with selected fields replaced.
  SubtitleEditorState copyWith({
    SubtitleEditorStatus? status,
    List<EditableCue>? cues,
    bool? isDirty,
  }) {
    return SubtitleEditorState(
      status: status ?? this.status,
      cues: cues ?? this.cues,
      isDirty: isDirty ?? this.isDirty,
    );
  }

  @override
  List<Object?> get props => [status, cues, isDirty];
}
