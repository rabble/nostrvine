// ABOUTME: Mobile platform implementation of camera service using the camera package
// ABOUTME: Handles camera initialization, switching, recording, and lifecycle management on mobile devices

import 'package:divine_camera/divine_camera.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/models/video_recorder/video_recorder_flash_mode.dart';
import 'package:openvine/services/video_recorder/camera/camera_base_service.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

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
  Future<void> initialize({
    DivineVideoQuality videoQuality = DivineVideoQuality.fhd,
    DivineCameraLens initialLens = DivineCameraLens.front,
  }) async {
    // Clear any previous error
    _initializationError = null;

    Log.info(
      '📷 Initializing mobile camera with quality: ${videoQuality.value}, '
      'lens: ${initialLens.displayName}',
      name: 'CameraMobileService',
      category: .video,
    );
    try {
      await _camera.initialize(lens: initialLens, videoQuality: videoQuality);
      _camera.onRecordingAutoStopped = (result) {
        onAutoStopped(EditorVideo.file(result.filePath));
      };
      // Re-apply remote record trigger callback (gets cleared on dispose)
      if (_remoteRecordTriggerCallback != null) {
        final callback = _remoteRecordTriggerCallback!;
        _camera.onRemoteRecordTrigger = (trigger) {
          Log.info(
            '🎮 Native remote trigger received: $trigger',
            name: 'CameraMobileService',
            category: .video,
          );
          callback();
        };
        Log.debug(
          '🎮 Remote record trigger callback re-applied after initialize',
          name: 'CameraMobileService',
          category: .video,
        );
      }
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
  Future<bool> setLens(DivineCameraLens lens) async {
    if (!_isInitialized) return false;
    try {
      Log.info(
        '📷 Switching to lens: ${lens.displayName}',
        name: 'CameraMobileService',
        category: .video,
      );

      final success = await _camera.setLens(lens);
      if (success) {
        onUpdateState(forceCameraRebuild: true);
        Log.info(
          '📷 Switched to lens: ${lens.displayName}',
          name: 'CameraMobileService',
          category: .video,
        );
      }
      return success;
    } catch (e) {
      Log.error(
        '📷 Failed to set lens: $e',
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
      final docsDir = await getDocumentsPath();
      final outputPath = outputDirectory ?? docsDir;

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
  DivineCameraLens get currentLens => _camera.state.lens;

  @override
  List<DivineCameraLens> get availableLenses => _camera.state.availableLenses;

  @override
  CameraLensMetadata? get currentLensMetadata =>
      _camera.state.currentLensMetadata;

  @override
  String? get initializationError => _initializationError;

  void Function()? _remoteRecordTriggerCallback;

  @override
  set onRemoteRecordTrigger(void Function()? callback) {
    _remoteRecordTriggerCallback = callback;
    // Connect to native callback with logging
    _camera.onRemoteRecordTrigger = callback != null
        ? (trigger) {
            Log.info(
              '🎮 Native remote trigger received: $trigger',
              name: 'CameraMobileService',
              category: .video,
            );
            callback();
          }
        : null;
    Log.debug(
      '🎮 Remote record trigger callback ${callback != null ? 'set' : 'cleared'}',
      name: 'CameraMobileService',
      category: .video,
    );
  }

  @override
  Future<bool> setRemoteRecordControlEnabled({required bool enabled}) async {
    if (!_isInitialized) return false;
    try {
      Log.info(
        '📷 Setting remote record control: ${enabled ? 'enabled' : 'disabled'}',
        name: 'CameraMobileService',
        category: LogCategory.video,
      );
      final success = await _camera.setRemoteRecordControlEnabled(
        enabled: enabled,
      );
      return success;
    } catch (e) {
      Log.error(
        '📷 Failed to set remote record control: $e',
        name: 'CameraMobileService',
        category: LogCategory.video,
      );
      return false;
    }
  }

  @override
  Future<bool> setVolumeKeysEnabled({required bool enabled}) async {
    if (!_isInitialized) return false;
    try {
      Log.debug(
        '📷 Setting volume keys: ${enabled ? 'enabled' : 'disabled'}',
        name: 'CameraMobileService',
        category: LogCategory.video,
      );
      final success = await _camera.setVolumeKeysEnabled(enabled: enabled);
      return success;
    } catch (e) {
      Log.error(
        '📷 Failed to set volume keys enabled: $e',
        name: 'CameraMobileService',
        category: LogCategory.video,
      );
      return false;
    }
  }
}
