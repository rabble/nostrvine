// ABOUTME: Bloc that owns the camera-recorder UI state (port of
// ABOUTME: VideoRecorderNotifier, removing concurrency-flag fields and
// ABOUTME: adding sequential() on recording start/stop).

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:collection/collection.dart';
import 'package:divine_camera/divine_camera.dart'
    show
        CameraLensMetadata,
        DivineCameraLens,
        DivineVideoQuality,
        DivineVideoStabilizationMode;
import 'package:divine_video_player/divine_video_player.dart'
    show DivineVideoPlayerController, VideoClip;
import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' as model show AspectRatio, AudioSourceKind;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_recorder/video_recorder_flash_mode.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:openvine/models/video_recorder/video_recorder_state.dart';
import 'package:openvine/models/video_recorder/video_recorder_timer_duration.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/services/haptic_service.dart';
import 'package:openvine/services/video_recorder/camera/camera_base_service.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sound_service/sound_service.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

part 'video_recorder_event.dart';
part 'video_recorder_state.dart';

/// SharedPreferences key for the last-used camera lens.
const _kLastUsedCameraLensKey = 'camera_last_used_lens';

/// SharedPreferences key for the last-used video stabilization mode.
const _kLastUsedStabilizationModeKey = 'camera_last_used_stabilization';

/// Factory for creating a [CountdownSoundService].
///
/// Injectable so tests can verify the wiring that protects the
/// camera-owned AVAudioSession (see [defaultCountdownSoundServiceFactory]
/// and #4539).
typedef CountdownSoundServiceFactory = CountdownSoundService Function();

/// Factory for creating an [AudioPlaybackService].
typedef AudioPlaybackServiceFactory = AudioPlaybackService Function();

/// Accessor for the [ClipManagerNotifier] (method-call + public-getter
/// side) living in the surrounding Riverpod scope. The bloc never
/// imports flutter_riverpod; the wiring site passes
/// `() => ref.read(clipManagerProvider.notifier)`.
///
/// Note: state reads use the notifier's existing public getters
/// (`.clips`, `.remainingDuration`, `.totalDuration`), not the
/// protected `.state` accessor.
typedef ReadClipManager = ClipManagerNotifier Function();

/// Accessor for the [VideoEditorNotifier] (method-call side).
typedef ReadVideoEditor = VideoEditorNotifier Function();

/// Accessor for the current [VideoEditorProviderState]. See
/// [ReadClipManagerState] for the same rationale.
typedef ReadVideoEditorState = VideoEditorProviderState Function();

/// Accessor for the [SharedPreferences] instance.
typedef ReadSharedPreferences = SharedPreferences Function();

/// Default [CountdownSoundService] factory.
///
/// Forwards `handleAudioSessionActivation: false` to [JustAudioSimplePlayer]
/// so just_audio never calls `setCategory(.playback)` on the shared
/// AVAudioSession — the camera already owns it in `.playAndRecord`
/// mode. Interference would trigger `attachAudioToSessionIfNeeded()`
/// on the native camera controller, restarting the audio capture
/// pipeline and resetting VPIO/AGC. That manifested as the progressive
/// mic-volume ramp-up reported in #4539.
CountdownSoundService defaultCountdownSoundServiceFactory() =>
    CountdownSoundService(
      audioPlayerFactory: () =>
          JustAudioSimplePlayer(handleAudioSessionActivation: false),
    );

/// Default [AudioPlaybackService] factory.
///
/// Forwards `handleAudioSessionActivation: false` for the same reason
/// as [defaultCountdownSoundServiceFactory] — see that function for
/// the full rationale and #4539.
AudioPlaybackService defaultAudioPlaybackServiceFactory() =>
    AudioPlaybackService(handleAudioSessionActivation: false);

