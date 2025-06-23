// ABOUTME: Universal Vine-style recording controller for all platforms
// ABOUTME: Handles press-to-record, release-to-pause segmented recording with cross-platform camera abstraction

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:camera_macos/camera_macos.dart' as macos;
import 'package:path_provider/path_provider.dart';
import 'web_camera_service_stub.dart' if (dart.library.html) 'web_camera_service.dart';
import 'web_camera_service_stub.dart' show blobUrlToBytes if (dart.library.html) 'web_camera_service.dart' show blobUrlToBytes;

/// Represents a single recording segment in the Vine-style recording
class RecordingSegment {
  final DateTime startTime;
  final DateTime endTime;
  final Duration duration;
  final String? filePath;

  RecordingSegment({
    required this.startTime,
    required this.endTime,
    required this.duration,
    this.filePath,
  });

  double get durationInSeconds => duration.inMilliseconds / 1000.0;

  @override
  String toString() => 'Segment(${duration.inMilliseconds}ms)';
}

/// Recording state for Vine-style segmented recording
enum VineRecordingState {
  idle,        // Camera preview active, not recording
  recording,   // Currently recording a segment
  paused,      // Between segments, camera preview active
  processing,  // Assembling final video
  completed,   // Recording finished
  error,       // Error state
}

/// Platform-agnostic interface for camera operations
abstract class CameraPlatformInterface {
  Future<void> initialize();
  Future<void> startRecordingSegment(String filePath);
  Future<String?> stopRecordingSegment();
  Widget get previewWidget;
  void dispose();
}

/// Mobile camera implementation (iOS/Android)
class MobileCameraInterface extends CameraPlatformInterface {
  CameraController? _controller;
  
  @override
  Future<void> initialize() async {
    final cameras = await availableCameras();
    if (cameras.isEmpty) {
      throw Exception('No cameras available');
    }
    
    final camera = cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    
    _controller = CameraController(camera, ResolutionPreset.high, enableAudio: true);
    await _controller!.initialize();
    await _controller!.prepareForVideoRecording();
  }
  
  @override
  Future<void> startRecordingSegment(String filePath) async {
    await _controller!.startVideoRecording();
  }
  
  @override
  Future<String?> stopRecordingSegment() async {
    final xFile = await _controller!.stopVideoRecording();
    return xFile.path;
  }
  
  @override
  Widget get previewWidget => _controller != null ? CameraPreview(_controller!) : Container();
  
  @override
  void dispose() {
    _controller?.dispose();
  }
}

/// macOS camera implementation
class MacOSCameraInterface extends CameraPlatformInterface {
  macos.CameraMacOSController? _controller;
  final GlobalKey _cameraKey = GlobalKey(debugLabel: "vineCamera");
  late Widget _previewWidget;
  String? currentRecordingPath; // Made public for access from controller
  bool _isInitialized = false;
  bool _isRecording = false;
  Completer<macos.CameraMacOSFile?>? _recordingCompleter;
  
  // For macOS single recording mode
  bool isSingleRecordingMode = false; // Made public for access
  final List<RecordingSegment> _virtualSegments = [];
  
  @override
  Future<void> initialize() async {
    // Create the camera widget wrapped in a SizedBox to ensure it has constraints
    _previewWidget = SizedBox.expand(
      child: macos.CameraMacOSView(
        key: _cameraKey,
        fit: BoxFit.cover,
        cameraMode: macos.CameraMacOSMode.video,
        onCameraInizialized: (controller) {
          _controller = controller;
          _isInitialized = true;
          debugPrint('📷 macOS camera controller initialized successfully');
        },
      ),
    );
    
    // For macOS, we can't wait for initialization here because the widget
    // needs to be in the widget tree first. Initialization will be checked
    // when recording starts.
    debugPrint('📷 macOS camera widget created - waiting for widget mount');
  }
  
