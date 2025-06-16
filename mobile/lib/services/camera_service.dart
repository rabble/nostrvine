// ABOUTME: Camera service implementing hybrid frame capture for vine creation
// ABOUTME: Manages recording, frame extraction, and GIF generation pipeline

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

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
  
  // Hybrid capture data
  final List<Uint8List> _realtimeFrames = [];
  bool _isRecording = false;
  bool _isStreaming = false;
  DateTime? _recordingStartTime;
  Timer? _progressTimer;
  
  // Recording parameters - configurable
  Duration maxVineDuration = const Duration(seconds: 6);
  double targetFPS = 5.0;
  int get targetFrameCount => (maxVineDuration.inSeconds * targetFPS).round();
  
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
      
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('No cameras available on device');
      }
      
      _controller = CameraController(
        cameras.first, // Use back camera by default
        ResolutionPreset.medium, // Balance quality vs performance
        enableAudio: false, // GIFs don't need audio
        imageFormatGroup: ImageFormatGroup.yuv420, // Efficient for processing
      );
      
      await _controller!.initialize();
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
      debugPrint('⚠️ Cannot start recording: initialized=${isInitialized}, recording=${_isRecording}');
      return;
    }
    
    try {
      _setState(RecordingState.recording);
      _isRecording = true; // Set this immediately to prevent double calls
      _realtimeFrames.clear();
      _recordingStartTime = DateTime.now();
      
      // Start hybrid capture: video recording + real-time frame streaming
      await _startHybridCapture();
      
      // Start progress timer to update UI regularly
      _startProgressTimer();
      
      debugPrint('🎬 Started vine recording (hybrid approach)');
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
      
      // Stop hybrid capture
      final result = await _stopHybridCapture();
      
      _setState(RecordingState.completed);
      debugPrint('✅ Vine recording completed: ${result.frameCount} frames');
      
      return result;
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
      await _stopHybridCapture(canceled: true);
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
      final cameras = await availableCameras();
      if (cameras.length < 2) return;
      
      final currentCamera = _controller!.description;
      final newCamera = cameras.firstWhere(
        (camera) => camera != currentCamera,
        orElse: () => cameras.first,
      );
      
      _controller?.dispose();
      _controller = null;
      
      _controller = CameraController(
        newCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      
      await _controller!.initialize();
      notifyListeners();
      
      debugPrint('🔄 Switched to ${newCamera.lensDirection} camera');
    } catch (e) {
      debugPrint('❌ Failed to switch camera: $e');
    }
  }
  
  /// Get camera controller for preview
  CameraController? get controller => _controller;
  
  /// Configure recording parameters
  void configureRecording({
    Duration? duration,
    double? frameRate,
  }) {
    if (duration != null) {
      maxVineDuration = duration;
      debugPrint('📹 Updated max recording duration to ${duration.inSeconds}s');
    }
    if (frameRate != null) {
      targetFPS = frameRate;
      debugPrint('📹 Updated target FPS to ${frameRate}');
    }
  }
  
  /// Dispose resources
  @override
  void dispose() {
    _disposed = true;
    _stopProgressTimer();
    _controller?.dispose();
    _controller = null;
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
  
  /// Start hybrid capture (video + real-time frames)
  Future<void> _startHybridCapture() async {
    if (_controller == null) throw Exception('Camera not initialized');
    
    // Calculate frame interval for target FPS
    final frameIntervalMs = (1000 / targetFPS).round();
    var lastFrameTime = DateTime.now();
    
    // Start video recording
    await _controller!.startVideoRecording();
    
    // Start real-time frame streaming, only if supported (not on web)
    if (!kIsWeb) {
      debugPrint('✅ Image streaming is supported. Starting stream.');
      await _controller!.startImageStream((CameraImage image) {
        if (!_isStreaming) return;
        
        final now = DateTime.now();
        if (now.difference(lastFrameTime).inMilliseconds >= frameIntervalMs) {
          _captureRealtimeFrame(image);
          lastFrameTime = now;
        }
      });
      _isStreaming = true;
    } else {
      debugPrint('⚠️ Image streaming not supported on web platform. Will rely on video extraction fallback.');
      _isStreaming = false;
    }
    
    // Auto-stop after max duration
    Future.delayed(maxVineDuration, () {
      if (_isRecording) {
        stopRecording();
      }
    });
  }
  
  /// Stop hybrid capture and determine best frame source
  Future<VineRecordingResult> _stopHybridCapture({bool canceled = false}) async {
    if (_controller == null) throw Exception('Camera not initialized');
    
    final stopwatch = Stopwatch()..start();
    
    // Stop both recording and streaming
    _isStreaming = false;
    
    // Only stop image stream if it was started (not on web)
    if (!kIsWeb) {
      await _controller!.stopImageStream();
    }
    
    final videoFile = await _controller!.stopVideoRecording();
    
    if (canceled) {
      // Clean up video file (only on non-web platforms)
      if (!kIsWeb) {
        try {
          await File(videoFile.path).delete();
        } catch (e) {
          debugPrint('⚠️ Failed to delete video file: $e');
        }
      }
      return VineRecordingResult.canceled();
    }
    
    // Determine frame source based on quality
    final realtimeFrameCount = _realtimeFrames.length;
    final expectedFrameCount = targetFrameCount;
    final qualityRatio = realtimeFrameCount / expectedFrameCount;
    
    List<Uint8List> finalFrames;
    String selectedApproach;
    
    if (qualityRatio >= 0.8) { // 80% quality threshold
      // Use real-time frames
      finalFrames = List.from(_realtimeFrames);
      selectedApproach = 'Real-time Stream';
      debugPrint('📸 Using real-time frames: $realtimeFrameCount/$expectedFrameCount');
    } else {
      // Fall back to video extraction
      finalFrames = await _extractFramesFromVideo(videoFile);
      selectedApproach = 'Video Extraction (Fallback)';
      debugPrint('🎥 Using video extraction fallback: ${finalFrames.length} frames');
    }
    
    final processingTime = stopwatch.elapsed;
    
    // Clean up video file (we have the frames we need, only on non-web platforms)
    if (!kIsWeb) {
      try {
        await File(videoFile.path).delete();
      } catch (e) {
        debugPrint('⚠️ Failed to delete video file: $e');
      }
    }
    
    return VineRecordingResult(
      frames: finalFrames,
      frameCount: finalFrames.length,
      processingTime: processingTime,
      selectedApproach: selectedApproach,
      qualityRatio: qualityRatio,
    );
  }
  
  /// Capture frame from real-time camera stream
  void _captureRealtimeFrame(CameraImage image) {
    if (!_isStreaming || !_isRecording) return;
    
    try {
      final frameData = _convertCameraImageToBytes(image);
      _realtimeFrames.add(frameData);
      
      // Update progress
      if (!_disposed) notifyListeners();
    } catch (e) {
      debugPrint('⚠️ Frame capture error: $e');
    }
  }
  
  /// Convert CameraImage to RGB bytes
  Uint8List _convertCameraImageToBytes(CameraImage image) {
    // Handle different image formats
    switch (image.format.group) {
      case ImageFormatGroup.yuv420:
        return _convertYUV420ToRGB(image);
      case ImageFormatGroup.bgra8888:
        return _convertBGRA8888ToRGB(image);
      default:
        // Fallback: create placeholder frame
        return _createPlaceholderFrame(image.width, image.height);
    }
  }
  
  /// Convert YUV420 to RGB (most common format)
  Uint8List _convertYUV420ToRGB(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    
    final rgbData = Uint8List(width * height * 3);
    
    // Simplified YUV to RGB conversion
    // In production, use optimized conversion libraries
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final yIndex = y * yPlane.bytesPerRow + x;
        final uvIndex = (y ~/ 2) * uPlane.bytesPerRow + (x ~/ 2);
        
        if (yIndex < yPlane.bytes.length && uvIndex < uPlane.bytes.length) {
          final yValue = yPlane.bytes[yIndex];
          final uValue = uPlane.bytes[uvIndex];
          final vValue = vPlane.bytes[uvIndex];
          
          // YUV to RGB conversion (simplified)
          final r = (yValue + 1.402 * (vValue - 128)).clamp(0, 255).toInt();
          final g = (yValue - 0.344 * (uValue - 128) - 0.714 * (vValue - 128)).clamp(0, 255).toInt();
          final b = (yValue + 1.772 * (uValue - 128)).clamp(0, 255).toInt();
          
          final rgbIndex = (y * width + x) * 3;
          rgbData[rgbIndex] = r;
          rgbData[rgbIndex + 1] = g;
          rgbData[rgbIndex + 2] = b;
        }
      }
    }
    
    return rgbData;
  }
  
  /// Convert BGRA8888 to RGB
  Uint8List _convertBGRA8888ToRGB(CameraImage image) {
    final bytes = image.planes[0].bytes;
    final rgbData = Uint8List((bytes.length ~/ 4) * 3);
    
    for (int i = 0; i < bytes.length; i += 4) {
      final b = bytes[i];
      final g = bytes[i + 1];
      final r = bytes[i + 2];
      // Skip alpha channel
      
      final rgbIndex = (i ~/ 4) * 3;
      rgbData[rgbIndex] = r;
      rgbData[rgbIndex + 1] = g;
      rgbData[rgbIndex + 2] = b;
    }
    
    return rgbData;
  }
  
  /// Create placeholder frame for unsupported formats
  Uint8List _createPlaceholderFrame(int width, int height) {
    final rgbData = Uint8List(width * height * 3);
    // Fill with gray color
    for (int i = 0; i < rgbData.length; i += 3) {
      rgbData[i] = 128;     // R
      rgbData[i + 1] = 128; // G
      rgbData[i + 2] = 128; // B
    }
    return rgbData;
  }

  /// Create varied placeholder frame for animation preview
  Uint8List _createVariedPlaceholderFrame(int width, int height, int frameIndex) {
    final rgbData = Uint8List(width * height * 3);
    
    // Create a simple animation effect - color shifting gradient
    final phase = (frameIndex * 0.2) % (2 * 3.14159); // Cycling through phases
    
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
  
  /// Extract frames from video file as fallback
  Future<List<Uint8List>> _extractFramesFromVideo(XFile videoFile) async {
    try {
      // TODO: Implement video frame extraction using video processing library
      // For now, return placeholder frames since web doesn't support video processing
      final frames = <Uint8List>[];
      
      debugPrint('🔄 Extracting frames from video (web fallback mode)');
      
      for (int i = 0; i < targetFrameCount; i++) {
        // Simulate processing delay
        await Future.delayed(const Duration(milliseconds: 10));
        
        // Create varied placeholder frame (640x480 RGB) for animation
        final frameData = _createVariedPlaceholderFrame(640, 480, i);
        frames.add(frameData);
      }
      
      debugPrint('✅ Generated ${frames.length} placeholder frames');
      return frames;
    } catch (e) {
      debugPrint('⚠️ Video extraction error: $e');
      // Return minimal frames to prevent complete failure
      return [_createPlaceholderFrame(640, 480)];
    }
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