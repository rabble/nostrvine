// ABOUTME: Base service for camera operations across different platforms
// ABOUTME: Provides unified API for camera control, recording, and preview

import 'dart:io';

import 'package:divine_camera/divine_camera.dart'
    show CameraLensMetadata, DivineCameraLens, DivineVideoQuality;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/models/video_recorder/video_recorder_flash_mode.dart';
import 'package:openvine/services/video_recorder/camera/camera_macos_service.dart';
import 'package:openvine/services/video_recorder/camera/camera_mobile_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

/// Base service for camera operations across different platforms.
/// Provides a unified API for camera control, recording, and preview.
abstract class CameraService {
  /// Protected constructor for subclasses
  CameraService({required this.onUpdateState, required this.onAutoStopped});

  /// Factory constructor that returns the appropriate camera service
  /// implementation based on the current platform.
  factory CameraService.create({
    required void Function({bool? forceCameraRebuild}) onUpdateState,
    required void Function(EditorVideo video) onAutoStopped,
  }) {
    if (!kIsWeb && Platform.isMacOS) {
      return CameraMacOSService(
        onUpdateState: onUpdateState,
        onAutoStopped: onAutoStopped,
      );
    }
    return CameraMobileService(
      onUpdateState: onUpdateState,
      onAutoStopped: onAutoStopped,
    );
  }

  /// Callback to trigger UI updates when camera state changes.
  final void Function({bool? forceCameraRebuild}) onUpdateState;

  final void Function(EditorVideo video) onAutoStopped;

  /// Initializes the camera and prepares it for use.
  ///
  /// [videoQuality] specifies the video recording quality (default: FHD/1080p).
  Future<void> initialize({
    DivineVideoQuality videoQuality = DivineVideoQuality.fhd,
  });

  /// Releases camera resources and cleans up.
  Future<void> dispose();

  /// Sets the flash mode. Returns true if successful.
  Future<bool> setFlashMode(DivineFlashMode mode);

  /// Sets the focus point in normalized coordinates (0.0-1.0).
  Future<bool> setFocusPoint(Offset offset);

  /// Sets the exposure point in normalized coordinates (0.0-1.0).
  Future<bool> setExposurePoint(Offset offset);

  /// Sets the zoom level. Returns true if successful.
  Future<bool> setZoomLevel(double value);

  /// Switches between front and back camera. Returns true if successful.
  Future<bool> switchCamera();

  /// Switches to a specific camera lens. Returns true if successful.
  Future<bool> setLens(DivineCameraLens lens);

  /// Starts video recording.
  /// [outputDirectory] specifies where to save the video.
  Future<bool> startRecording({Duration? maxDuration, String? outputDirectory});

  /// Stops video recording.
  Future<EditorVideo?> stopRecording();

  /// Handles app lifecycle changes (pause, resume, etc.).
  Future<void> handleAppLifecycleState(AppLifecycleState state);

  /// The aspect ratio of the camera sensor.
  double get cameraAspectRatio;

  /// Minimum zoom level supported by the camera.
  double get minZoomLevel;

  /// Maximum zoom level supported by the camera.
  double get maxZoomLevel;

  /// Whether the camera is initialized and ready to use.
  bool get isInitialized;

  /// Whether the camera supports manual focus point selection.
  bool get isFocusPointSupported;

  /// Whether the camera is ready to record (initialized and not recording).
  bool get canRecord;

  /// Whether the device has multiple cameras to switch between.
  bool get canSwitchCamera;

  /// Whether the device can active the camera-flash.
  bool get hasFlash;

  /// The current active camera lens.
  DivineCameraLens get currentLens;

  /// List of available camera lenses on this device.
  List<DivineCameraLens> get availableLenses;

  /// Metadata for the currently active camera lens.
  /// Returns null if metadata is not available.
  CameraLensMetadata? get currentLensMetadata;

  /// Error message if initialization failed, null if successful.
  String? get initializationError;
}
