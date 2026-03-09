part of 'video_editor_main_bloc.dart';

/// State for the video editor main screen.
class VideoEditorMainState extends Equatable {
  const VideoEditorMainState({
    this.canUndo = false,
    this.canRedo = false,
    this.openSubEditor,
    this.isLayerInteractionActive = false,
    this.isLayerOverRemoveArea = false,
    this.layers = const [],
    this.isPlaying = false,
    this.isPlayerReady = false,
    this.isExternalPauseRequested = false,
    this.playbackRestartCounter = 0,
    this.playbackToggleCounter = 0,
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

  /// The current list of layers in the editor.
  final List<Layer> layers;

  /// Whether the video is currently playing.
  final bool isPlaying;

  /// Whether the video player is ready for playback.
  final bool isPlayerReady;

  /// Whether an external component has requested playback pause.
  ///
  /// Used by audio selection to pause video while browsing sounds.
  final bool isExternalPauseRequested;

  /// Counter that increments when playback restart is requested.
  ///
  /// Used by BlocListener to trigger video restart from beginning.
  final int playbackRestartCounter;

  /// Counter that increments when playback toggle is requested.
  ///
  /// Used by BlocListener to trigger play/pause toggle.
  final int playbackToggleCounter;

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
    List<Layer>? layers,
    bool? isPlaying,
    bool? isPlayerReady,
    bool? isExternalPauseRequested,
    int? playbackRestartCounter,
    int? playbackToggleCounter,
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
      layers: layers ?? this.layers,
      isPlaying: isPlaying ?? this.isPlaying,
      isPlayerReady: isPlayerReady ?? this.isPlayerReady,
      isExternalPauseRequested:
          isExternalPauseRequested ?? this.isExternalPauseRequested,
      playbackRestartCounter:
          playbackRestartCounter ?? this.playbackRestartCounter,
      playbackToggleCounter:
          playbackToggleCounter ?? this.playbackToggleCounter,
    );
  }

  @override
  List<Object?> get props => [
    canUndo,
    canRedo,
    openSubEditor,
    isLayerInteractionActive,
    isLayerOverRemoveArea,
    layers,
    isPlaying,
    isPlayerReady,
    isExternalPauseRequested,
    playbackRestartCounter,
    playbackToggleCounter,
  ];
}