  @override
  Future<void> startRecordingSegment(String filePath) async {
    debugPrint('📷 Starting recording segment, initialized: $_isInitialized, recording: $_isRecording, singleMode: $isSingleRecordingMode');
    
    // Wait for camera to be initialized (up to 5 seconds)
    int attempts = 0;
    while (!_isInitialized && attempts < 50) {
      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
      if (attempts % 10 == 0) {
        debugPrint('📷 Waiting for macOS camera initialization... (${attempts * 100}ms)');
      }
    }
    
    if (!_isInitialized || _controller == null) {
      debugPrint('❌ macOS camera failed to initialize - isInitialized: $_isInitialized, controller: ${_controller != null}');
      throw Exception('macOS camera not initialized after waiting 5 seconds');
    }
    
    // For macOS, use single recording mode
    if (!isSingleRecordingMode && !_isRecording) {
      // First time - start the single recording
      currentRecordingPath = filePath;
      _isRecording = true;
      isSingleRecordingMode = true;
      _recordingCompleter = Completer<macos.CameraMacOSFile?>();
      
      // Start recording with max Vine duration
      await _controller!.recordVideo(
        url: filePath,
        maxVideoDuration: 6.3, // 6.3 seconds like original Vine
        onVideoRecordingFinished: (file, exception) {
          _isRecording = false;
          if (exception != null) {
            debugPrint('❌ macOS recording error: $exception');
            _recordingCompleter?.completeError(exception);
          } else {
            debugPrint('✅ macOS recording completed: ${file?.url}');
            _recordingCompleter?.complete(file);
          }
        },
      );
      
      debugPrint('🎬 Started macOS single recording mode');
    } else if (isSingleRecordingMode && _isRecording) {
      // Already recording in single mode - just track the virtual segment start
      debugPrint('📝 macOS single recording mode - tracking new virtual segment');
    }
  }
  
  @override
  Future<String?> stopRecordingSegment() async {
    debugPrint('📷 Stopping recording segment, recording: $_isRecording, singleMode: $isSingleRecordingMode');
    
    if (_controller == null || !isSingleRecordingMode) {
      return null;
    }
    
    // In single recording mode, we just track virtual segments
    // The actual recording continues until we call stopSingleRecording
    if (isSingleRecordingMode && _isRecording) {
      debugPrint('📝 macOS single recording mode - virtual segment stop');
      // Return the path for consistency, but actual file won't be ready yet
      return currentRecordingPath;
    }
    
    return null;
  }
  
  /// Stop the single recording mode and return the final file
  Future<String?> stopSingleRecording() async {
    debugPrint('🛑 Stopping macOS single recording mode');
    
    if (!isSingleRecordingMode || !_isRecording) {
      return null;
    }
    
    // The recording should auto-stop after 6 seconds or we can wait for it
    _isRecording = false;
    isSingleRecordingMode = false;
    
    // Return the recording path
    return currentRecordingPath;
  }
  
  /// Get virtual segments for macOS single recording mode
  List<RecordingSegment> getVirtualSegments() {
    return _virtualSegments;
  }
  
  @override
  Widget get previewWidget {
    if (!_isInitialized) {
      debugPrint('📷 macOS camera preview requested but not initialized yet');
    }
    return _previewWidget;
  }
  
  @override
  void dispose() {
    // Stop any active recording
    if (_isRecording) {
      _isRecording = false;
      debugPrint('📷 macOS camera interface disposed - stopped recording');
    }
    
    // Reset state
    isSingleRecordingMode = false;
    currentRecordingPath = null;
    _recordingCompleter = null;
    
    // macOS controller disposal handled by the widget
  }
  
  /// Reset the interface state (for reuse)
  void reset() {
    _isRecording = false;
    isSingleRecordingMode = false;
    currentRecordingPath = null;
    _recordingCompleter = null;
    _virtualSegments.clear();
    debugPrint('📷 macOS camera interface reset');
  }
}

/// Web camera implementation (using getUserMedia)
class WebCameraInterface extends CameraPlatformInterface {
  WebCameraService? _webCameraService;
  Widget? _previewWidget;
  
