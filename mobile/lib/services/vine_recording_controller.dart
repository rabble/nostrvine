// ABOUTME: Universal Vine-style recording controller for all platforms
// ABOUTME: Handles press-to-record, release-to-pause segmented recording with cross-platform camera abstraction

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
// camera_macos removed - using NativeMacOSCamera for both preview and recording
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';

import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/services/camera/native_macos_camera.dart';
import 'package:openvine/services/camera/enhanced_mobile_camera_interface.dart';
import 'package:openvine/services/camera/camerawesome_mobile_camera_interface.dart';
import 'package:openvine/services/web_camera_service_stub.dart'
    if (dart.library.html) 'web_camera_service.dart'
    as camera_service;
import 'package:openvine/services/native_proofmode_service.dart';
import 'package:models/models.dart' show NativeProofData;
import 'package:openvine/utils/async_utils.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/macos_camera_preview.dart';

/// Represents a single recording segment in the Vine-style recording
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class RecordingSegment {
  RecordingSegment({
    required this.startTime,
    required this.endTime,
    required this.duration,
    this.filePath,
  });
  final DateTime startTime;
  final DateTime endTime;
  final Duration duration;
  final String? filePath;

  double get durationInSeconds => duration.inMilliseconds / 1000.0;

  @override
  String toString() => 'Segment(${duration.inMilliseconds}ms)';
}

/// Recording state for Vine-style segmented recording
enum VineRecordingState {
  idle, // Camera preview active, not recording
  recording, // Currently recording a segment
  paused, // Between segments, camera preview active
  processing, // Assembling final video
  completed, // Recording finished
  error, // Error state
}

/// Platform-agnostic interface for camera operations
abstract class CameraPlatformInterface {
  Future<void> initialize();
  Future<void> startRecordingSegment(String filePath);
  Future<String?> stopRecordingSegment();
  Future<void> switchCamera();
  Widget get previewWidget;
  bool get canSwitchCamera;
  void dispose();
}

/// macOS camera implementation using native platform channels
/// Uses single AVCaptureSession for both preview and recording via NativeMacOSCamera
class MacOSCameraInterface extends CameraPlatformInterface
    with AsyncInitialization {
  final GlobalKey _cameraKey = GlobalKey(debugLabel: 'vineCamera');
  Widget? _previewWidget;
  String? currentRecordingPath;
  bool isRecording = false;
  int _currentCameraIndex = 0;
  int _availableCameraCount = 1;

  // For macOS single recording mode
  bool isSingleRecordingMode = false;
  final List<RecordingSegment> _virtualSegments = [];

  // Recording completion tracking
  DateTime? _recordingStartTime;
  DateTime? _currentSegmentStartTime;
  Timer? _maxDurationTimer;

  @override
  Future<void> initialize() async {
    startInitialization();

    // Get available cameras
    final cameras = await NativeMacOSCamera.getAvailableCameras();
    _availableCameraCount = cameras.length;
    Log.info(
      'Found $_availableCameraCount cameras on macOS',
      name: 'VineRecordingController',
      category: LogCategory.system,
    );

    // Initialize the native macOS camera for recording
    final nativeResult = await NativeMacOSCamera.initialize();
    if (!nativeResult) {
      throw Exception('Failed to initialize native macOS camera');
    }

    // Start native preview
    await NativeMacOSCamera.startPreview();

    // Complete initialization now that native camera is ready for recording
    completeInitialization();

    // Create the camera widget using native frame stream (single AVCaptureSession)
    _previewWidget = SizedBox.expand(
      child: _NativeFramePreview(key: _cameraKey),
    );

    Log.info(
      '📱 Native macOS camera initialized successfully',
      name: 'VineRecordingController',
      category: LogCategory.system,
    );
  }

  @override
  Future<void> startRecordingSegment(String filePath) async {
    Log.info(
      '📱 Starting recording segment, initialized: $isInitialized, recording: $isRecording, singleMode: $isSingleRecordingMode',
      name: 'VineRecordingController',
      category: LogCategory.system,
    );

    // Wait for visual preview to be initialized
    try {
      await waitForInitialization(timeout: const Duration(seconds: 5));
    } catch (e) {
      Log.error(
        'macOS camera failed to initialize: $e',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );
      throw Exception(
        'macOS camera not initialized after waiting 5 seconds: $e',
      );
    }

    // For macOS, use single recording mode - one continuous native recording
    // with virtual segments tracked in software
    if (!isSingleRecordingMode && !isRecording) {
      // First segment - start the native recording
      // Don't set currentRecordingPath yet - native will provide the actual path
      isRecording = true;
      isSingleRecordingMode = true;
      _recordingStartTime = DateTime.now();
      _currentSegmentStartTime = _recordingStartTime;

      // Start native recording
      final started = await NativeMacOSCamera.startRecording();
      if (!started) {
        isRecording = false;
        isSingleRecordingMode = false;
        _recordingStartTime = null;
        _currentSegmentStartTime = null;
        throw Exception('Failed to start native macOS recording');
      }

      Log.info(
        'Started native macOS single recording mode (segment 1)',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );
    } else if (isSingleRecordingMode && isRecording) {
      // Subsequent segments - native recording continues, just track segment start
      _currentSegmentStartTime = DateTime.now();
      Log.info(
        'Native macOS recording continues - starting segment ${_virtualSegments.length + 2}',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );
    }
    // Note: The case (isSingleRecordingMode && !isRecording) should not happen
    // since we keep isRecording=true between segments
  }

  @override
  Future<String?> stopRecordingSegment() async {
    Log.debug(
      '📱 Pausing segment, recording: $isRecording, singleMode: $isSingleRecordingMode',
      name: 'VineRecordingController',
      category: LogCategory.system,
    );

    if (!isSingleRecordingMode || !isRecording) {
      return null;
    }

    // In single recording mode, track the segment end but KEEP native recording going
    // This allows multiple segments to be recorded continuously
    if (_currentSegmentStartTime != null) {
      final endTime = DateTime.now();
      final duration = endTime.difference(_currentSegmentStartTime!);

      final segment = RecordingSegment(
        startTime: _currentSegmentStartTime!,
        endTime: endTime,
        duration: duration,
        filePath:
            '', // Placeholder - actual path comes from completeRecording()
      );

      _virtualSegments.add(segment);
      Log.info(
        'Tracked virtual segment ${_virtualSegments.length}: ${duration.inMilliseconds}ms (native recording continues)',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );
    }

    // Clear segment start time (will be set again on next segment start)
    _currentSegmentStartTime = null;

    // Return null - file path only comes from completeRecording() at the end
    return null;
  }

  /// Complete the recording and get the final file
  Future<String?> completeRecording() async {
    if (!isRecording) {
      return null;
    }

    _maxDurationTimer?.cancel();

    // If there's an active segment in progress, track it before stopping
    if (_currentSegmentStartTime != null) {
      final endTime = DateTime.now();
      final duration = endTime.difference(_currentSegmentStartTime!);

      final segment = RecordingSegment(
        startTime: _currentSegmentStartTime!,
        endTime: endTime,
        duration: duration,
        filePath: '', // Will be updated below
      );

      _virtualSegments.add(segment);
      Log.info(
        'Tracked final segment ${_virtualSegments.length}: ${duration.inMilliseconds}ms',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );
    }

    isRecording = false;

    // Stop native recording and get the file path
    final recordedPath = await NativeMacOSCamera.stopRecording();

    if (recordedPath != null && recordedPath.isNotEmpty) {
      // The native implementation returns the actual file path
      currentRecordingPath = recordedPath;

      // Calculate total duration from all segments
      final totalDuration = _virtualSegments.fold<Duration>(
        Duration.zero,
        (sum, segment) => sum + segment.duration,
      );

      Log.info(
        'Native macOS recording completed: $recordedPath (${_virtualSegments.length} segments, total: ${totalDuration.inMilliseconds}ms)',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );

      // Don't clear isSingleRecordingMode here - it's needed by finishRecording()
      // It will be cleared in dispose() or when starting a new recording
      _recordingStartTime = null;
      _currentSegmentStartTime = null;

      return recordedPath;
    } else {
      Log.error(
        'Native macOS recording failed - no file path returned',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );
      // Clear flags on error
      isSingleRecordingMode = false;
      _recordingStartTime = null;
      _currentSegmentStartTime = null;
      return null;
    }
  }

  /// Stop the single recording mode and return the final file
  Future<String?> stopSingleRecording() async {
    Log.debug(
      '📱 Stopping native macOS single recording mode',
      name: 'VineRecordingController',
      category: LogCategory.system,
    );

    if (!isSingleRecordingMode || !isRecording) {
      return null;
    }

    return await completeRecording();
  }

  /// Wait for recording completion using proper async pattern
  Future<String> waitForRecordingCompletion({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    // For native implementation, we complete the recording directly
    final path = await completeRecording();
    if (path != null) {
      return path;
    }
    throw TimeoutException('Recording completion failed');
  }

  /// Get virtual segments for macOS single recording mode
  List<RecordingSegment> getVirtualSegments() => _virtualSegments;

  /// Get the timestamp when native recording started (for calculating video offsets)
  DateTime? get recordingStartTime => _recordingStartTime;

  @override
  Widget get previewWidget {
    // Return the native frame preview widget, or placeholder if not ready
    if (_previewWidget == null) {
      if (isInitialized) {
        Log.info(
          '📱 macOS camera initialized but preview widget not created yet',
          name: 'VineRecordingController',
          category: LogCategory.system,
        );
      }
      // Return placeholder until preview widget is ready
      return const CameraPreviewPlaceholder();
    }
    return _previewWidget!;
  }

  @override
  bool get canSwitchCamera => _availableCameraCount > 1;

  @override
  Future<void> switchCamera() async {
    try {
      if (_availableCameraCount <= 1) {
        Log.info(
          'Only one camera available on macOS, cannot switch',
          name: 'VineRecordingController',
          category: LogCategory.system,
        );
        return;
      }

      // Cycle to next camera
      final nextCameraIndex = (_currentCameraIndex + 1) % _availableCameraCount;

      Log.info(
        'Switching macOS camera from $_currentCameraIndex to $nextCameraIndex',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );

      final success = await NativeMacOSCamera.switchCamera(nextCameraIndex);

      if (success) {
        _currentCameraIndex = nextCameraIndex;
        Log.info(
          '📱 macOS camera switched successfully to camera $_currentCameraIndex',
          name: 'VineRecordingController',
          category: LogCategory.system,
        );
      } else {
        Log.error(
          'Failed to switch macOS camera to index $nextCameraIndex',
          name: 'VineRecordingController',
          category: LogCategory.system,
        );
      }
    } catch (e) {
      Log.error(
        'macOS camera switching failed: $e',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );
    }
  }

  @override
  void dispose() {
    _maxDurationTimer?.cancel();
    // Stop any active recording
    if (isRecording) {
      NativeMacOSCamera.stopRecording();
      isRecording = false;
    }
    // Stop preview
    NativeMacOSCamera.stopPreview();
  }

  /// Reset the interface state (for reuse)
  void reset() {
    _maxDurationTimer?.cancel();
    isRecording = false;
    isSingleRecordingMode = false;
    currentRecordingPath = null;
    _virtualSegments.clear();
    _recordingStartTime = null;
    _currentSegmentStartTime = null;
    Log.debug(
      '📱 Native macOS camera interface reset',
      name: 'VineRecordingController',
      category: LogCategory.system,
    );
  }
}

/// Native frame preview widget for macOS using NativeMacOSCamera.frameStream
/// Uses a single AVCaptureSession for both preview and recording
class _NativeFramePreview extends StatefulWidget {
  const _NativeFramePreview({super.key});

  @override
  State<_NativeFramePreview> createState() => _NativeFramePreviewState();
}

class _NativeFramePreviewState extends State<_NativeFramePreview> {
  Uint8List? _lastFrame;
  StreamSubscription<Uint8List>? _frameSubscription;

  @override
  void initState() {
    super.initState();
    _frameSubscription = NativeMacOSCamera.frameStream.listen((frameData) {
      if (mounted) {
        setState(() {
          _lastFrame = frameData;
        });
      }
    });
  }

  @override
  void dispose() {
    _frameSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_lastFrame == null) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );
    }

    return Image.memory(_lastFrame!, fit: BoxFit.cover, gaplessPlayback: true);
  }
}

