// ABOUTME: Camera service implementing hybrid frame capture for vine creation
// ABOUTME: Manages recording, frame extraction, and GIF generation pipeline using provider abstraction

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'camera/camera_provider.dart';
import 'camera/mobile_camera_provider.dart';
import 'camera/web_camera_provider.dart';
import 'camera/macos_camera_provider.dart';
import 'camera/unsupported_camera_provider.dart';

/// Camera recording configuration
class CameraConfiguration {
  final Duration recordingDuration;
  final double targetFPS;
  final bool enableAutoStop;
  
  const CameraConfiguration({
    this.recordingDuration = const Duration(seconds: 6),
    this.targetFPS = 5.0,
    this.enableAutoStop = true,
  });
  
  /// Create configuration for vine-style recording (3-15 seconds)
  static CameraConfiguration vine({
    Duration? duration,
    double? fps,
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
    
    final clampedFPS = fps?.clamp(3.0, 10.0) ?? 5.0;
    
    return CameraConfiguration(
      recordingDuration: clampedDuration,
      targetFPS: clampedFPS,
      enableAutoStop: autoStop ?? true,
    );
  }
  
  int get targetFrameCount => (recordingDuration.inSeconds * targetFPS).round();
  
  @override
  String toString() {
    return 'CameraConfiguration(duration: ${recordingDuration.inSeconds}s, fps: $targetFPS, frames: $targetFrameCount)';
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
  late final CameraProvider _provider;
  RecordingState _state = RecordingState.idle;
  bool _disposed = false;
  
  // Hybrid capture data
  final List<Uint8List> _realtimeFrames = [];
  bool _isRecording = false;
  DateTime? _recordingStartTime;
  Timer? _progressTimer;
  
  // Recording configuration
  CameraConfiguration _configuration = const CameraConfiguration();
  
  // Convenience getters for current configuration
  Duration get maxVineDuration => _configuration.recordingDuration;
  double get targetFPS => _configuration.targetFPS;
  bool get enableAutoStop => _configuration.enableAutoStop;
  int get targetFrameCount => _configuration.targetFrameCount;
  CameraConfiguration get configuration => _configuration;
  
  /// Constructor with platform-specific provider selection
  CameraService() {
    _provider = _createProviderForPlatform();
  }
  
  /// Create appropriate camera provider based on current platform
  CameraProvider _createProviderForPlatform() {
    if (kIsWeb) {
      debugPrint('🌐 Using WebCameraProvider for web platform');
      return WebCameraProvider();
    }
    
    if (!kIsWeb) {
      if (Platform.isIOS || Platform.isAndroid) {
        debugPrint('📱 Using MobileCameraProvider for mobile platform');
        return MobileCameraProvider();
      }
      
      if (Platform.isMacOS) {
        debugPrint('💻 Using MacosCameraProvider for macOS platform');
        return MacosCameraProvider();
      }
    }
    
    debugPrint('❓ Using UnsupportedCameraProvider for unknown platform');
    return UnsupportedCameraProvider();
  }
  
  // Getters
  RecordingState get state => _state;
  bool get isInitialized => _provider.isInitialized;
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
      
      await _provider.initialize();
      _setState(RecordingState.idle);
      
      debugPrint('📷 Camera initialized successfully');
    } catch (e) {
      _setState(RecordingState.error);
      debugPrint('❌ Camera initialization failed: $e');
      rethrow;
    }
  }
  
  /// Start vine recording using hybrid approach
  Future<void> startRecording() async {
    if (!isInitialized || _isRecording) {
      debugPrint('⚠️ Cannot start recording: initialized=$isInitialized, recording=$_isRecording');
      return;
    }
    
    try {
      _setState(RecordingState.recording);
      _isRecording = true; // Set this immediately to prevent double calls
      _realtimeFrames.clear();
      _recordingStartTime = DateTime.now();
      
      // Start recording using the provider with frame callback
      await _provider.startRecording(
        onFrame: (frameData) {
          if (_isRecording) {
            _realtimeFrames.add(frameData);
          }
        },
      );
      
      // Start progress timer to update UI regularly
      _startProgressTimer();
      
      // Set up auto-stop timer if enabled
      if (enableAutoStop) {
        Timer(maxVineDuration, () {
          if (_isRecording) {
            debugPrint('⏰ Auto-stopping recording after ${maxVineDuration.inSeconds}s');
            stopRecording();
          }
        });
      }
      
      debugPrint('🎬 Started vine recording (provider-based approach)');
      debugPrint('🕰️ Recording duration: ${maxVineDuration.inSeconds}s, Auto-stop: $enableAutoStop');
    } catch (e) {
      _setState(RecordingState.error);
      _isRecording = false; // Reset on error
      debugPrint('❌ Failed to start recording: $e');
      rethrow;
    }
  }
  