  @override
  Future<void> initialize() async {
    if (!kIsWeb) throw Exception('WebCameraInterface only works on web');
    
    try {
      _webCameraService = WebCameraService();
      await _webCameraService!.initialize();
      
      // Create preview widget with the initialized camera service
      _previewWidget = WebCameraPreview(cameraService: _webCameraService!);
      
      debugPrint('📷 Web camera interface initialized successfully');
    } catch (e) {
      debugPrint('❌ Web camera interface initialization failed: $e');
      rethrow;
    }
  }
  
  @override
  Future<void> startRecordingSegment(String filePath) async {
    if (_webCameraService == null) {
      throw Exception('Web camera service not initialized');
    }
    
    await _webCameraService!.startRecording();
  }
  
  @override
  Future<String?> stopRecordingSegment() async {
    if (_webCameraService == null) {
      throw Exception('Web camera service not initialized');
    }
    
    try {
      final blobUrl = await _webCameraService!.stopRecording();
      debugPrint('📹 Web recording completed: $blobUrl');
      return blobUrl;
    } catch (e) {
      debugPrint('❌ Failed to stop web recording: $e');
      rethrow;
    }
  }
  
  @override
  Widget get previewWidget => _previewWidget ?? Container(
    color: Colors.black,
    child: const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
      ),
    ),
  );
  
  /// Clean up a blob URL (internal method for cleanup)
  void _cleanupBlobUrl(String blobUrl) {
    if (kIsWeb && _webCameraService != null) {
      try {
        // Call the static method through the service
        WebCameraService.revokeBlobUrl(blobUrl);
      } catch (e) {
        debugPrint('⚠️ Error revoking blob URL: $e');
      }
    }
  }
  
  @override
  void dispose() {
    _webCameraService?.dispose();
    _webCameraService = null;
    _previewWidget = null;
  }
}

/// Universal Vine recording controller that works across all platforms
class VineRecordingController extends ChangeNotifier {
  static const Duration maxRecordingDuration = Duration(milliseconds: 6300); // 6.3 seconds like original Vine
  static const Duration minSegmentDuration = Duration(milliseconds: 100);
  
  late CameraPlatformInterface _cameraInterface;
  VineRecordingState _state = VineRecordingState.idle;
  
  // Recording session data
  final List<RecordingSegment> _segments = [];
  DateTime? _currentSegmentStartTime;
  Timer? _progressTimer;
  Timer? _maxDurationTimer;
  String? _tempDirectory;
  
  // Progress tracking
  Duration _totalRecordedDuration = Duration.zero;
  bool _disposed = false;
  
  // Getters
  VineRecordingState get state => _state;
  List<RecordingSegment> get segments => List.unmodifiable(_segments);
  Duration get totalRecordedDuration => _totalRecordedDuration;
  Duration get remainingDuration => maxRecordingDuration - _totalRecordedDuration;
  double get progress => _totalRecordedDuration.inMilliseconds / maxRecordingDuration.inMilliseconds;
  bool get canRecord => remainingDuration > minSegmentDuration && _state != VineRecordingState.processing;
  bool get hasSegments => _segments.isNotEmpty;
  Widget get cameraPreview => _cameraInterface.previewWidget;
  
  /// Initialize the recording controller for the current platform
  Future<void> initialize() async {
    try {
      _setState(VineRecordingState.idle);
      
      // Create platform-specific camera interface
      if (kIsWeb) {
        _cameraInterface = WebCameraInterface();
      } else if (Platform.isMacOS) {
        _cameraInterface = MacOSCameraInterface();
      } else if (Platform.isIOS || Platform.isAndroid) {
        _cameraInterface = MobileCameraInterface();
      } else {
        throw Exception('Platform not supported: ${Platform.operatingSystem}');
      }
      
      await _cameraInterface.initialize();
      
      // Set up temp directory for segments
      if (!kIsWeb) {
        final tempDir = await _getTempDirectory();
        _tempDirectory = tempDir.path;
      }
      
      debugPrint('🎬 VineRecordingController initialized for ${_getPlatformName()}');
    } catch (e) {
      _setState(VineRecordingState.error);
      debugPrint('❌ VineRecordingController initialization failed: $e');
      rethrow;
    }
  }
  
