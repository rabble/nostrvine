part of 'clip_editor_bloc.dart';

/// Immutable snapshot of the clip list used for undo/redo history.
class ClipSnapshot extends Equatable {
  const ClipSnapshot(this.clips);

  final List<DivineVideoClip> clips;

  @override
  List<Object?> get props => [clips];
}

/// State for the clip editor screen.
///
/// Manages playback, clip selection, editing mode, reorder state,
/// and a local copy of clips with undo/redo history.
///
/// Clip mutations happen locally in this state. The parent screen
/// syncs the final clip list back to the Riverpod provider when
/// the editor is closed.
class ClipEditorState extends Equatable {
  const ClipEditorState({
    this.clips = const [],
    this.currentClipIndex = 0,
    this.currentPosition = Duration.zero,
    this.splitPosition = Duration.zero,
    this.isEditing = false,
    this.isReordering = false,
    this.isOverDeleteZone = false,
    this.isPlaying = false,
    this.isPlayerReady = false,
    this.hasPlayedOnce = false,
    this.isMuted = false,
    this.isTrimDragging = false,
    this.undoStack = const [],
    this.redoStack = const [],
  });

  /// Local copy of clips managed by this editor session.
  final List<DivineVideoClip> clips;

  /// Index of the currently active/selected clip (0-based).
  final int currentClipIndex;

  /// Current playback position within the video timeline.
  final Duration currentPosition;

  /// Position where a clip split operation will occur.
  final Duration splitPosition;

  /// Whether the editor is in editing mode (e.g., trimming, adjusting).
  final bool isEditing;

  /// Whether clips are being reordered by drag-and-drop.
  final bool isReordering;

  /// Whether a dragged clip is over the delete zone during reordering.
  final bool isOverDeleteZone;

  /// Whether video playback is currently active.
  final bool isPlaying;

  /// Whether the video player is initialized and ready for playback.
  final bool isPlayerReady;

  /// Whether the video has started playing at least once.
  /// Used to determine if thumbnail should be hidden.
  final bool hasPlayedOnce;

  /// Whether audio is muted during playback.
  final bool isMuted;

  /// Whether a trim handle is currently being dragged.
  final bool isTrimDragging;

  /// Stack of previous clip states for undo.
  final List<ClipSnapshot> undoStack;

  /// Stack of undone clip states for redo.
  final List<ClipSnapshot> redoStack;

  /// Whether an undo operation is available.
  bool get canUndo => undoStack.isNotEmpty;

  /// Whether a redo operation is available.
  bool get canRedo => redoStack.isNotEmpty;

  /// Total duration of all clips (respecting trim).
  Duration get totalDuration =>
      clips.fold(Duration.zero, (sum, clip) => sum + clip.trimmedDuration);

  /// Creates a copy with the given fields replaced.
  ClipEditorState copyWith({
    List<DivineVideoClip>? clips,
    int? currentClipIndex,
    Duration? currentPosition,
    Duration? splitPosition,
    bool? isEditing,
    bool? isReordering,
    bool? isOverDeleteZone,
    bool? isPlaying,
    bool? isPlayerReady,
    bool? hasPlayedOnce,
    bool? isMuted,
    bool? isTrimDragging,
    List<ClipSnapshot>? undoStack,
    List<ClipSnapshot>? redoStack,
  }) {
    return ClipEditorState(
      clips: clips ?? this.clips,
      currentClipIndex: currentClipIndex ?? this.currentClipIndex,
      currentPosition: currentPosition ?? this.currentPosition,
      splitPosition: splitPosition ?? this.splitPosition,
      isEditing: isEditing ?? this.isEditing,
      isReordering: isReordering ?? this.isReordering,
      isOverDeleteZone: isOverDeleteZone ?? this.isOverDeleteZone,
      isPlaying: isPlaying ?? this.isPlaying,
      isPlayerReady: isPlayerReady ?? this.isPlayerReady,
      hasPlayedOnce: hasPlayedOnce ?? this.hasPlayedOnce,
      isMuted: isMuted ?? this.isMuted,
      isTrimDragging: isTrimDragging ?? this.isTrimDragging,
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
    );
  }

  @override
  List<Object?> get props => [
    clips,
    currentClipIndex,
    currentPosition,
    splitPosition,
    isEditing,
    isReordering,
    isOverDeleteZone,
    isPlaying,
    isPlayerReady,
    hasPlayedOnce,
    isMuted,
    isTrimDragging,
    undoStack,
    redoStack,
  ];
}
