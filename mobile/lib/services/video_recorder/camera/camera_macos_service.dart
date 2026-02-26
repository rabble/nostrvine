// ABOUTME: macOS platform implementation of camera service using the camera_macos package
// ABOUTME: Handles camera and audio device management, recording, and torch control on macOS

import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:camera_macos_plus/camera_macos.dart';
import 'package:divine_camera/divine_camera.dart'
    show CameraLensMetadata, DivineCameraLens, DivineVideoQuality;
import 'package:flutter/widgets.dart';
import 'package:openvine/models/video_recorder/video_recorder_flash_mode.dart';
import 'package:openvine/services/audio_device_preference_service.dart';
import 'package:openvine/services/video_recorder/camera/camera_base_service.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:path/path.dart' as p;
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  String? _initializationError;
  Timer? _autoStopTimer;
  DivineVideoQuality _currentVideoQuality = DivineVideoQuality.fhd;

  @override
  Future<void> initialize({
    DivineVideoQuality videoQuality = DivineVideoQuality.fhd,
    DivineCameraLens initialLens = DivineCameraLens.front,
  }) async {
    // Note: macOS does not support lens selection - initialLens is ignored
    _currentVideoQuality = videoQuality;
    if (_isInitialized) return;

    // Clear any previous error
    _initializationError = null;

    Log.info(
      '📷 Initializing macOS camera',
      name: 'CameraMacOSService',
      category: .video,
    );

    try {
      _videoDevices ??= await CameraMacOS.instance.listDevices(
        deviceType: CameraMacOSDeviceType.video,
      );
      _audioDevices ??= await CameraMacOS.instance.listDevices(
        deviceType: CameraMacOSDeviceType.audio,
      );
    } catch (e) {
      _initializationError = 'Failed to detect cameras: $e';
      Log.error(
        '📷 Failed to list devices: $e',
        name: 'CameraMacOSService',
        category: .video,
      );
      return;
    }

    // Check if any video devices were found
    if (_videoDevices == null || _videoDevices!.isEmpty) {
      _initializationError = 'No camera found. Please connect a camera.';
      Log.warning(
        '⚠️ No video devices found on macOS',
        name: 'CameraMacOSService',
        category: .video,
      );
      return;
    }

    Log.info(
      '📷 Found ${_videoDevices!.length} video device(s)',
      name: 'CameraMacOSService',
      category: LogCategory.video,
    );

    // Log audio devices for debugging
    if (_audioDevices != null && _audioDevices!.isNotEmpty) {
      Log.info(
        '🎤 Found ${_audioDevices!.length} audio device(s): '
        '${_audioDevices!.map((d) => d.deviceId).join(", ")}',
        name: 'CameraMacOSService',
        category: LogCategory.video,
      );
    } else {
      Log.warning(
        '⚠️ No audio devices found - recording will have no audio!',
        name: 'CameraMacOSService',
        category: LogCategory.video,
      );
    }

    await _initializeCameraController();

    // Only mark setup as completed if initialization succeeded
    if (_isInitialized) {
      _isInitialSetupCompleted = true;
      Log.info(
        '📷 macOS camera initialized (${_videoDevices!.length} video, '
        '${_audioDevices!.length} audio devices)',
        name: 'CameraMacOSService',
        category: .video,
      );
    }
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
    if (_videoDevices == null || _videoDevices!.isEmpty) {
      _initializationError ??= 'No camera found. Please connect a camera.';
      Log.warning(
        '⚠️ Cannot initialize camera controller: no video devices',
        name: 'CameraMacOSService',
        category: .video,
      );
      return;
    }

    try {
      final deviceId = _videoDevices![_currentCameraIndex].deviceId;
      final audioDeviceId = await _selectBestAudioDevice();

      Log.info(
        '📷 Initializing camera with video=$deviceId, audio=$audioDeviceId',
        name: 'CameraMacOSService',
        category: LogCategory.video,
      );

      final result = await CameraMacOS.instance.initialize(
        cameraMacOSMode: CameraMacOSMode.video,
        deviceId: deviceId,
        audioDeviceId: audioDeviceId,
        resolution: _getPictureResolution(_currentVideoQuality),
      );
      _isInitialized = true;
      _initializationError = null; // Clear error on success

      _cameraSensorSize = result?.size ?? const Size(500, 500);

      final hasFlash = await CameraMacOS.instance.hasFlash(deviceId: deviceId);
      _hasFlash = hasFlash;
      onUpdateState(forceCameraRebuild: true);
    } catch (e) {
      _initializationError = _getUserFriendlyErrorMessage(e.toString());
      Log.error(
        '📷 Failed to initialize camera controller: $e',
        name: 'CameraMacOSService',
        category: .video,
      );
    }
  }

  /// Converts native camera error messages to user-friendly descriptions.
  String _getUserFriendlyErrorMessage(String error) {
    final errorLower = error.toLowerCase();

    if (errorLower.contains('cannot use') ||
        errorLower.contains('in use') ||
        errorLower.contains('busy')) {
      return 'Camera is being used by another app. '
          'Please close other apps using the camera and try again.';
    }

    if (errorLower.contains('denied') ||
        errorLower.contains('not authorized') ||
        errorLower.contains('permission')) {
      return 'Camera access denied. '
          'Please allow camera access in System Settings > Privacy & Security.';
    }

    if (errorLower.contains('not found') ||
        errorLower.contains('no camera') ||
        errorLower.contains('unavailable')) {
      return 'No camera found. Please connect a camera and try again.';
    }

    // Default fallback - still better than raw error
    return 'Unable to access camera. Please try again.';
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

  /// Configures audio session for recording (enables microphone input).
  Future<void> _configureAudioSessionForRecording() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: .playAndRecord,
          avAudioSessionMode: .videoRecording,
          avAudioSessionCategoryOptions: .allowBluetooth,
        ),
      );
      Log.info(
        '🎤 Audio session configured for recording (playAndRecord mode)',
        name: 'CameraMacOSService',
        category: LogCategory.video,
      );
    } catch (e) {
      Log.error(
        '🎤 Failed to configure audio session for recording: $e',
        name: 'CameraMacOSService',
        category: LogCategory.video,
      );
    }
  }

  /// Restores audio session to ambient mode (respects mute switch).
  Future<void> _restoreAudioSession() async {
    try {
      final session = await AudioSession.instance;
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: .ambient,
          avAudioSessionMode: .defaultMode,
          avAudioSessionCategoryOptions: .mixWithOthers,
        ),
      );
      Log.info(
        '🎤 Audio session restored to ambient mode',
        name: 'CameraMacOSService',
        category: LogCategory.video,
      );
    } catch (e) {
      Log.warning(
        '🎤 Failed to restore audio session: $e',
        name: 'CameraMacOSService',
        category: LogCategory.video,
      );
    }
  }

  @override
  Future<bool> startRecording({
    Duration? maxDuration,
    String? outputDirectory,
  }) async {
    try {
      Log.info(
        '📷 Starting macOS video recording',
        name: 'CameraMacOSService',
        category: LogCategory.video,
      );

      // Configure audio session for recording BEFORE starting
      await _configureAudioSessionForRecording();

      final baseDir = await getDocumentsPath();
      final recordingsDir = Directory(baseDir);
      if (!recordingsDir.existsSync()) {
        await recordingsDir.create(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final outputPath = p.join(
        recordingsDir.path,
        'openvine_recording_$timestamp.mp4',
      );

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
          final result = await stopRecording();
          if (result != null) {
            onAutoStopped(result);
          }
        });
      }

      Log.info(
        '📷 Recording to: $outputPath',
        name: 'CameraMacOSService',
        category: .video,
      );
      return true;
    } catch (e) {
      Log.error(
        '📷 Failed to start recording: $e',
        name: 'CameraMacOSService',
        category: .video,
      );
      return false;
    }
  }

  @override
  Future<EditorVideo?> stopRecording() async {
    try {
      Log.info(
        '📷 Stopping macOS video recording',
        name: 'CameraMacOSService',
        category: LogCategory.video,
      );

      _autoStopTimer?.cancel();
      _autoStopTimer = null;

      final result = await CameraMacOS.instance.stopVideoRecording();
      _isRecording = false;

      // Restore audio session to ambient mode after recording
      await _restoreAudioSession();

      Log.info(
        '📷 macOS stopVideoRecording result: '
        'url=${result?.url}, '
        'hasBytes=${result?.bytes != null}, '
        'byteLength=${result?.bytes?.length ?? 0}',
        name: 'CameraMacOSService',
        category: .video,
      );

      if (result?.bytes == null) {
        Log.warning(
          '📷 macOS video recording stopped with null bytes - '
          'trying file path fallback',
          name: 'CameraMacOSService',
          category: .video,
        );
        // Try to read from file path if bytes are null but URL exists
        if (result?.url != null && result!.url!.isNotEmpty) {
          final file = File(result.url!);
          if (file.existsSync()) {
            Log.info(
              '📷 Reading video from file path: ${result.url}',
              name: 'CameraMacOSService',
              category: .video,
            );
            return EditorVideo.file(result.url);
          }
        }
        return null;
      }

      Log.info(
        '📷 macOS video recording stopped successfully, '
        '${result!.bytes!.length} bytes',
        name: 'CameraMacOSService',
        category: .video,
      );

      return EditorVideo.memory(result.bytes!);
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

  /// Selects the best audio device for recording.
  ///
  /// Priority order:
  /// 1. User's manually selected preference (if still available)
  /// 2. Built-in microphone (most reliable for recording)
  /// 3. Any device with "Microphone" in the name
  /// 4. First non-virtual device
  /// 5. First device as fallback
  ///
  /// Returns null if no audio devices available.
  Future<String?> _selectBestAudioDevice() async {
    if (_audioDevices == null || _audioDevices!.isEmpty) {
      return null;
    }

    // Check for user's manual preference first
    try {
      final prefs = await SharedPreferences.getInstance();
      final preferredId = prefs.getString(
        AudioDevicePreferenceService.prefsKey,
      );
      if (preferredId != null) {
        // Check if the preferred device is still available
        final preferred = _audioDevices!.where(
          (d) => d.deviceId == preferredId,
        );
        if (preferred.isNotEmpty) {
          Log.info(
            '🎤 Using user-selected audio device: ${preferred.first.deviceId}',
            name: 'CameraMacOSService',
            category: LogCategory.video,
          );
          return preferred.first.deviceId;
        } else {
          Log.warning(
            '⚠️ User-selected audio device no longer available: $preferredId',
            name: 'CameraMacOSService',
            category: LogCategory.video,
          );
        }
      }
    } catch (e) {
      Log.warning(
        '⚠️ Failed to load audio device preference: $e',
        name: 'CameraMacOSService',
        category: LogCategory.video,
      );
    }

    // Auto-select: Try to find built-in microphone first
    final builtIn = _audioDevices!.where(
      (d) =>
          d.deviceId.toLowerCase().contains('builtinmicrophone') ||
          d.deviceId.toLowerCase().contains('built-in'),
    );
    if (builtIn.isNotEmpty) {
      Log.info(
        '🎤 Auto-selected built-in microphone: ${builtIn.first.deviceId}',
        name: 'CameraMacOSService',
        category: LogCategory.video,
      );
      return builtIn.first.deviceId;
    }

    // Try any device with "microphone" in the name
    final microphone = _audioDevices!.where(
      (d) => d.deviceId.toLowerCase().contains('microphone'),
    );
    if (microphone.isNotEmpty) {
      Log.info(
        '🎤 Auto-selected microphone device: ${microphone.first.deviceId}',
        name: 'CameraMacOSService',
        category: LogCategory.video,
      );
      return microphone.first.deviceId;
    }

    // Skip virtual audio devices (Zoom, etc.)
    final nonVirtual = _audioDevices!.where(
      (d) =>
          !d.deviceId.toLowerCase().contains('zoom') &&
          !d.deviceId.toLowerCase().contains('virtual') &&
          !d.deviceId.toLowerCase().contains('aggregate'),
    );
    if (nonVirtual.isNotEmpty) {
      Log.info(
        '🎤 Auto-selected non-virtual audio device: '
        '${nonVirtual.first.deviceId}',
        name: 'CameraMacOSService',
        category: LogCategory.video,
      );
      return nonVirtual.first.deviceId;
    }

    // Fallback to first device
    Log.warning(
      '⚠️ No preferred audio device found, using first: '
      '${_audioDevices!.first.deviceId}',
      name: 'CameraMacOSService',
      category: LogCategory.video,
    );
    return _audioDevices!.first.deviceId;
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

  /// Converts [DivineVideoQuality] to macOS [PictureResolution].
  ///
  /// Maps video quality settings to camera_macos resolution presets.
  PictureResolution _getPictureResolution(DivineVideoQuality quality) {
    return switch (quality) {
      DivineVideoQuality.sd => PictureResolution.low, // 480p
      DivineVideoQuality.hd => PictureResolution.high, // 720p
      DivineVideoQuality.fhd => PictureResolution.veryHigh, // 1080p
      DivineVideoQuality.uhd => PictureResolution.ultraHigh, // 4K
      DivineVideoQuality.highest => PictureResolution.max,
      DivineVideoQuality.lowest => PictureResolution.low,
    };
  }

  @override
  double get cameraAspectRatio => _cameraSensorSize.aspectRatio;

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

  @override
  Future<bool> setLens(DivineCameraLens lens) async {
    // macOS doesn't support different lens types like mobile
    // Only basic camera switching is supported
    return false;
  }

  @override
  DivineCameraLens get currentLens => DivineCameraLens.front;

  @override
  List<DivineCameraLens> get availableLenses => [DivineCameraLens.front];

  @override
  CameraLensMetadata? get currentLensMetadata => null;

  @override
  String? get initializationError => _initializationError;

  @override
  set onRemoteRecordTrigger(void Function()? callback) {
    // Remote record control is not supported on macOS
  }

  @override
  Future<bool> setRemoteRecordControlEnabled({required bool enabled}) async {
    // Remote record control is not supported on macOS
    return false;
  }

  @override
  Future<bool> setVolumeKeysEnabled({required bool enabled}) async {
    // Volume key control is not supported on macOS
    return false;
  }
}
