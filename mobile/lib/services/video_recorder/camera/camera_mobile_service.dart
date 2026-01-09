// ABOUTME: Mobile platform implementation of camera service using the camera package
// ABOUTME: Handles camera initialization, switching, recording, and lifecycle management on mobile devices

import 'package:camerawesome/camerawesome_plugin.dart';
import 'package:camerawesome/pigeon.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/models/video_recorder/video_recorder_flash_mode.dart';
import 'package:openvine/services/video_recorder/camera/camera_base_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// Mobile implementation of [CameraService] using the camera package.
///
/// Manages camera initialization, recording, and switching between front/back cameras.
class CameraMobileService extends CameraService {
  /// Creates a mobile camera service instance.
  CameraMobileService({required super.onUpdateState});

  CameraState? _cameraState;

  double _minZoomLevel = 1;
  double _maxZoomLevel = 1;
  Size _previewSize = Size.zero;

  bool _isInitialized = false;
  bool _isInitialSetupCompleted = false;
  TapDownDetails? _tapDownDetails;

  @override
  Future<void> initialize() async {
    Log.info(
      '📷 Initializing mobile camera',
      name: 'CameraMobileService',
      category: .video,
    );

    // CamerAwesome requires initialization through the CameraAwesomeBuilder
    // widget.
    // We mark as initialized immediately since the actual camera setup happens
    // in buildPreviewWidget() when the widget is built. Zoom limits are loaded
    // asynchronously after the camera starts.
    _isInitialized = true;
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
    await CamerawesomePlugin.stop();
    _isInitialSetupCompleted = false;
  }

  Future<void> _loadZoomLimits() async {
    if (!_isInitialized) {
      Log.warning(
        '📷 Cannot load zoom limits: Camera not initialized',
        name: 'CameraMobileService',
        category: .video,
      );
      return;
    }

    try {
      // Get zoom limits in parallel for faster initialization
      final results = await Future.wait([
        CamerawesomePlugin.getMinZoom(),
        CamerawesomePlugin.getMaxZoom(),
      ]);
      _minZoomLevel = results[0] ?? 1;
      _maxZoomLevel = results[1] ?? 1;
    } catch (e) {
      Log.error(
        '📷 Failed to load zoom limits (unexpected error): $e',
        name: 'CameraMobileService',
        category: .video,
      );
    }
  }