  /// Start recording a new segment (press down)
  Future<void> startRecording() async {
    if (!canRecord || _state == VineRecordingState.recording) return;
    
    // On web, prevent multiple segments until compilation is implemented
    if (kIsWeb && _segments.isNotEmpty) {
      debugPrint('⚠️ Multiple segments not supported on web yet');
      return;
    }
    
    try {
      _setState(VineRecordingState.recording);
      _currentSegmentStartTime = DateTime.now();
      
      // Normal segmented recording for all platforms
      final segmentPath = _generateSegmentPath();
      await _cameraInterface.startRecordingSegment(segmentPath);
      
      // Start progress timer
      _startProgressTimer();
      
      // Set max duration timer if this is the first segment or we're close to limit
      _startMaxDurationTimer();
      
      debugPrint('🎬 Started recording segment ${_segments.length + 1}');
    } catch (e) {
      _setState(VineRecordingState.error);
      debugPrint('❌ Failed to start recording: $e');
      rethrow;
    }
  }
  
  /// Stop recording current segment (release)
  Future<void> stopRecording() async {
    if (_state != VineRecordingState.recording || _currentSegmentStartTime == null) return;
    
    try {
      final segmentEndTime = DateTime.now();
      final segmentDuration = segmentEndTime.difference(_currentSegmentStartTime!);
      
      // Only save segments longer than minimum duration
      if (segmentDuration >= minSegmentDuration) {
        // For macOS in single recording mode, create virtual segments
        if (!kIsWeb && Platform.isMacOS && _cameraInterface is MacOSCameraInterface) {
          final macOSInterface = _cameraInterface as MacOSCameraInterface;
          
          // Create a virtual segment (the actual file is still recording)
          final segment = RecordingSegment(
            startTime: _currentSegmentStartTime!,
            endTime: segmentEndTime,
            duration: segmentDuration,
            filePath: macOSInterface.currentRecordingPath, // Use the single recording path
          );
          
          _segments.add(segment);
          _totalRecordedDuration += segmentDuration;
          
          debugPrint('✅ Completed virtual segment ${_segments.length}: ${segmentDuration.inMilliseconds}ms');
        } else {
          // Normal segment recording for other platforms
          final filePath = await _cameraInterface.stopRecordingSegment();
          
          final segment = RecordingSegment(
            startTime: _currentSegmentStartTime!,
            endTime: segmentEndTime,
            duration: segmentDuration,
            filePath: filePath,
          );
          
          _segments.add(segment);
          _totalRecordedDuration += segmentDuration;
          
          debugPrint('✅ Completed segment ${_segments.length}: ${segmentDuration.inMilliseconds}ms');
        }
      }
      
      _currentSegmentStartTime = null;
      _stopProgressTimer();
      _stopMaxDurationTimer();
      
      // Reset total duration to actual segments total (removing any in-progress time)
      _totalRecordedDuration = _segments.fold<Duration>(
        Duration.zero,
        (total, segment) => total + segment.duration,
      );
      
      // Check if we've reached the maximum duration or if on web (single segment only)
      if (_totalRecordedDuration >= maxRecordingDuration || kIsWeb) {
        _setState(VineRecordingState.completed);
        debugPrint('🏁 Recording completed - ${kIsWeb ? "web single segment" : "reached maximum duration"}');
      } else {
        _setState(VineRecordingState.paused);
      }
      
    } catch (e) {
      _setState(VineRecordingState.error);
      debugPrint('❌ Failed to stop recording: $e');
      rethrow;
    }
  }
  
