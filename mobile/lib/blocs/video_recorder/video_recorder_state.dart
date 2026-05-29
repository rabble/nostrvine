part of 'video_recorder_bloc.dart';

/// State for [VideoRecorderBloc].
///
/// Ports the legacy `VideoRecorderProviderState` verbatim and adds the mutable
/// instance fields that were previously held on the provider class
/// (concurrency flags + zoom-snap gesture state) so all observable
/// data lives in the state stream per `state_management.md`.
class VideoRecorderBlocState extends Equatable {
  const VideoRecorderBlocState({
    this.recorderMode = VideoRecorderMode.capture,
    this.recordingState = VideoRecorderState.idle,
    this.zoomLevel = 1.0,
    this.cameraSensorAspectRatio = 1.0,
    this.focusPoint = Offset.zero,
    this.canRecord = false,
    this.isCameraInitialized = false,
    this.canSwitchCamera = true,
    this.hasFlash = true,
    this.countdownValue = 0,
    this.cameraRebuildCount = 0,
    this.aspectRatio = model.AspectRatio.vertical,
    this.flashMode = DivineFlashMode.auto,
    this.timerDuration = TimerDuration.off,
    // TODO(#4787): Replace with a status enum + l10n key per
    // `state_management.md` once the UI migration (PR2/PR3) is in.
    // Kept as-is for PR1 to preserve verbatim provider behavior.
    this.initializationErrorMessage,
    this.showLastClipOverlay = false,
    this.showGridLines = false,
    this.isStartingRecording = false,
    this.isStoppingRecording = false,
    this.baseZoomLevel = 1.0,
    this.snappedTo1x = false,
    this.lastRawZoom = 1.0,
    this.snapTime,
  });

  /// Recorder mode from the camera.
  final VideoRecorderMode recorderMode;

  /// Camera focus point in normalized coordinates (0.0-1.0).
  final Offset focusPoint;

  /// Whether recording is allowed.
  final bool canRecord;

  /// Whether the camera is initialized.
  final bool isCameraInitialized;

  /// Whether camera switching is available.
  final bool canSwitchCamera;

  /// Whether the camera has flash capability.
  final bool hasFlash;

  /// Current zoom level.
  final double zoomLevel;

  /// Aspect ratio of the camera sensor.
  final double cameraSensorAspectRatio;

  /// Current countdown value before recording starts.
  final int countdownValue;

  /// Count of camera rebuilds for forcing UI updates.
  final int cameraRebuildCount;

  /// Current recording aspect ratio.
  final model.AspectRatio aspectRatio;

  /// Current flash mode.
  final DivineFlashMode flashMode;

  /// Timer duration before recording starts.
  final TimerDuration timerDuration;

  /// Current recording state.
  final VideoRecorderState recordingState;

  /// Custom error message when camera initialization fails.
  final String? initializationErrorMessage;

  /// Whether to show a semi-transparent overlay of the last recorded clip
  /// on the camera preview (ghost frame).
  final bool showLastClipOverlay;

  /// Whether to show the rule-of-thirds grid overlay on the camera preview.
  final bool showGridLines;

  /// True while [_VideoRecorderRecordingStarted] is in-flight (between
  /// pressing record and the camera reporting the first keyframe).
  ///
  /// Moved out of the notifier's private fields per `state_management.md`.
  final bool isStartingRecording;

  /// True while [_VideoRecorderRecordingStopped] is finalizing.
  ///
  /// Moved out of the notifier's private fields per `state_management.md`.
  final bool isStoppingRecording;

  /// Zoom level captured at the start of the current pinch gesture.
  ///
  /// Used to compute relative zoom from pinch scale. Moved out of the
  /// notifier's private fields per `state_management.md`.
  final double baseZoomLevel;

  /// Whether the zoom is currently locked at 1.0x via the snap detent.
  final bool snappedTo1x;

