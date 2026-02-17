// ABOUTME: Method channel implementation for divine_camera plugin
// ABOUTME: Handles native platform communication via Flutter method channels

import 'package:divine_camera/divine_camera_platform_interface.dart';
import 'package:divine_camera/src/models/camera_lens.dart';
import 'package:divine_camera/src/models/camera_state.dart';
import 'package:divine_camera/src/models/flash_mode.dart';
import 'package:divine_camera/src/models/video_quality.dart';
import 'package:divine_camera/src/models/video_recording_result.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// An implementation of [DivineCameraPlatform] that uses method channels.
class MethodChannelDivineCamera extends DivineCameraPlatform {
  /// Constructor that sets up method call handler for native callbacks.
  MethodChannelDivineCamera() {
    methodChannel.setMethodCallHandler(_handleMethodCall);
  }

  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('divine_camera');

  /// Callback for when recording auto-stops due to max duration.
  void Function(VideoRecordingResult result)? _onRecordingAutoStopped;

  @override
  void Function(VideoRecordingResult result)? get onRecordingAutoStopped =>
      _onRecordingAutoStopped;

  @override
  set onRecordingAutoStopped(
    void Function(VideoRecordingResult result)? callback,
  ) {
    _onRecordingAutoStopped = callback;
  }

  /// Handles method calls from native platform.
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onRecordingAutoStopped':
        final args = call.arguments as Map<dynamic, dynamic>?;
        if (args != null && onRecordingAutoStopped != null) {
          final result = VideoRecordingResult.fromMap(args);
          onRecordingAutoStopped!(result);
        }
        return null;
      default:
        return null;
    }
  }

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  Future<CameraState> initializeCamera({
    DivineCameraLens lens = DivineCameraLens.back,
    DivineVideoQuality videoQuality = DivineVideoQuality.fhd,
    bool enableScreenFlash = true,
    bool mirrorFrontCameraOutput = true,
  }) async {
    final result = await methodChannel.invokeMapMethod<dynamic, dynamic>(
      'initializeCamera',
      {
        'lens': lens.toNativeString(),
        'videoQuality': videoQuality.value,
        'enableScreenFlash': enableScreenFlash,
        'mirrorFrontCameraOutput': mirrorFrontCameraOutput,
      },
    );
    if (result == null) {
      throw PlatformException(
        code: 'INIT_FAILED',
        message: 'Failed to initialize camera',
      );
    }
    debugPrint('DivineCamera: Raw result from native: $result');
    debugPrint(
      'DivineCamera: aspectRatio value: ${result['aspectRatio']} '
      '(type: ${result['aspectRatio']?.runtimeType})',
    );
    final state = CameraState.fromMap(result);
    debugPrint('DivineCamera: Parsed state aspectRatio: ${state.aspectRatio}');
    return state;
  }

  @override
  Future<void> disposeCamera() async {
    await methodChannel.invokeMethod<void>('disposeCamera');
  }

  @override
  Future<bool> setFlashMode(DivineCameraFlashMode mode) async {
    final result = await methodChannel.invokeMethod<bool>('setFlashMode', {
      'mode': mode.toNativeString(),
    });
    return result ?? false;
  }

  @override
  Future<bool> setFocusPoint(Offset offset) async {
    final result = await methodChannel.invokeMethod<bool>('setFocusPoint', {
      'x': offset.dx,
      'y': offset.dy,
    });
    return result ?? false;
  }

  @override
  Future<bool> setExposurePoint(Offset offset) async {
    final result = await methodChannel.invokeMethod<bool>('setExposurePoint', {
      'x': offset.dx,
      'y': offset.dy,
    });
    return result ?? false;
  }

  @override
  Future<bool> cancelFocusAndMetering() async {
    final result = await methodChannel.invokeMethod<bool>(
      'cancelFocusAndMetering',
    );
    return result ?? false;
  }

  @override
  Future<bool> setZoomLevel(double level) async {
    final result = await methodChannel.invokeMethod<bool>('setZoomLevel', {
      'level': level,
    });
    return result ?? false;
  }

  @override
  Future<CameraState> switchCamera(DivineCameraLens lens) async {
    final result = await methodChannel.invokeMapMethod<dynamic, dynamic>(
      'switchCamera',
      {'lens': lens.toNativeString()},
    );
    if (result == null) {
      throw PlatformException(
        code: 'SWITCH_FAILED',
        message: 'Failed to switch camera',
      );
    }
    return CameraState.fromMap(result);
  }

  @override
  Future<bool> startRecording({
    Duration? maxDuration,
    bool useCache = true,
    String? outputDirectory,
  }) async {
    try {
      await methodChannel.invokeMethod<void>('startRecording', {
        if (maxDuration != null) 'maxDurationMs': maxDuration.inMilliseconds,
        'useCache': useCache,
        'outputDirectory': ?outputDirectory,
      });
      return true;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<VideoRecordingResult?> stopRecording() async {
    final result = await methodChannel.invokeMapMethod<dynamic, dynamic>(
      'stopRecording',
    );
    if (result == null) return null;
    return VideoRecordingResult.fromMap(result);
  }

  @override
  Future<void> pausePreview() async {
    await methodChannel.invokeMethod<void>('pausePreview');
  }

  @override
  Future<void> resumePreview() async {
    await methodChannel.invokeMethod<void>('resumePreview');
  }

  @override
  Future<CameraState> getCameraState() async {
    final result = await methodChannel.invokeMapMethod<dynamic, dynamic>(
      'getCameraState',
    );
    if (result == null) {
      throw PlatformException(
        code: 'STATE_FAILED',
        message: 'Failed to get camera state',
      );
    }
    return CameraState.fromMap(result);
  }

  @override
  Widget buildPreview(int textureId) {
    return Texture(textureId: textureId);
  }
}
