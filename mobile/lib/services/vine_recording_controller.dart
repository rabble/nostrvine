// ABOUTME: Universal Vine-style recording controller for all platforms
// ABOUTME: Handles press-to-record, release-to-pause segmented recording with cross-platform camera abstraction

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:camera_macos/camera_macos.dart' as macos;
import 'package:path_provider/path_provider.dart';
import '../utils/async_utils.dart';
import 'web_camera_service_stub.dart' if (dart.library.html) 'web_camera_service.dart' as camera_service;
import 'camera/native_macos_camera.dart';
import '../utils/unified_logger.dart';

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
  Future<void> switchCamera();
  Widget get previewWidget;
  void dispose();
}

/// Mobile camera implementation (iOS/Android)
class MobileCameraInterface extends CameraPlatformInterface {
  CameraController? _controller;
  List<CameraDescription> _availableCameras = [];
  int _currentCameraIndex = 0;
  bool _isRecording = false;
  
  @override
  Future<void> initialize() async {
    _availableCameras = await availableCameras();
    if (_availableCameras.isEmpty) {
      throw Exception('No cameras available');
    }
    
    // Default to back camera if available
    _currentCameraIndex = _availableCameras.indexWhere(
      (cam) => cam.lensDirection == CameraLensDirection.back,
    );
    if (_currentCameraIndex == -1) {
      _currentCameraIndex = 0;
    }
    
    await _initializeCurrentCamera();
  }
  
  Future<void> _initializeCurrentCamera() async {
    _controller?.dispose();
    
    final camera = _availableCameras[_currentCameraIndex];
    _controller = CameraController(camera, ResolutionPreset.high, enableAudio: true);
    await _controller!.initialize();
    await _controller!.prepareForVideoRecording();
  }
  
  Future<void> _initializeNewCamera() async {
    // Initialize new camera without disposing (disposal handled separately)
    final camera = _availableCameras[_currentCameraIndex];
    _controller = CameraController(camera, ResolutionPreset.high, enableAudio: true);
    await _controller!.initialize();
    await _controller!.prepareForVideoRecording();
  }
  
  @override
  Future<void> startRecordingSegment(String filePath) async {
    if (_controller == null) {
      throw Exception('Camera controller not initialized');
    }
    
    // Check if already recording to prevent double-start
    if (_isRecording) {
      Log.warning('Already recording, skipping startVideoRecording', name: 'VineRecordingController', category: LogCategory.system);
      return;
    }
    
    try {
      await _controller!.startVideoRecording();
      _isRecording = true;
      Log.info('Started mobile camera recording', name: 'VineRecordingController', category: LogCategory.system);
    } catch (e) {
      Log.error('Failed to start mobile camera recording: $e', name: 'VineRecordingController', category: LogCategory.system);
      rethrow;
    }
  }
  
  @override
  Future<String?> stopRecordingSegment() async {
    if (_controller == null) {
      throw Exception('Camera controller not initialized');
    }
    
    // Check if not recording to prevent double-stop
    if (!_isRecording) {
      Log.warning('Not currently recording, skipping stopVideoRecording', name: 'VineRecordingController', category: LogCategory.system);
      return null;
    }
    
    try {
      final xFile = await _controller!.stopVideoRecording();
      _isRecording = false;
      Log.info('Stopped mobile camera recording: ${xFile.path}', name: 'VineRecordingController', category: LogCategory.system);
      return xFile.path;
    } catch (e) {
      _isRecording = false; // Reset state even on error
      Log.error('Failed to stop mobile camera recording: $e', name: 'VineRecordingController', category: LogCategory.system);
      // Don't rethrow - return null to indicate no file was saved
      return null;
    }
  }
  
  @override
  Future<void> switchCamera() async {
    if (_availableCameras.length <= 1) return; // No other cameras to switch to
    
    // Don't switch if controller is not properly initialized
    if (_controller == null || !_controller!.value.isInitialized) {
      Log.warning('Cannot switch camera - controller not initialized', name: 'VineRecordingController', category: LogCategory.system);
      return;
    }
    
    // Stop any active recording before switching
    if (_isRecording) {
      try {
        await _controller?.stopVideoRecording();
      } catch (e) {
        Log.error('Error stopping recording during camera switch: $e', name: 'VineRecordingController', category: LogCategory.system);
      }
      _isRecording = false;
    }
    
    // Store old controller reference for safe disposal
    final oldController = _controller;
    _controller = null; // Clear reference to prevent access during switch
    
    try {
      // Switch to the next camera
      _currentCameraIndex = (_currentCameraIndex + 1) % _availableCameras.length;
      await _initializeNewCamera();
      
      // Safely dispose old controller after new one is ready
      await oldController?.dispose();
      
      Log.info('� Successfully switched to camera $_currentCameraIndex', name: 'VineRecordingController', category: LogCategory.system);
    } catch (e) {
      // If switching fails, restore old controller
      _controller = oldController;
      Log.error('Camera switch failed, restored previous camera: $e', name: 'VineRecordingController', category: LogCategory.system);
      rethrow;
    }
  }
  
