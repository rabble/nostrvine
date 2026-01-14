// ABOUTME: State class for camera operations
// ABOUTME: Holds current camera configuration and status

import 'package:divine_camera/src/models/camera_lens.dart';
import 'package:divine_camera/src/models/flash_mode.dart';
import 'package:equatable/equatable.dart';

/// Represents the current state of the camera.
class CameraState extends Equatable {
  /// Creates a new camera state.
  const CameraState({
    this.isInitialized = false,
    this.isRecording = false,
    this.isSwitchingCamera = false,
    this.flashMode = DivineCameraFlashMode.off,
    this.lens = DivineCameraLens.back,
    this.zoomLevel = 1.0,
    this.minZoomLevel = 1.0,
    this.maxZoomLevel = 1.0,
    this.aspectRatio = 16 / 9,
    this.hasFlash = false,
    this.hasFrontCamera = false,
    this.hasBackCamera = false,
    this.isFocusPointSupported = false,
    this.isExposurePointSupported = false,
    this.textureId,
  });

  /// Creates a [CameraState] from a map.
  factory CameraState.fromMap(Map<dynamic, dynamic> map) {
    return CameraState(
      isInitialized: map['isInitialized'] as bool? ?? false,
      isRecording: map['isRecording'] as bool? ?? false,
      isSwitchingCamera: map['isSwitchingCamera'] as bool? ?? false,
      flashMode: DivineCameraFlashMode.fromNativeString(
        map['flashMode'] as String? ?? 'off',
      ),
      lens: DivineCameraLens.fromNativeString(map['lens'] as String? ?? 'back'),
      zoomLevel: (map['zoomLevel'] as num?)?.toDouble() ?? 1.0,
      minZoomLevel: (map['minZoomLevel'] as num?)?.toDouble() ?? 1.0,
      maxZoomLevel: (map['maxZoomLevel'] as num?)?.toDouble() ?? 1.0,
      aspectRatio: (map['aspectRatio'] as num?)?.toDouble() ?? (16 / 9),
      hasFlash: map['hasFlash'] as bool? ?? false,
      hasFrontCamera: map['hasFrontCamera'] as bool? ?? false,
      hasBackCamera: map['hasBackCamera'] as bool? ?? false,
      isFocusPointSupported: map['isFocusPointSupported'] as bool? ?? false,
      isExposurePointSupported:
          map['isExposurePointSupported'] as bool? ?? false,
      textureId: map['textureId'] as int?,
    );
  }

  /// Whether the camera is initialized.
  final bool isInitialized;

  /// Whether the camera is currently recording.
  final bool isRecording;

  /// Whether the camera is currently switching between front and back.
  final bool isSwitchingCamera;

  /// The current flash mode.
  final DivineCameraFlashMode flashMode;

  /// The current camera lens.
  final DivineCameraLens lens;

  /// The current zoom level.
  final double zoomLevel;

  /// The minimum zoom level.
  final double minZoomLevel;

  /// The maximum zoom level.
  final double maxZoomLevel;

  /// The aspect ratio of the camera preview.
  final double aspectRatio;

  /// Whether the camera has a flash.
  final bool hasFlash;

  /// Whether the device has a front camera.
  final bool hasFrontCamera;

  /// Whether the device has a back camera.
  final bool hasBackCamera;

  /// Whether manual focus point selection is supported.
  final bool isFocusPointSupported;

  /// Whether manual exposure point selection is supported.
  final bool isExposurePointSupported;

  /// The texture ID for the camera preview (Android).
  final int? textureId;

  /// Whether the camera can record video.
  bool get canRecord => isInitialized && !isRecording;

  /// Whether the camera can switch between front and back.
  bool get canSwitchCamera => hasFrontCamera && hasBackCamera;

  /// Creates a copy of this state with the given fields replaced.
  CameraState copyWith({
    bool? isInitialized,
    bool? isRecording,
    bool? isSwitchingCamera,
    DivineCameraFlashMode? flashMode,
    DivineCameraLens? lens,
    double? zoomLevel,
    double? minZoomLevel,
    double? maxZoomLevel,
    double? aspectRatio,
    bool? hasFlash,
    bool? hasFrontCamera,
    bool? hasBackCamera,
    bool? isFocusPointSupported,
    bool? isExposurePointSupported,
    int? textureId,
  }) {
    return CameraState(
      isInitialized: isInitialized ?? this.isInitialized,
      isRecording: isRecording ?? this.isRecording,
      isSwitchingCamera: isSwitchingCamera ?? this.isSwitchingCamera,
      flashMode: flashMode ?? this.flashMode,
      lens: lens ?? this.lens,
      zoomLevel: zoomLevel ?? this.zoomLevel,
      minZoomLevel: minZoomLevel ?? this.minZoomLevel,
      maxZoomLevel: maxZoomLevel ?? this.maxZoomLevel,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      hasFlash: hasFlash ?? this.hasFlash,
      hasFrontCamera: hasFrontCamera ?? this.hasFrontCamera,
      hasBackCamera: hasBackCamera ?? this.hasBackCamera,
      isFocusPointSupported:
          isFocusPointSupported ?? this.isFocusPointSupported,
      isExposurePointSupported:
          isExposurePointSupported ?? this.isExposurePointSupported,
      textureId: textureId ?? this.textureId,
    );
  }

  /// Converts this [CameraState] to a map.
  Map<String, dynamic> toMap() {
    return {
      'isInitialized': isInitialized,
      'isRecording': isRecording,
      'isSwitchingCamera': isSwitchingCamera,
      'flashMode': flashMode.name,
      'lens': lens.name,
      'zoomLevel': zoomLevel,
      'minZoomLevel': minZoomLevel,
      'maxZoomLevel': maxZoomLevel,
      'aspectRatio': aspectRatio,
      'hasFlash': hasFlash,
      'hasFrontCamera': hasFrontCamera,
      'hasBackCamera': hasBackCamera,
      'isFocusPointSupported': isFocusPointSupported,
      'isExposurePointSupported': isExposurePointSupported,
      'textureId': textureId,
    };
  }

  @override
  String toString() {
    return 'CameraState(isInitialized: $isInitialized, '
        'isRecording: $isRecording, '
        'isSwitchingCamera: $isSwitchingCamera, '
        'flashMode: $flashMode, '
        'lens: $lens, '
        'zoomLevel: $zoomLevel, '
        'minZoomLevel: $minZoomLevel, '
        'maxZoomLevel: $maxZoomLevel, '
        'aspectRatio: $aspectRatio, '
        'hasFlash: $hasFlash, '
        'hasFrontCamera: $hasFrontCamera, '
        'hasBackCamera: $hasBackCamera, '
        'isFocusPointSupported: $isFocusPointSupported, '
        'isExposurePointSupported: $isExposurePointSupported, '
        'textureId: $textureId)';
  }

  @override
  List<Object?> get props => [
    isInitialized,
    isRecording,
    isSwitchingCamera,
    flashMode,
    lens,
    zoomLevel,
    minZoomLevel,
    maxZoomLevel,
    aspectRatio,
    hasFlash,
    hasFrontCamera,
    hasBackCamera,
    isFocusPointSupported,
    isExposurePointSupported,
    textureId,
  ];
}
