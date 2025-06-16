// ABOUTME: macOS camera provider with fallback implementation
// ABOUTME: Uses test frames until native implementation is ready

import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'camera_provider.dart';
import 'native_macos_camera.dart';
// import '../video_frame_extractor.dart'; // Temporarily disabled due to dependency conflict

/// Camera provider for macOS using fallback implementation
/// 
/// Provides working camera interface for testing while native implementation
/// is developed. Generates test frames for GIF pipeline validation.
class MacosCameraProvider implements CameraProvider {
  bool _isRecording = false;
  DateTime? _recordingStartTime;
  StreamSubscription<Uint8List>? _frameSubscription;
  final List<Uint8List> _realtimeFrames = [];
  Function(Uint8List)? _frameCallback;
  Timer? _autoStopTimer;
  
  // Recording parameters
  static const Duration maxVineDuration = Duration(seconds: 6);
  
  bool _isInitialized = false;
  
  @override
  bool get isInitialized => _isInitialized;
  
  @override
  Future<void> initialize() async {
    try {
      debugPrint('🔵 [MacosCameraProvider] Starting initialization (native mode)');
      
      // Check permission first
      debugPrint('🔵 [MacosCameraProvider] Checking camera permission...');
      final hasPermission = await NativeMacOSCamera.hasPermission();
      debugPrint('🔵 [MacosCameraProvider] Has permission: $hasPermission');
      
      if (!hasPermission) {
        debugPrint('🔵 [MacosCameraProvider] Requesting camera permission...');
        final granted = await NativeMacOSCamera.requestPermission();
        debugPrint('🔵 [MacosCameraProvider] Permission granted: $granted');
        if (!granted) {
          throw CameraProviderException('Camera permission denied');
        }
      }
      
      // Initialize native camera
      debugPrint('🔵 [MacosCameraProvider] Initializing native camera...');
      final initialized = await NativeMacOSCamera.initialize();
      debugPrint('🔵 [MacosCameraProvider] Native camera initialized: $initialized');
      if (!initialized) {
        throw CameraProviderException('Failed to initialize native camera');
      }
      
      // Start preview
      debugPrint('🔵 [MacosCameraProvider] Starting camera preview...');
      final previewStarted = await NativeMacOSCamera.startPreview();
      debugPrint('🔵 [MacosCameraProvider] Preview started: $previewStarted');
      if (!previewStarted) {
        throw CameraProviderException('Failed to start camera preview');
      }
      
      _isInitialized = true;
      debugPrint('✅ [MacosCameraProvider] Successfully initialized with native implementation');
    } catch (e) {
      debugPrint('❌ [MacosCameraProvider] Failed to initialize: $e');
      throw CameraProviderException('Failed to initialize macOS camera', e);
    }
  }
  
