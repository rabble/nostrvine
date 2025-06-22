// ABOUTME: Simplified camera service using direct video recording for vine creation
// ABOUTME: Records MP4 videos directly without frame extraction complexity

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

/// Camera recording configuration
class CameraConfiguration {
  final Duration recordingDuration;
  final bool enableAutoStop;
  
  const CameraConfiguration({
    this.recordingDuration = const Duration(seconds: 6),
    this.enableAutoStop = true,
  });
  
  /// Create configuration for vine-style recording (3-15 seconds)
  static CameraConfiguration vine({
    Duration? duration,
    bool? autoStop,
  }) {
    Duration clampedDuration;
    if (duration != null) {
      final seconds = duration.inSeconds;
      final clampedSeconds = seconds.clamp(3, 15);
      clampedDuration = Duration(seconds: clampedSeconds);
    } else {
      clampedDuration = const Duration(seconds: 6);
    }
    
    return CameraConfiguration(
      recordingDuration: clampedDuration,
      enableAutoStop: autoStop ?? true,
    );
  }
  
  @override
  String toString() {
    return 'CameraConfiguration(duration: ${recordingDuration.inSeconds}s)';
  }
}

enum RecordingState {
  idle,
  initializing,
  recording,
  processing,
  completed,
  error,
}

class CameraService extends ChangeNotifier {
  CameraController? _controller;
  RecordingState _state = RecordingState.idle;
  bool _disposed = false;
  
  // Recording state
  bool _isRecording = false;
  DateTime? _recordingStartTime;
  Timer? _progressTimer;
  Timer? _autoStopTimer;
  
  // Recording configuration
  CameraConfiguration _configuration = const CameraConfiguration();
  
  // Convenience getters for current configuration
  Duration get maxVineDuration => _configuration.recordingDuration;
  bool get enableAutoStop => _configuration.enableAutoStop;
  CameraConfiguration get configuration => _configuration;
  
  // Getters
  RecordingState get state => _state;
  bool get isInitialized => _controller?.value.isInitialized ?? false;
  bool get isRecording => _isRecording;
  double get recordingProgress {
    if (!_isRecording || _recordingStartTime == null) return 0.0;
    final elapsed = DateTime.now().difference(_recordingStartTime!);
    return (elapsed.inMilliseconds / maxVineDuration.inMilliseconds).clamp(0.0, 1.0);
  }
  
