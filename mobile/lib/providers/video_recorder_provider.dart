// ABOUTME: Riverpod state management for VineRecordingController
// ABOUTME: Provides reactive state updates for recording UI without ChangeNotifier

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/services/haptic_service.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/audio_event.dart';
import 'package:openvine/models/video_recorder/video_recorder_flash_mode.dart';
import 'package:openvine/models/video_recorder/video_recorder_provider_state.dart';
import 'package:openvine/models/video_recorder/video_recorder_timer_duration.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/screens/home_screen_router.dart';
import 'package:divine_camera/divine_camera.dart'
    show DivineCameraLens, DivineVideoQuality;
import 'package:openvine/services/audio_playback_service.dart';
import 'package:openvine/screens/video_editor/video_clip_editor_screen.dart';
import 'package:openvine/services/video_recorder/camera/camera_base_service.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// SharedPreferences key for storing the last used camera lens.
const _kLastUsedCameraLensKey = 'camera_last_used_lens';

/// Notifier that wraps VideoRecorderNotifier and provides reactive updates.
///
/// Manages camera lifecycle, recording state, and UI interactions including:
/// - Camera initialization
/// - Recording start/stop with countdown timer
/// - Focus, exposure, and zoom controls
/// - Flash mode and aspect ratio toggles
/// - Clip creation and thumbnail generation
class VideoRecorderNotifier extends Notifier<VideoRecorderProviderState> {
  /// Creates a video recorder notifier.
  ///
  /// [cameraService] is an optional camera service override for testing.
  VideoRecorderNotifier([CameraService? cameraService])
    : _cameraServiceOverride = cameraService;

  final CameraService? _cameraServiceOverride;
  late final CameraService _cameraService;
  AudioPlaybackService? _audioPlaybackService;
  Timer? _focusPointTimer;

  double _baseZoomLevel = 1;
  bool _isDestroyed = false;

  // Flag to track if startRecording is in progress (waiting for first keyframe)
  bool _isStartingRecording = false;

  // Flag to prevent multiple simultaneous stopRecording calls
  bool _isStoppingRecording = false;

  // Flag to track if remote record control is currently enabled
  bool _remoteRecordControlEnabled = false;

  // Flag to track if remote control is paused due to sound selection
  bool _remoteRecordPausedForSound = false;

  @override
  VideoRecorderProviderState build() {
    _cameraService =
        _cameraServiceOverride ??
        CameraService.create(
          onUpdateState: ({forceCameraRebuild}) {
            // Don't update state if provider is being destroyed
            if (_isDestroyed || !ref.mounted) return;

            updateState(
              cameraRebuildCount: forceCameraRebuild ?? false
                  ? state.cameraRebuildCount + 1
                  : null,
            );
          },
          onAutoStopped: stopRecording,
        );

    // Listen for sound selection changes to pause/resume remote control
    ref.listen<AudioEvent?>(selectedSoundProvider, (previous, next) {
      _handleSoundSelectionChanged(previous, next);
    });

    // Setup cleanup when provider is disposed
    ref.onDispose(() async {
      if (!_isDestroyed) {
        _isDestroyed = true; // Set flag before cleanup
        _focusPointTimer?.cancel();
        try {
          await _audioPlaybackService?.dispose();
          _audioPlaybackService = null;
        } catch (e) {
          Log.warning(
            '🧹 Audio playback service disposal failed: $e',
            name: 'VideoRecorderNotifier',
            category: .system,
          );
        }
        try {
          await _cameraService.dispose();
        } catch (e) {
          // Ignore camera disposal errors during cleanup
          Log.warning(
            '🧹 Camera service disposal failed during cleanup: $e',
            name: 'VideoRecorderNotifier',
            category: .system,
          );
        }
      }
    });

    return const VideoRecorderProviderState();
  }