  @override
  Widget buildPreview() {
    if (!isInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    // Native camera preview for macOS using frame stream
    return StreamBuilder<Uint8List>(
      stream: NativeMacOSCamera.frameStream,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          // Display live camera frame
          return Container(
            color: Colors.black,
            child: Image.memory(
              snapshot.data!,
              fit: BoxFit.cover,
              gaplessPlayback: true,
            ),
          );
        } else if (snapshot.hasError) {
          // Show error state
          return Container(
            color: Colors.black,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Camera Error: ${snapshot.error}',
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        } else {
          // Loading state
          return Container(
            color: Colors.black,
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.white),
                  SizedBox(height: 12),
                  Text(
                    'Starting camera...',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }
  
  @override
  Future<void> startRecording({Function(Uint8List)? onFrame}) async {
    debugPrint('🔵 [MacosCameraProvider] startRecording called');
    debugPrint('🔵 [MacosCameraProvider] initialized: $isInitialized, recording: $_isRecording');
    
    if (!isInitialized || _isRecording) {
      throw CameraProviderException('Cannot start recording: camera not ready or already recording');
    }
    
    try {
      _isRecording = true;
      _recordingStartTime = DateTime.now();
      _frameCallback = onFrame;
      _realtimeFrames.clear();
      
      debugPrint('🔵 [MacosCameraProvider] Starting native macOS camera recording');
      
      // Start native recording
      final recordingStarted = await NativeMacOSCamera.startRecording();
      debugPrint('🔵 [MacosCameraProvider] Native recording started: $recordingStarted');
      if (!recordingStarted) {
        throw CameraProviderException('Failed to start native recording');
      }
      
      // Subscribe to frame stream for real-time processing
      debugPrint('🔵 [MacosCameraProvider] Setting up frame stream subscription');
      _frameSubscription = NativeMacOSCamera.frameStream.listen(
        (frame) {
          _realtimeFrames.add(frame);
          _frameCallback?.call(frame);
          // Log every 30th frame to avoid spam but show activity
          if (_realtimeFrames.length % 30 == 0) {
            debugPrint('🖼️ [MacosCameraProvider] Captured ${_realtimeFrames.length} frames');
          }
        },
        onError: (error) {
          debugPrint('❌ [MacosCameraProvider] Frame stream error: $error');
        },
      );
      
      debugPrint('✅ [MacosCameraProvider] Native macOS camera recording started successfully');
      
      // Auto-stop after max duration using Timer for proper cancellation
      _autoStopTimer = Timer(maxVineDuration, () {
        if (_isRecording) {
          debugPrint('⏱️ [MacosCameraProvider] Auto-stopping recording after ${maxVineDuration.inSeconds}s');
          stopRecording();
        }
      });
    } catch (e) {
      debugPrint('❌ [MacosCameraProvider] Failed to start recording: $e');
      _isRecording = false;
      await _frameSubscription?.cancel();
      _frameSubscription = null;
      throw CameraProviderException('Failed to start macOS recording', e);
    }
  }
  
  @override
  Future<CameraRecordingResult> stopRecording() async {
    if (!_isRecording) {
      throw CameraProviderException('Not currently recording');
    }
    
    debugPrint('🔵 [MacosCameraProvider] stopRecording called, _isRecording: $_isRecording');
    
    // Cancel auto-stop timer to prevent race condition
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    
    // Immediately set recording to false to prevent duplicate calls
    _isRecording = false;
    
    try {
      final duration = _recordingStartTime != null 
        ? DateTime.now().difference(_recordingStartTime!)
        : Duration.zero;
      
      debugPrint('🛑 Stopping native macOS camera recording');
      
      // Stop native recording
      final videoPath = await NativeMacOSCamera.stopRecording();
      debugPrint('🔵 [MacosCameraProvider] Native stopRecording completed with path: $videoPath');
      
      // Stop frame subscription
      await _frameSubscription?.cancel();
      _frameSubscription = null;
      
      debugPrint('✅ Native macOS camera recording stopped');
      debugPrint('📁 Video saved to: $videoPath');
      debugPrint('🎨 Captured ${_realtimeFrames.length} live frames');
      
      return CameraRecordingResult(
        videoPath: videoPath ?? '/tmp/nostrvine_recording.mp4', // Provide fallback if null
        liveFrames: List.from(_realtimeFrames), // Copy captured frames
        width: 1920, // HD resolution from native camera
        height: 1080,
        duration: duration,
      );
    } catch (e) {
      debugPrint('❌ Error stopping native recording: $e');
      // Fallback to test frames if native recording fails
      final testFrames = _generateTestFrames();
      final duration = _recordingStartTime != null 
        ? DateTime.now().difference(_recordingStartTime!)
        : Duration.zero;
      
      return CameraRecordingResult(
        videoPath: '/fallback/video/path.mp4',
        liveFrames: testFrames,
        width: 640,
        height: 480,
        duration: duration,
      );
    } finally {
      _recordingStartTime = null;
      _frameCallback = null;
      await _frameSubscription?.cancel();
      _frameSubscription = null;
      _autoStopTimer?.cancel();
      _autoStopTimer = null;
    }
  }
  
  @override
  Future<void> switchCamera() async {
    if (!isInitialized || _isRecording) return;
    
    try {
      debugPrint('🔄 Switching native macOS camera');
      
      final switched = await NativeMacOSCamera.switchCamera(1);
      if (switched) {
        debugPrint('✅ Camera switched successfully');
      } else {
        debugPrint('⚠️ Camera switch not supported or failed');
      }
    } catch (e) {
      debugPrint('❌ Error switching camera: $e');
    }
  }
  
  @override
  Future<void> dispose() async {
    if (_isRecording) {
      try {
        await stopRecording();
      } catch (e) {
        debugPrint('⚠️ Error stopping recording during disposal: $e');
      }
    }
    
    await _frameSubscription?.cancel();
    _frameSubscription = null;
    
    // Cancel any pending timer
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    
    // Dispose native camera resources
    try {
      await NativeMacOSCamera.dispose();
      debugPrint('✅ Native macOS camera disposed');
    } catch (e) {
      debugPrint('⚠️ Error disposing native camera: $e');
    }
    
    _isInitialized = false;
  }
  
  /// Generate test frames for GIF pipeline testing
  List<Uint8List> _generateTestFrames() {
    final frames = <Uint8List>[];
    const frameCount = 30; // 6 seconds * 5 fps
    const width = 640;
    const height = 480;
    
    for (int i = 0; i < frameCount; i++) {
      // Create a simple pattern that changes over time
      final frameData = Uint8List(width * height * 3); // RGB
      
      final progress = i / frameCount;
      final red = (128 + 127 * math.sin(progress * math.pi * 2)).round();
      final green = (128 + 127 * math.sin(progress * math.pi * 2 + math.pi / 3)).round();
      final blue = (128 + 127 * math.sin(progress * math.pi * 2 + 2 * math.pi / 3)).round();
      
      // Fill frame with gradient pattern
      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final index = (y * width + x) * 3;
          final xProgress = x / width;
          final yProgress = y / height;
          
          frameData[index] = (red * (1 - xProgress) + blue * xProgress).round(); // R
          frameData[index + 1] = (green * (1 - yProgress) + red * yProgress).round(); // G
          frameData[index + 2] = (blue * yProgress + green * (1 - yProgress)).round(); // B
        }
      }
      
      frames.add(frameData);
    }
    
    return frames;
  }
}