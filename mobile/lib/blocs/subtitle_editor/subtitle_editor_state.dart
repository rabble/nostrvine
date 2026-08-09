part of 'subtitle_editor_cubit.dart';

/// Loading and editing status for the subtitle editor.
enum SubtitleEditorStatus {
  /// Initial cue-load is in progress.
  loading,

  /// Auto-transcription is still running; polling is expected.
  processing,

  /// Auto-transcription finished but found nothing to transcribe.
  empty,

  /// No subtitle track could be reached for this video.
  unavailable,

  /// Cues are loaded and ready to edit.
  ready,

  /// Edited cues are being published.
  saving,

  /// Publish completed successfully.
  success,

  /// An operation failed; check [addError] for details.
  failure,
}

/// A single subtitle cue the creator can edit — text and timing alike.
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

  /// Start time in milliseconds.
  final int start;

  /// End time in milliseconds.
  final int end;

  /// The subtitle text content.
  final String text;

  /// Converts back to a [SubtitleCue] for publishing.
  SubtitleCue toCue() => SubtitleCue(start: start, end: end, text: text);

  /// Returns a copy with the given fields replaced.
  EditableCue copyWith({int? start, int? end, String? text}) => EditableCue(
    start: start ?? this.start,
    end: end ?? this.end,
    text: text ?? this.text,
  );

  /// Whether this cue can be published: it says something, and it ends after
  /// it starts.
  bool get isValid => text.trim().isNotEmpty && end > start;

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
    this.updatedVideo,
  });

  /// Current editor status.
  final SubtitleEditorStatus status;

  /// The editable cues loaded from the subtitle track.
  final List<EditableCue> cues;

  /// Whether [cues] have been modified since the last save or load.
  final bool isDirty;

  /// Updated video event returned after a successful subtitle republish.
  final VideoEvent? updatedVideo;

  /// Whether [cues] can be published as they stand.
  bool get isValid => cues.isNotEmpty && cues.every((cue) => cue.isValid);

  /// Whether the creator is authoring cues rather than correcting
  /// auto-generated ones — used to decide which empty-state copy applies.
  bool get isEmptyDraft => status == SubtitleEditorStatus.ready && cues.isEmpty;

  /// Returns a copy with selected fields replaced.
  SubtitleEditorState copyWith({
    SubtitleEditorStatus? status,
    List<EditableCue>? cues,
    bool? isDirty,
    VideoEvent? updatedVideo,
  }) {
    return SubtitleEditorState(
      status: status ?? this.status,
      cues: cues ?? this.cues,
      isDirty: isDirty ?? this.isDirty,
      updatedVideo: updatedVideo ?? this.updatedVideo,
    );
  }

  @override
  List<Object?> get props => [status, cues, isDirty, updatedVideo];
}