  /// Initialize camera.
  ///
  /// [videoQuality] specifies the video recording quality (default: FHD/1080p).
  Future<void> initialize({
    BuildContext? context,
    DivineVideoQuality videoQuality = DivineVideoQuality.fhd,
  }) async {
    _isDestroyed = false;

    // Load the last used camera lens from preferences
    final prefs = ref.read(sharedPreferencesProvider);
    final savedLensString = prefs.getString(_kLastUsedCameraLensKey);
    final initialLens = savedLensString != null
        ? DivineCameraLens.fromNativeString(savedLensString)
        : DivineCameraLens.front;

    Log.info(
      '📹 Initializing video recorder with quality: ${videoQuality.value}, '
      'lens: ${initialLens.displayName}',
      name: 'VideoRecorderNotifier',
      category: .video,
    );

    try {
      await _cameraService.initialize(
        videoQuality: videoQuality,
        initialLens: initialLens,
      );
    } catch (e) {
      Log.error(
        '📹 Camera service initialization threw exception: $e',
        name: 'VideoRecorderNotifier',
        category: .video,
      );
      state = state.copyWith(
        initializationErrorMessage: 'Camera initialization failed: $e',
      );
      return;
    }

    // Check if camera initialization failed
    if (!_cameraService.isInitialized) {
      final error =
          _cameraService.initializationError ?? 'Camera initialization failed';
      Log.warning(
        '⚠️ Camera failed to initialize: $error',
        name: 'VideoRecorderNotifier',
        category: .video,
      );
      state = state.copyWith(initializationErrorMessage: error);
      return;
    }

    // If the user has recorded clips in the clip manager, we use this
    // aspect-ratio to prevent mixing different ratios.
    final clips = ref.read(clipManagerProvider).clips;
    updateState(
      aspectRatio: clips.isNotEmpty ? clips.first.targetAspectRatio : null,
    );

    // Enable remote record control if user preference is enabled
    await _setupRemoteRecordControl();

    Log.info(
      '✅ Video recorder initialized successfully',
      name: 'VideoRecorderNotifier',
      category: .video,
    );
  }

  /// Handle app lifecycle changes (pause/resume).
  ///
  /// Pauses camera when app goes to background, resumes when returning.
  Future<void> handleAppLifecycleState(AppLifecycleState appState) async {
    await _cameraService.handleAppLifecycleState(appState);
  }

  /// Clean up resources and dispose camera service.
  ///
  /// Cancels timers and releases camera resources.
  Future<void> destroy() async {
    Log.debug(
      '🧹 Destroying video recorder',
      name: 'VideoRecorderNotifier',
      category: .video,
    );
    _isDestroyed = true;
    _focusPointTimer?.cancel();
    await _audioPlaybackService?.dispose();
    _audioPlaybackService = null;
    await _disableRemoteRecordControl();
    await _cameraService.dispose();
  }

  /// Set up remote record control (volume buttons / Bluetooth accessories).
  ///
  /// Always enabled - allows triggering recording via volume buttons or
  /// Bluetooth accessories.
  Future<void> _setupRemoteRecordControl() async {
    // Set up callback before enabling
    _cameraService.onRemoteRecordTrigger = () {
      Log.info(
        '🎮 Remote record trigger received! Calling toggleRecording...',
        name: 'VideoRecorderNotifier',
        category: .video,
      );
      toggleRecording();
    };

    final success = await _cameraService.setRemoteRecordControlEnabled(
      enabled: true,
    );
    _remoteRecordControlEnabled = success;

    if (success) {
      Log.info(
        '🎮 Remote record control enabled (volume buttons / Bluetooth)',
        name: 'VideoRecorderNotifier',
        category: .video,
      );
    } else {
      Log.warning(
        '⚠️ Failed to enable remote record control',
        name: 'VideoRecorderNotifier',
        category: .video,
      );
    }
  }

  /// Disable remote record control.
  Future<void> _disableRemoteRecordControl() async {
    if (_remoteRecordControlEnabled) {
      await _cameraService.setRemoteRecordControlEnabled(enabled: false);
      _cameraService.onRemoteRecordTrigger = null;
      _remoteRecordControlEnabled = false;
      Log.debug(
        '🎮 Remote record control disabled',
        name: 'VideoRecorderNotifier',
        category: .video,
      );
    }
  }