  @override
  Widget get previewWidget {
    final controller = _controller;
    if (controller != null && controller.value.isInitialized) {
      return CameraPreview(controller);
    }
    return Container(
      color: Colors.black,
      child: const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
  
  @override
  void dispose() {
    // Stop any active recording before disposal
    if (_isRecording) {
      try {
        _controller?.stopVideoRecording();
      } catch (e) {
        Log.error('Error stopping recording during disposal: $e', name: 'VineRecordingController', category: LogCategory.system);
      }
      _isRecording = false;
    }
    _controller?.dispose();
  }
}

/// macOS camera implementation
class MacOSCameraInterface extends CameraPlatformInterface with AsyncInitialization {
  macos.CameraMacOSController? _controller;
  final GlobalKey _cameraKey = GlobalKey(debugLabel: "vineCamera");
  late Widget _previewWidget;
  String? currentRecordingPath; // Made public for access from controller
  bool _isRecording = false;
  Completer<macos.CameraMacOSFile?>? _recordingCompleter;
  
  // For macOS single recording mode
  bool isSingleRecordingMode = false; // Made public for access
  final List<RecordingSegment> _virtualSegments = [];
  
  // Recording completion callback mechanism
  Completer<String>? _recordingCompletionCompleter;
  
  // Track current camera index
  int _currentCameraIndex = 0;
  
  @override
  Future<void> initialize() async {
    startInitialization();
    
    // Create the camera widget wrapped in a SizedBox to ensure it has constraints
    _previewWidget = SizedBox.expand(
      child: macos.CameraMacOSView(
        key: _cameraKey,
        fit: BoxFit.cover,
        cameraMode: macos.CameraMacOSMode.video,
        onCameraInizialized: (controller) {
          _controller = controller;
          completeInitialization();
          Log.info('� macOS camera controller initialized successfully', name: 'VineRecordingController', category: LogCategory.system);
        },
      ),
    );
    
    // For macOS, we can't wait for initialization here because the widget
    // needs to be in the widget tree first. Initialization will be checked
    // when recording starts.
    Log.info('� macOS camera widget created - waiting for widget mount', name: 'VineRecordingController', category: LogCategory.system);
  }
  
  @override
  Future<void> startRecordingSegment(String filePath) async {
    Log.info('� Starting recording segment, initialized: $isInitialized, recording: $_isRecording, singleMode: $isSingleRecordingMode', name: 'VineRecordingController', category: LogCategory.system);
    
    // Wait for camera to be initialized (up to 5 seconds) using proper async pattern
    try {
      await waitForInitialization(timeout: const Duration(seconds: 5));
    } catch (e) {
      Log.error('macOS camera failed to initialize: $e', name: 'VineRecordingController', category: LogCategory.system);
      throw Exception('macOS camera not initialized after waiting 5 seconds: $e');
    }
    
    if (_controller == null) {
      Log.error('macOS camera controller is null after initialization', name: 'VineRecordingController', category: LogCategory.system);
      throw Exception('macOS camera controller not available');
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
            Log.error('macOS recording error: $exception', name: 'VineRecordingController', category: LogCategory.system);
            _recordingCompleter?.completeError(exception);
            _recordingCompletionCompleter?.completeError(exception);
          } else {
            Log.info('macOS recording completed: ${file?.url}', name: 'VineRecordingController', category: LogCategory.system);
            _recordingCompleter?.complete(file);
            _recordingCompletionCompleter?.complete(file?.url ?? '');
          }
        },
      );
      
      Log.info('Started macOS single recording mode', name: 'VineRecordingController', category: LogCategory.system);
    } else if (isSingleRecordingMode && _isRecording) {
      // Already recording in single mode - just track the virtual segment start
      Log.verbose('macOS single recording mode - tracking new virtual segment', name: 'VineRecordingController', category: LogCategory.system);
    }
  }
  
  @override
  Future<String?> stopRecordingSegment() async {
    Log.debug('� Stopping recording segment, recording: $_isRecording, singleMode: $isSingleRecordingMode', name: 'VineRecordingController', category: LogCategory.system);
    
    if (_controller == null || !isSingleRecordingMode) {
      return null;
    }
    
    // In single recording mode, we just track virtual segments
    // The actual recording continues until we call stopSingleRecording
    if (isSingleRecordingMode && _isRecording) {
      Log.verbose('macOS single recording mode - virtual segment stop', name: 'VineRecordingController', category: LogCategory.system);
      // Return the path for consistency, but actual file won't be ready yet
      return currentRecordingPath;
    }
    
    return null;
  }
  
  /// Stop the single recording mode and return the final file
  Future<String?> stopSingleRecording() async {
    Log.debug('� Stopping macOS single recording mode', name: 'VineRecordingController', category: LogCategory.system);
    
    if (!isSingleRecordingMode || !_isRecording) {
      return null;
    }
    
    // The recording should auto-stop after 6 seconds or we can wait for it
    _isRecording = false;
    isSingleRecordingMode = false;
    
    // Return the recording path
    return currentRecordingPath;
  }
  
  /// Wait for recording completion using proper async pattern
  Future<String> waitForRecordingCompletion({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (_recordingCompletionCompleter == null) {
      _recordingCompletionCompleter = Completer<String>();
    }
    
    try {
      return await _recordingCompletionCompleter!.future.timeout(timeout);
    } catch (e) {
      Log.error('Recording completion timeout or error: $e', name: 'VineRecordingController', category: LogCategory.system);
      rethrow;
    }
  }
  
  /// Get virtual segments for macOS single recording mode
  List<RecordingSegment> getVirtualSegments() {
    return _virtualSegments;
  }
  
  @override
  Widget get previewWidget {
    if (!isInitialized) {
      Log.info('� macOS camera preview requested but not initialized yet', name: 'VineRecordingController', category: LogCategory.system);
    }
    return _previewWidget;
  }
  
  @override
  Future<void> switchCamera() async {
    try {
      // Get available cameras from native macOS
      final cameras = await NativeMacOSCamera.getAvailableCameras();
      
      if (cameras.length <= 1) {
        Log.info('� Only one camera available, cannot switch', name: 'VineRecordingController', category: LogCategory.system);
        return;
      }
      
      // Switch to next camera
      _currentCameraIndex = (_currentCameraIndex + 1) % cameras.length;
      final success = await NativeMacOSCamera.switchCamera(_currentCameraIndex);
      
      if (success) {
        Log.info('� Successfully switched to camera $_currentCameraIndex: ${cameras[_currentCameraIndex]['name']}', name: 'VineRecordingController', category: LogCategory.system);
      } else {
        // Revert index on failure
        _currentCameraIndex = (_currentCameraIndex - 1 + cameras.length) % cameras.length;
        Log.error('Failed to switch camera', name: 'VineRecordingController', category: LogCategory.system);
      }
    } catch (e) {
      Log.error('Error switching macOS camera: $e', name: 'VineRecordingController', category: LogCategory.system);
    }
  }
  
  @override
  void dispose() {
    // Stop any active recording
    if (_isRecording) {
      _isRecording = false;
      Log.info('� macOS camera interface disposed - stopped recording', name: 'VineRecordingController', category: LogCategory.system);
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
    Log.debug('� macOS camera interface reset', name: 'VineRecordingController', category: LogCategory.system);
  }
}

/// Web camera implementation (using getUserMedia)
class WebCameraInterface extends CameraPlatformInterface {
  camera_service.WebCameraService? _webCameraService;
  Widget? _previewWidget;
  
  @override
  Future<void> initialize() async {
    if (!kIsWeb) throw Exception('WebCameraInterface only works on web');
    
    try {
      _webCameraService = camera_service.WebCameraService();
      await _webCameraService!.initialize();
      
      // Create preview widget with the initialized camera service
      _previewWidget = camera_service.WebCameraPreview(cameraService: _webCameraService!);
      
      Log.info('� Web camera interface initialized successfully', name: 'VineRecordingController', category: LogCategory.system);
    } catch (e) {
      Log.error('Web camera interface initialization failed: $e', name: 'VineRecordingController', category: LogCategory.system);
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
      Log.info('� Web recording completed: $blobUrl', name: 'VineRecordingController', category: LogCategory.system);
      return blobUrl;
    } catch (e) {
      Log.error('Failed to stop web recording: $e', name: 'VineRecordingController', category: LogCategory.system);
      rethrow;
    }
  }
  
  @override
  Future<void> switchCamera() async {
    if (_webCameraService == null) {
      Log.warning('Web camera service not initialized', name: 'VineRecordingController', category: LogCategory.system);
      return;
    }
    
    try {
      await _webCameraService!.switchCamera();
      Log.info('� Web camera switched successfully', name: 'VineRecordingController', category: LogCategory.system);
    } catch (e) {
      Log.error('Camera switching failed on web: $e', name: 'VineRecordingController', category: LogCategory.system);
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
        camera_service.WebCameraService.revokeBlobUrl(blobUrl);
      } catch (e) {
        Log.error('Error revoking blob URL: $e', name: 'VineRecordingController', category: LogCategory.system);
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
  
  /// Switch between front and rear cameras
  Future<void> switchCamera() async {
    if (_state == VineRecordingState.recording) {
      Log.warning('Cannot switch camera while recording', name: 'VineRecordingController', category: LogCategory.system);
      return;
    }
    
    // If we're in paused state with a segment in progress, ensure it's properly stopped
    if (_currentSegmentStartTime != null) {
      Log.warning('Cleaning up incomplete segment before camera switch', name: 'VineRecordingController', category: LogCategory.system);
      _currentSegmentStartTime = null;
      _stopProgressTimer();
      _stopMaxDurationTimer();
    }
    
    try {
      await _cameraInterface.switchCamera();
      Log.info('� Camera switched successfully', name: 'VineRecordingController', category: LogCategory.system);
    } catch (e) {
      Log.error('Failed to switch camera: $e', name: 'VineRecordingController', category: LogCategory.system);
    }
  }
  
  /// Initialize the recording controller for the current platform
  Future<void> initialize() async {
    try {
      _setState(VineRecordingState.idle);
      
      // Clean up any old recordings from previous sessions
      _cleanupRecordings();
      
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
      
      Log.info('VineRecordingController initialized for ${_getPlatformName()}', name: 'VineRecordingController', category: LogCategory.system);
    } catch (e) {
      _setState(VineRecordingState.error);
      Log.error('VineRecordingController initialization failed: $e', name: 'VineRecordingController', category: LogCategory.system);
      rethrow;
    }
  }
  
  /// Start recording a new segment (press down)
  Future<void> startRecording() async {
    if (!canRecord) return;
    
    // Prevent starting if already recording
    if (_state == VineRecordingState.recording) {
      Log.warning('Already recording, ignoring start request', name: 'VineRecordingController', category: LogCategory.system);
      return;
    }
    
    // On web, prevent multiple segments until compilation is implemented
    if (kIsWeb && _segments.isNotEmpty) {
      Log.warning('Multiple segments not supported on web yet', name: 'VineRecordingController', category: LogCategory.system);
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
      
      Log.info('Started recording segment ${_segments.length + 1}', name: 'VineRecordingController', category: LogCategory.system);
    } catch (e) {
      // Reset state and clean up on error
      _currentSegmentStartTime = null;
      _stopProgressTimer();
      _stopMaxDurationTimer();
      _setState(VineRecordingState.error);
      Log.error('Failed to start recording: $e', name: 'VineRecordingController', category: LogCategory.system);
      // Don't rethrow - handle gracefully in UI
    }
  }
  
  /// Stop recording current segment (release)
  Future<void> stopRecording() async {
    if (_state != VineRecordingState.recording || _currentSegmentStartTime == null) {
      Log.warning('Not recording or no start time, ignoring stop request', name: 'VineRecordingController', category: LogCategory.system);
      return;
    }
    
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
          
          Log.info('Completed virtual segment ${_segments.length}: ${segmentDuration.inMilliseconds}ms', name: 'VineRecordingController', category: LogCategory.system);
        } else {
          // Normal segment recording for other platforms
          final filePath = await _cameraInterface.stopRecordingSegment();
          
          if (filePath != null) {
            final segment = RecordingSegment(
              startTime: _currentSegmentStartTime!,
              endTime: segmentEndTime,
              duration: segmentDuration,
              filePath: filePath,
            );
            
            _segments.add(segment);
            _totalRecordedDuration += segmentDuration;
            
            Log.info('Completed segment ${_segments.length}: ${segmentDuration.inMilliseconds}ms', name: 'VineRecordingController', category: LogCategory.system);
          } else {
            Log.warning('No file path returned from camera interface', name: 'VineRecordingController', category: LogCategory.system);
          }
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
        Log.info('� Recording completed - ${kIsWeb ? "web single segment" : "reached maximum duration"}', name: 'VineRecordingController', category: LogCategory.system);
      } else {
        _setState(VineRecordingState.paused);
      }
      
    } catch (e) {
      // Reset state and clean up on error
      _currentSegmentStartTime = null;
      _stopProgressTimer();
      _stopMaxDurationTimer();
      _setState(VineRecordingState.error);
      Log.error('Failed to stop recording: $e', name: 'VineRecordingController', category: LogCategory.system);
      // Don't rethrow - handle gracefully in UI
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
        
        // For single recording mode, wait for proper completion callback
        if (macOSInterface.isSingleRecordingMode && macOSInterface.currentRecordingPath != null) {
          try {
            // Wait for recording completion using proper async pattern
            final completedPath = await macOSInterface.waitForRecordingCompletion(
              timeout: const Duration(seconds: 10),
            );
            
            final file = File(completedPath);
            if (await file.exists()) {
              _setState(VineRecordingState.completed);
              return file;
            } else {
              Log.warning('Recording completed but file not found: $completedPath', name: 'VineRecordingController', category: LogCategory.system);
            }
          } catch (e) {
            Log.error('Recording completion failed: $e', name: 'VineRecordingController', category: LogCategory.system);
            // Fall back to checking the current path
            if (macOSInterface.currentRecordingPath != null) {
              final file = File(macOSInterface.currentRecordingPath!);
              if (await file.exists()) {
                _setState(VineRecordingState.completed);
                return file;
              }
            }
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
            final bytes = await camera_service.blobUrlToBytes(filePath);
            if (bytes.isNotEmpty) {
              // Create a temporary file with the blob data
              final tempDir = await getTemporaryDirectory();
              final tempFile = File('${tempDir.path}/web_recording_${DateTime.now().millisecondsSinceEpoch}.mp4');
              await tempFile.writeAsBytes(bytes);
              
              _setState(VineRecordingState.completed);
              return tempFile;
            }
          } catch (e) {
            Log.error('Failed to convert blob to file: $e', name: 'VineRecordingController', category: LogCategory.system);
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
      Log.error('Failed to finish recording: $e', name: 'VineRecordingController', category: LogCategory.system);
      rethrow;
    }
  }
  
  /// Reset the recording session (but keep files for upload)
  void reset() {
    _stopProgressTimer();
    _stopMaxDurationTimer();
    
    // Don't clean up recording files here - they're needed for upload
    // Files will be cleaned up when starting a new recording session
    
    _segments.clear();
    _totalRecordedDuration = Duration.zero;
    _currentSegmentStartTime = null;
    
    // Check if we need to reinitialize before resetting state
    final wasInError = _state == VineRecordingState.error;
    
    // Reset state
    _setState(VineRecordingState.idle);
    
    // If was in error state and on web, reinitialize the camera
    if (wasInError && kIsWeb) {
      Log.error('Reinitializing web camera after error...', name: 'VineRecordingController', category: LogCategory.system);
      if (_cameraInterface is WebCameraInterface) {
        final webInterface = _cameraInterface as WebCameraInterface;
        webInterface.dispose();
      }
      // Create new camera interface and initialize
      _cameraInterface = WebCameraInterface();
      initialize().then((_) {
        Log.info('Web camera reinitialized successfully', name: 'VineRecordingController', category: LogCategory.system);
        _setState(VineRecordingState.idle);
      }).catchError((e) {
        Log.error('Failed to reinitialize web camera: $e', name: 'VineRecordingController', category: LogCategory.system);
        _setState(VineRecordingState.error);
      });
    }
    
    Log.debug('Recording session reset', name: 'VineRecordingController', category: LogCategory.system);
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
      
      Log.debug('🧹 Cleaned up recording resources', name: 'VineRecordingController', category: LogCategory.system);
    } catch (e) {
      Log.error('Error cleaning up recordings: $e', name: 'VineRecordingController', category: LogCategory.system);
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
            Log.error('Error cleaning up blob URL: $e', name: 'VineRecordingController', category: LogCategory.system);
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
          Log.debug('🧹 Deleted macOS recording file: ${macOSInterface.currentRecordingPath}', name: 'VineRecordingController', category: LogCategory.system);
        }
      } catch (e) {
        Log.error('Error deleting macOS recording file: $e', name: 'VineRecordingController', category: LogCategory.system);
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
            Log.debug('🧹 Deleted mobile recording file: ${segment.filePath}', name: 'VineRecordingController', category: LogCategory.system);
          }
        } catch (e) {
          Log.error('Error deleting mobile recording file: $e', name: 'VineRecordingController', category: LogCategory.system);
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
          Log.error('State notification error: $e', name: 'VineRecordingController', category: LogCategory.system);
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