  /// Initialize camera for vine recording
  Future<void> initialize() async {
    try {
      _setState(RecordingState.initializing);
      
      // Skip camera initialization on Linux/Windows (not supported)
      if (defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.windows) {
        throw Exception('Camera recording not currently supported on Linux/Windows. Please use mobile app for recording.');
      }
      
      // Handle macOS camera initialization differently
      if (defaultTargetPlatform == TargetPlatform.macOS) {
        await _initializeMacOSCamera();
        return;
      }
      
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        // Check if we're running on iOS/Android simulator
        if (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android) {
          throw Exception('Camera not available on simulator. Please test on a real device.');
        }
        throw Exception('No cameras available on device');
      }
      
      // Prefer back camera for initial setup
      final camera = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      
      _controller = CameraController(
        camera,
        ResolutionPreset.high, // High quality for vine videos
        enableAudio: true, // Enable audio for videos
      );
      
      await _controller!.initialize();
      
      // Prepare for video recording
      await _controller!.prepareForVideoRecording();
      
      _setState(RecordingState.idle);
      
      debugPrint('📷 Camera initialized successfully');
    } catch (e) {
      _setState(RecordingState.error);
      debugPrint('❌ Camera initialization failed: $e');
      rethrow;
    }
  }
  
  /// Start vine recording (direct video recording)
  Future<void> startRecording() async {
    if (!isInitialized || _isRecording) {
      debugPrint('⚠️ Cannot start recording: initialized=$isInitialized, recording=$_isRecording');
      return;
    }
    
    try {
      _setState(RecordingState.recording);
      _isRecording = true;
      _recordingStartTime = DateTime.now();
      
      // Start video recording
      await _controller!.startVideoRecording();
      
      // Start progress timer to update UI regularly
      _startProgressTimer();
      
      // Set up auto-stop timer if enabled
      if (enableAutoStop) {
        _autoStopTimer = Timer(maxVineDuration, () {
          if (_isRecording) {
            debugPrint('⏰ Auto-stopping recording after ${maxVineDuration.inSeconds}s');
            stopRecording();
          }
        });
      }
      
      debugPrint('🎬 Started vine recording (${maxVineDuration.inSeconds}s max)');
    } catch (e) {
      _setState(RecordingState.error);
      _isRecording = false;
      debugPrint('❌ Failed to start recording: $e');
      rethrow;
    }
  }
  
  /// Stop recording and return video file
  Future<VineRecordingResult> stopRecording() async {
    if (!_isRecording) {
      debugPrint('⚠️ Not currently recording, cannot stop');
      throw Exception('Not currently recording');
    }
    
    try {
      _setState(RecordingState.processing);
      
      // Cancel timers
      _stopProgressTimer();
      _autoStopTimer?.cancel();
      _autoStopTimer = null;
      
      // Calculate recording duration
      final duration = _recordingStartTime != null 
        ? DateTime.now().difference(_recordingStartTime!)
        : Duration.zero;
      
      // Stop video recording
      final xFile = await _controller!.stopVideoRecording();
      final videoFile = File(xFile.path);
      
      _setState(RecordingState.completed);
      
      debugPrint('✅ Vine recording completed:');
      debugPrint('  📹 File: ${videoFile.path}');
      debugPrint('  ⏱️ Duration: ${duration.inSeconds}s');
      debugPrint('  📦 Size: ${(await videoFile.length() / 1024 / 1024).toStringAsFixed(2)}MB');
      
      return VineRecordingResult(
        videoFile: videoFile,
        duration: duration,
      );
    } catch (e) {
      _setState(RecordingState.error);
      debugPrint('❌ Failed to stop recording: $e');
      rethrow;
    } finally {
      _isRecording = false;
      _recordingStartTime = null;
    }
  }
  
  /// Cancel current recording
  Future<void> cancelRecording() async {
    if (!_isRecording) return;
    
    try {
      // Cancel timers
      _stopProgressTimer();
      _autoStopTimer?.cancel();
      _autoStopTimer = null;
      
      // Stop the recording without saving
      await _controller!.stopVideoRecording();
      
      _setState(RecordingState.idle);
      _isRecording = false;
      _recordingStartTime = null;
      
      debugPrint('🚫 Recording canceled');
    } catch (e) {
      debugPrint('⚠️ Error canceling recording: $e');
    }
  }
  
  /// Switch between front and back camera
  Future<void> switchCamera() async {
    if (!isInitialized || _isRecording) return;
    
    try {
      final cameras = await availableCameras();
      if (cameras.length < 2) return;
      
      final currentCamera = _controller!.description;
      final currentDirection = currentCamera.lensDirection;
      
      // Find camera with opposite direction
      final newCamera = cameras.firstWhere(
        (camera) => camera.lensDirection != currentDirection,
        orElse: () => cameras.firstWhere((cam) => cam != currentCamera),
      );
      
      // Dispose current controller
      await _controller?.dispose();
      
      // Create new controller with new camera
      _controller = CameraController(
        newCamera,
        ResolutionPreset.high,
        enableAudio: true,
      );
      
      await _controller!.initialize();
      await _controller!.prepareForVideoRecording();
      
      notifyListeners();
      debugPrint('🔄 Switched to ${newCamera.lensDirection} camera');
    } catch (e) {
      debugPrint('❌ Failed to switch camera: $e');
    }
  }
  
  /// Get camera preview widget
  Widget get cameraPreview {
    if (!isInitialized || _controller == null) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    return CameraPreview(_controller!);
  }
  
  /// Update camera configuration
  void updateConfiguration(CameraConfiguration newConfiguration) {
    _configuration = newConfiguration;
    debugPrint('📹 Updated camera configuration: $newConfiguration');
    notifyListeners();
  }
  
  /// Set recording duration (clamped to 3-15 seconds)
  void setRecordingDuration(Duration duration) {
    final seconds = duration.inSeconds.clamp(3, 15);
    final clampedDuration = Duration(seconds: seconds);
    
    _configuration = CameraConfiguration(
      recordingDuration: clampedDuration,
      enableAutoStop: _configuration.enableAutoStop,
    );
    debugPrint('📹 Updated recording duration to ${clampedDuration.inSeconds}s');
    notifyListeners();
  }
  
  /// Configure recording using vine-style presets
  void useVineConfiguration({
    Duration? duration,
    bool? autoStop,
  }) {
    _configuration = CameraConfiguration.vine(
      duration: duration,
      autoStop: autoStop,
    );
    debugPrint('📹 Applied vine configuration: $_configuration');
    notifyListeners();
  }
  
  /// Dispose resources
  @override
  void dispose() {
    _disposed = true;
    _stopProgressTimer();
    _autoStopTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }
  
  // Private methods
  
  void _setState(RecordingState newState) {
    _state = newState;
    
    // Use post-frame callback to safely notify listeners
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_disposed && hasListeners) {
        try {
          notifyListeners();
        } catch (e) {
          // Ignore errors during disposal
          debugPrint('⚠️ State notification error: $e');
        }
      }
    });
  }
  
  /// Start progress timer to update UI during recording
  void _startProgressTimer() {
    _stopProgressTimer(); // Clean up any existing timer
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_isRecording && !_disposed && hasListeners) {
        try {
          notifyListeners(); // Update UI with current progress
        } catch (e) {
          // Ignore errors during disposal
          debugPrint('⚠️ Progress timer notification error: $e');
        }
      }
    });
  }

  /// Stop progress timer
  void _stopProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }
  
  /// Initialize macOS camera using camera_macos plugin
  Future<void> _initializeMacOSCamera() async {
    try {
      // For now, throw an exception to indicate macOS needs special handling
      // We'll implement a proper macOS camera widget in the next step
      throw Exception('macOS camera requires CameraMacOSView widget. Use dedicated macOS camera screen.');
      
    } catch (e) {
      debugPrint('❌ macOS camera initialization failed: $e');
      // Fall back to showing error
      throw Exception('macOS camera initialization failed: $e');
    }
  }
}

/// Result from vine recording
class VineRecordingResult {
  final File videoFile;
  final Duration duration;
  
  VineRecordingResult({
    required this.videoFile,
    required this.duration,
  });
  
  bool get hasVideo => videoFile.existsSync();
  
  @override
  String toString() {
    return 'VineRecordingResult(file: ${videoFile.path}, duration: ${duration.inSeconds}s)';
  }
}