// ABOUTME: Immutable state model for video editor managing text overlays, sound, and export progress
// ABOUTME: Tracks editing state with export stages and computed properties for UI state

class EditorState {
  const EditorState({
    this.currentClipIndex = 0,
    this.currentPosition = .zero,
    this.isEditing = false,
    this.isReordering = false,
    this.isOverDeleteZone = false,
    this.isPlaying = false,
    this.isMuted = false,
    this.isProcessing = false,
  });

  final int currentClipIndex;
  final Duration currentPosition;

  final bool isEditing;
  final bool isReordering;
  final bool isOverDeleteZone;
  final bool isPlaying;
  final bool isMuted;
  final bool isProcessing;

  EditorState copyWith({
    bool? isEditing,
    bool? isReordering,
    bool? isOverDeleteZone,
    int? currentClipIndex,
    Duration? currentPosition,
    bool? isPlaying,
    bool? isMuted,
    bool? isProcessing,
  }) {
    return EditorState(
      isEditing: isEditing ?? this.isEditing,
      isReordering: isReordering ?? this.isReordering,
      isOverDeleteZone: isOverDeleteZone ?? this.isOverDeleteZone,
      currentClipIndex: currentClipIndex ?? this.currentClipIndex,
      currentPosition: currentPosition ?? this.currentPosition,
      isPlaying: isPlaying ?? this.isPlaying,
      isMuted: isMuted ?? this.isMuted,
      isProcessing: isProcessing ?? this.isProcessing,
    );
  }
}
