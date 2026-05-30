// ABOUTME: Bloc that owns the camera-recorder UI state (port of
// ABOUTME: VideoRecorderNotifier, removing concurrency-flag fields and
// ABOUTME: adding sequential() on recording start/stop).

import 'dart:async';
import 'dart:io';

import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:divine_camera/divine_camera.dart'
    show CameraLensMetadata, DivineCameraLens, DivineVideoQuality;
import 'package:divine_video_player/divine_video_player.dart'
    show DivineVideoPlayerController, VideoClip;
import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/constants/video_editor_constants.dart';
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
    on<VideoRecorderZoomedByLongPress>(_onZoomedByLongPress);
    on<VideoRecorderScaleStarted>(_onScaleStarted);
    on<VideoRecorderScaleUpdated>(_onScaleUpdated);
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
  bool _remoteRecordControlEnabled = false;

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
    emit(state.copyWith(zoomLevel: event.value));
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

    if (!_cameraService.canRecord ||
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

    if (state.timerDuration != TimerDuration.off) {
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

    if (success) {
      Log.info(
        '✅ Recording truly started',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      await WakelockPlus.enable();
      clipManager.startRecording();
      emit(state.copyWith(isStartingRecording: false));
    } else {
      Log.warning(
        '⚠️ Recording failed to start or was stopped early',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      emit(
        state.copyWith(
          isStartingRecording: false,
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
      Log.info(
        '⏳ Stop requested during startup - calling native stop '
        '(startRecording will handle state)',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
      unawaited(_cameraService.stopRecording());
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

    await _stopSoundPlayback();

    final videoResult = event.result ?? await _cameraService.stopRecording();

    await WakelockPlus.disable();
    final clipManager = _readClipManager()..stopRecording();
    final remainingDuration = clipManager.remainingDuration;

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

    final videoPath = await videoResult.safeFilePath();
    final workCopyPath = '$videoPath.work.mp4';
    await File(videoPath).copy(workCopyPath);

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

    final updatedClip = clipManager.clips.firstWhere(
      (c) => c.id == clip.id,
    );
    final saved = await clipManager.saveClipToLibrary(updatedClip);
    if (!saved) {
      Log.warning(
        '⚠️ Metadata-enriched clip save to library failed for ${clip.id}',
        name: 'VideoRecorderBloc',
        category: LogCategory.video,
      );
    }
    try {
      await File(workCopyPath).delete();
    } catch (_) {}
  }

  Future<void> _onZoomedByLongPress(
    VideoRecorderZoomedByLongPress event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    const maxDragDistance = 240.0;
    final dragDistance = (-event.offsetFromOrigin.dy).clamp(
      0.0,
      maxDragDistance,
    );

    final availableZoomRange =
        _cameraService.maxZoomLevel - state.baseZoomLevel;
    final zoomLevel =
        state.baseZoomLevel +
        (dragDistance / maxDragDistance) * availableZoomRange;

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
      ),
    );
  }

  Future<void> _onScaleUpdated(
    VideoRecorderScaleUpdated event,
    Emitter<VideoRecorderBlocState> emit,
  ) async {
    final scaleChange = event.details.scale - 1.0;
    final normalizedChange = scaleChange.clamp(-1.0, 2.0);

    final zoomRangeDown = state.baseZoomLevel - _cameraService.minZoomLevel;
    final zoomRangeUp = _cameraService.maxZoomLevel - state.baseZoomLevel;

    final newZoom = normalizedChange >= 0
        ? state.baseZoomLevel + (normalizedChange / 2.0) * zoomRangeUp
        : state.baseZoomLevel + normalizedChange * zoomRangeDown;

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
      ),
    );

    if ((state.zoomLevel - clampedZoom).abs() > 0.01) {
      add(VideoRecorderZoomLevelSet(clampedZoom));
    }
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
    await _cameraService.dispose();
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
        cameraSensorAspectRatio: _cameraService.cameraAspectRatio,
        canRecord: _cameraService.canRecord,
        isCameraInitialized: _cameraService.isInitialized,
        hasFlash: _cameraService.hasFlash,
        canSwitchCamera: _cameraService.canSwitchCamera,
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

  Future<void> _prepareSoundForPlayback() async {
    final selectedSound = _readVideoEditorState().selectedSound;
    if (selectedSound == null || selectedSound.url == null) {
      await _audioPlaybackService?.dispose();
      _audioPlaybackService = null;
      return;
    }

    try {
      _audioPlaybackService ??= _audioPlaybackServiceFactory();

      await _audioPlaybackService!.configureForRecording();
      await _audioPlaybackService!.loadAudio(selectedSound.url!);

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

  @override
  Future<void> close() async {
    Log.debug(
      '🧹 Closing VideoRecorderBloc',
      name: 'VideoRecorderBloc',
      category: LogCategory.video,
    );
    _focusPointTimer?.cancel();
    _focusPointTimer = null;
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
