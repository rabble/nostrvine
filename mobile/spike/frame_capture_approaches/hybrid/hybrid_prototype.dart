// ABOUTME: Prototype for hybrid frame capture approach
// ABOUTME: Combines video recording with real-time frame streaming

import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';

class HybridPrototype {
  late CameraController _controller;
  bool _isRecording = false;
  bool _isStreaming = false;
  final List<Uint8List> _realtimeFrames = [];
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
  
  /// Hybrid approach: Record video AND capture frames simultaneously
  Future<HybridResult> captureWithHybridApproach({
    required Duration duration,
    required double targetFPS,
    required int fallbackFrameCount,
  }) async {
    final stopwatch = Stopwatch()..start();
    _realtimeFrames.clear();
    _startTime = DateTime.now();
    
    // Calculate frame interval for real-time capture
    final frameIntervalMs = (1000 / targetFPS).round();
    var lastFrameTime = DateTime.now();
    
    // Step 1: Start both video recording AND real-time frame capture
    final videoFuture = _startVideoRecording();
    final streamFuture = _startFrameStreaming(frameIntervalMs, lastFrameTime);
    
    await Future.wait([videoFuture, streamFuture]);
    
    // Step 2: Capture for specified duration
    await Future.delayed(duration);
    
    // Step 3: Stop both simultaneously
    final stopVideoFuture = _stopVideoRecording();
    final stopStreamFuture = _stopFrameStreaming();
    
    final results = await Future.wait([stopVideoFuture, stopStreamFuture]);
    final videoFile = results[0] as XFile;
    
    final totalTime = stopwatch.elapsed;
    
    // Step 4: Determine best frame source
    final realtimeFrameCount = _realtimeFrames.length;
    final expectedFrameCount = (duration.inMilliseconds * targetFPS / 1000).round();
    
    bool useRealtimeFrames = realtimeFrameCount >= (expectedFrameCount * 0.8); // 80% threshold
    
    List<Uint8List> finalFrames;
    String selectedApproach;
    Duration processingTime;
    
    if (useRealtimeFrames) {
      // Use real-time captured frames
      finalFrames = List.from(_realtimeFrames);
      selectedApproach = 'Real-time Stream (Primary)';
      processingTime = Duration.zero; // No additional processing needed
    } else {
      // Fall back to video extraction
      final extractionStart = DateTime.now();
      finalFrames = await _extractFramesFromVideo(videoFile, fallbackFrameCount);
      processingTime = DateTime.now().difference(extractionStart);
      selectedApproach = 'Video Extraction (Fallback)';
    }
    
    // Step 5: Calculate metrics
    final videoSize = await File(videoFile.path).length();
    final framesSizeTotal = finalFrames.fold<int>(
      0, 
      (sum, frame) => sum + frame.length,
    );
    
    return HybridResult(
      totalTime: totalTime,
      processingTime: processingTime,
      videoFileSize: videoSize,
      frameCount: finalFrames.length,
      realtimeFrameCount: realtimeFrameCount,
      framesDataSize: framesSizeTotal,
      frames: finalFrames,
      selectedApproach: selectedApproach,
      frameQualityRatio: realtimeFrameCount / expectedFrameCount,
      fallbackUsed: !useRealtimeFrames,
    );
  }
  
  Future<XFile> _startVideoRecording() async {
    await _controller.startVideoRecording();
    _isRecording = true;
    return Future.value(XFile('')); // Placeholder, actual file returned by stop
  }
  
  Future<void> _startFrameStreaming(int frameIntervalMs, DateTime lastFrameTime) async {
    await _controller.startImageStream((CameraImage image) {
      if (!_isStreaming) return;
      
      final now = DateTime.now();
      if (now.difference(lastFrameTime).inMilliseconds >= frameIntervalMs) {
        _captureRealtimeFrame(image);
        lastFrameTime = now;
      }
    });
    _isStreaming = true;
  }
  
  Future<XFile> _stopVideoRecording() async {
    _isRecording = false;
    return await _controller.stopVideoRecording();
  }
  
