// ABOUTME: macOS platform implementation of camera service using the camera_macos package
// ABOUTME: Handles camera and audio device management, recording, and torch control on macOS

import 'dart:async';
import 'dart:io';

import 'package:camera_macos_plus/camera_macos.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/models/video_recorder/video_recorder_flash_mode.dart';
import 'package:openvine/services/video_recorder/camera/camera_base_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// macOS implementation of [CameraService] using the camera_macos package.
///
/// Manages video and audio devices, recording, and camera switching on macOS.
class CameraMacOSService extends CameraService {
  /// Creates a macOS camera service instance.
  CameraMacOSService({
    required super.onUpdateState,
    required super.onAutoStopped,
  });

  List<CameraMacOSDevice>? _videoDevices;
  List<CameraMacOSDevice>? _audioDevices;

  int _currentCameraIndex = 0;

  final double _minZoomLevel = 1;
  final double _maxZoomLevel = 10;
  Size _cameraSensorSize = const Size(500, 500);

  bool _hasFlash = false;
  bool _isRecording = false;
  bool _isInitialized = false;
  bool _isInitialSetupCompleted = false;
  Timer? _autoStopTimer;

  @override
  Future<void> initialize() async {
    if (_isInitialized) return;

    Log.info(
      '📷 Initializing macOS camera',
      name: 'CameraMacOSService',
      category: .video,
    );

    _videoDevices ??= await CameraMacOS.instance.listDevices(
      deviceType: CameraMacOSDeviceType.video,
    );
    _audioDevices ??= await CameraMacOS.instance.listDevices(
      deviceType: CameraMacOSDeviceType.audio,
    );

    await _initializeCameraController();
    _isInitialSetupCompleted = true;

    Log.info(
      '📷 macOS camera initialized (${_videoDevices!.length} video, '
      '${_audioDevices!.length} audio devices)',
      name: 'CameraMacOSService',
      category: .video,
    );
  }

  @override
  Future<void> dispose() async {
    if (!_isInitialized) return;

    Log.info(
      '📷 Disposing macOS camera',
      name: 'CameraMacOSService',
      category: .video,
    );
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    _isInitialized = false;

    await CameraMacOS.instance.destroy();
  }

  /// Initializes the camera with the current video and audio device.
  ///
  /// Sets up the camera in video mode with the selected devices.
  Future<void> _initializeCameraController() async {
    if (_videoDevices == null) return;

    try {
      final deviceId = _videoDevices![_currentCameraIndex].deviceId;
      final result = await CameraMacOS.instance.initialize(
        cameraMacOSMode: CameraMacOSMode.video,
        deviceId: deviceId,
        audioDeviceId: _audioDevices?.first.deviceId,
      );
      _isInitialized = true;

      _cameraSensorSize = result?.size ?? const Size(500, 500);

      final hasFlash = await CameraMacOS.instance.hasFlash(deviceId: deviceId);
      _hasFlash = hasFlash;
      onUpdateState(forceCameraRebuild: true);
    } catch (e) {
      Log.error(
        '📷 Failed to initialize camera controller: $e',
        name: 'CameraMacOSService',
        category: .video,
      );
    }
  }

  @override
  Future<bool> setFlashMode(DivineFlashMode mode) async {
    if (!isInitialized) return false;
    try {
      Log.info(
        '📷 Setting torch mode to ${mode.name}',
        name: 'CameraMacOSService',
        category: .video,
      );
      await CameraMacOS.instance.toggleTorch(_getFlashMode(mode));
      return true;
    } catch (e) {
      Log.error(
        '📷 Failed to set torch mode: $e',
        name: 'CameraMacOSService',
        category: .video,
      );
      return false;
    }
  }

  @override
  Future<bool> setFocusPoint(Offset offset) async {
    if (!isInitialized) return false;
    try {
      Log.info(
        '📷 Setting focus point to (${offset.dx}, ${offset.dy})',
        name: 'CameraMacOSService',
        category: .video,
      );
      await CameraMacOS.instance.setFocusPoint(offset);
      return true;
    } catch (e) {
      Log.error(
        '📷 Failed to set focus point: $e',
        name: 'CameraMacOSService',
        category: .video,
      );
      return false;
    }
  }

  @override
  Future<bool> setExposurePoint(Offset offset) async {
    if (!isInitialized) return false;
    try {
      Log.info(
        '📷 Setting exposure point to (${offset.dx}, ${offset.dy})',
        name: 'CameraMacOSService',
        category: .video,
      );
      await CameraMacOS.instance.setExposurePoint(offset);
      return true;
    } catch (e) {
      Log.error(
        '📷 Failed to set exposure point: $e',
        name: 'CameraMacOSService',
        category: .video,
      );
      return false;
    }
  }

