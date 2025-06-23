// ABOUTME: macOS camera provider with fallback implementation
// ABOUTME: Uses test frames until native implementation is ready

import 'dart:async';
import 'dart:math' as math;
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
  static const Duration maxVineDuration = Duration(milliseconds: 6300); // 6.3 seconds like original Vine
  
  bool _isInitialized = false;
  
  @override
  bool get isInitialized => _isInitialized;
  
  @override
  Future<void> initialize() async {
    // Development mode: Skip native camera permissions during debug builds
    final isDevelopmentMode = kDebugMode;
    
    if (isDevelopmentMode) {
      debugPrint('🔧 [MacosCameraProvider] Development mode - using fallback implementation');
      debugPrint('🔧 This bypasses macOS permission issues during development');
      await _initializeFallbackMode();
      return;
    }
    
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
          debugPrint('⚠️ [MacosCameraProvider] Permission denied, falling back to test mode');
          await _initializeFallbackMode();
          return;
        }
      }
      
      // Initialize native camera
      debugPrint('🔵 [MacosCameraProvider] Initializing native camera...');
      final initialized = await NativeMacOSCamera.initialize();
      debugPrint('🔵 [MacosCameraProvider] Native camera initialized: $initialized');
      if (!initialized) {
        debugPrint('⚠️ [MacosCameraProvider] Native init failed, falling back to test mode');
        await _initializeFallbackMode();
        return;
      }
      
      // Start preview
      debugPrint('🔵 [MacosCameraProvider] Starting camera preview...');
      final previewStarted = await NativeMacOSCamera.startPreview();
      debugPrint('🔵 [MacosCameraProvider] Preview started: $previewStarted');
      if (!previewStarted) {
        debugPrint('⚠️ [MacosCameraProvider] Preview failed, falling back to test mode');
        await _initializeFallbackMode();
        return;
      }
      
      _isInitialized = true;
      debugPrint('✅ [MacosCameraProvider] Successfully initialized with native implementation');
    } catch (e) {
      debugPrint('❌ [MacosCameraProvider] Native camera failed: $e');
      debugPrint('🔧 [MacosCameraProvider] Falling back to development test mode');
      await _initializeFallbackMode();
    }
  }
  
  /// Initialize fallback mode for development (bypasses camera permissions)
  Future<void> _initializeFallbackMode() async {
    debugPrint('🔧 [MacosCameraProvider] Initializing fallback mode');
    debugPrint('📸 This provides a working camera interface for development');
    
    _isInitialized = true;
    debugPrint('✅ [MacosCameraProvider] Fallback mode initialized successfully');
  }
  
  @override
  Widget buildPreview() {
    if (!isInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    // Check if we're in development/fallback mode
    if (kDebugMode) {
      return _buildFallbackPreview();
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
  
  /// Build fallback preview for development mode
  Widget _buildFallbackPreview() {
    return Container(
      color: const Color(0xFF1a1a2e),
      child: Stack(
        children: [
          // Animated gradient background to simulate video
          AnimatedBuilder(
            animation: AlwaysStoppedAnimation(0),
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xFF16213e),
                      const Color(0xFF0f3460),
                      const Color(0xFF16537e),
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              );
            },
          ),
          
          // Development mode indicator
          Positioned(
            top: 20,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.developer_mode, size: 16, color: Colors.white),
                  SizedBox(width: 4),
                  Text(
                    'DEV MODE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Fake camera frame indicator
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.videocam,
                  size: 80,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 16),
                Text(
                  'Camera Preview\n(Development Mode)',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Bypassing macOS permissions\nfor faster development',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          // Recording indicator when recording
          if (_isRecording)
            Positioned(
              top: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fiber_manual_record, size: 12, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'REC',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
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
      
      // Check if we're in development/fallback mode
      if (kDebugMode) {
        debugPrint('🔧 [MacosCameraProvider] Starting fallback recording (dev mode)');
        await _startFallbackRecording();
        return;
      }
      
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
      
      // Check if we're in development/fallback mode
      if (kDebugMode) {
        debugPrint('🔧 [MacosCameraProvider] Stopping fallback recording (dev mode)');
        return _stopFallbackRecording(duration);
      }
      
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
        videoPath: videoPath ?? '/tmp/openvine_recording.mp4', // Provide fallback if null
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
  
  /// Start fallback recording for development mode
  Future<void> _startFallbackRecording() async {
    debugPrint('🔧 [MacosCameraProvider] Starting fallback recording simulation');
    
    // Generate test frames periodically to simulate real-time capture
    Timer.periodic(const Duration(milliseconds: 200), (timer) {
      if (!_isRecording) {
        timer.cancel();
        return;
      }
      
      // Generate a test frame
      final testFrame = _generateSingleTestFrame(_realtimeFrames.length);
      _realtimeFrames.add(testFrame);
      _frameCallback?.call(testFrame);
      
      // Stop at reasonable number of frames (6 seconds @ 5fps = 30 frames)
      if (_realtimeFrames.length >= 30) {
        timer.cancel();
        if (_isRecording) {
          stopRecording();
        }
      }
    });
    
    // Auto-stop after max duration
    _autoStopTimer = Timer(maxVineDuration, () {
      if (_isRecording) {
        debugPrint('⏱️ [MacosCameraProvider] Auto-stopping fallback recording after ${maxVineDuration.inSeconds}s');
        stopRecording();
      }
    });
    
    debugPrint('✅ [MacosCameraProvider] Fallback recording started successfully');
  }
  
  /// Stop fallback recording and return result
  CameraRecordingResult _stopFallbackRecording(Duration duration) {
    debugPrint('🔧 [MacosCameraProvider] Generating fallback recording result');
    debugPrint('🎨 Captured ${_realtimeFrames.length} test frames');
    
    return CameraRecordingResult(
      videoPath: '/dev/fallback/openvine_test_video.mp4',
      liveFrames: List.from(_realtimeFrames),
      width: 640,
      height: 480,
      duration: duration,
    );
  }
  
  /// Generate a single test frame for fallback mode
  Uint8List _generateSingleTestFrame(int frameIndex) {
    const width = 640;
    const height = 480;
    final frameData = Uint8List(width * height * 3); // RGB
    
    final progress = frameIndex / 30.0; // Assuming 30 frames total
    final red = (128 + 127 * math.sin(progress * math.pi * 2)).round();
    final green = (128 + 127 * math.sin(progress * math.pi * 2 + math.pi / 3)).round();
    final blue = (128 + 127 * math.sin(progress * math.pi * 2 + 2 * math.pi / 3)).round();
    
    // Create animated gradient pattern
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final index = (y * width + x) * 3;
        final xProgress = x / width;
        final yProgress = y / height;
        
        // Animate the pattern based on frame index
        final timeOffset = progress * 2 * math.pi;
        final animatedRed = (red * (1 - xProgress) + blue * xProgress * math.cos(timeOffset)).round().clamp(0, 255);
        final animatedGreen = (green * (1 - yProgress) + red * yProgress * math.sin(timeOffset)).round().clamp(0, 255);
        final animatedBlue = (blue * yProgress + green * (1 - yProgress) * math.cos(timeOffset + math.pi)).round().clamp(0, 255);
        
        frameData[index] = animatedRed; // R
        frameData[index + 1] = animatedGreen; // G
        frameData[index + 2] = animatedBlue; // B
      }
    }
    
    return frameData;
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