  /// Finish recording and return the final compiled video
  Future<File?> finishRecording() async {
    if (!hasSegments) return null;
    
    try {
      _setState(VineRecordingState.processing);
      
      // Stop any active recording
      if (_state == VineRecordingState.recording) {
        await stopRecording();
      }
      
      // For macOS single recording mode, wait for the recording to finish
      if (!kIsWeb && Platform.isMacOS && _cameraInterface is MacOSCameraInterface) {
        final macOSInterface = _cameraInterface as MacOSCameraInterface;
        
        // For single recording mode, return the single file
        if (macOSInterface.isSingleRecordingMode && macOSInterface.currentRecordingPath != null) {
          // Wait a moment for the recording to finish writing
          await Future.delayed(const Duration(milliseconds: 500));
          
          final file = File(macOSInterface.currentRecordingPath!);
          if (await file.exists()) {
            _setState(VineRecordingState.completed);
            return file;
          }
        }
      }
      
      // For web platform, handle blob URLs
      if (kIsWeb && _segments.length == 1 && _segments.first.filePath != null) {
        final filePath = _segments.first.filePath!;
        if (filePath.startsWith('blob:')) {
          // For web, we can't return a File object from blob URL
          // Instead, we'll create a temporary file representation
          try {
            // Use the standalone blobUrlToBytes function
            final bytes = await blobUrlToBytes(filePath);
            if (bytes.isNotEmpty) {
              // Create a temporary file with the blob data
              final tempDir = await getTemporaryDirectory();
              final tempFile = File('${tempDir.path}/web_recording_${DateTime.now().millisecondsSinceEpoch}.mp4');
              await tempFile.writeAsBytes(bytes);
              
              _setState(VineRecordingState.completed);
              return tempFile;
            }
          } catch (e) {
            debugPrint('❌ Failed to convert blob to file: $e');
          }
        }
      }
      
      // For other platforms, handle segments
      if (!kIsWeb && _segments.length == 1 && _segments.first.filePath != null) {
        final file = File(_segments.first.filePath!);
        if (await file.exists()) {
          _setState(VineRecordingState.completed);
          return file;
        }
      }
      
      // TODO: Implement multi-segment video compilation
      throw UnimplementedError('Multi-segment video compilation not yet implemented');
      
    } catch (e) {
      _setState(VineRecordingState.error);
      debugPrint('❌ Failed to finish recording: $e');
      rethrow;
    }
  }
  
  /// Reset the recording session
  void reset() {
    _stopProgressTimer();
    _stopMaxDurationTimer();
    
    // Clean up recording files/resources
    _cleanupRecordings();
    
    _segments.clear();
    _totalRecordedDuration = Duration.zero;
    _currentSegmentStartTime = null;
    
    // Check if we need to reinitialize before resetting state
    final wasInError = _state == VineRecordingState.error;
    
    // Reset state
    _setState(VineRecordingState.idle);
    
    // If was in error state and on web, reinitialize the camera
    if (wasInError && kIsWeb) {
      debugPrint('🔄 Reinitializing web camera after error...');
      if (_cameraInterface is WebCameraInterface) {
        final webInterface = _cameraInterface as WebCameraInterface;
        webInterface.dispose();
      }
      // Create new camera interface and initialize
      _cameraInterface = WebCameraInterface();
      initialize().then((_) {
        debugPrint('✅ Web camera reinitialized successfully');
        _setState(VineRecordingState.idle);
      }).catchError((e) {
        debugPrint('❌ Failed to reinitialize web camera: $e');
        _setState(VineRecordingState.error);
      });
    }
    
    debugPrint('🔄 Recording session reset');
  }
  
  /// Clean up recording files and resources
  void _cleanupRecordings() {
    try {
      // Clean up platform-specific resources
      if (kIsWeb && _cameraInterface is WebCameraInterface) {
        _cleanupWebRecordings();
      } else if (!kIsWeb && Platform.isMacOS && _cameraInterface is MacOSCameraInterface) {
        _cleanupMacOSRecording();
      } else {
        _cleanupMobileRecordings();
      }
      
      debugPrint('🧹 Cleaned up recording resources');
    } catch (e) {
      debugPrint('⚠️ Error cleaning up recordings: $e');
    }
  }
  
