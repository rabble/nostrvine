part of 'clip_editor_bloc.dart';

/// State for the clip editor screen.
///
/// Manages playback, clip selection, editing mode, and reorder state.
/// Uses a single class with enum-like booleans because clip editing
/// accumulates incremental updates (position, selection, mode toggles).
class ClipEditorState extends Equatable {
  const ClipEditorState({
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
  });

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

  /// Creates a copy with the given fields replaced.
  ClipEditorState copyWith({
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
  }) {
    return ClipEditorState(
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
    );
  }

  @override
  List<Object?> get props => [
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
  ];
}
