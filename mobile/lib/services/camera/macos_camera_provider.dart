// ABOUTME: macOS camera provider with fallback implementation
// ABOUTME: Uses test frames until native implementation is ready

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'camera_provider.dart';
import 'native_macos_camera.dart';
import '../utils/unified_logger.dart';
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
      Log.debug('[MacosCameraProvider] Development mode - using fallback implementation', name: 'MacosCameraProvider', category: LogCategory.video);
      Log.debug('This bypasses macOS permission issues during development', name: 'MacosCameraProvider', category: LogCategory.video);
      await _initializeFallbackMode();
      return;
    }
    
    try {
      Log.debug('� [MacosCameraProvider] Starting initialization (native mode)', name: 'MacosCameraProvider', category: LogCategory.video);
      
      // Check permission first
      Log.debug('� [MacosCameraProvider] Checking camera permission...', name: 'MacosCameraProvider', category: LogCategory.video);
      final hasPermission = await NativeMacOSCamera.hasPermission();
      Log.debug('� [MacosCameraProvider] Has permission: $hasPermission', name: 'MacosCameraProvider', category: LogCategory.video);
      
      if (!hasPermission) {
        Log.debug('� [MacosCameraProvider] Requesting camera permission...', name: 'MacosCameraProvider', category: LogCategory.video);
        final granted = await NativeMacOSCamera.requestPermission();
        Log.debug('� [MacosCameraProvider] Permission granted: $granted', name: 'MacosCameraProvider', category: LogCategory.video);
        if (!granted) {
          Log.warning('[MacosCameraProvider] Permission denied, falling back to test mode', name: 'MacosCameraProvider', category: LogCategory.video);
          await _initializeFallbackMode();
          return;
        }
      }
      
      // Initialize native camera
      Log.debug('� [MacosCameraProvider] Initializing native camera...', name: 'MacosCameraProvider', category: LogCategory.video);
      final initialized = await NativeMacOSCamera.initialize();
      Log.info('� [MacosCameraProvider] Native camera initialized: $initialized', name: 'MacosCameraProvider', category: LogCategory.video);
      if (!initialized) {
        Log.error('[MacosCameraProvider] Native init failed, falling back to test mode', name: 'MacosCameraProvider', category: LogCategory.video);
        await _initializeFallbackMode();
        return;
      }
      
      // Start preview
      Log.debug('� [MacosCameraProvider] Starting camera preview...', name: 'MacosCameraProvider', category: LogCategory.video);
      final previewStarted = await NativeMacOSCamera.startPreview();
      Log.info('� [MacosCameraProvider] Preview started: $previewStarted', name: 'MacosCameraProvider', category: LogCategory.video);
      if (!previewStarted) {
        Log.error('[MacosCameraProvider] Preview failed, falling back to test mode', name: 'MacosCameraProvider', category: LogCategory.video);
        await _initializeFallbackMode();
        return;
      }
      
      _isInitialized = true;
      Log.info('[MacosCameraProvider] Successfully initialized with native implementation', name: 'MacosCameraProvider', category: LogCategory.video);
    } catch (e) {
      Log.error('[MacosCameraProvider] Native camera failed: $e', name: 'MacosCameraProvider', category: LogCategory.video);
      Log.debug('[MacosCameraProvider] Falling back to development test mode', name: 'MacosCameraProvider', category: LogCategory.video);
      await _initializeFallbackMode();
    }
  }
  
  /// Initialize fallback mode for development (bypasses camera permissions)
  Future<void> _initializeFallbackMode() async {
    Log.debug('[MacosCameraProvider] Initializing fallback mode', name: 'MacosCameraProvider', category: LogCategory.video);
    Log.debug('� This provides a working camera interface for development', name: 'MacosCameraProvider', category: LogCategory.video);
    
    _isInitialized = true;
    Log.info('[MacosCameraProvider] Fallback mode initialized successfully', name: 'MacosCameraProvider', category: LogCategory.video);
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
    Log.debug('� [MacosCameraProvider] startRecording called', name: 'MacosCameraProvider', category: LogCategory.video);
    Log.info('� [MacosCameraProvider] initialized: $isInitialized, recording: $_isRecording', name: 'MacosCameraProvider', category: LogCategory.video);
    
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
        Log.debug('[MacosCameraProvider] Starting fallback recording (dev mode)', name: 'MacosCameraProvider', category: LogCategory.video);
        await _startFallbackRecording();
        return;
      }
      
      Log.debug('� [MacosCameraProvider] Starting native macOS camera recording', name: 'MacosCameraProvider', category: LogCategory.video);
      
      // Start native recording
      final recordingStarted = await NativeMacOSCamera.startRecording();
      Log.info('� [MacosCameraProvider] Native recording started: $recordingStarted', name: 'MacosCameraProvider', category: LogCategory.video);
      if (!recordingStarted) {
        throw CameraProviderException('Failed to start native recording');
      }
      
      // Subscribe to frame stream for real-time processing
      Log.debug('� [MacosCameraProvider] Setting up frame stream subscription', name: 'MacosCameraProvider', category: LogCategory.video);
      _frameSubscription = NativeMacOSCamera.frameStream.listen(
        (frame) {
          _realtimeFrames.add(frame);
          _frameCallback?.call(frame);
          // Log every 30th frame to avoid spam but show activity
          if (_realtimeFrames.length % 30 == 0) {
            Log.verbose('[MacosCameraProvider] Captured ${_realtimeFrames.length} frames', name: 'MacosCameraProvider', category: LogCategory.video);
          }
        },
        onError: (error) {
          Log.error('[MacosCameraProvider] Frame stream error: $error', name: 'MacosCameraProvider', category: LogCategory.video);
        },
      );
      
      Log.info('[MacosCameraProvider] Native macOS camera recording started successfully', name: 'MacosCameraProvider', category: LogCategory.video);
      
      // Auto-stop after max duration using Timer for proper cancellation
      _autoStopTimer = Timer(maxVineDuration, () {
        if (_isRecording) {
          Log.debug('⏱️ [MacosCameraProvider] Auto-stopping recording after ${maxVineDuration.inSeconds}s', name: 'MacosCameraProvider', category: LogCategory.video);
          stopRecording();
        }
      });
    } catch (e) {
      Log.error('[MacosCameraProvider] Failed to start recording: $e', name: 'MacosCameraProvider', category: LogCategory.video);
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
    
    Log.debug('� [MacosCameraProvider] stopRecording called, _isRecording: $_isRecording', name: 'MacosCameraProvider', category: LogCategory.video);
    
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
        Log.debug('[MacosCameraProvider] Stopping fallback recording (dev mode)', name: 'MacosCameraProvider', category: LogCategory.video);
        return _stopFallbackRecording(duration);
      }
      
      Log.debug('� Stopping native macOS camera recording', name: 'MacosCameraProvider', category: LogCategory.video);
      
      // Stop native recording
      final videoPath = await NativeMacOSCamera.stopRecording();
      Log.info('� [MacosCameraProvider] Native stopRecording completed with path: $videoPath', name: 'MacosCameraProvider', category: LogCategory.video);
      
      // Stop frame subscription
      await _frameSubscription?.cancel();
      _frameSubscription = null;
      
      Log.info('Native macOS camera recording stopped', name: 'MacosCameraProvider', category: LogCategory.video);
      Log.debug('� Video saved to: $videoPath', name: 'MacosCameraProvider', category: LogCategory.video);
      Log.debug('Captured ${_realtimeFrames.length} live frames', name: 'MacosCameraProvider', category: LogCategory.video);
      
      return CameraRecordingResult(
        videoPath: videoPath ?? '/tmp/openvine_recording.mp4', // Provide fallback if null
        liveFrames: List.from(_realtimeFrames), // Copy captured frames
        width: 1920, // HD resolution from native camera
        height: 1080,
        duration: duration,
      );
    } catch (e) {
      Log.error('Error stopping native recording: $e', name: 'MacosCameraProvider', category: LogCategory.video);
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
      Log.debug('Switching native macOS camera', name: 'MacosCameraProvider', category: LogCategory.video);
      
      final switched = await NativeMacOSCamera.switchCamera(1);
      if (switched) {
        Log.info('Camera switched successfully', name: 'MacosCameraProvider', category: LogCategory.video);
      } else {
        Log.error('Camera switch not supported or failed', name: 'MacosCameraProvider', category: LogCategory.video);
      }
    } catch (e) {
      Log.error('Error switching camera: $e', name: 'MacosCameraProvider', category: LogCategory.video);
    }
  }
  
  @override
  Future<void> dispose() async {
    if (_isRecording) {
      try {
        await stopRecording();
      } catch (e) {
        Log.error('Error stopping recording during disposal: $e', name: 'MacosCameraProvider', category: LogCategory.video);
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
      Log.info('Native macOS camera disposed', name: 'MacosCameraProvider', category: LogCategory.video);
    } catch (e) {
      Log.error('Error disposing native camera: $e', name: 'MacosCameraProvider', category: LogCategory.video);
    }
    
    _isInitialized = false;
  }
  
  /// Start fallback recording for development mode
  Future<void> _startFallbackRecording() async {
    Log.debug('[MacosCameraProvider] Starting fallback recording simulation', name: 'MacosCameraProvider', category: LogCategory.video);
    
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
        Log.debug('⏱️ [MacosCameraProvider] Auto-stopping fallback recording after ${maxVineDuration.inSeconds}s', name: 'MacosCameraProvider', category: LogCategory.video);
        stopRecording();
      }
    });
    
    Log.info('[MacosCameraProvider] Fallback recording started successfully', name: 'MacosCameraProvider', category: LogCategory.video);
  }
  
  /// Stop fallback recording and return result
  CameraRecordingResult _stopFallbackRecording(Duration duration) {
    Log.debug('[MacosCameraProvider] Generating fallback recording result', name: 'MacosCameraProvider', category: LogCategory.video);
    Log.debug('Captured ${_realtimeFrames.length} test frames', name: 'MacosCameraProvider', category: LogCategory.video);
    
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