// ABOUTME: Mock camera controller for comprehensive video processing pipeline testing
// ABOUTME: Provides controllable camera behavior for unit and integration tests

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:mocktail/mocktail.dart';
import '../helpers/test_video_files.dart';

/// Mock camera controller with controllable behavior for testing
class MockCameraController extends Mock implements CameraController {
  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isDisposed = false;
  bool _shouldSimulateFailure = false;
  Duration _initializationDelay = Duration.zero;
  Exception? _initializationError;
  List<Uint8List>? _presetFrames;
  int _currentFrameIndex = 0;
  
  // Statistics for test verification
  int _initializeCalls = 0;
  int _startImageStreamCalls = 0;
  int _stopImageStreamCalls = 0;
  int _disposeCalls = 0;

  /// Configure the mock to simulate initialization delay
  void setInitializationDelay(Duration delay) {
    _initializationDelay = delay;
  }

  /// Configure the mock to simulate initialization failure
  void setInitializationError(Exception error) {
    _initializationError = error;
  }

  /// Configure the mock to simulate general failures
  void setShouldSimulateFailure(bool shouldFail) {
    _shouldSimulateFailure = shouldFail;
  }

  /// Set preset frames for image stream simulation
  void setPresetFrames(List<Uint8List> frames) {
    _presetFrames = frames;
    _currentFrameIndex = 0;
  }

  /// Generate realistic test frames for the mock
  void generateTestFrames({
    int frameCount = 30,
    int width = 640,
    int height = 480,
    VideoTestPattern pattern = VideoTestPattern.gradient,
  }) {
    setPresetFrames(TestVideoFiles.createVideoFrames(
      frameCount: frameCount,
      width: width,
      height: height,
      pattern: pattern,
    ));
  }

  @override
  Future<void> initialize() async {
    _initializeCalls++;
    
    if (_isDisposed) {
      throw CameraException('dispose', 'Controller was disposed');
    }
    
    if (_initializationError != null) {
      throw _initializationError!;
    }
    
    if (_shouldSimulateFailure) {
      throw CameraException('initialize', 'Simulated initialization failure');
    }
    
    // Simulate initialization time
    if (_initializationDelay > Duration.zero) {
      await Future.delayed(_initializationDelay);
    }
    
    _isInitialized = true;
  }

  @override
  CameraValue get value => CameraValue(
    isInitialized: _isInitialized,
    isRecordingVideo: _isRecording,
    errorDescription: _shouldSimulateFailure ? 'Mock error' : null,
    previewSize: const Size(640, 480),
    aspectRatio: 4/3,
    flashMode: FlashMode.off,
    exposureMode: ExposureMode.auto,
    focusMode: FocusMode.auto,
    isPreviewPaused: false,
    isCaptureOrientationLocked: false,
    recordingOrientation: DeviceOrientation.portraitUp,
    lockedCaptureOrientation: DeviceOrientation.portraitUp,
    isStreamingImages: false,
    exposurePointSupported: false,
    focusPointSupported: false,
    deviceOrientation: DeviceOrientation.portraitUp,
  );

  @override
  Future<void> startImageStream(onAvailable) async {
    _startImageStreamCalls++;
    
    if (!_isInitialized) {
      throw CameraException('startImageStream', 'Controller not initialized');
    }
    
    if (_shouldSimulateFailure) {
      throw CameraException('startImageStream', 'Simulated stream failure');
    }
    
    // Start streaming preset frames if available
    if (_presetFrames != null && _presetFrames!.isNotEmpty) {
      _simulateImageStream(onAvailable);
    }
  }

  @override
  Future<void> stopImageStream() async {
    _stopImageStreamCalls++;
    
    if (_shouldSimulateFailure) {
      throw CameraException('stopImageStream', 'Simulated stop failure');
    }
  }

  @override
  Future<void> dispose() async {
    _disposeCalls++;
    _isDisposed = true;
    _isInitialized = false;
    _isRecording = false;
    
    await _imageStreamController.close();
  }

  /// Simulate continuous image stream with preset frames
  void _simulateImageStream(onAvailable) {
    if (_presetFrames == null || _presetFrames!.isEmpty) return;
    
    Timer.periodic(const Duration(milliseconds: 200), (timer) { // 5 FPS
      if (_isDisposed || !_isInitialized) {
        timer.cancel();
        return;
      }
      
      final frame = _presetFrames![_currentFrameIndex % _presetFrames!.length];
      _currentFrameIndex++;
      
      // Create mock CameraImage (simplified for testing)
      final mockImage = MockCameraImage();
      onAvailable(mockImage);
    });
  }

