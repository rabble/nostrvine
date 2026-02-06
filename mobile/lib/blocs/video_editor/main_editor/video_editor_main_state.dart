part of 'video_editor_main_bloc.dart';

/// State for the video editor main screen.
class VideoEditorMainState extends Equatable {
  const VideoEditorMainState({
    this.canUndo = false,
    this.canRedo = false,
    this.openSubEditor,
    this.isLayerInteractionActive = false,
    this.isLayerOverRemoveArea = false,
  });

  /// Whether the undo action is available.
  final bool canUndo;

  /// Whether the redo action is available.
  final bool canRedo;

  /// The currently open sub-editor, or `null` if none is open.
  final SubEditorType? openSubEditor;

  /// Whether a sub-editor is currently open.
  bool get isSubEditorOpen => openSubEditor != null;

  /// Whether the user is currently interacting with a layer (scaling/rotating).
  final bool isLayerInteractionActive;

  /// Whether the layer is currently positioned over the remove area.
  final bool isLayerOverRemoveArea;

  /// Creates a copy with the given fields replaced.
  ///
  /// Use [clearOpenSubEditor] to explicitly close the sub-editor.
  VideoEditorMainState copyWith({
    bool? canUndo,
    bool? canRedo,
    SubEditorType? openSubEditor,
    bool clearOpenSubEditor = false,
    bool? isLayerInteractionActive,
    bool? isLayerOverRemoveArea,
  }) {
    return VideoEditorMainState(
      canUndo: canUndo ?? this.canUndo,
      canRedo: canRedo ?? this.canRedo,
      openSubEditor: clearOpenSubEditor
          ? null
          : (openSubEditor ?? this.openSubEditor),
      isLayerInteractionActive:
          isLayerInteractionActive ?? this.isLayerInteractionActive,
      isLayerOverRemoveArea:
          isLayerOverRemoveArea ?? this.isLayerOverRemoveArea,
    );
  }

  @override
  List<Object?> get props => [
    canUndo,
    canRedo,
    openSubEditor,
    isLayerInteractionActive,
    isLayerOverRemoveArea,
  ];
}
