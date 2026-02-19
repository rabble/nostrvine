// ABOUTME: Base service for camera operations across different platforms
// ABOUTME: Provides unified API for camera control, recording, and preview

import 'package:divine_camera/divine_camera_platform_interface.dart';
import 'package:divine_camera/src/models/camera_lens.dart';
import 'package:divine_camera/src/models/camera_state.dart';
import 'package:divine_camera/src/models/flash_mode.dart';
import 'package:divine_camera/src/models/remote_record_trigger.dart';
import 'package:divine_camera/src/models/video_quality.dart';
import 'package:divine_camera/src/models/video_recording_result.dart';
import 'package:flutter/widgets.dart';

// Export models for external use
export 'src/models/camera_lens.dart';
export 'src/models/camera_lens_metadata.dart';
export 'src/models/camera_state.dart';
export 'src/models/flash_mode.dart';
export 'src/models/remote_record_trigger.dart';
export 'src/models/video_quality.dart';
export 'src/models/video_recording_result.dart';
// Export widgets
export 'src/widgets/camera_preview_widget.dart';

/// Base service for camera operations across different platforms.
/// Provides a unified API for camera control, recording, and preview.
///
/// Use [DivineCamera.instance] to access the singleton instance:
/// ```dart
/// await DivineCamera.instance.initialize();
/// ```
class DivineCamera {
  DivineCamera._internal();

  /// The singleton instance of [DivineCamera].
  static final DivineCamera instance = DivineCamera._internal();

  /// Callback invoked when camera state changes.
  void Function(CameraState state)? onStateChanged;

  /// Callback invoked when recording auto-stops due to max duration.
  void Function(VideoRecordingResult result)? onRecordingAutoStopped;

  /// Callback invoked when a remote record trigger is detected.
  ///
  /// This includes volume button presses or Bluetooth remote triggers
  /// when remote record control is enabled.
  void Function(RemoteRecordTrigger trigger)? onRemoteRecordTrigger;

  /// Whether remote record control is currently enabled.
  bool _remoteRecordControlEnabled = false;

  /// Whether remote record control is currently enabled.
  bool get remoteRecordControlEnabled => _remoteRecordControlEnabled;

  /// The current camera state.
  CameraState _state = const CameraState();

  /// Gets the current camera state.
  CameraState get state => _state;

  /// Whether the front camera video output should be mirrored.
  /// When `true`, recorded video appears as mirror image (like preview).
  /// When `false`, recorded video shows real-world orientation.
  bool _mirrorFrontCameraOutput = false;

  /// Gets whether the front camera video output is mirrored.
  bool get mirrorFrontCameraOutput => _mirrorFrontCameraOutput;

  /// The platform interface instance.
  DivineCameraPlatform get _platform => DivineCameraPlatform.instance;

  /// Handles auto-stop event from platform.
  void _handleAutoStop(VideoRecordingResult result) {
    _state = _state.copyWith(isRecording: false);
    _notifyStateChanged();
    onRecordingAutoStopped?.call(result);
  }

  /// Handles remote record trigger event from platform.
  void _handleRemoteRecordTrigger(RemoteRecordTrigger trigger) {
    onRemoteRecordTrigger?.call(trigger);
  }

  /// Returns the platform version.
  Future<String?> getPlatformVersion() {
    return _platform.getPlatformVersion();
  }

  /// Initializes the camera and prepares it for use.
  ///
  /// [lens] specifies which camera to use (front or back).
  /// [videoQuality] specifies the video recording quality (default: FHD/1080p).
  /// [enableScreenFlash] enables using screen brightness as flash for
  /// front camera (default: true).
  /// [mirrorFrontCameraOutput] controls whether the front camera video output
  /// is horizontally mirrored.
  /// When `true`, the recorded video appears
  /// as a mirror image (like the preview).
  /// When `false`, the video shows the real-world orientation (non-mirrored).
  /// The preview is always mirrored.
  ///
  /// Returns the initialized camera state.
  Future<CameraState> initialize({
    DivineCameraLens lens = DivineCameraLens.back,
    DivineVideoQuality videoQuality = DivineVideoQuality.fhd,
    bool enableScreenFlash = true,
    bool mirrorFrontCameraOutput = false,
  }) async {
    // Register auto-stop callback with platform
    _platform.onRecordingAutoStopped = _handleAutoStop;

    // Register remote record trigger callback with platform
    _platform.onRemoteRecordTrigger = _handleRemoteRecordTrigger;

    // Store the mirror setting for preview widget
    _mirrorFrontCameraOutput = mirrorFrontCameraOutput;

    _state = await _platform.initializeCamera(
      lens: lens,
      videoQuality: videoQuality,
      enableScreenFlash: enableScreenFlash,
      mirrorFrontCameraOutput: mirrorFrontCameraOutput,
    );
    _notifyStateChanged();
    return _state;
  }