  /// Stop recording and process frames
  Future<VineRecordingResult> stopRecording() async {
    if (!_isRecording) {
      debugPrint('⚠️ Not currently recording, cannot stop');
      throw Exception('Not currently recording');
    }
    
    try {
      _setState(RecordingState.processing);
      
      // Stop progress timer immediately
      _stopProgressTimer();
      
      // Stop recording using the provider
      final cameraResult = await _provider.stopRecording();
      
      // Process the result using our hybrid strategy
      final vineResult = await _processRecordingResult(cameraResult);
      
      _setState(RecordingState.completed);
      debugPrint('✅ Vine recording completed: ${vineResult.frameCount} frames');
      
      return vineResult;
    } catch (e) {
      _setState(RecordingState.error);
      debugPrint('❌ Failed to stop recording: $e');
      rethrow;
    } finally {
      _isRecording = false;
      _recordingStartTime = null;
      _stopProgressTimer();
    }
  }
  
  /// Cancel current recording
  Future<void> cancelRecording() async {
    if (!_isRecording) return;
    
    try {
      // Just stop the recording without processing
      await _provider.stopRecording();
      _setState(RecordingState.idle);
      _isRecording = false;
      _recordingStartTime = null;
      _realtimeFrames.clear();
      _stopProgressTimer();
      
      debugPrint('🚫 Recording canceled');
    } catch (e) {
      debugPrint('⚠️ Error canceling recording: $e');
    }
  }
  
  /// Switch between front and back camera
  Future<void> switchCamera() async {
    if (!isInitialized || _isRecording) return;
    
    try {
      await _provider.switchCamera();
      notifyListeners();
      debugPrint('🔄 Camera switched successfully');
    } catch (e) {
      debugPrint('❌ Failed to switch camera: $e');
    }
  }
  