  @override
  Future<bool> setFlashMode(DivineFlashMode mode) async {
    if (!isInitialized || _cameraState == null) {
      Log.warning(
        '📷 Cannot set flash mode: Camera not initialized or state is null',
        name: 'CameraMobileService',
        category: .video,
      );
      return false;
    }
    try {
      Log.info(
        '📷 Setting flash mode to ${mode.name}',
        name: 'CameraMobileService',
        category: .video,
      );
      await _cameraState!.sensorConfig.setFlashMode(_getFlashMode(mode));
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
    if (!isInitialized ||
        _cameraState == null ||
        _cameraState is! VideoCameraState) {
      Log.warning(
        '📷 Cannot set focus point: Camera not initialized or state is null',
        name: 'CameraMobileService',
        category: .video,
      );
      return false;
    }
    try {
      Log.info(
        '📷 Setting focus point to (${offset.dx}, ${offset.dy})',
        name: 'CameraMobileService',
        category: .video,
      );

      final previewSize = PreviewSize(
        width: _previewSize.width,
        height: _previewSize.height,
      );

      await (_cameraState! as VideoCameraState).focusOnPoint(
        flutterPosition: Offset(
          previewSize.width * offset.dx,
          previewSize.height * offset.dy,
        ),
        flutterPreviewSize: previewSize,
        pixelPreviewSize: previewSize,
      );
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
    if (!isInitialized) {
      Log.warning(
        '📷 Cannot set exposure point: Camera not initialized',
        name: 'CameraMobileService',
        category: .video,
      );
      return false;
    }
    try {
      Log.info(
        '📷 Setting exposure point to (${offset.dx}, ${offset.dy})',
        name: 'CameraMobileService',
        category: .video,
      );
      // CamerAwesome doesn't support setting exposure point separately.
      // The exposure is automatically handled together with focus point
      // in setFocusPoint(), so we return true here without doing anything.
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
    if (!isInitialized || _cameraState == null) {
      Log.warning(
        '📷 Cannot set zoom level: Camera not initialized or state is null',
        name: 'CameraMobileService',
        category: .video,
      );
      return false;
    }
    try {
      Log.info(
        '📷 Setting zoom level to $value',
        name: 'CameraMobileService',
        category: .video,
      );

      // Convert zoom value from [minZoomLevel, maxZoomLevel] to [0.0, 1.0]
      final normalizedZoom = (_maxZoomLevel - _minZoomLevel) > 0
          ? (value - _minZoomLevel) / (_maxZoomLevel - _minZoomLevel)
          : 0.0;

      await _cameraState!.sensorConfig.setZoom(normalizedZoom.clamp(0.0, 1.0));
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
    if (_cameraState == null) {
      Log.warning(
        '📷 Cannot switch camera: Camera state is null',
        name: 'CameraMobileService',
        category: .video,
      );
      return false;
    }

    try {
      Log.info(
        '📷 Switching camera',
        name: 'CameraMobileService',
        category: .video,
      );

      await _cameraState!.switchCameraSensor();

      await _loadZoomLimits();

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
  Future<void> startRecording() async {
    if (_cameraState == null || _cameraState is! VideoCameraState) {
      Log.warning(
        '📷 Cannot start recording: Camera state is null or not in video mode',
        name: 'CameraMobileService',
        category: .video,
      );
      return;
    }
    try {
      Log.info(
        '📷 Starting video recording',
        name: 'CameraMobileService',
        category: .video,
      );
      await (_cameraState! as VideoCameraState).startRecording();
    } catch (e) {
      Log.error(
        '📷 Failed to start recording (unexpected error): $e',
        name: 'CameraMobileService',
        category: .video,
      );
    }
  }

  @override
  Future<EditorVideo?> stopRecording() async {
    if (_cameraState == null || _cameraState is! VideoRecordingCameraState) {
      Log.warning(
        '📷 Cannot stop recording: Camera state is null or not currently '
        'recording',
        name: 'CameraMobileService',
        category: .video,
      );
      return null;
    }

    try {
      Log.info(
        '📷 Stopping video recording',
        name: 'CameraMobileService',
        category: .video,
      );

      late final String? resultPath;
      await (_cameraState! as VideoRecordingCameraState).stopRecording(
        onVideo: (request) {
          resultPath = request.path;
        },
      );

      Log.info(
        '📷 Video recording stopped',
        name: 'CameraMobileService',
        category: .video,
      );
      if (resultPath == null) return null;

      return EditorVideo.autoSource(file: resultPath);
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
    if (_cameraState == null || !_isInitialSetupCompleted) {
      Log.warning(
        '📷 Cannot handle lifecycle state: Camera state is null',
        name: 'CameraMobileService',
        category: .video,
      );
      return;
    }

    _isInitialized = state == .resumed;
    onUpdateState(forceCameraRebuild: true);

    Log.info(
      '📷 App lifecycle state changed to ${state.name}',
      name: 'CameraMobileService',
      category: .video,
    );
  }

  @override
  Widget buildPreviewWidget({
    required void Function(ScaleStartDetails details) onScaleStart,
    required void Function(ScaleUpdateDetails details) onScaleUpdate,
    required void Function(TapDownDetails details, BoxConstraints constraints)
    onTapDown,
  }) {
    if (!_isInitialized) return Container(color: const Color(0xFF141414));

    return CameraAwesomeBuilder.custom(
      saveConfig: SaveConfig.video(),
      progressIndicator: Container(color: const Color(0xFF141414)),
      loadingWidget: Container(color: const Color(0xFF141414)),
      builder: (state, preview) {
        // The builder callback is called multiple times during rebuilds.
        // We only want to load zoom limits once when the camera is first ready,
        // not on every rebuild. This ensures we don't spam the native API.
        if (!_isInitialSetupCompleted) {
          _isInitialSetupCompleted = true;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            await _loadZoomLimits();
            onUpdateState();
          });
        }

        _cameraState = state;
        _previewSize = preview.nativePreviewSize;
        return LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onScaleStart: onScaleStart,
              onScaleUpdate: onScaleUpdate,
              onTapDown: (details) => _tapDownDetails = details,
              onTap: () {
                if (_tapDownDetails != null) {
                  onTapDown(_tapDownDetails!, constraints);
                }
              },
              // Important: We need to keep OnTapUp so that we can create our
              // own FocusPoint design.
              onTapUp: (_) {},
              child: Container(),
            );
          },
        );
      },
    );
  }

  /// Converts [DivineFlashMode] to camerawesome [FlashMode] mode.
  FlashMode _getFlashMode(DivineFlashMode mode) {
    return switch (mode) {
      .torch => .always,
      .auto => .auto,
      .off => .none,
    };
  }

  @override
  double get cameraAspectRatio {
    switch (_cameraState?.sensorConfig.aspectRatio) {
      case .ratio_16_9:
        return 16 / 9;
      case .ratio_4_3:
        return 4 / 3;
      case .ratio_1_1:
      case null:
        return 1;
    }
  }

  @override
  double get minZoomLevel => _minZoomLevel;

  @override
  double get maxZoomLevel => _maxZoomLevel;

  @override
  bool get isInitialized => _isInitialized;

  @override
  bool get isFocusPointSupported => true;

  @override
  bool get canRecord => isInitialized;

  @override
  bool get hasFlash => true;

  @override
  bool get canSwitchCamera =>
      _cameraState?.sensorConfig.sensors.isNotEmpty ?? false;
}
