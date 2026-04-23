part of 'video_editor_main_bloc.dart';

/// State for the video editor main screen.
class VideoEditorMainState extends Equatable {
  const VideoEditorMainState({
    this.canUndo = false,
    this.canRedo = false,
    this.openSubEditor,
    this.isLayerInteractionActive = false,
    this.isLayerOverRemoveArea = false,
    this.isPlaying = false,
    this.isPlayerReady = false,
    this.isExternalPauseRequested = false,
    this.playbackRestartCounter = 0,
    this.playbackToggleCounter = 0,
    this.seekPosition = Duration.zero,
    this.seekCounter = 0,
    this.currentPosition = Duration.zero,
    this.totalDuration = Duration.zero,
    this.isMuted = false,
    this.isReordering = false,
    this.isTimelineHiddenByUser = false,
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

  /// The position to seek to, set by the timeline during scrubbing.
  final Duration seekPosition;

  /// Counter that increments when a seek is requested.
  ///
  /// Used by BlocListener to trigger video player seekTo.
  final int seekCounter;

  /// Current playback position reported by the video player.
  final Duration currentPosition;

  /// Total duration of all clips reported by the video player.
  final Duration totalDuration;

  /// Whether audio is currently muted.
  final bool isMuted;

  /// Whether the timeline is in clip reorder mode.
  final bool isReordering;

  /// Whether timeline visibility was manually toggled off by the user.
  final bool isTimelineHiddenByUser;

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
    bool? isMuted,
    bool? isPlaying,
    bool? isPlayerReady,
    bool? isExternalPauseRequested,
    int? playbackRestartCounter,
    int? playbackToggleCounter,
    Duration? seekPosition,
    int? seekCounter,
    Duration? currentPosition,
    Duration? totalDuration,
    bool? isReordering,
    bool? isTimelineHiddenByUser,
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
      isPlaying: isPlaying ?? this.isPlaying,
      isPlayerReady: isPlayerReady ?? this.isPlayerReady,
      isExternalPauseRequested:
          isExternalPauseRequested ?? this.isExternalPauseRequested,
      playbackRestartCounter:
          playbackRestartCounter ?? this.playbackRestartCounter,
      playbackToggleCounter:
          playbackToggleCounter ?? this.playbackToggleCounter,
      seekPosition: seekPosition ?? this.seekPosition,
      seekCounter: seekCounter ?? this.seekCounter,
      currentPosition: currentPosition ?? this.currentPosition,
      totalDuration: totalDuration ?? this.totalDuration,
      isMuted: isMuted ?? this.isMuted,
      isReordering: isReordering ?? this.isReordering,
      isTimelineHiddenByUser:
          isTimelineHiddenByUser ?? this.isTimelineHiddenByUser,
    );
  }

  @override
  List<Object?> get props => [
    canUndo,
    canRedo,
    openSubEditor,
    isLayerInteractionActive,
    isLayerOverRemoveArea,
    isPlaying,
    isPlayerReady,
    isExternalPauseRequested,
    playbackRestartCounter,
    playbackToggleCounter,
    seekPosition,
    seekCounter,
    currentPosition,
    totalDuration,
    isMuted,
    isReordering,
    isTimelineHiddenByUser,
  ];
}