  /// Handle sound selection changes to enable/disable volume keys.
  ///
  /// When a sound is selected, volume buttons should adjust volume for preview.
  /// Bluetooth media buttons continue to work for recording control.
  /// When sound is cleared, re-enable volume key interception.
  void _handleSoundSelectionChanged(AudioEvent? previous, AudioEvent? next) {
    if (next != null && previous == null) {
      // Sound was selected - disable volume key interception only
      // Bluetooth media buttons still work for recording control
      _remoteRecordPausedForSound = true;
      _cameraService.setVolumeKeysEnabled(enabled: false);
      Log.debug(
        '🎵 Sound selected - volume keys disabled (Bluetooth still works)',
        name: 'VideoRecorderNotifier',
        category: .video,
      );
    } else if (next == null && previous != null) {
      // Sound was cleared - re-enable volume key interception
      _remoteRecordPausedForSound = false;
      _cameraService.setVolumeKeysEnabled(enabled: true);
      Log.debug(
        '🎵 Sound cleared - volume keys re-enabled',
        name: 'VideoRecorderNotifier',
        category: .video,
      );
    }
  }

  /// Temporarily pause remote record control.
  ///
  /// Call this when opening screens that need audio playback (e.g., SoundsScreen).
  /// The MediaSession used for Bluetooth remotes can interfere with audio playback.
  /// Call [resumeRemoteRecordControl] when returning to the camera.
  Future<void> pauseRemoteRecordControl() async {
    if (_remoteRecordControlEnabled) {
      await _cameraService.setRemoteRecordControlEnabled(enabled: false);
      Log.debug(
        '🎮 Remote record control paused (for audio playback)',
        name: 'VideoRecorderNotifier',
        category: .video,
      );
    }
  }

  /// Resume remote record control after pausing.
  ///
  /// Call this when returning from screens that needed audio playback.
  /// If a sound is currently selected, volume keys will remain disabled
  /// but Bluetooth media buttons will work.
  Future<void> resumeRemoteRecordControl() async {
    if (_remoteRecordControlEnabled) {
      await _cameraService.setRemoteRecordControlEnabled(enabled: true);
      Log.debug(
        '🎮 Remote record control resumed',
        name: 'VideoRecorderNotifier',
        category: .video,
      );

      // If a sound is selected, keep volume keys disabled
      if (_remoteRecordPausedForSound) {
        await _cameraService.setVolumeKeysEnabled(enabled: false);
        Log.debug(
          '🎮 Volume keys re-disabled (sound is selected)',
          name: 'VideoRecorderNotifier',
          category: .video,
        );
      }
    }
  }

  /// Toggle flash mode between `off`, `torch`, and `auto`.
  ///
  /// Returns `true` if flash mode was successfully changed, `false` otherwise.
  Future<bool> toggleFlash() async {
    final DivineFlashMode newMode = switch (state.flashMode) {
      .off => .torch,
      .torch => .auto,
      .auto => .off,
    };
    final success = await _cameraService.setFlashMode(newMode);
    if (!success) {
      Log.warning(
        '⚠️ Failed to toggle flash mode',
        name: 'VideoRecorderNotifier',
        category: .video,
      );
      return false;
    }
    state = state.copyWith(flashMode: newMode);
    Log.debug(
      '🔦 Flash mode changed to: ${newMode.name}',
      name: 'VideoRecorderNotifier',
      category: .video,
    );
    return true;
  }

  /// Toggle between square (1:1) and vertical (9:16) aspect ratios.
  void toggleAspectRatio() {
    final model.AspectRatio newRatio = state.aspectRatio == .square
        ? .vertical
        : .square;

    Log.debug(
      '📱 Aspect ratio changed to: ${newRatio.name}',
      name: 'VideoRecorderNotifier',
      category: .video,
    );

    setAspectRatio(newRatio);
  }