/// Bloc that owns the camera-recorder UI state.
///
/// Direct port of `VideoRecorderNotifier`. Differences from the
/// provider:
///
/// 1. [VideoRecorderRecordingStartRequested] and
///    [VideoRecorderRecordingStopRequested] are registered with
///    `transformer: sequential()` so each becomes a FIFO queue
///    (#4787 hazard R1).
/// 2. The provider's `_isStartingRecording`, `_isStoppingRecording`,
///    `_baseZoomLevel`, `_snappedTo1x`, `_lastRawZoom`, and
///    `_snapTime` mutable instance fields now live in
///    [VideoRecorderBlocState] per `state_management.md`.
/// 3. Navigation methods (`closeVideoRecorder`, `openVideoEditor`,
///    `openLibrary`) move to the View. The bloc exposes
///    [VideoRecorderCameraPausedForNavigation] so the View can
///    dispose the camera mid-transition without owning the
///    navigation contract.
/// 4. Sibling Riverpod providers are reached via typedef accessors
///    ([ReadClipManager], [ReadVideoEditor], [ReadSharedPreferences])
///    so the bloc remains pure Dart.
class VideoRecorderBloc
    extends Bloc<VideoRecorderEvent, VideoRecorderBlocState> {
  /// Creates a video recorder bloc.
  ///
  /// [readClipManager], [readVideoEditor], and [readSharedPreferences]
  /// bridge the Riverpod-scoped dependencies that survive
  /// migration (the sibling providers are out of scope for #4744 —
  /// see `tasks/plan_4744.md` §4 WS-2 PR3).
  ///
  /// [cameraService] is an optional override for tests. When omitted
  /// the bloc creates the platform-appropriate [CameraService] via
  /// `CameraService.create`, wiring its update / auto-stop / remote
  /// callbacks to internal events.
  ///
  /// [countdownSoundServiceFactory] and [audioPlaybackServiceFactory]
  /// are optional test overrides. Defaults preserve the iOS
  /// audio-session wiring required by #4539.
  VideoRecorderBloc({
    required ReadClipManager readClipManager,
    required ReadVideoEditor readVideoEditor,
    required ReadVideoEditorState readVideoEditorState,
    required ReadSharedPreferences readSharedPreferences,
    CameraService? cameraService,
    CountdownSoundServiceFactory? countdownSoundServiceFactory,
    AudioPlaybackServiceFactory? audioPlaybackServiceFactory,
  }) : _readClipManager = readClipManager,
       _readVideoEditor = readVideoEditor,
       _readVideoEditorState = readVideoEditorState,
       _readSharedPreferences = readSharedPreferences,
       _cameraServiceOverride = cameraService,
       _countdownSoundServiceFactory =
           countdownSoundServiceFactory ?? defaultCountdownSoundServiceFactory,
       _audioPlaybackServiceFactory =
           audioPlaybackServiceFactory ?? defaultAudioPlaybackServiceFactory,
       super(const VideoRecorderBlocState()) {
    _cameraService =
        _cameraServiceOverride ??
        CameraService.create(
          onUpdateState: ({forceCameraRebuild}) {
            if (isClosed) return;
            add(
              _VideoRecorderCameraStateChanged(
                cameraRebuildCount: (forceCameraRebuild ?? false)
                    ? state.cameraRebuildCount + 1
                    : null,
              ),
            );
          },
          onAutoStopped: (video) {
            if (isClosed) return;
            if (state.recorderMode.hasRecordingLimit) {
              add(_VideoRecorderAutoStopped(video));
            }
          },
        );

    on<VideoRecorderInitializeRequested>(_onInitializeRequested);
    on<VideoRecorderAppLifecycleChanged>(_onAppLifecycleChanged);
    on<VideoRecorderRemoteRecordPaused>(_onRemoteRecordPaused);
    on<VideoRecorderRemoteRecordResumed>(_onRemoteRecordResumed);
    on<VideoRecorderFlashToggled>(_onFlashToggled);
    on<VideoRecorderAspectRatioToggled>(_onAspectRatioToggled);
    on<VideoRecorderAspectRatioSet>(_onAspectRatioSet);
    on<VideoRecorderCameraSwitched>(_onCameraSwitched);
    on<VideoRecorderStabilizationModeSet>(
      _onStabilizationModeSet,
      // Each change drives a native reconfigure (a CameraX rebind on Android);
      // process them FIFO so rapid menu picks can't overlap and the last
      // selection wins.
      transformer: sequential(),
    );
    on<VideoRecorderLensSet>(_onLensSet);
    on<VideoRecorderZoomLevelSet>(_onZoomLevelSet);
    on<VideoRecorderFocusPointSet>(_onFocusPointSet);
    on<VideoRecorderExposurePointSet>(_onExposurePointSet);
    on<VideoRecorderRecordingToggleRequested>(_onRecordingToggleRequested);
    on<VideoRecorderRecordingStartRequested>(
      _onRecordingStartRequested,
      transformer: sequential(),
    );
    on<VideoRecorderRecordingStopRequested>(
      _onRecordingStopRequested,
      transformer: sequential(),
    );
    on<VideoRecorderLongPressZoomStarted>(_onLongPressZoomStarted);
    on<VideoRecorderZoomedByLongPress>(_onZoomedByLongPress);
    on<VideoRecorderScaleStarted>(_onScaleStarted);
    on<VideoRecorderScaleUpdated>(_onScaleUpdated);
    on<VideoRecorderRecordingLockedForNavigation>(
      _onRecordingLockedForNavigation,
    );
    on<VideoRecorderCameraPausedForNavigation>(_onCameraPausedForNavigation);
    on<VideoRecorderRecorderModeSet>(_onRecorderModeSet);
    on<VideoRecorderTimerCycled>(_onTimerCycled);
    on<VideoRecorderResetRequested>(_onResetRequested);
    on<VideoRecorderShowLastClipOverlayToggled>(
      _onShowLastClipOverlayToggled,
    );
    on<VideoRecorderGridLinesToggled>(_onGridLinesToggled);
    on<_VideoRecorderCameraStateChanged>(_onCameraStateChanged);
    on<_VideoRecorderRemoteRecordTriggered>(_onRemoteRecordTriggered);
    on<_VideoRecorderAutoStopped>(_onAutoStopped);
    on<_VideoRecorderFocusPointTimerFired>(_onFocusPointTimerFired);
    on<_VideoRecorderZoomIndicatorTimerFired>(_onZoomIndicatorTimerFired);
  }

  final ReadClipManager _readClipManager;
  final ReadVideoEditor _readVideoEditor;
  final ReadVideoEditorState _readVideoEditorState;
  final ReadSharedPreferences _readSharedPreferences;
  final CameraService? _cameraServiceOverride;
  final CountdownSoundServiceFactory _countdownSoundServiceFactory;
  final AudioPlaybackServiceFactory _audioPlaybackServiceFactory;

  late final CameraService _cameraService;
  AudioPlaybackService? _audioPlaybackService;
  CountdownSoundService? _countdownSoundService;
  Timer? _focusPointTimer;
  Timer? _zoomIndicatorTimer;
  bool _remoteRecordControlEnabled = false;

  /// How long the zoom ruler stays visible after the last pinch activity
  /// before the auto-hide timer clears it.
  static const _zoomIndicatorHideDelay = Duration(milliseconds: 1000);

  /// The current active camera lens. Delegates to the camera service.
  DivineCameraLens get currentLens => _cameraService.currentLens;

  /// List of available camera lenses on this device. Delegates to the
  /// camera service.
  List<DivineCameraLens> get availableLenses => _cameraService.availableLenses;

  /// Metadata for the currently active lens, if available.
  CameraLensMetadata? get currentLensMetadata =>
      _cameraService.currentLensMetadata;

  bool get _remoteRecordPausedForSound =>
      _readVideoEditorState().selectedSound != null;

  // === Event handlers ===

  Future<void> _onInitializeRequested(
    VideoRecorderInitializeRequested event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    // Re-initialization marks the end of any navigation teardown, so release
    // the navigation recording lock up front — this covers the camera-init
    // error returns below too, which previously left the recorder locked until
    // a later successful init. The camera isn't usable yet (`canRecord` stays
    // false until initialize() completes), so clearing the lock here cannot let
    // a racing trigger start a recording on a torn-down camera.
    if (state.recordingLockedForNavigation) {
      emit(state.copyWith(recordingLockedForNavigation: false));
    }

    final prefs = _readSharedPreferences();

    final savedMode = VideoRecorderMode.fromName(
      prefs.getString(VideoRecorderMode.persistenceKey),
    );
    if (!event.fromEditor && savedMode != state.recorderMode) {
      _applyRecorderMode(emit, savedMode, keepAutosavedDraft: true);
    }

    final savedLensString = prefs.getString(_kLastUsedCameraLensKey);
    final initialLens = savedLensString != null
        ? DivineCameraLens.fromNativeString(savedLensString)
        : DivineCameraLens.back;

    Log.info(
      '📹 Initializing video recorder with quality: '
      '${event.videoQuality.value}, lens: ${initialLens.displayName}',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );

    try {
      await _cameraService.initialize(
        videoQuality: event.videoQuality,
        initialLens: initialLens,
        enableAutoLensSwitch: true,
      );
    } catch (e) {
      Log.error(
        '📹 Camera service initialization threw exception: $e',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      emit(
        state.copyWith(
          initializationErrorMessage: 'Camera initialization failed: $e',
        ),
      );
      return;
    }

    if (!_cameraService.isInitialized) {
      final error =
          _cameraService.initializationError ?? 'Camera initialization failed';
      Log.warning(
        '⚠️ Camera failed to initialize: $error',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      emit(state.copyWith(initializationErrorMessage: error));
      return;
    }

    final clips = _readClipManager().clips;
    _emitCameraSync(
      emit,
      aspectRatio: clips.isNotEmpty ? clips.first.targetAspectRatio : null,
    );

    await _restoreStabilizationModePreference(emit);

    await _setupRemoteRecordControl();

    Log.info(
      '✅ Video recorder initialized successfully',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );
  }

  Future<void> _onAppLifecycleChanged(
    VideoRecorderAppLifecycleChanged event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    await _cameraService.handleAppLifecycleState(event.state);
  }

  Future<void> _onRemoteRecordPaused(
    VideoRecorderRemoteRecordPaused event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    if (_remoteRecordControlEnabled) {
      await _cameraService.setRemoteRecordControlEnabled(enabled: false);
      Log.debug(
        '🎮 Remote record control paused (for audio playback)',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
    }
  }

  Future<void> _onRemoteRecordResumed(
    VideoRecorderRemoteRecordResumed event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    if (_remoteRecordControlEnabled) {
      await _cameraService.setRemoteRecordControlEnabled(enabled: true);
      Log.debug(
        '🎮 Remote record control resumed',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );

      if (_remoteRecordPausedForSound) {
        await _cameraService.setVolumeKeysEnabled(enabled: false);
        Log.debug(
          '🎮 Volume keys re-disabled (sound is selected)',
          name: 'VideoRecorderBloc',
          category: LogCategory.video,
        );
      }
    }
  }

  Future<void> _onFlashToggled(
    VideoRecorderFlashToggled event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    final newMode = switch (state.flashMode) {
      DivineFlashMode.off => DivineFlashMode.torch,
      DivineFlashMode.torch => DivineFlashMode.auto,
      DivineFlashMode.auto => DivineFlashMode.off,
    };
    final success = await _cameraService.setFlashMode(newMode);
    if (!success) {
      Log.warning(
        '⚠️ Failed to toggle flash mode',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      return;
    }
    emit(state.copyWith(flashMode: newMode));
    Log.debug(
      '🔦 Flash mode changed to: ${newMode.name}',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );
  }

  void _onAspectRatioToggled(
    VideoRecorderAspectRatioToggled event,
    Emitter<VideoRecorderBlocState> emit,
  ) {
    final newRatio = state.aspectRatio == model.AspectRatio.square
        ? model.AspectRatio.vertical
        : model.AspectRatio.square;
    Log.debug(
      '📱 Aspect ratio changed to: ${newRatio.name}',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );
    emit(state.copyWith(aspectRatio: newRatio));
  }

  void _onAspectRatioSet(
    VideoRecorderAspectRatioSet event,
    Emitter<VideoRecorderBlocState> emit,
  ) {
    emit(state.copyWith(aspectRatio: event.ratio));
  }

  Future<void> _onCameraSwitched(
    VideoRecorderCameraSwitched event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    final success = await _cameraService.switchCamera();

    if (!success) {
      Log.warning(
        '⚠️ Camera switch failed - no available cameras to switch',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      return;
    }

    await _saveCurrentLensPreference();

    Log.info(
      '🔄 Camera switched successfully - zoom reset to 1.0x',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );

    emit(state.copyWith(zoomLevel: 1, baseZoomLevel: 1));
    _emitCameraSync(emit);
  }

  Future<void> _onStabilizationModeSet(
    VideoRecorderStabilizationModeSet event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    if (state.isRecording) return;
    if (event.mode == state.videoStabilizationMode) return;
    final success = await _cameraService.setVideoStabilizationMode(event.mode);
    if (!success) {
      Log.warning(
        '⚠️ Failed to set stabilization mode to ${event.mode.name}',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      return;
    }
    emit(state.copyWith(videoStabilizationMode: event.mode));
    await _saveStabilizationModePreference(event.mode);
    Log.debug(
      '🎯 Stabilization mode changed to: ${event.mode.name}',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );
  }

  Future<void> _onLensSet(
    VideoRecorderLensSet event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    final success = await _cameraService.setLens(event.lens);
    if (!success) {
      Log.warning(
        '⚠️ Failed to set lens to ${event.lens.displayName}',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      return;
    }

    await _saveCurrentLensPreference();

    Log.info(
      '🔄 Lens switched to ${event.lens.displayName} - zoom reset to 1.0x',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );

    emit(state.copyWith(zoomLevel: 1, baseZoomLevel: 1));
    _emitCameraSync(emit);
  }

  Future<void> _onZoomLevelSet(
    VideoRecorderZoomLevelSet event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    if (event.value > _cameraService.maxZoomLevel ||
        event.value < _cameraService.minZoomLevel) {
      Log.debug(
        '⚠️ Zoom level ${event.value} out of bounds '
        '(${_cameraService.minZoomLevel}-${_cameraService.maxZoomLevel})',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      return;
    }

    final success = await _cameraService.setZoomLevel(event.value);
    if (!success) {
      Log.warning(
        '⚠️ Failed to set zoom level to ${event.value}',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      return;
    }
    emit(state.copyWith(zoomLevel: event.value, showZoomIndicator: true));
    _armZoomIndicatorHideTimer();
  }

  Future<void> _onFocusPointSet(
    VideoRecorderFocusPointSet event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    final success = await _cameraService.setFocusPoint(event.value);
    if (!success) {
      Log.warning(
        '⚠️ Failed to set focus point at '
        '(${event.value.dx.toStringAsFixed(2)}, '
        '${event.value.dy.toStringAsFixed(2)})',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      return;
    }

    _focusPointTimer?.cancel();
    emit(state.copyWith(focusPoint: event.value));

    _focusPointTimer = Timer(const Duration(milliseconds: 800), () {
      if (isClosed) return;
      add(const _VideoRecorderFocusPointTimerFired());
    });
  }

  void _onFocusPointTimerFired(
    _VideoRecorderFocusPointTimerFired event,
    Emitter<VideoRecorderBlocState> emit,
  ) {
    _focusPointTimer = null;
    emit(state.copyWith(focusPoint: Offset.zero));
  }

  Future<void> _onExposurePointSet(
    VideoRecorderExposurePointSet event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    final success = await _cameraService.setExposurePoint(event.value);
    if (!success) {
      Log.warning(
        '⚠️ Failed to set exposure point at '
        '(${event.value.dx.toStringAsFixed(2)}, '
        '${event.value.dy.toStringAsFixed(2)})',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
    }
  }

  Future<void> _onRecordingToggleRequested(
    VideoRecorderRecordingToggleRequested event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    if (_cameraService.isSwitchingCamera) {
      Log.debug(
        '🎮 toggleRecording ignored - camera switch in progress',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      return;
    }

    if (state.recordingLockedForNavigation) {
      Log.debug(
        '🎮 toggleRecording ignored - recording locked for navigation',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      return;
    }

    switch (state.recordingState) {
      case VideoRecorderState.idle:
        add(const VideoRecorderRecordingStartRequested());
      case VideoRecorderState.error:
      case VideoRecorderState.recording:
        add(const VideoRecorderRecordingStopRequested());
    }
  }

  Future<void> _onRecordingStartRequested(
    VideoRecorderRecordingStartRequested event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    final clipManager = _readClipManager();
    final remainingDuration = clipManager.remainingDuration;

    if (state.recordingLockedForNavigation ||
        !_cameraService.canRecord ||
        state.isRecording ||
        state.isStartingRecording ||
        state.isStoppingRecording ||
        (remainingDuration < const Duration(milliseconds: 30) &&
            state.recorderMode.hasRecordingLimit)) {
      return;
    }

    emit(
      state.copyWith(
        isStartingRecording: true,
        baseZoomLevel: state.zoomLevel,
      ),
    );
    unawaited(HapticService.recordingFeedback());

    final shouldRunCountdown =
        state.recorderMode.supportsCountdownTimer &&
        state.timerDuration != TimerDuration.off;
    if (shouldRunCountdown) {
      final seconds = state.timerDuration.duration.inSeconds;
      Log.info(
        '⏱️  Starting ${seconds}s countdown before recording',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );

      _countdownSoundService ??= _countdownSoundServiceFactory();
      try {
        await _countdownSoundService!.preload();
      } catch (e) {
        Log.warning(
          '⚠️ Failed to preload countdown sounds: $e',
          name: 'VideoRecorderBloc',
          category: LogCategory.video,
        );
      }

      await _cameraService.setVolumeKeysEnabled(enabled: false);

      emit(state.copyWith(recordingState: VideoRecorderState.recording));

      for (var i = seconds; i > 0 && !isClosed; i--) {
        if (isClosed) break;
        emit(state.copyWith(countdownValue: i));

        unawaited(_countdownSoundService!.playShortBeep());
        final delay = i > 1
            ? const Duration(seconds: 1)
            : const Duration(seconds: 1) -
                  CountdownSoundService.longBeepDuration -
                  CountdownSoundService.postPlaybackBuffer;
        await Future<void>.delayed(delay);
      }

      if (isClosed) {
        emit(
          state.copyWith(
            isStartingRecording: false,
            recordingState: VideoRecorderState.idle,
          ),
        );
        await _cameraService.setVolumeKeysEnabled(enabled: true);
        return;
      }

      emit(state.copyWith(countdownValue: 0));
      unawaited(HapticService.recordingFeedback());

      await _countdownSoundService!.playLongBeepAndWait();

      if (!_remoteRecordPausedForSound) {
        await _cameraService.setVolumeKeysEnabled(enabled: true);
      }
    }

    if (isClosed) {
      emit(state.copyWith(isStartingRecording: false));
      return;
    }

    if (state.recordingLockedForNavigation) {
      // Navigation released (or is releasing) the camera before the native
      // start ran — abort to idle instead of recording on a camera that is
      // about to be torn down.
      emit(
        state.copyWith(
          isStartingRecording: false,
          pendingStopAfterStart: false,
          recordingState: VideoRecorderState.idle,
        ),
      );
      return;
    }

    await _prepareSoundForPlayback();

    emit(state.copyWith(recordingState: VideoRecorderState.recording));

    Log.info(
      '🎥 Starting recording - aspect ratio: ${state.aspectRatio.name}',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );

    unawaited(_playSoundPlayback());
    final success = await _cameraService.startRecording(
      maxDuration: state.recorderMode.hasRecordingLimit
          ? remainingDuration
          : null,
    );

    if (state.recordingLockedForNavigation) {
      // The camera was released for navigation while the native start was in
      // flight. Don't latch a recording the user can never stop.
      await _abortInFlightStartForLock(emit, sessionStarted: success);
      return;
    }

    if (success) {
      Log.info(
        '✅ Recording truly started',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      await WakelockPlus.enable();
      if (state.recordingLockedForNavigation) {
        // Navigation locked during the wakelock-enable await, after the native
        // session started. Abort with the same teardown as the in-flight guard
        // above rather than arm a clip manager (60fps timer + stopwatch) that
        // nothing can stop.
        await _abortInFlightStartForLock(emit, sessionStarted: true);
        return;
      }
      clipManager.startRecording();
      if (state.pendingStopAfterStart) {
        // A stop was requested while the native start was still in-flight
        // (brief press in hold-to-record mode).  Dispatch a proper stop now
        // that the camera is actually recording so the clip is finalized.
        Log.info(
          '⏹️  Dispatching pending stop after recording start (brief press)',
          name: 'VideoRecorderBloc',
          category: LogCategory.video,
        );
        emit(
          state.copyWith(
            isStartingRecording: false,
            pendingStopAfterStart: false,
          ),
        );
        add(const VideoRecorderRecordingStopRequested());
      } else {
        emit(state.copyWith(isStartingRecording: false));
      }
    } else {
      Log.warning(
        '⚠️ Recording failed to start or was stopped early',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      emit(
        state.copyWith(
          isStartingRecording: false,
          pendingStopAfterStart: false,
          recordingState: VideoRecorderState.idle,
        ),
      );
    }
  }

  Future<void> _onRecordingStopRequested(
    VideoRecorderRecordingStopRequested event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    if (state.isStoppingRecording) {
      return;
    }

    if (state.isStartingRecording) {
      // Recording is still starting (isStartingRecording=true).  The native
      // camera hasn't begun capturing yet, so calling stopRecording() here is
      // a no-op that races with startRecording() and can leave the BLoC stuck
      // in the recording state.  Instead, set the pendingStopAfterStart flag
      // and let _onRecordingStartRequested dispatch a proper stop once the
      // native start completes.
      Log.info(
        '⏳ Stop requested during startup - flagging pendingStopAfterStart '
        '(startRecording will dispatch stop after native start)',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      emit(state.copyWith(pendingStopAfterStart: true));
      return;
    }

    if (!state.isRecording && event.result == null) return;

    Log.info(
      '⏹️  Stopping recording and processing clip...',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );
    emit(state.copyWith(isStoppingRecording: true));

    unawaited(HapticService.recordingFeedback());

    final EditorVideo? videoResult;
    final ClipManagerNotifier clipManager;
    final Duration remainingDuration;
    try {
      await _stopSoundPlayback();
      videoResult = event.result ?? await _cameraService.stopRecording();
      // Best-effort: a wakelock teardown failure must not abort the stop and
      // discard an already-captured clip (videoResult is assigned above), so
      // it is swallowed rather than thrown into the recovery catch.
      await _disableWakelockSafely();
      clipManager = _readClipManager()..stopRecording();
      remainingDuration = clipManager.remainingDuration;
    } catch (e, stackTrace) {
      // Defense-in-depth recovery. Neither production CameraService throws
      // from stopRecording() (both catch internally and return null),
      // _stopSoundPlayback() swallows its own errors, and the wakelock
      // teardown is guarded above — so this is only reached if that
      // camera/audio/clip-manager contract is violated. If it ever is,
      // anything thrown between setting isStoppingRecording=true and clearing
      // it below would strand the recorder: the flag stays true and every
      // future stop bails at the top of this handler, so the recording could
      // never be stopped again. Run best-effort cleanup so the user can
      // recover.
      Log.error(
        '⚠️ Failed to stop recording cleanly - resetting recorder state',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
      addError(e, stackTrace);
      // stopRecording() cancels the periodic 60fps duration timer and stops
      // the stopwatch (resetRecording alone would leave that timer running).
      _readClipManager()
        ..stopRecording()
        ..resetRecording();
      await _disableWakelockSafely();
      emit(
        state.copyWith(
          recordingState: VideoRecorderState.idle,
          isStoppingRecording: false,
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        recordingState: VideoRecorderState.idle,
        isStoppingRecording: false,
      ),
    );
    if (videoResult == null) {
      Log.warning(
        '⚠️ Recording stopped but no video file returned from '
        'camera service',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      clipManager.resetRecording();
      return;
    }

    final clip = clipManager.addClip(
      video: videoResult,
      originalAspectRatio: _cameraService.cameraAspectRatio,
      targetAspectRatio: state.aspectRatio,
      lensMetadata: _cameraService.currentLensMetadata,
      limitClipDuration: state.recorderMode.hasRecordingLimit,
    );
    unawaited(
      clipManager.saveClipToLibrary(clip).then((saved) {
        if (!saved) {
          Log.warning(
            '⚠️ Initial clip save to library failed for ${clip.id}',
            name: 'VideoRecorderBloc',
            category: LogCategory.video,
          );
        }
      }),
    );

    Log.debug(
      '📷 Lens metadata: ${_cameraService.currentLensMetadata?.toMap()}',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );

    Log.info(
      '✅ Clip added successfully - ID: ${clip.id}',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );

    // Clip post-processing — real duration, thumbnail, ghost frame and the
    // metadata-enriched library save — is deliberately detached (not awaited).
    // This handler runs in the `sequential()` stop bucket, so awaiting the
    // post-processing would serialize it ahead of the *next* stop request: a
    // slow library save or metadata pass (observed in the field taking ~100s)
    // would leave the user unable to stop their next recording until it
    // finished. The work mutates the clip in place on the clip manager (which
    // the UI observes) and re-saves it, so it is safe to run detached. The
    // bare clip was already persisted by the unawaited save above.
    unawaited(
      _enrichAndSaveClip(
        videoResult: videoResult,
        clip: clip,
        clipManager: clipManager,
        remainingDuration: remainingDuration,
      ).catchError((Object error, StackTrace stackTrace) {
        // Detached work must not escape as an unhandled async error. The bare
        // clip is already saved, so a failure here only loses the enriched
        // metadata, not the recording.
        Log.error(
          '⚠️ Clip post-processing failed for ${clip.id}',
          name: 'VideoRecorderBloc',
          category: LogCategory.video,
          error: error,
          stackTrace: stackTrace,
        );
      }),
    );
  }

  /// Enriches a freshly recorded [clip] with its real duration, thumbnail and
  /// ghost frame, then re-saves the enriched clip to the library.
  ///
  /// Runs detached (fire-and-forget) from [_onRecordingStopRequested] so the
  /// `sequential()` stop handler returns immediately and never blocks a
  /// following stop request behind this potentially slow work.
  Future<void> _enrichAndSaveClip({
    required EditorVideo videoResult,
    required DivineVideoClip clip,
    required ClipManagerNotifier clipManager,
    required Duration remainingDuration,
  }) async {
    final videoPath = await videoResult.safeFilePath();
    final workCopyPath = '$videoPath.work.mp4';
    await File(videoPath).copy(workCopyPath);

    try {
      final metadata = await ProVideoEditor.instance.getMetadata(
        EditorVideo.file(File(workCopyPath)),
      );
      clipManager.updateClipDuration(clip.id, metadata.duration);
      Log.debug(
        '📊 Video duration: ${metadata.duration.inMilliseconds}ms',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );

      if (clipManager.clips.length == 1) {
        if (clip.processingCompleter != null) {
          unawaited(
            clip.processingCompleter!.future.then((_) {
              DivineVideoPlayerController.preload([VideoClip.file(videoPath)]);
            }),
          );
        } else {
          unawaited(
            DivineVideoPlayerController.preload([VideoClip.file(videoPath)]),
          );
        }
      }

      final effectiveDuration = remainingDuration < metadata.duration
          ? remainingDuration
          : metadata.duration;
      final halfDuration = effectiveDuration ~/ 2;
      final targetTimestamp =
          halfDuration < VideoEditorConstants.defaultThumbnailExtractTime
          ? halfDuration
          : VideoEditorConstants.defaultThumbnailExtractTime;

      final thumbnailResult = await VideoThumbnailService.extractThumbnail(
        videoPath: workCopyPath,
        targetTimestamp: targetTimestamp,
      );

      if (thumbnailResult != null) {
        clipManager.updateThumbnail(
          clipId: clip.id,
          thumbnailPath: thumbnailResult.path,
          thumbnailTimestamp: thumbnailResult.timestamp,
        );
        Log.debug(
          '🖼️  Thumbnail generated: ${thumbnailResult.path}',
          name: 'VideoRecorderBloc',
          category: LogCategory.video,
        );
      } else {
        Log.warning(
          '⚠️ Thumbnail generation failed',
          name: 'VideoRecorderBloc',
          category: LogCategory.video,
        );
      }

      final ghostFramePath = await VideoThumbnailService.extractLastFrame(
        videoPath: workCopyPath,
        videoDuration: metadata.duration,
      );

      if (ghostFramePath != null) {
        clipManager.updateGhostFrame(
          clipId: clip.id,
          ghostFramePath: ghostFramePath,
        );
        Log.debug(
          '👻 Ghost frame generated: $ghostFramePath',
          name: 'VideoRecorderBloc',
          category: LogCategory.video,
        );
      } else {
        Log.warning(
          '⚠️ Ghost frame generation failed',
          name: 'VideoRecorderBloc',
          category: LogCategory.video,
        );
      }

      // firstWhereOrNull, not firstWhere: the clip can be removed mid-
      // enrichment (delete-last-clip undo, capture↔classic switch) while this
      // detached work runs. A swallowed StateError would skip the work-copy
      // cleanup below; here the cleanup always runs in the finally.
      final updatedClip = clipManager.clips.firstWhereOrNull(
        (c) => c.id == clip.id,
      );
      if (updatedClip == null) {
        Log.warning(
          '⚠️ Clip ${clip.id} removed before metadata save — skipping '
          'enriched library save',
          name: 'VideoRecorderBloc',
          category: LogCategory.video,
        );
        return;
      }
      final saved = await clipManager.saveClipToLibrary(updatedClip);
      if (!saved) {
        Log.warning(
          '⚠️ Metadata-enriched clip save to library failed for ${clip.id}',
          name: 'VideoRecorderBloc',
          category: LogCategory.video,
        );
      }
    } finally {
      try {
        await File(workCopyPath).delete();
      } catch (_) {}
    }
  }

  /// Aborts a native recording session the navigation lock landed on while a
  /// start was still in flight: best-effort stops + discards the just-started
  /// session (when [sessionStarted]) and returns to idle. Shared by the two
  /// lock guards in [_onRecordingStartRequested] — before the native start and
  /// after the wakelock-enable await — so neither latches a recording the user
  /// can never stop.
  Future<void> _abortInFlightStartForLock(
    Emitter<VideoRecorderBlocState> emit, {
    required bool sessionStarted,
  }) async {
    if (sessionStarted) {
      await _discardAbortedRecording(await _cameraService.stopRecording());
    }
    emit(
      state.copyWith(
        isStartingRecording: false,
        pendingStopAfterStart: false,
        recordingState: VideoRecorderState.idle,
      ),
    );
  }

  /// Best-effort deletes the orphaned file from a recording aborted by the
  /// navigation lock. Such a recording is never added to the library or shown
  /// to the user, so without this its file would leak on disk.
  Future<void> _discardAbortedRecording(EditorVideo? video) async {
    if (video == null) return;
    try {
      await File(await video.safeFilePath()).delete();
    } catch (error) {
      Log.debug(
        '⚠️ Failed to delete aborted recording file: $error',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
    }
  }

  void _onLongPressZoomStarted(
    VideoRecorderLongPressZoomStarted event,
    Emitter<VideoRecorderBlocState> emit,
  ) {
    // Anchor the drag-zoom to the zoom level in effect when the gesture
    // begins. Without this, a long-press on a recording started elsewhere
    // (tap, volume key, BLE remote) — or one resumed after a pinch changed the
    // zoom — would measure from a stale base and snap on the first move.
    emit(state.copyWith(baseZoomLevel: state.zoomLevel));
  }

  Future<void> _onZoomedByLongPress(
    VideoRecorderZoomedByLongPress event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    const maxDragDistance = 240.0;
    // Up is negative dy, so a positive [verticalDrag] is a drag up (zoom in)
    // and a negative one is a drag down (zoom out).
    final verticalDrag = (-event.offsetFromOrigin.dy).clamp(
      -maxDragDistance,
      maxDragDistance,
    );

    // Exponential drag→zoom mapping so perceived sensitivity is uniform in
    // both directions: an equal drag step always multiplies zoom by the same
    // factor, so 1×→2× travels the same distance as 2×→4×. Dragging up
    // approaches the camera max; dragging down approaches the camera min
    // (e.g. an ultra-wide 0.6×). The previous linear, upward-only mapping
    // packed the whole absolute range into a short upward drag — jumpy at the
    // most-used low end — and could never reach sub-1× zoom. Mirrors the
    // multiplicative pinch mapping in _onScaleUpdated.
    final baseZoom = state.baseZoomLevel <= 0 ? 1.0 : state.baseZoomLevel;
    final targetBound = verticalDrag >= 0
        ? _cameraService.maxZoomLevel
        : _cameraService.minZoomLevel;
    final progress = verticalDrag.abs() / maxDragDistance;
    final zoomLevel = (baseZoom * math.pow(targetBound / baseZoom, progress))
        .clamp(_cameraService.minZoomLevel, _cameraService.maxZoomLevel);

    // Re-uses the same camera+state path as ZoomLevelSet.
    add(VideoRecorderZoomLevelSet(zoomLevel));
  }

  void _onScaleStarted(
    VideoRecorderScaleStarted event,
    Emitter<VideoRecorderBlocState> emit,
  ) {
    // snapTime is intentionally not reset here: copyWith's null-coalescing
    // semantics make explicit-null a no-op anyway, and the snap-update
    // handler guards every snapTime read with snappedTo1x — which we
    // just cleared. The next snap engagement overwrites snapTime fresh.
    emit(
      state.copyWith(
        baseZoomLevel: state.zoomLevel,
        snappedTo1x: false,
        lastRawZoom: state.zoomLevel,
        showZoomIndicator: true,
      ),
    );
    _armZoomIndicatorHideTimer();
  }

  Future<void> _onScaleUpdated(
    VideoRecorderScaleUpdated event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    // Multiplicative mapping: the cumulative pinch scale multiplies the zoom
    // captured at gesture start, so the perceived sensitivity is uniform
    // across the whole range (1×→2× feels like 2×→4×). The previous
    // range-proportional mapping made the gain depend on the starting zoom —
    // fast far from a bound, sluggish near max — and differed between
    // zoom-in and zoom-out.
    final newZoom = state.baseZoomLevel * event.details.scale;

    var clampedZoom = newZoom.clamp(
      _cameraService.minZoomLevel,
      _cameraService.maxZoomLevel,
    );

    final hasUltraWideRange =
        _cameraService.minZoomLevel < 1.0 && _cameraService.maxZoomLevel > 1.0;

    if (hasUltraWideRange && !state.snappedTo1x) {
      const gravityRadius = 0.15;
      final distFrom1 = (clampedZoom - 1.0).abs();
      if (distFrom1 < gravityRadius) {
        final t = distFrom1 / gravityRadius;
        final damped = t * t;
        final direction = clampedZoom >= 1.0 ? 1.0 : -1.0;
        clampedZoom = 1.0 + direction * gravityRadius * damped;
      }
    }

    const snapHoldMs = 350;
    final crossedFrom = state.lastRawZoom;
    var snapped = state.snappedTo1x;
    DateTime? snapTime = state.snapTime;

    if (hasUltraWideRange) {
      if (!snapped &&
          (crossedFrom > 1.02 || crossedFrom < 0.98) &&
          (clampedZoom - 1.0).abs() <= 0.02) {
        snapped = true;
        snapTime = DateTime.now();
        clampedZoom = 1.0;
        // Confirm the 1× detent engagement with a light tick.
        unawaited(HapticService.snapFeedback());
      }

      if (snapped) {
        final elapsed = DateTime.now().difference(snapTime!).inMilliseconds;
        if (elapsed < snapHoldMs) {
          clampedZoom = 1.0;
        } else {
          snapped = false;
        }
      }
    }

    emit(
      state.copyWith(
        lastRawZoom: clampedZoom,
        snappedTo1x: snapped,
        snapTime: snapTime,
        showZoomIndicator: true,
      ),
    );
    _armZoomIndicatorHideTimer();

    if ((state.zoomLevel - clampedZoom).abs() > 0.01) {
      add(VideoRecorderZoomLevelSet(clampedZoom));
    }
  }

  /// (Re)starts the zoom-ruler auto-hide countdown. Called on every pinch
  /// activity so the ruler stays up while the user is zooming and fades a
  /// short while after the gesture settles.
  void _armZoomIndicatorHideTimer() {
    _zoomIndicatorTimer?.cancel();
    _zoomIndicatorTimer = Timer(_zoomIndicatorHideDelay, () {
      if (isClosed) return;
      add(const _VideoRecorderZoomIndicatorTimerFired());
    });
  }

  void _onZoomIndicatorTimerFired(
    _VideoRecorderZoomIndicatorTimerFired event,
    Emitter<VideoRecorderBlocState> emit,
  ) {
    _zoomIndicatorTimer = null;
    emit(state.copyWith(showZoomIndicator: false));
  }

  void _onRecordingLockedForNavigation(
    VideoRecorderRecordingLockedForNavigation event,
    Emitter<VideoRecorderBlocState> emit,
  ) {
    _lockRecordingForNavigation(emit);
  }

  Future<void> _onCameraPausedForNavigation(
    VideoRecorderCameraPausedForNavigation event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    Log.info(
      '📹 Camera paused for navigation - disposing',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );
    // Idempotent with VideoRecorderRecordingLockedForNavigation (which the View
    // dispatches first, before the push transition). Re-asserting here keeps
    // the recorder safe even if only the pause event is dispatched.
    _lockRecordingForNavigation(emit);
    await _cameraService.dispose();
  }

  /// Locks recording for a navigation push: sets the lock, detaches the remote
  /// (volume / Bluetooth) trigger, and resets any in-flight / active recording
  /// to idle so a trigger that raced the navigation can't leave a recording the
  /// user can never stop. Runs synchronously while the camera is still live —
  /// the dispose (if any) happens after — so it never races the native start.
  /// The lock is cleared on the next [VideoRecorderInitializeRequested].
  void _lockRecordingForNavigation(Emitter<VideoRecorderBlocState> emit) {
    _cameraService.onRemoteRecordTrigger = null;
    if (state.isRecording || state.isStartingRecording) {
      _readClipManager()
        ..stopRecording()
        ..resetRecording();
      emit(
        state.copyWith(
          recordingLockedForNavigation: true,
          recordingState: VideoRecorderState.idle,
          isStartingRecording: false,
          isStoppingRecording: false,
          pendingStopAfterStart: false,
        ),
      );
    } else {
      emit(state.copyWith(recordingLockedForNavigation: true));
    }
  }

  void _onRecorderModeSet(
    VideoRecorderRecorderModeSet event,
    Emitter<VideoRecorderBlocState> emit,
  ) {
    _applyRecorderMode(
      emit,
      event.mode,
      keepAutosavedDraft: event.keepAutosavedDraft,
    );
  }

  void _applyRecorderMode(
    Emitter<VideoRecorderBlocState> emit,
    VideoRecorderMode mode, {
    required bool keepAutosavedDraft,
  }) {
    final previousMode = state.recorderMode;
    emit(
      state.copyWith(
        recorderMode: mode,
        aspectRatio: mode.defaultAspectRatio,
        showGridLines: mode.supportGridLines,
        timerDuration: mode.supportsCountdownTimer
            ? state.timerDuration
            : TimerDuration.off,
        countdownValue: 0,
      ),
    );
    final prefs = _readSharedPreferences();
    prefs.setString(VideoRecorderMode.persistenceKey, mode.name);

    final touchesRecordingState =
        mode != VideoRecorderMode.upload &&
        previousMode != VideoRecorderMode.upload;
    if (touchesRecordingState) {
      _readClipManager().clearAll(keepAutosavedDraft: keepAutosavedDraft);
      _readVideoEditor().reset(keepAutosavedDraft: keepAutosavedDraft);
    }

    Log.debug(
      '🎬 Recorder mode changed to: ${mode.name}',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );
  }

  void _onTimerCycled(
    VideoRecorderTimerCycled event,
    Emitter<VideoRecorderBlocState> emit,
  ) {
    if (!state.recorderMode.supportsCountdownTimer) return;

    final newTimer = switch (state.timerDuration) {
      TimerDuration.off => TimerDuration.three,
      TimerDuration.three => TimerDuration.ten,
      TimerDuration.ten => TimerDuration.off,
    };
    emit(state.copyWith(timerDuration: newTimer));
    Log.debug(
      '⏱️  Timer duration changed to: ${newTimer.name}',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );
  }

  void _onResetRequested(
    VideoRecorderResetRequested event,
    Emitter<VideoRecorderBlocState> emit,
  ) {
    Log.debug(
      '🔄 Resetting video recorder state',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );
    emit(const VideoRecorderBlocState());
  }

  void _onShowLastClipOverlayToggled(
    VideoRecorderShowLastClipOverlayToggled event,
    Emitter<VideoRecorderBlocState> emit,
  ) {
    emit(state.copyWith(showLastClipOverlay: !state.showLastClipOverlay));
  }

  void _onGridLinesToggled(
    VideoRecorderGridLinesToggled event,
    Emitter<VideoRecorderBlocState> emit,
  ) {
    emit(state.copyWith(showGridLines: !state.showGridLines));
  }

  void _onCameraStateChanged(
    _VideoRecorderCameraStateChanged event,
    Emitter<VideoRecorderBlocState> emit,
  ) {
    Log.debug(
      '🔄 Updating video recorder state',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );
    _emitCameraSync(emit, cameraRebuildCount: event.cameraRebuildCount);
  }

  /// Re-synchronizes the camera-derived fields in [state] with the
  /// current [CameraService] values. Matches the legacy
  /// `VideoRecorderNotifier.updateState` semantics: replaces sensor /
  /// capability fields wholesale and resets flash to `off`.
  void _emitCameraSync(
    Emitter<VideoRecorderBlocState> emit, {
    int? cameraRebuildCount,
    model.AspectRatio? aspectRatio,
  }) {
    emit(
      VideoRecorderBlocState(
        cameraRebuildCount: cameraRebuildCount ?? state.cameraRebuildCount,
        aspectRatio: aspectRatio ?? state.aspectRatio,
        flashMode: DivineFlashMode.off,
        minZoomLevel: _cameraService.minZoomLevel,
        maxZoomLevel: _cameraService.maxZoomLevel,
        cameraSensorAspectRatio: _cameraService.cameraAspectRatio,
        canRecord: _cameraService.canRecord,
        isCameraInitialized: _cameraService.isInitialized,
        hasFlash: _cameraService.hasFlash,
        canSwitchCamera: _cameraService.canSwitchCamera,
        videoStabilizationMode: _cameraService.videoStabilizationMode,
        availableVideoStabilizationModes:
            _cameraService.availableVideoStabilizationModes,
        isVideoStabilizationSupported:
            _cameraService.isVideoStabilizationSupported,
        showLastClipOverlay: state.showLastClipOverlay,
        recorderMode: state.recorderMode,
        showGridLines: state.showGridLines,
      ),
    );
  }

  void _onRemoteRecordTriggered(
    _VideoRecorderRemoteRecordTriggered event,
    Emitter<VideoRecorderBlocState> emit,
  ) {
    if (_remoteRecordPausedForSound) {
      Log.debug(
        '🎮 Remote record trigger ignored - sound is selected',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      return;
    }
    Log.info(
      '🎮 Remote record trigger received! Dispatching toggleRecording…',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );
    add(const VideoRecorderRecordingToggleRequested());
  }

  Future<void> _onAutoStopped(
    _VideoRecorderAutoStopped event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    add(VideoRecorderRecordingStopRequested(result: event.video));
  }

  // === Private helpers ===

  Future<void> _setupRemoteRecordControl() async {
    _cameraService.onRemoteRecordTrigger = () {
      if (isClosed) return;
      add(const _VideoRecorderRemoteRecordTriggered());
    };

    final success = await _cameraService.setRemoteRecordControlEnabled(
      enabled: true,
    );
    _remoteRecordControlEnabled = success;

    if (success) {
      Log.info(
        '🎮 Remote record control enabled (volume buttons / Bluetooth)',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );

      if (_remoteRecordPausedForSound) {
        await _cameraService.setVolumeKeysEnabled(enabled: false);
        Log.debug(
          '🎮 Volume keys released (sound already selected)',
          name: 'VideoRecorderBloc',
          category: LogCategory.video,
        );
      }
    } else {
      Log.warning(
        '⚠️ Failed to enable remote record control',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
    }
  }

  Future<void> _disableRemoteRecordControl() async {
    if (_remoteRecordControlEnabled) {
      await _cameraService.setRemoteRecordControlEnabled(enabled: false);
      _cameraService.onRemoteRecordTrigger = null;
      _remoteRecordControlEnabled = false;
      Log.debug(
        '🎮 Remote record control disabled',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
    }
  }

  Future<void> _saveCurrentLensPreference() async {
    final lens = _cameraService.currentLens;
    final prefs = _readSharedPreferences();
    await prefs.setString(_kLastUsedCameraLensKey, lens.toNativeString());
    Log.debug(
      '💾 Saved camera lens preference: ${lens.displayName}',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );
  }

  Future<void> _saveStabilizationModePreference(
    DivineVideoStabilizationMode mode,
  ) async {
    final prefs = _readSharedPreferences();
    await prefs.setString(
      _kLastUsedStabilizationModeKey,
      mode.toNativeString(),
    );
    Log.debug(
      '💾 Saved stabilization preference: ${mode.name}',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );
  }

  /// Re-applies the persisted stabilization mode after the camera initializes.
  ///
  /// The native controller is recreated (mode reset to off) on every init, so
  /// the saved preference is restored here. Skipped when the saved mode is off
  /// or unsupported by the active camera.
  Future<void> _restoreStabilizationModePreference(
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    final saved = _readSharedPreferences().getString(
      _kLastUsedStabilizationModeKey,
    );
    if (saved == null) return;
    final mode = DivineVideoStabilizationMode.fromNativeString(saved);
    if (mode == DivineVideoStabilizationMode.off) return;
    if (!state.availableVideoStabilizationModes.contains(mode)) return;

    final success = await _cameraService.setVideoStabilizationMode(mode);
    if (success) {
      emit(state.copyWith(videoStabilizationMode: mode));
      Log.debug(
        '🎯 Restored stabilization mode: ${mode.name}',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
    }
  }

  Future<void> _prepareSoundForPlayback() async {
    final selectedSound = _readVideoEditorState().selectedSound;
    final source = selectedSound?.resolvedSource;
    if (selectedSound == null || source == null) {
      await _audioPlaybackService?.dispose();
      _audioPlaybackService = null;
      return;
    }

    try {
      _audioPlaybackService ??= _audioPlaybackServiceFactory();

      await _audioPlaybackService!.configureForRecording();
      // Imported audio is an on-disk file; loading it via loadAudio would
      // parse the path as a URL and fail with iOS "unsupported URL".
      if (source.kind == model.AudioSourceKind.file) {
        await _audioPlaybackService!.loadAudioFromFile(source.path);
      } else {
        await _audioPlaybackService!.loadAudio(selectedSound.url!);
      }

      final clipManager = _readClipManager();
      final startPosition =
          clipManager.totalDuration + selectedSound.startOffset;
      if (startPosition > Duration.zero) {
        await _audioPlaybackService!.seek(startPosition);
        Log.debug(
          'Seeking sound to position: '
          '${startPosition.inMilliseconds}ms '
          '(clips: ${clipManager.totalDuration.inMilliseconds}ms, '
          'offset: ${selectedSound.startOffset.inMilliseconds}ms)',
          name: 'VideoRecorderBloc',
          category: LogCategory.video,
        );
      }

      Log.info(
        'Sound prepared for playback: '
        '${selectedSound.title ?? selectedSound.id}',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
    } catch (e) {
      Log.warning(
        'Failed to prepare sound for playback: $e',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
    }
  }

  Future<void> _playSoundPlayback() async {
    if (_audioPlaybackService == null) return;

    try {
      await _audioPlaybackService!.play();
      Log.info(
        'Started sound playback during recording',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
    } catch (e) {
      Log.warning(
        'Failed to start sound playback: $e',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
    }
  }

  Future<void> _stopSoundPlayback() async {
    if (_audioPlaybackService == null) return;

    try {
      await _audioPlaybackService!.stop();
      await _audioPlaybackService!.resetAudioSession();
      Log.info(
        'Stopped sound playback',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
    } catch (e) {
      Log.warning(
        'Failed to stop sound playback: $e',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
    }
  }

  /// Releases the wakelock without letting a failure abort the caller.
  ///
  /// Wakelock teardown is best-effort: a failure only means the screen stays
  /// awake. It must never strand the recorder state or discard a captured
  /// clip, so the error is logged and swallowed.
  Future<void> _disableWakelockSafely() async {
    try {
      await WakelockPlus.disable();
    } catch (e) {
      Log.warning(
        'Failed to disable wakelock: $e',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
    }
  }

  @override
  Future<void> close() async {
    Log.debug(
      '🧹 Closing VideoRecorderBloc',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );
    _focusPointTimer?.cancel();
    _focusPointTimer = null;
    _zoomIndicatorTimer?.cancel();
    _zoomIndicatorTimer = null;
    try {
      await _audioPlaybackService?.dispose();
      _audioPlaybackService = null;
    } catch (e) {
      Log.warning(
        '🧹 Audio playback service disposal failed: $e',
        name: 'VideoRecorderBloc',
        category: LogCategory.system,
      );
    }
    try {
      await _countdownSoundService?.dispose();
      _countdownSoundService = null;
    } catch (e) {
      Log.warning(
        '🧹 Countdown sound service disposal failed: $e',
        name: 'VideoRecorderBloc',
        category: LogCategory.system,
      );
    }
    try {
      await _disableRemoteRecordControl();
    } catch (e) {
      Log.warning(
        '🧹 Disable remote record control failed: $e',
        name: 'VideoRecorderBloc',
        category: LogCategory.system,
      );
    }
    try {
      await WakelockPlus.disable();
    } catch (_) {}
    try {
      await _cameraService.dispose();
    } catch (e) {
      Log.warning(
        '🧹 Camera service disposal failed during cleanup: $e',
        name: 'VideoRecorderBloc',
        category: LogCategory.system,
      );
    }
    return super.close();
  }
}
