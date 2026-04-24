part of 'clip_editor_bloc.dart';

/// State for the clip editor screen.
///
/// Manages clip selection, editing mode, and local clip mutations.
///
/// Clip mutations happen locally in this state. The parent screen
/// syncs the final clip list back to the Riverpod provider when
/// the editor is closed.
class ClipEditorState extends Equatable {
  const ClipEditorState({
    this.clips = const [],
    this.currentClipIndex = 0,
    this.splitPosition = Duration.zero,
    this.isEditing = false,
    this.isTrimDragging = false,
  });

  /// Local copy of clips managed by this editor session.
  final List<DivineVideoClip> clips;

  /// Index of the currently active/selected clip (0-based).
  final int currentClipIndex;

  /// Position where a clip split operation will occur.
  final Duration splitPosition;

  /// Whether the editor is in editing mode (e.g., trimming, adjusting).
  final bool isEditing;

  /// Whether a trim handle is currently being dragged.
  final bool isTrimDragging;

  /// Total duration of all clips (respecting trim).
  Duration get totalDuration =>
      clips.fold(Duration.zero, (sum, clip) => sum + clip.trimmedDuration);

  /// Creates a copy with the given fields replaced.
  ClipEditorState copyWith({
    List<DivineVideoClip>? clips,
    int? currentClipIndex,
    Duration? splitPosition,
    bool? isEditing,
    bool? isTrimDragging,
  }) {
    return ClipEditorState(
      clips: clips ?? this.clips,
      currentClipIndex: currentClipIndex ?? this.currentClipIndex,
      splitPosition: splitPosition ?? this.splitPosition,
      isEditing: isEditing ?? this.isEditing,
      isTrimDragging: isTrimDragging ?? this.isTrimDragging,
    );
  }

  @override
  List<Object?> get props => [
    clips,
    currentClipIndex,
    splitPosition,
    isEditing,
    isTrimDragging,
  ];
}