  /// Set aspect ratio for recording.
  void setAspectRatio(model.AspectRatio ratio) {
    state = state.copyWith(aspectRatio: ratio);
  }

  /// Switch between front and back camera.
  Future<void> switchCamera() async {
    final success = await _cameraService.switchCamera();

    if (!success) {
      Log.warning(
        '⚠️ Camera switch failed - no available cameras to switch',
        name: 'VideoRecorderNotifier',
        category: .video,
      );
      return;
    }
    _baseZoomLevel = 1;

    // Save the new lens preference
    await _saveCurrentLensPreference();

    Log.info(
      '🔄 Camera switched successfully - zoom reset to 1.0x',
      name: 'VideoRecorderNotifier',
      category: .video,
    );

    // Force state update to rebuild UI with new camera preview
    // Increment camera switch count to ensure state object changes and
    // triggers UI rebuild
    state = state.copyWith(zoomLevel: 1);
    updateState();
  }

  /// Switch to a specific camera lens.
  Future<void> setLens(DivineCameraLens lens) async {
    final success = await _cameraService.setLens(lens);

    if (!success) {
      Log.warning(
        '⚠️ Failed to set lens to ${lens.displayName}',
        name: 'VideoRecorderNotifier',
        category: .video,
      );
      return;
    }
    _baseZoomLevel = 1;

    // Save the new lens preference
    await _saveCurrentLensPreference();

    Log.info(
      '🔄 Lens switched to ${lens.displayName} - zoom reset to 1.0x',
      name: 'VideoRecorderNotifier',
      category: .video,
    );

    state = state.copyWith(zoomLevel: 1);
    updateState();
  }

  /// The current active camera lens.
  DivineCameraLens get currentLens => _cameraService.currentLens;

  /// List of available camera lenses on this device.
  List<DivineCameraLens> get availableLenses => _cameraService.availableLenses;

  /// Saves the current camera lens to SharedPreferences.
  Future<void> _saveCurrentLensPreference() async {
    final lens = _cameraService.currentLens;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString(_kLastUsedCameraLensKey, lens.toNativeString());
    Log.debug(
      '💾 Saved camera lens preference: ${lens.displayName}',
      name: 'VideoRecorderNotifier',
      category: .video,
    );
  }

  /// Set camera zoom level (within min/max bounds).
  Future<void> setZoomLevel(double value) async {
    if (value > _cameraService.maxZoomLevel ||
        value < _cameraService.minZoomLevel) {
      Log.debug(
        '⚠️ Zoom level $value out of bounds '
        '(${_cameraService.minZoomLevel}-${_cameraService.maxZoomLevel})',
        name: 'VideoRecorderNotifier',
        category: .video,
      );
      return;
    }

    final success = await _cameraService.setZoomLevel(value);
    if (!success) {
      Log.warning(
        '⚠️ Failed to set zoom level to $value',
        name: 'VideoRecorderNotifier',
        category: .video,
      );
      return;
    }
    state = state.copyWith(zoomLevel: value);
  }

  /// Set camera focus point (normalized 0.0-1.0 coordinates).
  Future<void> setFocusPoint(Offset value) async {
    final success = await _cameraService.setFocusPoint(value);
    if (!success) {
      Log.warning(
        '⚠️ Failed to set focus point at (${value.dx.toStringAsFixed(2)}, '
        '${value.dy.toStringAsFixed(2)})',
        name: 'VideoRecorderNotifier',
        category: .video,
      );
      return;
    }

    // Cancel previous timer if exists
    _focusPointTimer?.cancel();

    state = state.copyWith(focusPoint: value);

    // Hide focus point after 1.5 seconds
    _focusPointTimer = Timer(const Duration(milliseconds: 800), () {
      if (!_isDestroyed) {
        state = state.copyWith(focusPoint: .zero);
        _focusPointTimer = null;
      }
    });
  }