  Future<void> _stopFrameStreaming() async {
    _isStreaming = false;
    await _controller.stopImageStream();
  }
  
  void _captureRealtimeFrame(CameraImage image) {
    if (!_isStreaming) return;
    
    try {
      final frameData = _convertCameraImageToBytes(image);
      _realtimeFrames.add(frameData);
    } catch (e) {
      // Handle conversion errors gracefully
      print('Real-time frame capture error: $e');
    }
  }
  
  /// Extracts frames from video as fallback
  Future<List<Uint8List>> _extractFramesFromVideo(
    XFile videoFile, 
    int targetFrameCount,
  ) async {
    final frames = <Uint8List>[];
    
    // Simulate video frame extraction
    for (int i = 0; i < targetFrameCount; i++) {
      await Future.delayed(const Duration(milliseconds: 25)); // Faster than real extraction
      
      // Create dummy frame data (in practice, extract from video)
      final frameData = Uint8List(512 * 384 * 3); // RGB data, smaller than full res
      frames.add(frameData);
    }
    
    return frames;
  }
  
  /// Convert CameraImage to bytes (simplified)
  Uint8List _convertCameraImageToBytes(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final rgbSize = width * height * 3; // RGB
    
    final rgbData = Uint8List(rgbSize);
    
    // Simulate conversion (in practice, convert from YUV/NV21 to RGB)
    for (int i = 0; i < rgbSize; i += 3) {
      rgbData[i] = 120;     // R
      rgbData[i + 1] = 130; // G  
      rgbData[i + 2] = 140; // B
    }
    
    return rgbData;
  }
  
  void dispose() {
    _controller.dispose();
  }
}

class HybridResult {
  final Duration totalTime;
  final Duration processingTime;
  final int videoFileSize;
  final int frameCount;
  final int realtimeFrameCount;
  final int framesDataSize;
  final List<Uint8List> frames;
  final String selectedApproach;
  final double frameQualityRatio;
  final bool fallbackUsed;
  
  HybridResult({
    required this.totalTime,
    required this.processingTime,
    required this.videoFileSize,
    required this.frameCount,
    required this.realtimeFrameCount,
    required this.framesDataSize,
    required this.frames,
    required this.selectedApproach,
    required this.frameQualityRatio,
    required this.fallbackUsed,
  });
  
  double get totalTimeSeconds => totalTime.inMilliseconds / 1000.0;
  double get effectiveFrameRate => frameCount / totalTimeSeconds;
  double get reliabilityScore => frameQualityRatio * (fallbackUsed ? 0.8 : 1.0);
  
  @override
  String toString() {
    return '''
Approach: Hybrid (Video + Real-time Stream)
Selected Method: $selectedApproach
Total Time: ${totalTime.inMilliseconds}ms
Processing Time: ${processingTime.inMilliseconds}ms
Frame Count: $frameCount
Real-time Frames: $realtimeFrameCount
Effective Frame Rate: ${effectiveFrameRate.toStringAsFixed(1)} FPS
Frame Quality Ratio: ${(frameQualityRatio * 100).toStringAsFixed(1)}%
Fallback Used: ${fallbackUsed ? 'Yes' : 'No'}
Reliability Score: ${(reliabilityScore * 100).toStringAsFixed(1)}%
Video Size: ${(videoFileSize / 1024).toStringAsFixed(1)} KB
Frames Size: ${(framesDataSize / 1024).toStringAsFixed(1)} KB
''';
  }
}

/// Benchmark test for hybrid approach
class HybridBenchmark {
  static Future<HybridResult> runBenchmark() async {
    final prototype = HybridPrototype();
    
    try {
      await prototype.initialize();
      
      // Test with 6-second vine recording at 5 FPS
      final result = await prototype.captureWithHybridApproach(
        duration: const Duration(seconds: 6),
        targetFPS: 5.0,
        fallbackFrameCount: 30, // Fallback to 30 frames if real-time fails
      );
      
      return result;
    } finally {
      prototype.dispose();
    }
  }
}