  /// Last raw (post-damping, pre-snap) zoom value observed by the
  /// scale update handler — feeds the detent edge detector.
  final double lastRawZoom;

  /// Time the snap-to-1x detent engaged. Used to enforce the snap
  /// hold duration before releasing back to free-scrubbing.
  final DateTime? snapTime;

  /// Whether currently recording.
  bool get isRecording => recordingState == VideoRecorderState.recording;

  /// Whether camera is initialized and not in error state.
  bool get isInitialized =>
      isCameraInitialized && recordingState != VideoRecorderState.error;

  /// Whether in error state.
  bool get isError => recordingState == VideoRecorderState.error;

  /// Error message if in error state or initialization failed.
  String? get errorMessage =>
      initializationErrorMessage ??
      (isError ? 'Recording error occurred' : null);

  /// Creates a copy of this state with updated values.
  VideoRecorderBlocState copyWith({
    VideoRecorderMode? recorderMode,
    VideoRecorderState? recordingState,
    double? zoomLevel,
    double? cameraSensorAspectRatio,
    Offset? focusPoint,
    bool? canRecord,
    bool? isCameraInitialized,
    bool? canSwitchCamera,
    bool? hasFlash,
    int? countdownValue,
    int? cameraRebuildCount,
    model.AspectRatio? aspectRatio,
    DivineFlashMode? flashMode,
    TimerDuration? timerDuration,
    String? initializationErrorMessage,
    bool? showLastClipOverlay,
    bool? showGridLines,
    bool? isStartingRecording,
    bool? isStoppingRecording,
    double? baseZoomLevel,
    bool? snappedTo1x,
    double? lastRawZoom,
    DateTime? snapTime,
  }) {
    return VideoRecorderBlocState(
      recorderMode: recorderMode ?? this.recorderMode,
      recordingState: recordingState ?? this.recordingState,
      zoomLevel: zoomLevel ?? this.zoomLevel,
      cameraSensorAspectRatio:
          cameraSensorAspectRatio ?? this.cameraSensorAspectRatio,
      focusPoint: focusPoint ?? this.focusPoint,
      canRecord: canRecord ?? this.canRecord,
      isCameraInitialized: isCameraInitialized ?? this.isCameraInitialized,
      canSwitchCamera: canSwitchCamera ?? this.canSwitchCamera,
      hasFlash: hasFlash ?? this.hasFlash,
      countdownValue: countdownValue ?? this.countdownValue,
      cameraRebuildCount: cameraRebuildCount ?? this.cameraRebuildCount,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      flashMode: flashMode ?? this.flashMode,
      timerDuration: timerDuration ?? this.timerDuration,
      initializationErrorMessage:
          initializationErrorMessage ?? this.initializationErrorMessage,
      showLastClipOverlay: showLastClipOverlay ?? this.showLastClipOverlay,
      showGridLines: showGridLines ?? this.showGridLines,
      isStartingRecording: isStartingRecording ?? this.isStartingRecording,
      isStoppingRecording: isStoppingRecording ?? this.isStoppingRecording,
      baseZoomLevel: baseZoomLevel ?? this.baseZoomLevel,
      snappedTo1x: snappedTo1x ?? this.snappedTo1x,
      lastRawZoom: lastRawZoom ?? this.lastRawZoom,
      snapTime: snapTime ?? this.snapTime,
    );
  }

  @override
  List<Object?> get props => [
    recorderMode,
    recordingState,
    zoomLevel,
    cameraSensorAspectRatio,
    focusPoint,
    canRecord,
    isCameraInitialized,
    canSwitchCamera,
    hasFlash,
    countdownValue,
    cameraRebuildCount,
    aspectRatio,
    flashMode,
    timerDuration,
    initializationErrorMessage,
    showLastClipOverlay,
    showGridLines,
    isStartingRecording,
    isStoppingRecording,
    baseZoomLevel,
    snappedTo1x,
    lastRawZoom,
    snapTime,
  ];
}