  /// Set camera exposure point (normalized 0.0-1.0 coordinates).
  ///
  /// Adjusts exposure metering to the specified point on the preview.
  Future<void> setExposurePoint(Offset value) async {
    final success = await _cameraService.setExposurePoint(value);
    if (!success) {
      Log.warning(
        '⚠️ Failed to set exposure point at (${value.dx.toStringAsFixed(2)}, '
        '${value.dy.toStringAsFixed(2)})',
        name: 'VideoRecorderNotifier',
        category: .video,
      );
    }
  }

  /// Toggle recording state (start if idle, stop if recording).
  ///
  /// Convenience method for record button - starts recording when idle,
  /// stops when recording.
  Future<void> toggleRecording() async {
    switch (state.recordingState) {
      case .idle:
        await startRecording();
      case .error:
      case .recording:
        await stopRecording();
    }
  }

  /// Start video recording with optional timer countdown.
  ///
  /// If timer duration is set, displays countdown before starting recording.
  /// Notifies clip manager to begin tracking recording duration.
  Future<void> startRecording() async {
    final clipProvider = ref.read(clipManagerProvider.notifier);
    final remainingDuration = clipProvider.remainingDuration;

    // We block the recording if the video is already recording or if the
    // remaining duration is less than one frame.
    if (!_cameraService.canRecord ||
        state.isRecording ||
        _isStartingRecording ||
        _isStoppingRecording ||
        remainingDuration < const Duration(milliseconds: 30)) {
      return;
    }

    _baseZoomLevel = state.zoomLevel;
    _isStartingRecording = true;
    unawaited(HapticService.recordingFeedback());

    // Handle timer countdown
    if (state.timerDuration != .off) {
      final seconds = state.timerDuration.duration.inSeconds;
      Log.info(
        '⏱️  Starting ${seconds}s countdown before recording',
        name: 'VideoRecorderNotifier',
        category: .video,
      );

      // Disable volume key interception during countdown so users can
      // adjust volume before recording starts
      await _cameraService.setVolumeKeysEnabled(enabled: false);

      // Set recording state during countdown so UI shows countdown
      state = state.copyWith(recordingState: .recording);

      for (var i = seconds; i > 0 && !_isDestroyed; i--) {
        state = state.copyWith(countdownValue: i);
        await Future<void>.delayed(const Duration(seconds: 1));
      }
      if (_isDestroyed) {
        _isStartingRecording = false;
        state = state.copyWith(recordingState: .idle);
        // Re-enable volume keys on early exit
        await _cameraService.setVolumeKeysEnabled(enabled: true);
        return;
      }
      state = state.copyWith(countdownValue: 0);
      unawaited(HapticService.recordingFeedback());

      // Re-enable volume key interception after countdown
      // (unless a sound is selected, then keep them disabled)
      if (!_remoteRecordPausedForSound) {
        await _cameraService.setVolumeKeysEnabled(enabled: true);
      }
    }

    if (_isDestroyed) {
      _isStartingRecording = false;
      return;
    }

    // Set recording state before starting (UI feedback)
    state = state.copyWith(recordingState: .recording);

    Log.info(
      '🎥 Starting recording - aspect ratio: ${state.aspectRatio.name}',
      name: 'VideoRecorderNotifier',
      category: .video,
    );

    final success = await _cameraService.startRecording(
      maxDuration: remainingDuration,
    );

    _isStartingRecording = false;

    if (success) {
      Log.info(
        '✅ Recording truly started',
        name: 'VideoRecorderNotifier',
        category: .video,
      );
      clipProvider.startRecording();

      // Start audio playback if a sound is selected
      unawaited(_startSoundPlayback());
    } else {
      Log.warning(
        '⚠️ Recording failed to start or was stopped early',
        name: 'VideoRecorderNotifier',
        category: .video,
      );
      state = state.copyWith(recordingState: .idle);
    }
  }

