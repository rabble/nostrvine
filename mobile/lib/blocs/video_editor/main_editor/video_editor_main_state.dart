part of 'video_editor_main_bloc.dart';

/// State for the video editor main screen.
class VideoEditorMainState extends Equatable {
  const VideoEditorMainState({
    this.canUndo = false,
    this.canRedo = false,
    this.isSubEditorOpen = false,
    this.isLayerInteractionActive = false,
  });

  /// Whether the undo action is available.
  final bool canUndo;

  /// Whether the redo action is available.
  final bool canRedo;

  /// Whether a sub-editor (text, paint, filter) is currently open.
  final bool isSubEditorOpen;

  /// Whether the user is currently interacting with a layer (scaling/rotating).
  final bool isLayerInteractionActive;

  VideoEditorMainState copyWith({
    bool? canUndo,
    bool? canRedo,
    bool? isSubEditorOpen,
    bool? isLayerInteractionActive,
  }) {
    return VideoEditorMainState(
      canUndo: canUndo ?? this.canUndo,
      canRedo: canRedo ?? this.canRedo,
      isSubEditorOpen: isSubEditorOpen ?? this.isSubEditorOpen,
      isLayerInteractionActive:
          isLayerInteractionActive ?? this.isLayerInteractionActive,
    );
  }

  @override
  List<Object?> get props => [
    canUndo,
    canRedo,
    isSubEditorOpen,
    isLayerInteractionActive,
  ];
}