  /// Releases camera resources and cleans up.
  ///
  /// This also clears any registered listeners.
  Future<void> dispose() async {
    await _platform.disposeCamera();
    _state = const CameraState();
    _notifyStateChanged();

    // Clear listeners to prevent memory leaks
    onStateChanged = null;
    onRecordingAutoStopped = null;
    onRemoteRecordTrigger = null;
    _platform.onRecordingAutoStopped = null;
    _platform.onRemoteRecordTrigger = null;
    _remoteRecordControlEnabled = false;
  }

  /// Sets the flash mode.
  ///
  /// [mode] the flash mode to set.
  /// Returns true if successful.
  Future<bool> setFlashMode(DivineCameraFlashMode mode) async {
    final success = await _platform.setFlashMode(mode);
    if (success) {
      _state = _state.copyWith(flashMode: mode);
      _notifyStateChanged();
    }
    return success;
  }

  /// Sets the focus point in normalized coordinates (0.0-1.0).
  ///
  /// [offset] the focus point coordinates.
  /// Returns true if successful.
  Future<bool> setFocusPoint(Offset offset) async {
    if (!_state.isFocusPointSupported) return false;
    return _platform.setFocusPoint(offset);
  }

  /// Sets the exposure point in normalized coordinates (0.0-1.0).
  ///
  /// [offset] the exposure point coordinates.
  /// Returns true if successful.
  Future<bool> setExposurePoint(Offset offset) async {
    if (!_state.isExposurePointSupported) return false;
    return _platform.setExposurePoint(offset);
  }

  /// Cancels any active focus/metering lock and returns to continuous
  /// auto-focus mode.
  ///
  /// Call this to reset focus behavior after a tap-to-focus.
  /// For example, when recording ends or camera switches.
  /// Returns true if successful.
  Future<bool> cancelFocusAndMetering() async {
    return _platform.cancelFocusAndMetering();
  }

  /// Sets the zoom level.
  ///
  /// [level] the zoom level to set.
  /// Returns true if successful.
  Future<bool> setZoomLevel(double level) async {
    final clampedLevel = level.clamp(_state.minZoomLevel, _state.maxZoomLevel);
    final success = await _platform.setZoomLevel(clampedLevel);
    if (success) {
      _state = _state.copyWith(zoomLevel: clampedLevel);
      _notifyStateChanged();
    }
    return success;
  }

  /// Switches between front and back camera.
  ///
  /// Returns true if successful.
  Future<bool> switchCamera() async {
    if (!_state.canSwitchCamera) return false;
    final newLens = _state.lens.opposite;

    // Set switching state to keep last frame visible
    _state = _state.copyWith(isSwitchingCamera: true);
    _notifyStateChanged();

    _state = await _platform.switchCamera(newLens);
    _state = _state.copyWith(isSwitchingCamera: false);
    _notifyStateChanged();
    return true;
  }

  /// Switches to a specific camera lens.
  ///
  /// [lens] the lens to switch to.
  /// Returns true if successful.
  Future<bool> setLens(DivineCameraLens lens) async {
    if (lens == _state.lens) return true;
    if (!_state.availableLenses.contains(lens)) return false;

    // Set switching state to keep last frame visible
    _state = _state.copyWith(isSwitchingCamera: true);
    _notifyStateChanged();

    _state = await _platform.switchCamera(lens);
    _state = _state.copyWith(isSwitchingCamera: false);
    _notifyStateChanged();
    return true;
  }