  /// Stop recording and process clip (metadata, thumbnail).
  ///
  /// Stops camera recording, extracts video metadata for exact duration,
  /// generates thumbnail, and adds clip to clip manager.
  Future<void> stopRecording([EditorVideo? result]) async {
    // Prevent multiple simultaneous stop calls.
    if (_isStoppingRecording) {
      return;
    }

    // If we're still starting up (waiting for first keyframe), just call native stop
    // The native Finalize event will trigger startRecordingCallback with error,
    // which makes startRecording return false and set state to idle
    if (_isStartingRecording) {
      Log.info(
        '⏳ Stop requested during startup - calling native stop (startRecording will handle state)',
        name: 'VideoRecorderNotifier',
        category: .video,
      );
      // Don't await - let native handle it asynchronously
      // The startRecording method will get the error callback and set state to idle
      unawaited(_cameraService.stopRecording());
      return;
    }

    if (!state.isRecording && result == null) return;

    Log.info(
      '⏹️  Stopping recording and processing clip...',
      name: 'VideoRecorderNotifier',
      category: .video,
    );
    _isStoppingRecording = true;

    unawaited(HapticService.recordingFeedback());

    // Stop audio playback if active
    await _stopSoundPlayback();

    final videoResult = result ?? await _cameraService.stopRecording();

    final clipProvider = ref.read(clipManagerProvider.notifier)
      ..stopRecording();
    final remainingDuration = clipProvider.remainingDuration;

    state = state.copyWith(recordingState: .idle);
    _isStoppingRecording = false;
    if (videoResult == null) {
      Log.warning(
        '⚠️ Recording stopped but no video file returned from camera service',
        name: 'VideoRecorderNotifier',
        category: .video,
      );
      clipProvider.resetRecording();
      return;
    }

    /// Add the recorded clip to ClipManager
    final clip = clipProvider.addClip(
      video: videoResult,
      originalAspectRatio: _cameraService.cameraAspectRatio,
      targetAspectRatio: state.aspectRatio,
      lensMetadata: _cameraService.currentLensMetadata,
    );

    Log.debug(
      '📷 Lens metadata: ${_cameraService.currentLensMetadata?.toMap()}',
      name: 'VideoRecorderNotifier',
      category: .video,
    );

    Log.info(
      '✅ Clip added successfully - ID: ${clip.id}',
      name: 'VideoRecorderNotifier',
      category: .video,
    );

    /// We used the stopwatch as a temporary timer to set an expected duration.
    /// However, we now read the exact video duration in the background and
    /// update it.
    // Extract video metadata and update duration
    final metadata = await ProVideoEditor.instance.getMetadata(videoResult);
    clipProvider.updateClipDuration(clip.id, metadata.duration);
    Log.debug(
      '📊 Video duration: ${metadata.duration.inMilliseconds}ms',
      name: 'VideoRecorderNotifier',
      category: .video,
    );

    // Save clip to device gallery (fire-and-forget)
    unawaited(
      ref
          .read(gallerySaveServiceProvider)
          .saveVideoToGallery(
            videoResult,
            aspectRatio: state.aspectRatio,
            metadata: metadata,
          ),
    );

    // Generate and attach thumbnail.
    // Take the smaller of remaining duration or actual video duration.
    final effectiveDuration = remainingDuration < metadata.duration
        ? remainingDuration
        : metadata.duration;
    final halfDuration = effectiveDuration ~/ 2;
    final targetTimestamp =
        halfDuration < VideoEditorConstants.defaultThumbnailExtractTime
        ? halfDuration
        : VideoEditorConstants.defaultThumbnailExtractTime;
    final thumbnailResult = await VideoThumbnailService.extractThumbnail(
      videoPath: await videoResult.safeFilePath(),
      targetTimestamp: targetTimestamp,
    );
    if (thumbnailResult != null) {
      clipProvider.updateThumbnail(
        clipId: clip.id,
        thumbnailPath: thumbnailResult.path,
        thumbnailTimestamp: thumbnailResult.timestamp,
      );
      Log.debug(
        '🖼️  Thumbnail generated: ${thumbnailResult.path}',
        name: 'VideoRecorderNotifier',
        category: .video,
      );
    } else {
      Log.warning(
        '⚠️ Thumbnail generation failed',
        name: 'VideoRecorderNotifier',
        category: .video,
      );
    }
  }

