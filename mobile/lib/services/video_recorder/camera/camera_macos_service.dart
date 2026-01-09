// ABOUTME: macOS platform implementation of camera service using the camera_macos package
// ABOUTME: Handles camera and audio device management, recording, and torch control on macOS

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
  CameraMacOSService({required super.onUpdateState});

  List<CameraMacOSDevice>? _videoDevices;
  List<CameraMacOSDevice>? _audioDevices;

  int _currentCameraIndex = 0;

  final double _minZoomLevel = 1;
  final double _maxZoomLevel = 10;
  Size _cameraSensorSize = const Size(500, 500);
  int _textureId = 0;
  TapDownDetails? _tapDownDetails;

  bool _hasFlash = false;
  bool _isRecording = false;
  bool _isInitialized = false;
  bool _isInBackground = false;
  bool _isInitialSetupCompleted = false;

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
    _isInitialized = false;

    await CameraMacOS.instance.destroy();
  }

  /// Initializes the camera with the current video and audio device.
  ///
  /// Sets up the camera in video mode with the selected devices.
  Future<void> _initializeCameraController() async {
    if (_videoDevices == null) return;

    final deviceId = _videoDevices![_currentCameraIndex].deviceId;
    final result = await CameraMacOS.instance.initialize(
      cameraMacOSMode: CameraMacOSMode.video,
      deviceId: deviceId,
      audioDeviceId: _audioDevices?.first.deviceId,
    );
    _isInitialized = true;

    _textureId = result?.textureId ?? 0;
    _cameraSensorSize = result?.size ?? const Size(500, 500);

    final hasFlash = await CameraMacOS.instance.hasFlash(deviceId: deviceId);
    _hasFlash = hasFlash;
    onUpdateState(forceCameraRebuild: true);
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
  Future<void> startRecording() async {
    try {
      Log.info(
        '📷 Starting macOS video recording',
        name: 'CameraMacOSService',
        category: .video,
      );

      // Use /tmp/ directory which we have permission to write to
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = '/tmp/openvine_recording_$timestamp.mp4';

      await CameraMacOS.instance.startVideoRecording(url: outputPath);
      _isRecording = true;

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
        _isInBackground = true;
        if (isInitialized) {
          await dispose();
          onUpdateState(forceCameraRebuild: true);
        }
      case .resumed:
        _isInBackground = false;
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

  @override
  Widget buildPreviewWidget({
    required void Function(ScaleStartDetails details) onScaleStart,
    required void Function(ScaleUpdateDetails details) onScaleUpdate,
    required void Function(TapDownDetails details, BoxConstraints constraints)
    onTapDown,
  }) {
    if (_isInBackground || !_isInitialized) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return GestureDetector(
          behavior: .opaque,
          onScaleStart: onScaleStart,
          onScaleUpdate: onScaleUpdate,
          onTapDown: (details) => _tapDownDetails = details,
          onTap: () {
            if (_tapDownDetails != null) {
              onTapDown(_tapDownDetails!, constraints);
            }
          },
          child: CameraMacOSRawView(
            cameraSize: _cameraSensorSize,
            textureId: _textureId,
          ),
        );
      },
    );
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