  /// Starts video recording.
  ///
  /// [maxDuration] optionally limits the recording duration.
  /// When the duration is reached, recording stops automatically.
  /// [useCache] if true, saves video to cache directory (temporary),
  /// otherwise saves to documents directory (permanent). Defaults to true.
  /// [outputDirectory] specifies where to save the video.
  ///
  /// Returns true if recording successfully started (first keyframe recorded),
  /// false if recording failed to start or was stopped before first keyframe.
  Future<bool> startRecording({
    Duration? maxDuration,
    bool useCache = true,
    String? outputDirectory,
  }) async {
    if (!_state.canRecord) return false;
    final result = await _platform.startRecording(
      maxDuration: maxDuration,
      useCache: useCache,
      outputDirectory: outputDirectory,
    );
    if (result) {
      _state = _state.copyWith(isRecording: true);
      _notifyStateChanged();
    }
    return result;
  }

  /// Stops video recording.
  ///
  /// Returns the recorded video result, or null if recording failed.
  Future<VideoRecordingResult?> stopRecording() async {
    if (!_state.isRecording) return null;
    final result = await _platform.stopRecording();
    _state = _state.copyWith(isRecording: false);
    _notifyStateChanged();
    return result;
  }

  /// Handles app lifecycle changes (pause, resume, etc.).
  Future<void> handleAppLifecycleState(AppLifecycleState appState) async {
    if (!_state.isInitialized) return;

    switch (appState) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        await _platform.pausePreview();
      case AppLifecycleState.resumed:
        await _platform.resumePreview();
        _state = await _platform.getCameraState();
        _notifyStateChanged();
    }
  }

  /// Enables or disables remote record control via volume buttons.
  ///
  /// When enabled, volume button presses will trigger the
  /// [onRemoteRecordTrigger] callback instead of changing the system volume.
  /// This allows users to start/stop recording using physical volume buttons
  /// or Bluetooth accessories like clickers or earbuds.
  ///
  /// Returns `true` if successfully enabled/disabled.
  Future<bool> setRemoteRecordControlEnabled({required bool enabled}) async {
    final success = await _platform.setRemoteRecordControlEnabled(
      enabled: enabled,
    );
    if (success) {
      _remoteRecordControlEnabled = enabled;
    }
    return success;
  }

  /// Enables or disables volume key interception.
  ///
  /// When disabled, volume buttons will change system volume instead of
  /// triggering recording. Bluetooth media buttons are NOT affected and will
  /// continue to trigger recording.
  ///
  /// Use this when a sound is selected and the user needs to adjust volume
  /// for the sound preview.
  ///
  /// Returns `true` if successfully set.
  Future<bool> setVolumeKeysEnabled({required bool enabled}) async {
    return _platform.setVolumeKeysEnabled(enabled: enabled);
  }

  /// The aspect ratio of the camera sensor.
  double get cameraAspectRatio => _state.aspectRatio;

  /// Minimum zoom level supported by the camera.
  double get minZoomLevel => _state.minZoomLevel;

  /// Maximum zoom level supported by the camera.
  double get maxZoomLevel => _state.maxZoomLevel;

  /// The current zoom level.
  double get zoomLevel => _state.zoomLevel;

  /// Whether the camera is initialized and ready to use.
  bool get isInitialized => _state.isInitialized;

  /// Whether the camera supports manual focus point selection.
  bool get isFocusPointSupported => _state.isFocusPointSupported;

  /// Whether the camera supports manual exposure point selection.
  bool get isExposurePointSupported => _state.isExposurePointSupported;

  /// Whether the camera is ready to record (initialized and not recording).
  bool get canRecord => _state.canRecord;

  /// Whether the device has multiple cameras to switch between.
  bool get canSwitchCamera => _state.canSwitchCamera;

  /// Whether the device can activate the camera-flash.
  bool get hasFlash => _state.hasFlash;

  /// Whether the camera is currently recording.
  bool get isRecording => _state.isRecording;

  /// Whether the device has a front-facing camera.
  bool get hasFrontCamera => _state.hasFrontCamera;

  /// Whether the device has a back-facing camera.
  bool get hasBackCamera => _state.hasBackCamera;

  /// Whether the camera is currently switching between lenses.
  bool get isSwitchingCamera => _state.isSwitchingCamera;

  /// The texture ID for the camera preview.
  int? get textureId => _state.textureId;

  /// The currently active camera lens (front or back).
  DivineCameraLens get lens => _state.lens;

  /// Notifies listeners of state changes.
  void _notifyStateChanged() {
    onStateChanged?.call(_state);
  }
}