  /// Adjust zoom by vertical drag distance during long press.
  ///
  /// Maps upward drag distance (0-240px) to zoom range from base level to max.
  Future<void> zoomByLongPressMove(Offset offsetFromOrigin) async {
    // At 240px drag distance, reach maxZoomLevel
    const maxDragDistance = 240.0;
    // Calculate upward drag distance (negative Y = upward)
    final dragDistance = (-offsetFromOrigin.dy).clamp(0.0, maxDragDistance);

    final availableZoomRange = _cameraService.maxZoomLevel - _baseZoomLevel;
    final zoomLevel =
        _baseZoomLevel + (dragDistance / maxDragDistance) * availableZoomRange;

    await setZoomLevel(zoomLevel);
  }

  /// Handle pinch-to-zoom gesture start.
  ///
  /// Captures base zoom level for relative zoom calculations.
  void handleScaleStart(ScaleStartDetails details) {
    _baseZoomLevel = state.zoomLevel;
  }

  /// Handle pinch-to-zoom gesture update.
  ///
  /// Calculates zoom level based on pinch scale relative to base level.
  Future<void> handleScaleUpdate(ScaleUpdateDetails details) async {
    // Linear zoom: map scale gesture to zoom range
    // scale < 1.0 = zoom out, scale > 1.0 = zoom in
    final scaleChange = details.scale - 1.0; // -1.0 to +2.0 range
    final normalizedChange = scaleChange.clamp(-1.0, 2.0);

    // Calculate zoom based on available range from base level
    final zoomRangeDown = _baseZoomLevel - _cameraService.minZoomLevel;
    final zoomRangeUp = _cameraService.maxZoomLevel - _baseZoomLevel;

    final newZoom = normalizedChange >= 0
        ? _baseZoomLevel + (normalizedChange / 2.0) * zoomRangeUp
        : _baseZoomLevel + normalizedChange * zoomRangeDown;

    final clampedZoom = newZoom.clamp(
      _cameraService.minZoomLevel,
      _cameraService.maxZoomLevel,
    );

    // Only update if change is significant to avoid excessive updates
    if ((state.zoomLevel - clampedZoom).abs() > 0.01) {
      await setZoomLevel(clampedZoom);
    }
  }

  /// Close video recorder and navigate away.
  ///
  /// Pops navigation stack if possible, otherwise navigates home.
  void closeVideoRecorder(BuildContext context) {
    Log.info(
      '📹 X CANCEL - navigating away from camera',
      name: 'VideoRecorderNotifier',
      category: .video,
    );
    // Try to pop if possible, otherwise go home.
    if (context.canPop()) {
      context.pop();
    } else {
      // No screen to pop to (navigated via go), go home instead.
      context.go(HomeScreenRouter.pathForIndex(0));
    }
  }

  /// Navigate to video editor screen, pausing camera during transition.
  ///
  /// Pauses camera lifecycle, navigates to editor, and resumes camera on
  /// return.
  Future<void> openVideoEditor(BuildContext context) async {
    Log.info(
      '📹 Opening video editor - disposing camera',
      name: 'VideoRecorderNotifier',
      category: .video,
    );
    await Future.wait([
      context.push(VideoClipEditorScreen.path),
      // We delay camera dispose so that the screen animation can finish
      // before the editor open. Without that it will look weird to the user
      // because the initialization screen will show up quickly.
      Future.delayed(const Duration(milliseconds: 300), () {
        return _cameraService.dispose();
      }),
    ]);
    if (!context.mounted) return;

    Log.info(
      '📹 Returned from editor - reinitializing camera',
      name: 'VideoRecorderNotifier',
      category: .video,
    );
    await _cameraService.initialize();
  }