  /// Clean up web recordings (blob URLs)
  void _cleanupWebRecordings() {
    // Clean up through the web camera interface
    if (_cameraInterface is WebCameraInterface) {
      final webInterface = _cameraInterface as WebCameraInterface;
      
      // Clean up blob URLs through the service
      for (final segment in _segments) {
        if (segment.filePath != null && segment.filePath!.startsWith('blob:')) {
          try {
            webInterface._cleanupBlobUrl(segment.filePath!);
          } catch (e) {
            debugPrint('⚠️ Error cleaning up blob URL: $e');
          }
        }
      }
      
      // Dispose the service
      webInterface._webCameraService?.dispose();
    }
  }
  
  /// Clean up macOS recording
  void _cleanupMacOSRecording() {
    final macOSInterface = _cameraInterface as MacOSCameraInterface;
    
    // Stop any active recording and clean up files
    if (macOSInterface.currentRecordingPath != null) {
      try {
        // Clean up the recording file if it exists
        final file = File(macOSInterface.currentRecordingPath!);
        if (file.existsSync()) {
          file.deleteSync();
          debugPrint('🧹 Deleted macOS recording file: ${macOSInterface.currentRecordingPath}');
        }
      } catch (e) {
        debugPrint('⚠️ Error deleting macOS recording file: $e');
      }
    }
    
    // Reset the interface completely
    macOSInterface.reset();
  }
  
  /// Clean up mobile recordings
  void _cleanupMobileRecordings() {
    for (final segment in _segments) {
      if (segment.filePath != null) {
        try {
          final file = File(segment.filePath!);
          if (file.existsSync()) {
            file.deleteSync();
            debugPrint('🧹 Deleted mobile recording file: ${segment.filePath}');
          }
        } catch (e) {
          debugPrint('⚠️ Error deleting mobile recording file: $e');
        }
      }
    }
  }
  
  /// Dispose resources
  @override
  void dispose() {
    _disposed = true;
    _stopProgressTimer();
    _stopMaxDurationTimer();
    
    // Clean up all recordings
    _cleanupRecordings();
    
    _cameraInterface.dispose();
    super.dispose();
  }
  
  // Private methods
  
  void _setState(VineRecordingState newState) {
    if (_disposed) return;
    _state = newState;
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
  
  void _startProgressTimer() {
    _stopProgressTimer();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!_disposed && hasListeners && _state == VineRecordingState.recording) {
        // For macOS, update the total duration based on current segment time
        if (_currentSegmentStartTime != null) {
          final currentSegmentDuration = DateTime.now().difference(_currentSegmentStartTime!);
          final previousDuration = _segments.fold<Duration>(
            Duration.zero, 
            (total, segment) => total + segment.duration,
          );
          _totalRecordedDuration = previousDuration + currentSegmentDuration;
        }
        notifyListeners();
      }
    });
  }
  
  void _stopProgressTimer() {
    _progressTimer?.cancel();
    _progressTimer = null;
  }
  
  void _startMaxDurationTimer() {
    _stopMaxDurationTimer();
    final remainingTime = remainingDuration;
    if (remainingTime > Duration.zero) {
      _maxDurationTimer = Timer(remainingTime, () {
        if (_state == VineRecordingState.recording) {
          stopRecording();
        }
      });
    }
  }
  
  void _stopMaxDurationTimer() {
    _maxDurationTimer?.cancel();
    _maxDurationTimer = null;
  }
  
  String _generateSegmentPath() {
    if (kIsWeb) {
      return 'segment_${DateTime.now().millisecondsSinceEpoch}';
    }
    return '$_tempDirectory/vine_segment_${_segments.length + 1}_${DateTime.now().millisecondsSinceEpoch}.mov';
  }
  
  Future<Directory> _getTempDirectory() async {
    if (Platform.isIOS || Platform.isAndroid) {
      final directory = await getTemporaryDirectory();
      return directory;
    } else {
      // macOS/Windows temp directory
      return Directory.systemTemp;
    }
  }
  
  String _getPlatformName() {
    if (kIsWeb) return 'Web';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    return 'Unknown';
  }
}