  /// Get camera preview widget
  Widget get cameraPreview => _provider.buildPreview();
  
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
      targetFPS: _configuration.targetFPS,
      enableAutoStop: _configuration.enableAutoStop,
    );
    debugPrint('📹 Updated recording duration to ${clampedDuration.inSeconds}s');
    notifyListeners();
  }
  
  /// Set target frame rate (clamped to 3-10 FPS)
  void setTargetFPS(double fps) {
    final clampedFPS = fps.clamp(3.0, 10.0);
    _configuration = CameraConfiguration(
      recordingDuration: _configuration.recordingDuration,
      targetFPS: clampedFPS,
      enableAutoStop: _configuration.enableAutoStop,
    );
    debugPrint('📹 Updated target FPS to $clampedFPS');
    notifyListeners();
  }
  
  /// Configure recording using vine-style presets
  void useVineConfiguration({
    Duration? duration,
    double? fps,
    bool? autoStop,
  }) {
    _configuration = CameraConfiguration.vine(
      duration: duration,
      fps: fps,
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
    _provider.dispose();
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

  /// Process camera recording result using hybrid strategy
  Future<VineRecordingResult> _processRecordingResult(CameraRecordingResult cameraResult) async {
    final stopwatch = Stopwatch()..start();
    
    List<Uint8List> finalFrames;
    String selectedApproach;
    double qualityRatio;
    
    switch (cameraResult.extractionStrategy) {
      case FrameExtractionStrategy.useRealTimeFrames:
        // Use frames captured in real-time
        finalFrames = List.from(_realtimeFrames);
        selectedApproach = 'Real-time Stream';
        qualityRatio = _realtimeFrames.length / targetFrameCount;
        debugPrint('📸 Using real-time frames: ${_realtimeFrames.length}/$targetFrameCount');
        break;
        
      case FrameExtractionStrategy.extractFromVideo:
        // Extract frames from video file
        finalFrames = await _extractFramesFromVideo(cameraResult.videoPath!);
        selectedApproach = 'Video Extraction (Fallback)';
        qualityRatio = finalFrames.length / targetFrameCount;
        debugPrint('🎥 Using video extraction fallback: ${finalFrames.length} frames');
        break;
        
      case FrameExtractionStrategy.usePlaceholderFrames:
        // Generate placeholder frames (development/testing)
        finalFrames = _generatePlaceholderFrames();
        selectedApproach = 'Placeholder Frames (Development)';
        qualityRatio = 1.0;
        debugPrint('🎨 Using placeholder frames for development');
        break;
    }
    
    final processingTime = stopwatch.elapsed;
    
    return VineRecordingResult(
      frames: finalFrames,
      frameCount: finalFrames.length,
      processingTime: processingTime,
      selectedApproach: selectedApproach,
      qualityRatio: qualityRatio,
    );
  }

  /// Extract frames from video file (placeholder for now)
  Future<List<Uint8List>> _extractFramesFromVideo(String videoPath) async {
    // TODO: Implement real video frame extraction using FFmpeg
    debugPrint('🔄 Extracting frames from video: $videoPath');
    
    // For now, return placeholder frames
    return _generatePlaceholderFrames();
  }

  /// Generate placeholder frames for development/testing
  List<Uint8List> _generatePlaceholderFrames() {
    final frames = <Uint8List>[];
    
    for (int i = 0; i < targetFrameCount; i++) {
      final frameData = _createVariedPlaceholderFrame(640, 480, i);
      frames.add(frameData);
    }
    
    debugPrint('✅ Generated ${frames.length} placeholder frames');
    return frames;
  }

  /// Create varied placeholder frame for animation preview
  Uint8List _createVariedPlaceholderFrame(int width, int height, int frameIndex) {
    final rgbData = Uint8List(width * height * 3);
    
    // Create a simple animation effect - color shifting gradient
    final phase = (frameIndex * 0.2) % (2 * math.pi); // Cycling through phases
    
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final pixelIndex = (y * width + x) * 3;
        
        // Create a moving gradient pattern
        final normalizedX = x / width;
        final normalizedY = y / height;
        final distance = (normalizedX * normalizedX + normalizedY * normalizedY);
        
        // Animated color based on distance and frame
        final colorValue = ((math.sin(distance * 10 + phase) + 1) * 127.5).round();
        final complementColor = 255 - colorValue;
        
        rgbData[pixelIndex] = colorValue;     // R
        rgbData[pixelIndex + 1] = complementColor; // G  
        rgbData[pixelIndex + 2] = ((colorValue + complementColor) / 2).round(); // B
      }
    }
    
    return rgbData;
  }

  /// Start progress timer to update UI during recording
  void _startProgressTimer() {
    _stopProgressTimer(); // Clean up any existing timer
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (_isRecording && !_disposed && hasListeners) {
        try {
          // Add debug logging every second
          final elapsed = DateTime.now().difference(_recordingStartTime!);
          if (elapsed.inMilliseconds % 1000 < 100) {
            debugPrint('⏱️ Recording progress: ${(recordingProgress * 100).toStringAsFixed(1)}% (${elapsed.inSeconds}s)');
          }
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
}

class VineRecordingResult {
  final List<Uint8List> frames;
  final int frameCount;
  final Duration processingTime;
  final String selectedApproach;
  final double qualityRatio;
  final bool isCanceled;
  
  VineRecordingResult({
    required this.frames,
    required this.frameCount,
    required this.processingTime,
    required this.selectedApproach,
    required this.qualityRatio,
    this.isCanceled = false,
  });
  
  factory VineRecordingResult.canceled() {
    return VineRecordingResult(
      frames: [],
      frameCount: 0,
      processingTime: Duration.zero,
      selectedApproach: 'Canceled',
      qualityRatio: 0.0,
      isCanceled: true,
    );
  }
  
  bool get hasFrames => frameCount > 0 && !isCanceled;
  double get averageFrameSize => hasFrames ? frames.first.length / 1024.0 : 0.0;
  
  @override
  String toString() {
    return 'VineRecordingResult('
        'frames: $frameCount, '
        'approach: $selectedApproach, '
        'quality: ${(qualityRatio * 100).toStringAsFixed(1)}%, '
        'processing: ${processingTime.inMilliseconds}ms'
        ')';
  }
}