  /// Update the state based on the current camera state.
  ///
  /// Synchronizes provider state with camera service state including
  /// capabilities (flash, switch camera) and sensor properties.
  void updateState({int? cameraRebuildCount, model.AspectRatio? aspectRatio}) {
    // Check if ref is still mounted before updating state
    if (!ref.mounted) return;

    Log.debug(
      '🔄 Updating video recorder state',
      name: 'VideoRecorderNotifier',
      category: .video,
    );

    state = VideoRecorderProviderState(
      cameraRebuildCount: cameraRebuildCount ?? state.cameraRebuildCount,
      countdownValue: 0,
      zoomLevel: 1,
      focusPoint: .zero,
      aspectRatio: aspectRatio ?? state.aspectRatio,
      flashMode: .off,
      timerDuration: .off,
      recordingState: .idle,
      cameraSensorAspectRatio: _cameraService.cameraAspectRatio,
      canRecord: _cameraService.canRecord,
      isCameraInitialized: _cameraService.isInitialized,
      hasFlash: _cameraService.hasFlash,
      canSwitchCamera: _cameraService.canSwitchCamera,
    );
  }

  /// Cycle timer duration through off -> 3s -> 10s -> off.
  void cycleTimer() {
    final TimerDuration newTimer = switch (state.timerDuration) {
      .off => .three,
      .three => .ten,
      .ten => .off,
    };
    state = state.copyWith(timerDuration: newTimer);
    Log.debug(
      '⏱️  Timer duration changed to: ${newTimer.name}',
      name: 'VideoRecorderNotifier',
      category: .video,
    );
  }

  /// Reset state to initial values.
  void reset() {
    Log.debug(
      '🔄 Resetting video recorder state',
      name: 'VideoRecorderNotifier',
      category: .video,
    );
    state = const VideoRecorderProviderState();
  }

  // === SOUND PLAYBACK DURING RECORDING ===

  /// Starts audio playback for the selected sound during recording.
  ///
  /// Configures the audio session for simultaneous recording and playback,
  /// loads the audio from the sound's URL, and starts playback.
  /// Failures are logged but do not prevent recording from continuing.
  Future<void> _startSoundPlayback() async {
    final selectedSound = ref.read(selectedSoundProvider);
    if (selectedSound == null || selectedSound.url == null) return;

    try {
      _audioPlaybackService ??= AudioPlaybackService();

      // Configure audio session for recording + playback
      await _audioPlaybackService!.configureForRecording();

      // Load the audio from the sound's Blossom URL
      await _audioPlaybackService!.loadAudio(selectedSound.url!);

      // Start playback
      await _audioPlaybackService!.play();

      Log.info(
        'Started sound playback during recording: '
        '${selectedSound.title ?? selectedSound.id}',
        name: 'VideoRecorderNotifier',
        category: LogCategory.video,
      );
    } catch (e) {
      Log.warning(
        'Failed to start sound playback during recording: $e',
        name: 'VideoRecorderNotifier',
        category: LogCategory.video,
      );
      // Don't prevent recording - sound playback is best-effort
    }
  }

  /// Stops audio playback and resets the audio session.
  Future<void> _stopSoundPlayback() async {
    if (_audioPlaybackService == null) return;

    try {
      await _audioPlaybackService!.stop();
      await _audioPlaybackService!.resetAudioSession();

      Log.info(
        'Stopped sound playback',
        name: 'VideoRecorderNotifier',
        category: LogCategory.video,
      );
    } catch (e) {
      Log.warning(
        'Failed to stop sound playback: $e',
        name: 'VideoRecorderNotifier',
        category: LogCategory.video,
      );
    }
  }
}

/// Provider for video recorder state and operations.
final videoRecorderProvider =
    NotifierProvider<VideoRecorderNotifier, VideoRecorderProviderState>(
      VideoRecorderNotifier.new,
    );
