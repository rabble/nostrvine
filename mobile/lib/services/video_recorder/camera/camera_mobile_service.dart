// ABOUTME: Mobile platform implementation of camera service using the camera package
// ABOUTME: Handles camera initialization, switching, recording, and lifecycle management on mobile devices

import 'package:flutter/widgets.dart';
import 'package:openvine/models/video_recorder/video_recorder_flash_mode.dart';
import 'package:openvine/services/video_recorder/camera/camera_base_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:divine_camera/divine_camera.dart';

/// Mobile implementation of [CameraService] using the camera package.
///
/// Manages camera initialization, recording, and switching between front/back cameras.
class CameraMobileService extends CameraService {
  /// Creates a mobile camera service instance.
  CameraMobileService({
    required super.onUpdateState,
    required super.onAutoStopped,
  });

  bool _isInitialized = false;
  String? _initializationError;
  final _camera = DivineCamera.instance;

  @override
  Future<void> initialize() async {
    // Clear any previous error
    _initializationError = null;

    Log.info(
      '📷 Initializing mobile camera',
      name: 'CameraMobileService',
      category: .video,
    );
    try {
      await _camera.initialize(lens: .front);
      _camera.onRecordingAutoStopped = (result) {
        onAutoStopped(EditorVideo.file(result.filePath));
      };
      _isInitialized = true;
    } catch (e) {
      _initializationError = 'Camera initialization failed: $e';
      Log.error(
        '📷 Failed to initialize camera: $e',
        name: 'CameraMobileService',
        category: .video,
      );
    }

    onUpdateState(forceCameraRebuild: true);
  }

  @override
  Future<void> dispose() async {
    Log.info(
      '📷 Disposing mobile camera',
      name: 'CameraMobileService',
      category: .video,
    );

    _isInitialized = false;
    onUpdateState();
    await _camera.dispose();
  }

  @override
  Future<bool> setFlashMode(DivineFlashMode mode) async {
    if (!_isInitialized) return false;
    try {
      Log.info(
        '📷 Setting flash mode to ${mode.name}',
        name: 'CameraMobileService',
        category: .video,
      );
      await _camera.setFlashMode(_getFlashMode(mode));
      return true;
    } catch (e) {
      Log.error(
        '📷 Failed to set flash mode (unexpected error): $e',
        name: 'CameraMobileService',
        category: .video,
      );
      return false;
    }
  }

  @override
  Future<bool> setFocusPoint(Offset offset) async {
    if (!_isInitialized) return false;
    try {
      Log.info(
        '📷 Setting focus point to (${offset.dx}, ${offset.dy})',
        name: 'CameraMobileService',
        category: .video,
      );

      await _camera.setFocusPoint(offset);

      return true;
    } catch (e) {
      Log.error(
        '📷 Failed to set focus point (unexpected error): $e',
        name: 'CameraMobileService',
        category: .video,
      );
      return false;
    }
  }

  @override
  Future<bool> setExposurePoint(Offset offset) async {
    if (!_isInitialized) return false;
    try {
      Log.info(
        '📷 Setting exposure point to (${offset.dx}, ${offset.dy})',
        name: 'CameraMobileService',
        category: .video,
      );

      await _camera.setExposurePoint(offset);
      return true;
    } catch (e) {
      Log.error(
        '📷 Failed to set exposure point (unexpected error): $e',
        name: 'CameraMobileService',
        category: .video,
      );
      return false;
    }
  }

  @override
  Future<bool> setZoomLevel(double value) async {
    if (!_isInitialized) return false;
    try {
      Log.info(
        '📷 Setting zoom level to $value',
        name: 'CameraMobileService',
        category: .video,
      );

      await _camera.setZoomLevel(
        value.clamp(_camera.minZoomLevel, _camera.maxZoomLevel),
      );
      return true;
    } catch (e) {
      Log.error(
        '📷 Failed to set zoom level (unexpected error): $e',
        name: 'CameraMobileService',
        category: .video,
      );
      return false;
    }
  }

  @override
  Future<bool> switchCamera() async {
    if (!_isInitialized) return false;
    try {
      Log.info(
        '📷 Switching camera',
        name: 'CameraMobileService',
        category: .video,
      );

      await _camera.switchCamera();
      onUpdateState(forceCameraRebuild: true);

      Log.info(
        '📷 Camera switched',
        name: 'CameraMobileService',
        category: .video,
      );
      return true;
    } catch (e) {
      Log.error(
        '📷 Failed to switch camera (unexpected error): $e',
        name: 'CameraMobileService',
        category: .video,
      );
      return false;
    }
  }

  @override
  Future<bool> startRecording({
    Duration? maxDuration,
    String? outputDirectory,
  }) async {
    if (!_isInitialized) return false;
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final outputPath = outputDirectory ?? docsDir.path;

      Log.info(
        '📷 Starting video recording to: $outputPath',
        name: 'CameraMobileService',
        category: .video,
      );
      final success = await _camera.startRecording(
        maxDuration: maxDuration,
        useCache: false,
        outputDirectory: outputPath,
      );
      if (success) {
        Log.info(
          '📷 Video recording truly started',
          name: 'CameraMobileService',
          category: .video,
        );
      } else {
        Log.warning(
          '📷 Recording failed to start or was stopped before first keyframe',
          name: 'CameraMobileService',
          category: .video,
        );
      }
      return success;
    } catch (e) {
      Log.error(
        '📷 Failed to start recording (unexpected error): $e',
        name: 'CameraMobileService',
        category: .video,
      );
      return false;
    }
  }

  @override
  Future<EditorVideo?> stopRecording() async {
    if (!_isInitialized) return null;
    try {
      Log.info(
        '📷 Stopping video recording',
        name: 'CameraMobileService',
        category: .video,
      );

      final result = await _camera.stopRecording();

      Log.info(
        '📷 Video recording stopped',
        name: 'CameraMobileService',
        category: .video,
      );
      if (result?.filePath == null) return null;

      return EditorVideo.autoSource(file: result!.filePath);
    } catch (e) {
      Log.error(
        '📷 Failed to stop recording (unexpected error): $e',
        name: 'CameraMobileService',
        category: .video,
      );
      return null;
    }
  }

  @override
  Future<void> handleAppLifecycleState(AppLifecycleState state) async {
    return _camera.handleAppLifecycleState(state);
  }

  /// Converts [DivineFlashMode] to [DivineCameraFlashMode] mode.
  DivineCameraFlashMode _getFlashMode(DivineFlashMode mode) {
    return switch (mode) {
      .torch => .torch,
      .auto => .auto,
      .off => .off,
    };
  }

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get canRecord => isInitialized;

  @override
  double get cameraAspectRatio => _camera.cameraAspectRatio;

  @override
  double get minZoomLevel => _camera.minZoomLevel;

  @override
  double get maxZoomLevel => _camera.maxZoomLevel;

  @override
  bool get isFocusPointSupported => _camera.isFocusPointSupported;

  @override
  bool get hasFlash => _camera.hasFlash;

  @override
  bool get canSwitchCamera => _camera.canSwitchCamera;

  @override
  String? get initializationError => _initializationError;
}
