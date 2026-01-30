// ABOUTME: Platform interface for divine_camera plugin
// ABOUTME: Defines abstract methods for camera operations across platforms

import 'package:divine_camera/divine_camera_method_channel.dart';
import 'package:divine_camera/src/models/camera_lens.dart';
import 'package:divine_camera/src/models/camera_state.dart';
import 'package:divine_camera/src/models/flash_mode.dart';
import 'package:divine_camera/src/models/video_quality.dart';
import 'package:divine_camera/src/models/video_recording_result.dart';
import 'package:flutter/widgets.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

/// The interface that implementations of divine_camera must implement.
abstract class DivineCameraPlatform extends PlatformInterface {
  /// Constructs a DivineCameraPlatform.
  DivineCameraPlatform() : super(token: _token);

  static final Object _token = Object();

  static DivineCameraPlatform _instance = MethodChannelDivineCamera();

  /// The default instance of [DivineCameraPlatform] to use.
  static DivineCameraPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [DivineCameraPlatform].
  static set instance(DivineCameraPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Returns the platform version.
  Future<String?> getPlatformVersion() {
    throw UnimplementedError('getPlatformVersion() has not been implemented.');
  }

  /// Initializes the camera with the specified lens.
  /// Returns the initial camera state.
  Future<CameraState> initializeCamera({
    DivineCameraLens lens = DivineCameraLens.back,
    DivineVideoQuality videoQuality = DivineVideoQuality.fhd,
    bool enableScreenFlash = true,
  }) {
    throw UnimplementedError('initializeCamera() has not been implemented.');
  }

  /// Disposes of camera resources.
  Future<void> disposeCamera() {
    throw UnimplementedError('disposeCamera() has not been implemented.');
  }

  /// Sets the flash mode.
  /// Returns true if successful.
  Future<bool> setFlashMode(DivineCameraFlashMode mode) {
    throw UnimplementedError('setFlashMode() has not been implemented.');
  }

  /// Sets the focus point in normalized coordinates (0.0-1.0).
  /// Returns true if successful.
  Future<bool> setFocusPoint(Offset offset) {
    throw UnimplementedError('setFocusPoint() has not been implemented.');
  }

  /// Sets the exposure point in normalized coordinates (0.0-1.0).
  /// Returns true if successful.
  Future<bool> setExposurePoint(Offset offset) {
    throw UnimplementedError('setExposurePoint() has not been implemented.');
  }

  /// Sets the zoom level.
  /// Returns true if successful.
  Future<bool> setZoomLevel(double level) {
    throw UnimplementedError('setZoomLevel() has not been implemented.');
  }

  /// Switches to the specified camera lens.
  /// Returns the new camera state.
  Future<CameraState> switchCamera(DivineCameraLens lens) {
    throw UnimplementedError('switchCamera() has not been implemented.');
  }

  /// Starts video recording.
  ///
  /// [maxDuration] optionally limits the recording duration.
  /// [useCache] if true, saves video to cache directory (temporary), otherwise
  /// saves to documents directory (permanent). Defaults to true.
  Future<bool> startRecording({Duration? maxDuration, bool useCache = true}) {
    throw UnimplementedError('startRecording() has not been implemented.');
  }

  /// Stops video recording and returns the result.
  Future<VideoRecordingResult?> stopRecording() {
    throw UnimplementedError('stopRecording() has not been implemented.');
  }

  /// Pauses the camera preview.
  Future<void> pausePreview() {
    throw UnimplementedError('pausePreview() has not been implemented.');
  }

  /// Resumes the camera preview.
  Future<void> resumePreview() {
    throw UnimplementedError('resumePreview() has not been implemented.');
  }

  /// Gets the current camera state.
  Future<CameraState> getCameraState() {
    throw UnimplementedError('getCameraState() has not been implemented.');
  }

  /// Builds the platform-specific camera preview widget.
  Widget buildPreview(int textureId) {
    throw UnimplementedError('buildPreview() has not been implemented.');
  }

  /// Callback for when recording auto-stops due to max duration.
  void Function(VideoRecordingResult result)? get onRecordingAutoStopped {
    throw UnimplementedError(
      'onRecordingAutoStopped has not been implemented.',
    );
  }

  /// Sets the callback for when recording auto-stops due to max duration.
  set onRecordingAutoStopped(
    void Function(VideoRecordingResult result)? callback,
  ) {
    throw UnimplementedError(
      'onRecordingAutoStopped has not been implemented.',
    );
  }
}