/// Web camera implementation (using getUserMedia)
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
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
      _previewWidget = camera_service.WebCameraPreview(
        cameraService: _webCameraService!,
      );

      Log.info(
        '📱 Web camera interface initialized successfully',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Web camera interface initialization failed: $e',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );

      // Provide more specific error messages
      if (e.toString().contains('NotFoundError')) {
        throw Exception(
          'No camera found. Please ensure a camera is connected and accessible.',
        );
      } else if (e.toString().contains('NotAllowedError') ||
          e.toString().contains('PermissionDeniedError')) {
        throw Exception(
          'Camera access denied. Please allow camera permissions and try again.',
        );
      } else if (e.toString().contains('NotReadableError')) {
        throw Exception('Camera is already in use by another application.');
      } else if (e.toString().contains('MediaDevices API not available')) {
        throw Exception(
          'Camera API not available. Please ensure you are using HTTPS.',
        );
      }

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
      Log.info(
        '📱 Web recording completed: $blobUrl',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );
      return blobUrl;
    } catch (e) {
      Log.error(
        'Failed to stop web recording: $e',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );
      rethrow;
    }
  }

  @override
  Future<void> switchCamera() async {
    if (_webCameraService == null) {
      Log.warning(
        'Web camera service not initialized',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );
      return;
    }

    try {
      await _webCameraService!.switchCamera();
      Log.info(
        '📱 Web camera switched successfully',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Camera switching failed on web: $e',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );
    }
  }

  @override
  Widget get previewWidget =>
      _previewWidget ??
      const ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      );

  @override
  bool get canSwitchCamera {
    // For web, hide camera switch button as it's less common and
    // can cause confusion. Most users have only one camera.
    return false;
  }

  /// Clean up a blob URL (internal method for cleanup)
  void _cleanupBlobUrl(String blobUrl) {
    if (kIsWeb && _webCameraService != null) {
      try {
        // Call the static method through the service
        camera_service.WebCameraService.revokeBlobUrl(blobUrl);
      } catch (e) {
        Log.error(
          'Error revoking blob URL: $e',
          name: 'VineRecordingController',
          category: LogCategory.system,
        );
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
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class VineRecordingController {
  static const Duration maxRecordingDuration = Duration(
    milliseconds: 6300,
  ); // 6.3 seconds like original Vine
  static const Duration minSegmentDuration = Duration(
    milliseconds: 33,
  ); // 1 frame at 30fps for stop-motion

  CameraPlatformInterface? _cameraInterface;
  VineRecordingState _state = VineRecordingState.idle;
  bool _cameraInitialized = false;

  /// Constructor
  VineRecordingController();

  // Getter for camera interface (needed for enhanced controls)
  CameraPlatformInterface? get cameraInterface => _cameraInterface;

  // Getter for camera preview widget
  Widget get previewWidget =>
      _cameraInterface?.previewWidget ??
      const SizedBox(child: Center(child: CircularProgressIndicator()));

  // Callback for notifying UI of state changes during recording
  VoidCallback? _onStateChanged;

  // Recording session data
  final List<RecordingSegment> _segments = [];
  model.AspectRatio _aspectRatio =
      model.AspectRatio.vertical; // Default to 9:16 vertical
  DateTime? _currentSegmentStartTime;
  Timer? _progressTimer;
  Timer? _maxDurationTimer;
  String? _tempDirectory;

  // Progress tracking
  Duration _totalRecordedDuration = Duration.zero;
  bool _disposed = false;

  // Getters
  VineRecordingState get state => _state;
  bool get isCameraInitialized => _cameraInitialized;
  List<RecordingSegment> get segments => List.unmodifiable(_segments);

  /// Get current aspect ratio
  model.AspectRatio get aspectRatio => _aspectRatio;
  Duration get totalRecordedDuration => _totalRecordedDuration;
  Duration get remainingDuration =>
      maxRecordingDuration - _totalRecordedDuration;
  double get progress =>
      _totalRecordedDuration.inMilliseconds /
      maxRecordingDuration.inMilliseconds;
  bool get canRecord {
    bool isCameraReadyToRecord = true;
    final cameraInterface = _cameraInterface;

    if (cameraInterface is CamerAwesomeMobileCameraInterface) {
      isCameraReadyToRecord = cameraInterface.isReadyToRecord;
    }
    return _cameraInitialized &&
        isCameraReadyToRecord &&
        remainingDuration > minSegmentDuration &&
        _state != VineRecordingState.processing;
  }

  bool get hasSegments {
    if (_segments.isNotEmpty) return true;
    // For macOS, also check virtual segments since we use single-recording mode
    if (!kIsWeb &&
        Platform.isMacOS &&
        _cameraInterface is MacOSCameraInterface) {
      final macOSInterface = _cameraInterface as MacOSCameraInterface;
      return macOSInterface.getVirtualSegments().isNotEmpty;
    }
    return false;
  }

  Widget get cameraPreview =>
      _cameraInterface?.previewWidget ??
      const ColoredBox(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Color(0xFF00B488),
                ), // Vine green
                strokeWidth: 3.0,
              ),
              SizedBox(height: 16),
              Text(
                'Divine',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Starting camera...',
                style: TextStyle(
                  color: Color(0xFFBBBBBB),
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      );

  /// Check if camera switching is available on current platform
  bool get canSwitchCamera {
    if (_state == VineRecordingState.recording) return false;
    return _cameraInterface?.canSwitchCamera ?? false;
  }

  /// Set callback for state change notifications during recording
  void setStateChangeCallback(VoidCallback? callback) {
    _onStateChanged = callback;
  }

  /// Set aspect ratio (only allowed when not recording)
  void setAspectRatio(model.AspectRatio ratio) {
    if (state == VineRecordingState.recording) {
      Log.warning(
        'Cannot change aspect ratio while recording',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );
      return;
    }

    _aspectRatio = ratio;
    Log.info(
      'Aspect ratio changed to: $ratio',
      name: 'VineRecordingController',
      category: LogCategory.system,
    );
    _onStateChanged?.call();
  }

  /// Switch between front and rear cameras
  Future<void> switchCamera() async {
    Log.info(
      '🔄 VineRecordingController.switchCamera() called, current state: $_state',
      name: 'VineRecordingController',
      category: LogCategory.system,
    );

    if (_state == VineRecordingState.recording) {
      Log.warning(
        'Cannot switch camera while recording',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );
      return;
    }

    // If we're in paused state with a segment in progress, ensure it's properly stopped
    if (_currentSegmentStartTime != null) {
      Log.warning(
        'Cleaning up incomplete segment before camera switch',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );
      _currentSegmentStartTime = null;
      _stopProgressTimer();
      _stopMaxDurationTimer();
    }

    try {
      Log.info(
        '🔄 Calling _cameraInterface?.switchCamera()...',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );
      await _cameraInterface?.switchCamera();
      Log.info(
        '📱 Camera switched successfully at interface level',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );

      // CRITICAL: Force state notification to trigger UI rebuild
      Log.info(
        '🔄 Calling _onStateChanged callback to trigger UI rebuild, callback=${_onStateChanged != null ? "exists" : "null"}',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );
      _onStateChanged?.call();
      Log.info(
        '🔄 _onStateChanged callback completed',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to switch camera: $e',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );
    }
  }

  /// Initialize the recording controller for the current platform
  Future<void> initialize() async {
    try {
      _setState(VineRecordingState.idle);

      if (_cameraInterface != null) {
        _cameraInterface!.dispose();
        _cameraInterface = null;
        _cameraInitialized = false;
      }

      // Clean up any old recordings from previous sessions
      _cleanupRecordings();

      // Create platform-specific camera interface
      if (kIsWeb) {
        _cameraInterface = WebCameraInterface();
      } else if (Platform.isMacOS) {
        _cameraInterface = MacOSCameraInterface();
      } else if (Platform.isIOS || Platform.isAndroid) {
        // Use CamerAwesome for iOS with physical sensor switching support
        if (Platform.isIOS) {
          final camerAwesome = CamerAwesomeMobileCameraInterface();
          // Wire up callback to notify provider when camera becomes ready
          camerAwesome.onCameraReady = () {
            _onStateChanged?.call();
          };
          _cameraInterface = camerAwesome;
          await _cameraInterface!.initialize();
          Log.info(
            'Using CamerAwesome camera with physical sensor switching',
            name: 'VineRecordingController',
            category: LogCategory.system,
          );
        } else {
          // Android: Try CamerAwesome, fallback to enhanced camera if needed
          try {
            final camerAwesome = CamerAwesomeMobileCameraInterface();
            // Wire up callback to notify provider when camera becomes ready
            camerAwesome.onCameraReady = () {
              _onStateChanged?.call();
            };
            _cameraInterface = camerAwesome;
            await _cameraInterface!.initialize();
            Log.info(
              'Using CamerAwesome camera for Android',
              name: 'VineRecordingController',
              category: LogCategory.system,
            );
          } catch (cameraAwesomeError) {
            Log.warning(
              'CamerAwesome failed, falling back to enhanced camera: $cameraAwesomeError',
              name: 'VineRecordingController',
              category: LogCategory.system,
            );
            _cameraInterface?.dispose();
            _cameraInterface = EnhancedMobileCameraInterface();
            await _cameraInterface!.initialize();
            Log.info(
              'Using enhanced mobile camera interface as fallback',
              name: 'VineRecordingController',
              category: LogCategory.system,
            );
          }
        }
      } else {
        throw Exception('Platform not supported: ${Platform.operatingSystem}');
      }

      // For non-mobile platforms, initialize here (mobile initialization handled above)
      if (!Platform.isIOS && !Platform.isAndroid) {
        await _cameraInterface!.initialize();
      }

      // Set up temp directory for segments
      if (!kIsWeb) {
        final tempDir = await _getTempDirectory();
        _tempDirectory = tempDir.path;
      }

      // Mark camera as initialized - UI can now show preview
      _cameraInitialized = true;

      Log.info(
        'VineRecordingController initialized for ${_getPlatformName()}',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );
    } catch (e) {
      _setState(VineRecordingState.error);
      _cameraInitialized = false;
      Log.error(
        'VineRecordingController initialization failed: $e',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );
      rethrow;
    }
  }

  /// Start recording a new segment (press down)
  Future<void> startRecording() async {
    if (!canRecord) return;

    // Prevent starting if already recording
    if (_state == VineRecordingState.recording) {
      Log.warning(
        'Already recording, ignoring start request',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );
      return;
    }

    // On web, prevent multiple segments - MediaRecorder doesn't support pause/resume like mobile
    // Web needs continuous recording or a different concatenation approach
    if (kIsWeb && _segments.isNotEmpty) {
      Log.warning(
        'Multiple segments not supported on web - use single continuous recording',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );
      return;
    }

    try {
      _setState(VineRecordingState.recording);
      _currentSegmentStartTime = DateTime.now();

      // ProofMode proof will be generated after recording using Guardian Project native library

      // Normal segmented recording for all platforms
      final segmentPath = _generateSegmentPath();
      await _cameraInterface!.startRecordingSegment(segmentPath);

      // Start progress timer
      _startProgressTimer();

      // Set max duration timer if this is the first segment or we're close to limit
      _startMaxDurationTimer();

      Log.info(
        'Started recording segment ${_segments.length + 1}',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );
    } catch (e) {
      // Reset state and clean up on error
      _currentSegmentStartTime = null;
      _stopProgressTimer();
      _stopMaxDurationTimer();
      _setState(VineRecordingState.error);
      Log.error(
        'Failed to start recording: $e',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );
      // Don't rethrow - handle gracefully in UI
    }
  }

  /// Stop recording current segment (release)
  Future<void> stopRecording() async {
    // Capture start time locally to prevent race conditions
    final segmentStartTime = _currentSegmentStartTime;

    if (_state != VineRecordingState.recording || segmentStartTime == null) {
      Log.warning(
        'Not recording or no start time, ignoring stop request',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );
      return;
    }

    // Clear the segment start time immediately to prevent double-stop
    _currentSegmentStartTime = null;

    try {
      var segmentEndTime = DateTime.now();
      var segmentDuration = segmentEndTime.difference(segmentStartTime);

      // For stop-motion: if user taps very quickly, wait for minimum duration
      // to ensure at least one frame is captured
      if (segmentDuration < minSegmentDuration) {
        final waitTime = minSegmentDuration - segmentDuration;
        Log.info(
          '🎬 Stop-motion mode: waiting ${waitTime.inMilliseconds}ms to capture frame',
          name: 'VineRecordingController',
          category: LogCategory.system,
        );
        await Future.delayed(waitTime);

        // Recalculate after waiting
        segmentEndTime = DateTime.now();
        segmentDuration = segmentEndTime.difference(segmentStartTime);
      }

      // Now we're guaranteed to have at least minSegmentDuration
      if (segmentDuration >= minSegmentDuration) {
        // For macOS in single recording mode, track segment but KEEP native recording going
        // The native recording only stops when finishRecording() is called
        if (!kIsWeb &&
            Platform.isMacOS &&
            _cameraInterface is MacOSCameraInterface) {
          final macOSInterface = _cameraInterface as MacOSCameraInterface;

          // Track the segment end time but DON'T stop native recording
          // This allows subsequent segments to continue from the same recording
          await macOSInterface.stopRecordingSegment();

          // Update total recorded duration for progress bar
          _totalRecordedDuration += segmentDuration;

          final virtualSegments = macOSInterface.getVirtualSegments();
          Log.info(
            '📱 macOS segment ${virtualSegments.length} tracked (${segmentDuration.inMilliseconds}ms) - native recording continues',
            name: 'VineRecordingController',
            category: LogCategory.system,
          );
        } else {
          // Normal segment recording for other platforms
          final filePath = await _cameraInterface!.stopRecordingSegment();

          if (filePath != null) {
            // CRITICAL: Copy segment to safe location immediately
            // CamerAwesome may delete previous recordings when starting new ones
            // This ensures all segments are preserved for concatenation
            Log.info(
              '📹 Segment ${_segments.length + 1} recorded to: $filePath',
              name: 'VineRecordingController',
              category: LogCategory.system,
            );

            // Wait for file to be written - CamerAwesome's stopRecording may return
            // before the file is fully flushed to disk, especially for short recordings
            final sourceFile = File(filePath);
            bool exists = await sourceFile.exists();

            // Retry up to 500ms waiting for file to appear (for stop-motion short taps)
            if (!exists) {
              Log.info(
                '📹 File not yet written, waiting for CamerAwesome to flush...',
                name: 'VineRecordingController',
                category: LogCategory.system,
              );
              for (int i = 0; i < 10 && !exists; i++) {
                await Future.delayed(const Duration(milliseconds: 50));
                exists = await sourceFile.exists();
              }
            }

            Log.info(
              '📹 Source file exists: $exists',
              name: 'VineRecordingController',
              category: LogCategory.system,
            );

            if (!exists) {
              // Even after waiting, file doesn't exist - recording truly failed
              Log.warning(
                '📹 Segment file does not exist after waiting, skipping segment',
                name: 'VineRecordingController',
                category: LogCategory.system,
              );
              // Don't add to _segments - this segment is invalid
            } else {
              String safeFilePath = filePath;
              try {
                final safeDir = await _getTempDirectory();
                final safePath =
                    '${safeDir.path}/safe_segment_${_segments.length + 1}_${DateTime.now().millisecondsSinceEpoch}.mov';
                Log.info(
                  '📹 Copying to safe path: $safePath',
                  name: 'VineRecordingController',
                  category: LogCategory.system,
                );
                final copiedFile = await sourceFile.copy(safePath);
                safeFilePath = copiedFile.path;
                Log.info(
                  '📹 Copied segment to safe location: $safeFilePath',
                  name: 'VineRecordingController',
                  category: LogCategory.system,
                );
              } catch (e) {
                Log.error(
                  '📹 Failed to copy segment to safe location: $e, using original path: $filePath',
                  name: 'VineRecordingController',
                  category: LogCategory.system,
                );
              }

              final segment = RecordingSegment(
                startTime: segmentStartTime,
                endTime: segmentEndTime,
                duration: segmentDuration,
                filePath: safeFilePath,
              );

              _segments.add(segment);
              _totalRecordedDuration += segmentDuration;

              Log.info(
                'Completed segment ${_segments.length}: ${segmentDuration.inMilliseconds}ms',
                name: 'VineRecordingController',
                category: LogCategory.system,
              );
            }
          } else {
            Log.warning(
              'No file path returned from camera interface',
              name: 'VineRecordingController',
              category: LogCategory.system,
            );
          }
        }
      }

      // _currentSegmentStartTime already cleared at start of method
      _stopProgressTimer();
      _stopMaxDurationTimer();

      // Reset total duration to actual segments total (removing any in-progress time)
      // For macOS with virtual segments, use the virtual segments for duration calculation
      if (!kIsWeb &&
          Platform.isMacOS &&
          _cameraInterface is MacOSCameraInterface) {
        final macOSInterface = _cameraInterface as MacOSCameraInterface;
        final virtualSegments = macOSInterface.getVirtualSegments();
        _totalRecordedDuration = virtualSegments.fold<Duration>(
          Duration.zero,
          (total, segment) => total + segment.duration,
        );
      } else {
        _totalRecordedDuration = _segments.fold<Duration>(
          Duration.zero,
          (total, segment) => total + segment.duration,
        );
      }

      // Check if we've reached the maximum duration or if on web (single segment only)
      if (_totalRecordedDuration >= maxRecordingDuration || kIsWeb) {
        _setState(VineRecordingState.completed);
        Log.info(
          '📱 Recording completed - ${kIsWeb ? "web single segment" : "reached maximum duration"}',
          name: 'VineRecordingController',
          category: LogCategory.system,
        );
      } else {
        _setState(VineRecordingState.paused);
      }
    } catch (e) {
      // Reset state and clean up on error
      // Note: _currentSegmentStartTime already cleared at start of method
      _stopProgressTimer();
      _stopMaxDurationTimer();
      _setState(VineRecordingState.error);
      Log.error(
        'Failed to stop recording: $e',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );
      // Don't rethrow - handle gracefully in UI
    }
  }

  /// Build FFmpeg crop filter for the specified aspect ratio
  ///
  /// Square: Center crop to 1:1 (minimum dimension)
  /// Vertical: Center crop to 9:16 (portrait)
  String _buildCropFilter(model.AspectRatio aspectRatio) {
    switch (aspectRatio) {
      case model.AspectRatio.square:
        // Center crop to 1:1 (existing production logic)
        return "crop=min(iw\\,ih):min(iw\\,ih):(iw-min(iw\\,ih))/2:(ih-min(iw\\,ih))/2";

      case model.AspectRatio.vertical:
        // Center crop to 9:16 vertical
        // Tested and validated with FFmpeg integration tests
        return "crop='if(gt(iw/ih\\,9/16)\\,ih*9/16\\,iw)':'if(gt(iw/ih\\,9/16)\\,ih\\,iw*16/9)':'(iw-if(gt(iw/ih\\,9/16)\\,ih*9/16\\,iw))/2':'(ih-if(gt(iw/ih\\,9/16)\\,ih\\,iw*16/9))/2'";
    }
  }

  /// Concatenate multiple video segments using FFmpeg (mobile/desktop only)
  /// NOTE: Android currently uses continuous recording (no segmentation) due to FFmpeg build issues
  Future<File?> _concatenateSegments(List<RecordingSegment> segments) async {
    if (kIsWeb) {
      throw Exception('FFmpeg concatenation not supported on web platform');
    }

    if (segments.isEmpty) {
      throw Exception('No segments to concatenate');
    }

    // CRITICAL: Verify all segment files exist before proceeding
    // CamerAwesome may delete old segments when new recordings start
    Log.info(
      '📹 Verifying ${segments.length} segment files exist before concatenation',
      name: 'VineRecordingController',
      category: LogCategory.system,
    );

    for (var i = 0; i < segments.length; i++) {
      final segment = segments[i];
      if (segment.filePath == null) {
        throw Exception('Segment $i has null file path');
      }
      final file = File(segment.filePath!);
      if (!await file.exists()) {
        throw Exception('Segment $i file does not exist: ${segment.filePath}');
      }
      Log.info(
        '📹 Segment $i verified: ${segment.filePath}',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );
    }

    // Single segment - apply aspect ratio cropping via FFmpeg
    if (segments.length == 1 && segments.first.filePath != null) {
      Log.info(
        '📹 Applying square cropping to single segment',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );

      final inputPath = segments.first.filePath!;
      final tempDir = await getTemporaryDirectory();
      final outputPath =
          '${tempDir.path}/vine_final_${DateTime.now().millisecondsSinceEpoch}.mp4';

      final cropFilter = _buildCropFilter(_aspectRatio);

      final audioEncodeFlag = Platform.isAndroid ? '-c:a aac' : '-c:a copy';
      final command =
          '-hwaccel auto -y -i "$inputPath" -vf "$cropFilter" $audioEncodeFlag "$outputPath"';

      Log.info(
        '📹 Executing FFmpeg square crop command: $command',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        Log.info(
          '📹 FFmpeg square cropping successful: $outputPath',
          name: 'VineRecordingController',
          category: LogCategory.system,
        );

        final outputFile = File(outputPath);
        if (await outputFile.exists()) {
          return outputFile;
        } else {
          throw Exception('Output file does not exist after cropping');
        }
      } else {
        final output = await session.getOutput();
        Log.error(
          '📹 FFmpeg square cropping failed with code $returnCode',
          name: 'VineRecordingController',
          category: LogCategory.system,
        );
        Log.error(
          '📹 FFmpeg output: $output',
          name: 'VineRecordingController',
          category: LogCategory.system,
        );
        throw Exception('FFmpeg square cropping failed with code $returnCode');
      }
    }

    try {
      Log.info(
        '📹 Concatenating ${segments.length} video segments with FFmpeg',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );

      // Create output file path
      final tempDir = await getTemporaryDirectory();
      final outputPath =
          '${tempDir.path}/vine_final_${DateTime.now().millisecondsSinceEpoch}.mp4';

      // CRITICAL FIX: When switching cameras mid-recording, second segment gets 180° rotation
      // We need to normalize all segments to have the same rotation before concatenating
      // Strategy: Re-encode all segments with rotation metadata applied to pixels, then strip metadata
      Log.info(
        '📹 Normalizing rotation for all segments to prevent camera-switch flip',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );

      final normalizedPaths = <String>[];
      for (var i = 0; i < segments.length; i++) {
        final segment = segments[i];
        if (segment.filePath == null) continue;

        final normalizedPath = '${tempDir.path}/normalized_$i.mp4';

        // Use -noautorotate to prevent FFmpeg from auto-rotating during input
        // Then manually apply rotation metadata to pixels and strip metadata
        // This ensures all segments have physically upright pixels with no rotation tag
        // Re-encode audio too to ensure proper A/V sync across segments
        // Force 30fps output and use -vsync cfr for consistent timing
        final normalizeCommand =
            '-hwaccel auto -y -i "${segment.filePath}" -c:v libx264 -preset ultrafast -r 30 -vsync cfr -c:a aac -b:a 128k -async 1 -metadata:s:v rotate=0 "$normalizedPath"';

        Log.info(
          '📹 Normalizing segment $i with command: $normalizeCommand',
          name: 'VineRecordingController',
          category: LogCategory.system,
        );

        final session = await FFmpegKit.execute(normalizeCommand);
        final returnCode = await session.getReturnCode();

        if (!ReturnCode.isSuccess(returnCode)) {
          final output = await session.getOutput();
          Log.error(
            '📹 Failed to normalize segment $i: $output',
            name: 'VineRecordingController',
            category: LogCategory.system,
          );
          throw Exception('Failed to normalize rotation for segment $i');
        }

        normalizedPaths.add(normalizedPath);
        Log.info(
          '📹 Successfully normalized segment $i',
          name: 'VineRecordingController',
          category: LogCategory.system,
        );
      }

      // Create concat file list with normalized segments
      final concatFilePath = '${tempDir.path}/concat_list.txt';
      final concatFile = File(concatFilePath);

      final buffer = StringBuffer();
      for (final normalizedPath in normalizedPaths) {
        buffer.writeln("file '$normalizedPath'");
      }

      await concatFile.writeAsString(buffer.toString());

      Log.info(
        '📹 FFmpeg concat list:\n${buffer.toString()}',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );

      // Execute FFmpeg concatenation with aspect ratio cropping
      // Re-encode both video and audio to ensure proper A/V sync
      // Use -vsync cfr for constant frame rate and -async 1 to sync audio to video
      final cropFilter = _buildCropFilter(_aspectRatio);
      final command =
          '-hwaccel auto -y -f concat -safe 0 -i "$concatFilePath" -vf "$cropFilter" -c:v libx264 -preset ultrafast -vsync cfr -r 30 -c:a aac -b:a 128k -async 1 "$outputPath"';

      Log.info(
        '📹 Executing FFmpeg command: $command',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (ReturnCode.isSuccess(returnCode)) {
        Log.info(
          '📹 FFmpeg concatenation successful: $outputPath',
          name: 'VineRecordingController',
          category: LogCategory.system,
        );

        // Clean up concat list file and normalized segments
        try {
          await concatFile.delete();
          for (final normalizedPath in normalizedPaths) {
            try {
              await File(normalizedPath).delete();
            } catch (e) {
              Log.warning(
                'Failed to delete normalized segment $normalizedPath: $e',
                name: 'VineRecordingController',
                category: LogCategory.system,
              );
            }
          }
        } catch (e) {
          Log.warning(
            'Failed to delete concat list file: $e',
            name: 'VineRecordingController',
            category: LogCategory.system,
          );
        }

        final outputFile = File(outputPath);
        if (await outputFile.exists()) {
          return outputFile;
        } else {
          throw Exception('Output file does not exist after concatenation');
        }
      } else {
        final output = await session.getOutput();
        Log.error(
          '📹 FFmpeg concatenation failed with code $returnCode',
          name: 'VineRecordingController',
          category: LogCategory.system,
        );
        Log.error(
          '📹 FFmpeg output: $output',
          name: 'VineRecordingController',
          category: LogCategory.system,
        );
        throw Exception('FFmpeg concatenation failed with code $returnCode');
      }
    } catch (e) {
      Log.error(
        '📹 Video concatenation error: $e',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );
      rethrow;
    }
  }

  /// Get the recorded video path from macOS single recording mode.
  ///
  /// Refactored helper method that consolidates path discovery logic.
  /// Tries multiple sources in priority order:
  /// 1. Active recording completion (if still recording)
  /// 2. Current recording path (if already completed)
  /// 3. Virtual segments fallback (legacy path)
  ///
  /// Returns null if no valid recording is found.
  /// Throws exception if path discovery fails unexpectedly.
  Future<String?> _getMacOSRecordingPath(
    MacOSCameraInterface macOSInterface,
  ) async {
    // Try 1: If recording is still active, complete it first
    if (macOSInterface.isRecording) {
      try {
        final completedPath = await macOSInterface.completeRecording();
        if (completedPath != null && await File(completedPath).exists()) {
          Log.info(
            '📱 Got recording from active recording completion',
            name: 'VineRecordingController',
            category: LogCategory.system,
          );
          return completedPath;
        }
      } catch (e) {
        Log.error(
          'Failed to complete macOS recording: $e',
          name: 'VineRecordingController',
          category: LogCategory.system,
        );
      }
    }

    // Try 2: Check if we already have a recorded file
    if (macOSInterface.currentRecordingPath != null) {
      if (await File(macOSInterface.currentRecordingPath!).exists()) {
        Log.info(
          '📱 Got recording from currentRecordingPath',
          name: 'VineRecordingController',
          category: LogCategory.system,
        );
        return macOSInterface.currentRecordingPath;
      }
    }

    // Try 3: Check virtual segments as fallback
    final virtualSegments = macOSInterface.getVirtualSegments();
    if (virtualSegments.isNotEmpty && virtualSegments.first.filePath != null) {
      if (await File(virtualSegments.first.filePath!).exists()) {
        Log.info(
          '📱 Got recording from virtual segments',
          name: 'VineRecordingController',
          category: LogCategory.system,
        );
        return virtualSegments.first.filePath;
      }
    }

    return null;
  }

  /// Apply aspect ratio crop filter to a video file using FFmpeg.
  ///
  /// Refactored helper method that consolidates FFmpeg cropping logic.
  /// Uses the current aspect ratio setting (_aspectRatio) to:
  /// - Square (1:1): Crop to minimum dimension, centered
  /// - Vertical (9:16): Crop to 9:16 ratio, centered
  ///
  /// Returns a new cropped File in the temporary directory.
  /// Throws Exception if FFmpeg processing fails or output file doesn't exist.
  Future<File> _applyAspectRatioCrop(String inputPath) async {
    Log.info(
      '📹 Applying aspect ratio crop to video',
      name: 'VineRecordingController',
      category: LogCategory.system,
    );

    final tempDir = await getTemporaryDirectory();
    final outputPath =
        '${tempDir.path}/vine_final_${DateTime.now().millisecondsSinceEpoch}.mp4';

    final cropFilter = _buildCropFilter(_aspectRatio);
    final command =
        '-hwaccel auto -i "$inputPath" -vf "$cropFilter" -c:v libx264 -preset ultrafast -r 30 -vsync cfr -c:a aac -b:a 128k -async 1 "$outputPath"';

    Log.info(
      '📹 Executing FFmpeg crop command: $command',
      name: 'VineRecordingController',
      category: LogCategory.system,
    );

    final session = await FFmpegKit.execute(command);
    final returnCode = await session.getReturnCode();

    if (!ReturnCode.isSuccess(returnCode)) {
      final output = await session.getOutput();
      Log.error(
        '📹 FFmpeg crop failed with code $returnCode',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );
      Log.error(
        '📹 FFmpeg output: $output',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );
      throw Exception('FFmpeg crop failed with code $returnCode');
    }

    final croppedFile = File(outputPath);
    if (!await croppedFile.exists()) {
      throw Exception('Cropped file does not exist after FFmpeg processing');
    }

    Log.info(
      '📹 FFmpeg crop successful: $outputPath',
      name: 'VineRecordingController',
      category: LogCategory.system,
    );

    return croppedFile;
  }

  /// Extract only the recorded segments from a macOS continuous recording
  /// Uses FFmpeg to cut out the paused portions based on virtual segment timestamps
  Future<File> _extractMacOSSegments(
    String inputPath,
    List<RecordingSegment> virtualSegments,
    DateTime recordingStartTime,
  ) async {
    if (virtualSegments.isEmpty) {
      throw Exception('No virtual segments to extract');
    }

    final tempDir = await getTemporaryDirectory();

    // If only one segment, just trim it directly with aspect ratio crop
    if (virtualSegments.length == 1) {
      final segment = virtualSegments.first;
      final startOffset = segment.startTime.difference(recordingStartTime);
      final startSec = startOffset.inMilliseconds / 1000.0;
      final durationSec = segment.duration.inMilliseconds / 1000.0;

      final outputPath =
          '${tempDir.path}/vine_extracted_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final cropFilter = _buildCropFilter(_aspectRatio);

      // Use -ss before -i for fast seeking, then -t for duration
      final command =
          '-hwaccel auto -y -ss $startSec -i "$inputPath" -t $durationSec -vf "$cropFilter" -c:v libx264 -preset fast -c:a aac "$outputPath"';

      Log.info(
        '📹 Extracting single macOS segment: start=${startSec}s, duration=${durationSec}s',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );
      Log.info(
        '📹 FFmpeg command: $command',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );

      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();

      if (!ReturnCode.isSuccess(returnCode)) {
        final output = await session.getOutput();
        Log.error(
          '📹 FFmpeg segment extraction failed: $output',
          name: 'VineRecordingController',
          category: LogCategory.system,
        );
        throw Exception('FFmpeg segment extraction failed');
      }

      final outputFile = File(outputPath);
      if (!await outputFile.exists()) {
        throw Exception('Extracted segment file does not exist');
      }

      Log.info(
        '📹 Single segment extracted successfully: $outputPath',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );
      return outputFile;
    }

    // Multiple segments: extract each, then concatenate
    Log.info(
      '📹 Extracting ${virtualSegments.length} segments from macOS continuous recording',
      name: 'VineRecordingController',
      category: LogCategory.system,
    );

    final extractedPaths = <String>[];

    for (var i = 0; i < virtualSegments.length; i++) {
      final segment = virtualSegments[i];
      final startOffset = segment.startTime.difference(recordingStartTime);
      final startSec = startOffset.inMilliseconds / 1000.0;
      final durationSec = segment.duration.inMilliseconds / 1000.0;

      final extractedPath = '${tempDir.path}/segment_$i.mp4';

      // Extract segment without cropping first (will crop during concat)
      final extractCommand =
          '-hwaccel auto -y -ss $startSec -i "$inputPath" -t $durationSec -c:v libx264 -preset ultrafast -c:a aac "$extractedPath"';

      Log.info(
        '📹 Extracting segment $i: start=${startSec}s, duration=${durationSec}s',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );

      final session = await FFmpegKit.execute(extractCommand);
      final returnCode = await session.getReturnCode();

      if (!ReturnCode.isSuccess(returnCode)) {
        final output = await session.getOutput();
        Log.error(
          '📹 Failed to extract segment $i: $output',
          name: 'VineRecordingController',
          category: LogCategory.system,
        );
        throw Exception('Failed to extract segment $i');
      }

      extractedPaths.add(extractedPath);
      Log.info(
        '📹 Segment $i extracted successfully',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );
    }

    // Create concat file list
    final concatFilePath = '${tempDir.path}/concat_list.txt';
    final concatFile = File(concatFilePath);
    final buffer = StringBuffer();
    for (final path in extractedPaths) {
      buffer.writeln("file '$path'");
    }
    await concatFile.writeAsString(buffer.toString());

    // Concatenate with aspect ratio crop
    final outputPath =
        '${tempDir.path}/vine_final_${DateTime.now().millisecondsSinceEpoch}.mp4';
    final cropFilter = _buildCropFilter(_aspectRatio);
    final concatCommand =
        '-hwaccel auto -y -f concat -safe 0 -i "$concatFilePath" -vf "$cropFilter" -c:v libx264 -preset fast -c:a aac "$outputPath"';

    Log.info(
      '📹 Concatenating extracted segments with crop filter',
      name: 'VineRecordingController',
      category: LogCategory.system,
    );

    final concatSession = await FFmpegKit.execute(concatCommand);
    final concatReturnCode = await concatSession.getReturnCode();

    if (!ReturnCode.isSuccess(concatReturnCode)) {
      final output = await concatSession.getOutput();
      Log.error(
        '📹 FFmpeg concat failed: $output',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );
      throw Exception('FFmpeg concatenation of extracted segments failed');
    }

    // Cleanup temp files
    try {
      await concatFile.delete();
      for (final path in extractedPaths) {
        await File(path).delete();
      }
    } catch (e) {
      Log.warning(
        '📹 Failed to cleanup temp files: $e',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );
    }

    final outputFile = File(outputPath);
    if (!await outputFile.exists()) {
      throw Exception('Final concatenated file does not exist');
    }

    Log.info(
      '📹 All segments extracted and concatenated: $outputPath',
      name: 'VineRecordingController',
      category: LogCategory.system,
    );
    return outputFile;
  }

  /// Generate native ProofMode proof for a video file
  Future<NativeProofData?> _generateNativeProof(File videoFile) async {
    try {
      // Check if native ProofMode is available on this platform
      final isAvailable = await NativeProofModeService.isAvailable();
      if (!isAvailable) {
        Log.info(
          '🔐 Native ProofMode not available on this platform',
          name: 'VineRecordingController',
          category: LogCategory.system,
        );
        return null;
      }

      Log.info(
        '🔐 Generating native ProofMode proof for: ${videoFile.path}',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );

      // Generate proof using native library
      final proofHash = await NativeProofModeService.generateProof(
        videoFile.path,
      );
      if (proofHash == null) {
        Log.warning(
          '🔐 Native proof generation returned null',
          name: 'VineRecordingController',
          category: LogCategory.system,
        );
        return null;
      }

      Log.info(
        '🔐 Native proof hash: $proofHash',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );

      // Read proof metadata from native library
      final metadata = await NativeProofModeService.readProofMetadata(
        proofHash,
      );
      if (metadata == null) {
        Log.warning(
          '🔐 Could not read native proof metadata',
          name: 'VineRecordingController',
          category: LogCategory.system,
        );
        return null;
      }

      Log.info(
        '🔐 Native proof metadata fields: ${metadata.keys.join(", ")}',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );

      // Create NativeProofData from metadata
      final proofData = NativeProofData.fromMetadata(metadata);
      Log.info(
        '🔐 Native proof data created: ${proofData.verificationLevel}',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );

      return proofData;
    } catch (e) {
      Log.error(
        '🔐 Native proof generation failed: $e',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );
      return null;
    }
  }

  /// Finish recording and return the final compiled video with optional native ProofMode data
  Future<(File?, NativeProofData?)> finishRecording() async {
    final startTime = DateTime.now();
    final returnValue = await (() async {
      try {
        _setState(VineRecordingState.processing);

        // For macOS single recording mode, handle specially
        if (!kIsWeb &&
            Platform.isMacOS &&
            _cameraInterface is MacOSCameraInterface) {
          final macOSInterface = _cameraInterface as MacOSCameraInterface;

          // For single recording mode, extract only the virtual segment portions
          if (macOSInterface.isSingleRecordingMode) {
            final virtualSegments = macOSInterface.getVirtualSegments();
            final recordingStartTime = macOSInterface.recordingStartTime;

            Log.info(
              '📱 finishRecording: macOS single mode, isRecording=${macOSInterface.isRecording}, '
              'virtualSegments=${virtualSegments.length}, recordingStartTime=$recordingStartTime',
              name: 'VineRecordingController',
              category: LogCategory.system,
            );

            // Get the recording path from any available source
            final recordingPath = await _getMacOSRecordingPath(macOSInterface);
            if (recordingPath == null) {
              throw Exception(
                'No valid recording found for macOS single recording mode',
              );
            }

            File finalFile;

            // If we have virtual segments and a valid start time, extract only those portions
            if (virtualSegments.isNotEmpty && recordingStartTime != null) {
              Log.info(
                '📱 Extracting ${virtualSegments.length} virtual segments from continuous recording',
                name: 'VineRecordingController',
                category: LogCategory.system,
              );

              finalFile = await _extractMacOSSegments(
                recordingPath,
                virtualSegments,
                recordingStartTime,
              );
            } else {
              // Fallback: just apply aspect ratio crop (shouldn't normally happen)
              Log.warning(
                '📱 No virtual segments found, falling back to full video crop',
                name: 'VineRecordingController',
                category: LogCategory.system,
              );
              finalFile = await _applyAspectRatioCrop(recordingPath);
            }

            _setState(VineRecordingState.completed);
            macOSInterface.isSingleRecordingMode =
                false; // Clear flag after successful completion

            // Generate native ProofMode proof
            final nativeProof = await _generateNativeProof(finalFile);

            return (finalFile, nativeProof);
          }
        }

        // For non-single recording mode, stop any active recording
        if (_state == VineRecordingState.recording) {
          await stopRecording();
        }

        // For multi-segment recording, check virtual segments first
        if (!kIsWeb &&
            Platform.isMacOS &&
            _cameraInterface is MacOSCameraInterface) {
          final macOSInterface = _cameraInterface as MacOSCameraInterface;
          final virtualSegments = macOSInterface.getVirtualSegments();

          // If we have virtual segments but no main segments, use the virtual ones
          if (_segments.isEmpty && virtualSegments.isNotEmpty) {
            _segments.addAll(virtualSegments);
            Log.info(
              'Using ${virtualSegments.length} virtual segments from macOS recording',
              name: 'VineRecordingController',
              category: LogCategory.system,
            );
          }
        }

        Log.info(
          '📱 finishRecording: hasSegments=$hasSegments, segments count=${_segments.length}',
          name: 'VineRecordingController',
          category: LogCategory.system,
        );

        // Debug: Log all segment details
        for (int i = 0; i < _segments.length; i++) {
          final segment = _segments[i];
          Log.info(
            '📱 Segment $i: duration=${segment.duration.inMilliseconds}ms, filePath=${segment.filePath}',
            name: 'VineRecordingController',
            category: LogCategory.system,
          );
        }

        if (!hasSegments) {
          throw Exception('No valid video segments found for compilation');
        }

        // For web platform, handle blob URLs
        if (kIsWeb &&
            _segments.length == 1 &&
            _segments.first.filePath != null) {
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
                final tempFile = File(
                  '${tempDir.path}/web_recording_${DateTime.now().millisecondsSinceEpoch}.mp4',
                );
                await tempFile.writeAsBytes(bytes);

                _setState(VineRecordingState.completed);

                // Generate native ProofMode proof
                final nativeProof = await _generateNativeProof(tempFile);

                return (tempFile, nativeProof);
              }
            } catch (e) {
              Log.error(
                'Failed to convert blob to file: $e',
                name: 'VineRecordingController',
                category: LogCategory.system,
              );
            }
          }
        }

        // For other platforms (iOS, Android), handle single segment with aspect ratio crop
        if (!kIsWeb &&
            _segments.length == 1 &&
            _segments.first.filePath != null) {
          final file = File(_segments.first.filePath!);
          if (await file.exists()) {
            // Apply aspect ratio crop to the video
            final croppedFile = await _applyAspectRatioCrop(file.path);

            _setState(VineRecordingState.completed);

            // Generate native ProofMode proof
            final nativeProof = await _generateNativeProof(croppedFile);

            return (croppedFile, nativeProof);
          }
        }

        // Concatenate multiple segments using FFmpeg
        if (_segments.isNotEmpty) {
          Log.info(
            '📹 Concatenating ${_segments.length} segments using FFmpeg',
            name: 'VineRecordingController',
            category: LogCategory.system,
          );

          final concatenatedFile = await _concatenateSegments(_segments);
          if (concatenatedFile != null) {
            _setState(VineRecordingState.completed);

            // Generate native ProofMode proof
            final nativeProof = await _generateNativeProof(concatenatedFile);

            return (concatenatedFile, nativeProof);
          }
        }

        throw Exception('No valid video segments found for compilation');
      } catch (e) {
        _setState(VineRecordingState.error);
        Log.error(
          'Failed to finish recording: $e',
          name: 'VineRecordingController',
          category: LogCategory.system,
        );
        rethrow;
      }
    })();

    final endTime = DateTime.now();
    final duration = endTime.difference(startTime);

    Log.info(
      'finishRecording completed in ${duration.inMilliseconds}ms',
      name: 'VineRecordingController',
      category: LogCategory.system,
    );

    return returnValue;
  }

  /// Clean up recording files and prepare for new recording
  void cleanupFiles() {
    _cleanupRecordings();
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

    // Reset camera initialization flag if we're in error state
    if (wasInError) {
      _cameraInitialized = false;
    }

    // Reset state
    _setState(VineRecordingState.idle);

    // If was in error state and on web, reinitialize the camera
    if (wasInError && kIsWeb) {
      Log.error(
        'Reinitializing web camera after error...',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );
      if (_cameraInterface is WebCameraInterface) {
        final webInterface = _cameraInterface as WebCameraInterface;
        webInterface.dispose();
      }
      // Create new camera interface and initialize
      _cameraInterface = WebCameraInterface();
      initialize()
          .then((_) {
            Log.info(
              'Web camera reinitialized successfully',
              name: 'VineRecordingController',
              category: LogCategory.system,
            );
            _setState(VineRecordingState.idle);
          })
          .catchError((e) {
            Log.error(
              'Failed to reinitialize web camera: $e',
              name: 'VineRecordingController',
              category: LogCategory.system,
            );
            _setState(VineRecordingState.error);
          });
    }

    Log.debug(
      'Recording session reset',
      name: 'VineRecordingController',
      category: LogCategory.system,
    );
  }

  /// Clean up recording files and resources
  void _cleanupRecordings() {
    try {
      // Clean up platform-specific resources
      if (kIsWeb && _cameraInterface is WebCameraInterface) {
        _cleanupWebRecordings();
      } else if (!kIsWeb &&
          Platform.isMacOS &&
          _cameraInterface is MacOSCameraInterface) {
        _cleanupMacOSRecording();
      } else {
        _cleanupMobileRecordings();
      }

      Log.debug(
        '🧹 Cleaned up recording resources',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Error cleaning up recordings: $e',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );
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
            Log.error(
              'Error cleaning up blob URL: $e',
              name: 'VineRecordingController',
              category: LogCategory.system,
            );
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
          Log.debug(
            '🧹 Deleted macOS recording file: ${macOSInterface.currentRecordingPath}',
            name: 'VineRecordingController',
            category: LogCategory.system,
          );
        }
      } catch (e) {
        Log.error(
          'Error deleting macOS recording file: $e',
          name: 'VineRecordingController',
          category: LogCategory.system,
        );
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
            Log.debug(
              '🧹 Deleted mobile recording file: ${segment.filePath}',
              name: 'VineRecordingController',
              category: LogCategory.system,
            );
          }
        } catch (e) {
          Log.error(
            'Error deleting mobile recording file: $e',
            name: 'VineRecordingController',
            category: LogCategory.system,
          );
        }
      }
    }
  }

  /// Dispose resources
  void dispose() {
    _disposed = true;
    _stopProgressTimer();
    _stopMaxDurationTimer();

    // Clean up all recordings
    _cleanupRecordings();

    _cameraInterface?.dispose();
  }

  // Private methods

  void _setState(VineRecordingState newState) {
    if (_disposed) return;
    _state = newState;
    // Notify UI of state change
    _onStateChanged?.call();
  }

  void _startProgressTimer() {
    _stopProgressTimer();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!_disposed && _state == VineRecordingState.recording) {
        // Update the total duration based on current segment time
        if (_currentSegmentStartTime != null) {
          final currentSegmentDuration = DateTime.now().difference(
            _currentSegmentStartTime!,
          );

          Duration previousDuration;
          // On macOS, use virtual segments for accumulated duration since _segments is empty
          if (!kIsWeb &&
              Platform.isMacOS &&
              _cameraInterface is MacOSCameraInterface) {
            final macOSInterface = _cameraInterface as MacOSCameraInterface;
            final virtualSegments = macOSInterface.getVirtualSegments();
            previousDuration = virtualSegments.fold<Duration>(
              Duration.zero,
              (total, segment) => total + segment.duration,
            );
          } else {
            previousDuration = _segments.fold<Duration>(
              Duration.zero,
              (total, segment) => total + segment.duration,
            );
          }

          _totalRecordedDuration = previousDuration + currentSegmentDuration;
        }

        // Notify UI of progress update
        _onStateChanged?.call();
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
          Log.info(
            '📱 Recording completed - reached maximum duration',
            name: 'VineRecordingController',
            category: LogCategory.system,
          );

          // For macOS, handle auto-completion differently
          if (!kIsWeb &&
              Platform.isMacOS &&
              _cameraInterface is MacOSCameraInterface) {
            _handleMacOSAutoCompletion();
          } else {
            stopRecording();
          }
        }
      });
    }
  }

  /// Handle macOS recording auto-completion after max duration
  void _handleMacOSAutoCompletion() async {
    final macOSInterface = _cameraInterface as MacOSCameraInterface;

    // Stop the native recording first to get the file path
    final recordedPath = await macOSInterface.completeRecording();

    // Create a segment with the actual file path
    if (_currentSegmentStartTime != null && recordedPath != null) {
      final segmentEndTime = DateTime.now();
      final segmentDuration = segmentEndTime.difference(
        _currentSegmentStartTime!,
      );

      final segment = RecordingSegment(
        startTime: _currentSegmentStartTime!,
        endTime: segmentEndTime,
        duration: segmentDuration,
        filePath: recordedPath,
      );

      _segments.add(segment);
      _totalRecordedDuration += segmentDuration;

      Log.info(
        'Completed segment ${_segments.length} after auto-stop: ${segmentDuration.inMilliseconds}ms, path: $recordedPath',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );
    } else if (_currentSegmentStartTime == null) {
      Log.warning(
        'Cannot create segment - no start time recorded',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );
    } else if (recordedPath == null) {
      Log.error(
        'Cannot create segment - completeRecording returned null path',
        name: 'VineRecordingController',
        category: LogCategory.system,
      );
    }

    _currentSegmentStartTime = null;
    _stopProgressTimer();
    _stopMaxDurationTimer();

    // Set state to completed since we reached max duration
    _setState(VineRecordingState.completed);
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
