// ABOUTME: Prototype for direct image stream capture approach
// ABOUTME: Captures frames directly from camera stream in real-time

import 'dart:typed_data';
import 'package:camera/camera.dart';

class ImageStreamPrototype {
  late CameraController _controller;
  bool _isCapturing = false;
  final List<Uint8List> _capturedFrames = [];
  late DateTime _startTime;
  
  Future<void> initialize() async {
    final cameras = await availableCameras();
    _controller = CameraController(
      cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    await _controller.initialize();
  }
  
  /// Captures frames directly from camera image stream
  Future<ImageStreamResult> captureFramesFromStream({
    required Duration duration,
    required double targetFPS,
  }) async {
    final stopwatch = Stopwatch()..start();
    _capturedFrames.clear();
    _startTime = DateTime.now();
    
    // Calculate frame interval based on target FPS
    final frameIntervalMs = (1000 / targetFPS).round();
    var lastFrameTime = DateTime.now();
    
    // Start image stream
    await _controller.startImageStream((CameraImage image) {
      final now = DateTime.now();
      
      // Capture frame if enough time has passed
      if (now.difference(lastFrameTime).inMilliseconds >= frameIntervalMs) {
        _captureFrame(image);
        lastFrameTime = now;
      }
    });
    
    _isCapturing = true;
    
    // Capture for specified duration
    await Future.delayed(duration);
    
    // Stop capturing
    await _controller.stopImageStream();
    _isCapturing = false;
    
    final totalTime = stopwatch.elapsed;
    
    // Calculate metrics
    final framesSizeTotal = _capturedFrames.fold<int>(
      0, 
      (sum, frame) => sum + frame.length,
    );
    
    return ImageStreamResult(
      captureTime: totalTime,
      frameCount: _capturedFrames.length,
      targetFPS: targetFPS,
      actualFPS: _capturedFrames.length / (duration.inMilliseconds / 1000.0),
      framesDataSize: framesSizeTotal,
      frames: List.from(_capturedFrames),
      approach: 'Direct Image Stream Capture',
    );
  }
  
  /// Converts camera image to frame data
  void _captureFrame(CameraImage image) {
    if (!_isCapturing) return;
    
    try {
      // Convert CameraImage to RGB bytes
      final frameData = _convertCameraImageToBytes(image);
      _capturedFrames.add(frameData);
    } catch (e) {
      // Handle conversion errors gracefully
      print('Frame capture error: $e');
    }
  }
  
  /// Converts CameraImage to Uint8List (simplified conversion)
  Uint8List _convertCameraImageToBytes(CameraImage image) {
    // Simplified conversion - in practice would handle different formats
    // (YUV420, NV21, etc.) and convert to RGB
    
    final width = image.width;
    final height = image.height;
    final rgbSize = width * height * 3; // RGB
    
    // Create dummy RGB data (in practice, convert from camera format)
    final rgbData = Uint8List(rgbSize);
    
    // Simulate conversion time
    for (int i = 0; i < rgbSize; i += 3) {
      rgbData[i] = 128;     // R
      rgbData[i + 1] = 128; // G  
      rgbData[i + 2] = 128; // B
    }
    
    return rgbData;
  }
  
  void dispose() {
    _controller.dispose();
  }
}

class ImageStreamResult {
  final Duration captureTime;
  final int frameCount;
  final double targetFPS;
  final double actualFPS;
  final int framesDataSize;
  final List<Uint8List> frames;
  final String approach;
  
  ImageStreamResult({
    required this.captureTime,
    required this.frameCount,
    required this.targetFPS,
    required this.actualFPS,
    required this.framesDataSize,
    required this.frames,
    required this.approach,
  });
  
  double get captureTimeSeconds => captureTime.inMilliseconds / 1000.0;
  double get frameRateAccuracy => (actualFPS / targetFPS) * 100;
  double get averageFrameSize => framesDataSize / frameCount;
  
  @override
  String toString() {
    return '''
Approach: $approach
Capture Time: ${captureTime.inMilliseconds}ms
Frame Count: $frameCount
Target FPS: ${targetFPS.toStringAsFixed(1)}
Actual FPS: ${actualFPS.toStringAsFixed(1)}
Frame Rate Accuracy: ${frameRateAccuracy.toStringAsFixed(1)}%
Frames Size: ${(framesDataSize / 1024).toStringAsFixed(1)} KB
Average Frame Size: ${(averageFrameSize / 1024).toStringAsFixed(1)} KB
''';
  }
}

/// Benchmark test for image stream approach
class ImageStreamBenchmark {
  static Future<ImageStreamResult> runBenchmark() async {
    final prototype = ImageStreamPrototype();
    
    try {
      await prototype.initialize();
      
      // Test with 6-second vine recording at 5 FPS
      final result = await prototype.captureFramesFromStream(
        duration: const Duration(seconds: 6),
        targetFPS: 5.0,
      );
      
      return result;
    } finally {
      prototype.dispose();
    }
  }
}