  @override
  Future<bool> setZoomLevel(double value) async {
    if (!isInitialized) return false;
    try {
      Log.info(
        '📷 Setting zoom level to $value',
        name: 'CameraMacOSService',
        category: .video,
      );
      await CameraMacOS.instance.setZoomLevel(value);
      return true;
    } catch (e) {
      Log.error(
        '📷 Failed to set zoom level: $e',
        name: 'CameraMacOSService',
        category: .video,
      );
      return false;
    }
  }

  @override
  Future<bool> switchCamera() async {
    if (_videoDevices != null && _videoDevices!.length <= 1) return false;

    try {
      Log.info(
        '📷 Switching macOS camera',
        name: 'CameraMacOSService',
        category: .video,
      );

      await CameraMacOS.instance.destroy();

      _currentCameraIndex = (_currentCameraIndex + 1) % _videoDevices!.length;

      await _initializeCameraController();

      Log.info(
        '📷 macOS camera switched to device $_currentCameraIndex',
        name: 'CameraMacOSService',
        category: .video,
      );
      return true;
    } catch (e) {
      Log.error(
        '📷 Failed to switch macOS camera: $e',
        name: 'CameraMacOSService',
        category: .video,
      );
      return false;
    }
  }

  @override
  Future<void> startRecording({Duration? maxDuration}) async {
    try {
      Log.info(
        '📷 Starting macOS video recording',
        name: 'CameraMacOSService',
        category: .video,
      );

      // Use system temp directory which we have permission to write to
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath =
          '${Directory.systemTemp.path}/'
          'openvine_recording_$timestamp.mp4';

      await CameraMacOS.instance.startVideoRecording(url: outputPath);
      _isRecording = true;

      // Set up auto-stop timer if maxDuration is specified
      if (maxDuration != null) {
        Log.info(
          '📷 Auto-stop timer set for ${maxDuration.inSeconds}s',
          name: 'CameraMacOSService',
          category: .video,
        );
        _autoStopTimer = Timer(maxDuration, () async {
          Log.info(
            '📷 Max duration reached, auto-stopping recording',
            name: 'CameraMacOSService',
            category: .video,
          );
          await stopRecording();
        });
      }

      Log.info(
        '📷 Recording to: $outputPath',
        name: 'CameraMacOSService',
        category: .video,
      );
    } catch (e) {
      Log.error(
        '📷 Failed to start recording: $e',
        name: 'CameraMacOSService',
        category: .video,
      );
    }
  }

  @override
  Future<EditorVideo?> stopRecording() async {
    try {
      Log.info(
        '📷 Stopping macOS video recording',
        name: 'CameraMacOSService',
        category: .video,
      );

      _autoStopTimer?.cancel();
      _autoStopTimer = null;

      final result = await CameraMacOS.instance.stopVideoRecording();
      _isRecording = false;

      if (result?.bytes == null) {
        Log.warning(
          '📷 macOS video recording stopped with null result',
          name: 'CameraMacOSService',
          category: .video,
        );
        return null;
      }

      Log.info(
        '📷 macOS video recording stopped',
        name: 'CameraMacOSService',
        category: .video,
      );

      return EditorVideo.memory(result!.bytes!);
    } catch (e) {
      Log.error(
        '📷 Failed to stop recording: $e',
        name: 'CameraMacOSService',
        category: .video,
      );
      _isRecording = false;
      return null;
    }
  }

  @override
  Future<void> handleAppLifecycleState(AppLifecycleState state) async {
    Log.info(
      '📷 macOS app lifecycle state changed to ${state.name}',
      name: 'CameraMacOSService',
      category: .video,
    );
    switch (state) {
      case .hidden:
      case .detached:
      case .paused:
      case .inactive:
        if (isInitialized) {
          await dispose();
          onUpdateState(forceCameraRebuild: true);
        }
      case .resumed:
        // Only reinitialize if we had a successful initialization before
        // (prevents reinitialization attempts when coming back from permission
        // dialog)
        if (_isInitialSetupCompleted) {
          await _initializeCameraController();

          Log.info(
            '📷 macOS camera reinitialized after resume',
            name: 'CameraMacOSService',
            category: .video,
          );
        }
    }
  }

  /// Converts [DivineFlashMode] to macOS [Torch] mode.
  ///
  /// Maps camera package flash modes to camera_macos torch settings.
  Torch _getFlashMode(DivineFlashMode mode) {
    return switch (mode) {
      .torch => .on,
      .auto => .auto,
      .off => .off,
    };
  }

  @override
  double get cameraAspectRatio => 1 / _cameraSensorSize.aspectRatio;

  @override
  double get minZoomLevel => _minZoomLevel;
  @override
  double get maxZoomLevel => _maxZoomLevel;

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get isFocusPointSupported => true;

  @override
  bool get canRecord => _isInitialized && !_isRecording;

  @override
  bool get hasFlash => _hasFlash;

  @override
  bool get canSwitchCamera =>
      _videoDevices != null && _videoDevices!.length > 1;
}