  // Test verification methods
  int get initializeCalls => _initializeCalls;
  int get startImageStreamCalls => _startImageStreamCalls;
  int get stopImageStreamCalls => _stopImageStreamCalls;
  int get disposeCalls => _disposeCalls;
  bool get wasProperlyDisposed => _isDisposed;
  
  void resetCallCounts() {
    _initializeCalls = 0;
    _startImageStreamCalls = 0;
    _stopImageStreamCalls = 0;
    _disposeCalls = 0;
  }

  /// Create a mock that simulates common error scenarios
  static MockCameraController createFailingController({
    required String errorType,
  }) {
    final controller = MockCameraController();
    
    switch (errorType) {
      case 'initialization_timeout':
        controller.setInitializationDelay(const Duration(seconds: 10));
        break;
      case 'initialization_failure':
        controller.setInitializationError(
          CameraException('initialize', 'Camera unavailable')
        );
        break;
      case 'stream_failure':
        controller.setShouldSimulateFailure(true);
        break;
      case 'permission_denied':
        controller.setInitializationError(
          CameraException('initialize', 'Camera permission denied')
        );
        break;
      default:
        controller.setShouldSimulateFailure(true);
    }
    
    return controller;
  }

  /// Create a mock that simulates successful operation with test frames
  static MockCameraController createWorkingController({
    int frameCount = 30,
    VideoTestPattern pattern = VideoTestPattern.gradient,
    Duration? initDelay,
  }) {
    final controller = MockCameraController();
    
    if (initDelay != null) {
      controller.setInitializationDelay(initDelay);
    }
    
    controller.generateTestFrames(
      frameCount: frameCount,
      pattern: pattern,
    );
    
    return controller;
  }
}

/// Mock camera image for testing
class MockCameraImage extends Mock implements CameraImage {
  @override
  String toString() => 'MockCameraImage(640x480)';
}

/// Mock camera image plane for testing
class MockPlane extends Mock implements Plane {
  late Uint8List _testData;
  
  void setTestData(Uint8List data) {
    _testData = data;
  }
  
  @override
  Uint8List get bytes => _testData;
  
  @override
  int get bytesPerPixel => 1;
  
  @override
  int get bytesPerRow => 640;
  
  @override
  int get height => 480;
  
  @override
  int get width => 640;
}

/// Extended mock for testing camera-related exceptions
class MockCameraException extends CameraException {
  MockCameraException(String code, String description) : super(code, description);
  
  static final permissionDenied = MockCameraException(
    'camera_permission_denied',
    'Camera permission was denied by the user'
  );
  
  static final cameraNotAvailable = MockCameraException(
    'camera_not_available',
    'No camera available on this device'
  );
  
  static final initializationFailed = MockCameraException(
    'initialization_failed',
    'Failed to initialize camera controller'
  );
}

/// Factory for creating various camera test scenarios
class CameraTestScenarios {
  /// Create scenarios for testing camera failure recovery
  static List<MockCameraController> createFailureScenarios() {
    return [
      MockCameraController.createFailingController(errorType: 'initialization_timeout'),
      MockCameraController.createFailingController(errorType: 'initialization_failure'),
      MockCameraController.createFailingController(errorType: 'stream_failure'),
      MockCameraController.createFailingController(errorType: 'permission_denied'),
    ];
  }

  /// Create scenarios for testing different video qualities
  static List<MockCameraController> createQualityScenarios() {
    return [
      MockCameraController.createWorkingController(
        frameCount: 30,
        pattern: VideoTestPattern.gradient,
      ),
      MockCameraController.createWorkingController(
        frameCount: 30,
        pattern: VideoTestPattern.checkerboard,
      ),
      MockCameraController.createWorkingController(
        frameCount: 30,
        pattern: VideoTestPattern.noise,
      ),
    ];
  }

  /// Create scenarios for testing performance under different conditions
  static List<MockCameraController> createPerformanceScenarios() {
    return [
      MockCameraController.createWorkingController(
        frameCount: 10, // Short recording
        pattern: VideoTestPattern.solid,
      ),
      MockCameraController.createWorkingController(
        frameCount: 150, // Long recording
        pattern: VideoTestPattern.animated,
      ),
      MockCameraController.createWorkingController(
        frameCount: 30,
        pattern: VideoTestPattern.gradient,
        initDelay: const Duration(milliseconds: 500), // Slow initialization
      ),
    ];
  }
}