// ABOUTME: Pure universal camera screen using revolutionary Riverpod architecture
// ABOUTME: Cross-platform recording without VideoManager dependencies using pure providers

import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart' show FlashMode;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/audio_event.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:models/models.dart' as vine show AspectRatio;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/providers/vine_recording_provider.dart';
import 'package:openvine/screens/sounds_screen.dart';
import 'package:openvine/services/camera/camerawesome_mobile_camera_interface.dart';
import 'package:openvine/services/vine_recording_controller.dart'
    show ExtractedSegment;
import 'package:openvine/services/camera/enhanced_mobile_camera_interface.dart';
import 'package:openvine/services/camera/native_macos_camera.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/utils/video_controller_cleanup.dart';
import 'package:openvine/widgets/audio_waveform.dart';
import 'package:openvine/widgets/circular_icon_button.dart';
import 'package:openvine/widgets/dynamic_zoom_selector.dart';
import 'package:openvine/widgets/macos_camera_preview.dart'
    show CameraPreviewPlaceholder;
import 'package:permission_handler/permission_handler.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/services/video_thumbnail_service.dart';

/// Pure universal camera screen using revolutionary single-controller Riverpod architecture
class UniversalCameraScreenPure extends ConsumerStatefulWidget {
  const UniversalCameraScreenPure({super.key});

  @override
  ConsumerState<UniversalCameraScreenPure> createState() =>
      _UniversalCameraScreenPureState();
}

class _UniversalCameraScreenPureState
    extends ConsumerState<UniversalCameraScreenPure>
    with WidgetsBindingObserver {
  String? _errorMessage;
  bool _isProcessing = false;
  bool _permissionDenied = false;
  bool _isInitializing = false;

  // Camera control states
  FlashMode _flashMode = FlashMode.off;
  TimerDuration _timerDuration = TimerDuration.off;
  int? _countdownValue;

  // Track current device orientation for debugging
  DeviceOrientation? _currentOrientation;

  // Sound playback state for lip sync recording
  bool _headphonesConnected = false;
  bool _addVoiceEnabled = false;
  Duration _audioPosition = Duration.zero;
  Duration? _audioDuration;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;

  @override
  void initState() {
    super.initState();

    // Add app lifecycle observer to detect when user returns from Settings
    WidgetsBinding.instance.addObserver(this);

    // Log initial orientation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final orientation = MediaQuery.of(context).orientation;
      _currentOrientation = orientation == Orientation.portrait
          ? DeviceOrientation.portraitUp
          : DeviceOrientation.landscapeLeft;
      Log.info(
        '📱 [ORIENTATION] Camera screen initial orientation: $_currentOrientation, MediaQuery: $orientation',
        category: LogCategory.video,
      );
    });

    _initializeServices();

    // Check for headphone connection to enable voice recording toggle
    _checkHeadphoneConnection();

    // CRITICAL: Dispose all video controllers when entering camera screen
    // IndexedStack keeps widgets alive, so we must force-dispose controllers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        // Force dispose all video controllers (this also clears active video)
        disposeAllVideoControllers(ref);
        Log.info(
          '🗑️ UniversalCameraScreenPure: Disposed all video controllers',
          category: LogCategory.video,
        );
      } catch (e) {
        Log.warning(
          '📹 Failed to dispose video controllers: $e',
          category: LogCategory.video,
        );
      }
    });

    Log.info(
      '📹 UniversalCameraScreenPure: Initialized',
      category: LogCategory.video,
    );
  }

  @override
  void dispose() {
    // Remove app lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    // Clean up audio subscriptions
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();

    // Stop any playing audio when leaving camera screen
    _stopAudioPlayback();

    // Provider handles disposal automatically
    super.dispose();

    Log.info(
      '📹 UniversalCameraScreenPure: Disposed',
      category: LogCategory.video,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // When app resumes, re-check permissions in case user granted them in Settings
    if (state == AppLifecycleState.resumed && _permissionDenied) {
      Log.info(
        '📹 App resumed, re-checking permissions',
        category: LogCategory.video,
      );
      _recheckPermissions();
    }
  }

  /// Re-check permissions after returning from Settings
  Future<void> _recheckPermissions() async {
    try {
      if (Platform.isMacOS) {
        final hasPermission = await NativeMacOSCamera.hasPermission();
        if (hasPermission && mounted) {
          Log.info(
            '📹 macOS permission now granted, initializing camera',
            category: LogCategory.video,
          );
          setState(() {
            _permissionDenied = false;
          });
          await _initializeServices();
        }
      } else if (Platform.isIOS || Platform.isAndroid) {
        // iOS permission_handler has a known caching bug - status doesn't update after granting in Settings
        // Even calling .request() again returns the stale cached status
        // SOLUTION: Attempt camera initialization directly, bypassing permission_handler
        // The actual AVCaptureDevice will fail if permissions aren't granted
        Log.info(
          '📹 Bypassing permission_handler cache, attempting camera initialization',
          category: LogCategory.video,
        );

        setState(() {
          _permissionDenied = false;
        });

        // Try to initialize - if permissions really aren't granted, this will fail
        // and error handling will show permission screen again
        try {
          await ref.read(vineRecordingProvider.notifier).initialize();
          Log.info(
            '📹 Camera initialized successfully - permissions were granted',
            category: LogCategory.video,
          );
        } catch (e) {
          Log.error(
            '📹 Camera initialization failed: $e',
            category: LogCategory.video,
          );
          if (mounted) {
            // Check if it's a permission error
            final errorStr = e.toString().toLowerCase();
            if (errorStr.contains('permission') ||
                errorStr.contains('denied') ||
                errorStr.contains('authorized')) {
              Log.warning(
                '📹 Still no camera permissions - showing permission screen',
                category: LogCategory.video,
              );
              setState(() {
                _permissionDenied = true;
              });
            } else {
              // Some other error
              setState(() {
                _errorMessage = 'Failed to initialize camera: $e';
              });
            }
          }
        }
      }
    } catch (e) {
      Log.error(
        '📹 Failed to recheck permissions: $e',
        category: LogCategory.video,
      );
    }
  }

  Future<void> _initializeServices() async {
    // Mark as initializing to prevent double-initialization from build method
    _isInitializing = true;
    // Use Future.microtask to safely initialize after build completes
    // This ensures provider reads happen outside the build phase while still completing promptly
    Future.microtask(() => _performAsyncInitialization());
  }

  /// Perform async initialization after the first frame
  Future<void> _performAsyncInitialization() async {
    try {
      // Check if we're coming back to record more (ClipManager has existing clips)
      final clipManagerState = ref.read(clipManagerProvider);
      final existingDuration = clipManagerState.totalDuration;

      if (existingDuration > Duration.zero) {
        // Coming back to record more - don't reset, just set the offset
        Log.info(
          '📹 Recording more - existing clips: ${clipManagerState.clipCount}, duration: ${existingDuration.inMilliseconds}ms',
          category: LogCategory.video,
        );
        ref
            .read(vineRecordingProvider.notifier)
            .setPreviouslyRecordedDuration(existingDuration);
      } else {
        // Fresh start - clean up any old temp files and reset state
        ref.read(vineRecordingProvider.notifier).cleanupAndReset();
      }

      // Check platform and request permissions if needed
      if (Platform.isMacOS) {
        // macOS uses native platform channel
        Log.info(
          '📹 Checking macOS camera permission status',
          category: LogCategory.video,
        );

        final hasPermission = await NativeMacOSCamera.hasPermission();
        Log.info(
          '📹 macOS camera permission status: $hasPermission',
          category: LogCategory.video,
        );

        if (!hasPermission) {
          Log.info(
            '📹 Requesting macOS camera permission from user',
            category: LogCategory.video,
          );
          final granted = await NativeMacOSCamera.requestPermission();
          Log.info(
            '📹 macOS camera permission request result: $granted',
            category: LogCategory.video,
          );

          if (!granted) {
            Log.warning(
              '📹 macOS camera permission denied by user',
              category: LogCategory.video,
            );
            if (mounted) {
              setState(() {
                _permissionDenied = true;
              });
            }
            return;
          }

          Log.info(
            '📹 macOS camera permission granted, proceeding with initialization',
            category: LogCategory.video,
          );
        } else {
          Log.info(
            '📹 macOS camera permission already granted, proceeding with initialization',
            category: LogCategory.video,
          );
        }
      } else if (Platform.isIOS || Platform.isAndroid) {
        // iOS: permission_handler has caching issues - bypass it entirely
        // Try to initialize camera directly, let native AVFoundation check permissions
        Log.info(
          '📹 Bypassing permission_handler, attempting camera initialization directly',
          category: LogCategory.video,
        );

        try {
          // Initialize the recording service - will fail if permissions not granted
          await ref.read(vineRecordingProvider.notifier).initialize();
          Log.info(
            '📹 Recording service initialized successfully',
            category: LogCategory.video,
          );
          return; // Success - exit early
        } catch (e) {
          final errorStr = e.toString().toLowerCase();

          // Check if it's a permission error
          if (errorStr.contains('permission') ||
              errorStr.contains('denied') ||
              errorStr.contains('authorized')) {
            Log.info(
              '📹 Camera initialization failed due to permissions, requesting permissions',
              category: LogCategory.video,
            );

            // Request permissions
            final Map<Permission, PermissionStatus> statuses = await [
              Permission.camera,
              Permission.microphone,
            ].request();

            final cameraGranted =
                statuses[Permission.camera]?.isGranted ?? false;
            final microphoneGranted =
                statuses[Permission.microphone]?.isGranted ?? false;

            Log.info(
              '📹 Permission request results - Camera: $cameraGranted, Microphone: $microphoneGranted',
              category: LogCategory.video,
            );

            if (!cameraGranted || !microphoneGranted) {
              Log.warning(
                '📹 Permissions denied by user',
                category: LogCategory.video,
              );
              if (mounted) {
                setState(() {
                  _permissionDenied = true;
                });
              }
              return;
            }

            // Try initializing again after granting permissions
            try {
              await ref.read(vineRecordingProvider.notifier).initialize();
              Log.info(
                '📹 Recording service initialized after permission grant',
                category: LogCategory.video,
              );
              return;
            } catch (retryError) {
              Log.error(
                '📹 Failed to initialize even after granting permissions: $retryError',
                category: LogCategory.video,
              );
              if (mounted) {
                setState(() {
                  _errorMessage = 'Failed to initialize camera: $retryError';
                });
              }
              return;
            }
          } else {
            // Some other error
            Log.error(
              '📹 Camera initialization failed: $e',
              category: LogCategory.video,
            );
            if (mounted) {
              setState(() {
                _errorMessage = 'Failed to initialize camera: $e';
              });
            }
            return;
          }
        }
      }

      // macOS path continues here
      Log.info(
        '📹 Initializing recording service',
        category: LogCategory.video,
      );
      await ref.read(vineRecordingProvider.notifier).initialize();
      Log.info(
        '📹 Recording service initialized successfully',
        category: LogCategory.video,
      );
    } catch (e) {
      Log.error(
        '📹 UniversalCameraScreenPure: Failed to initialize recording: $e',
        category: LogCategory.video,
      );

      if (mounted) {
        // Check if it's a permission error
        final errorStr = e.toString();
        if (errorStr.contains('PERMISSION_DENIED') ||
            errorStr.contains('permission')) {
          setState(() {
            _permissionDenied = true;
          });
        } else {
          setState(() {
            _errorMessage = 'Failed to initialize camera: $e';
          });
        }
      }
    } finally {
      // Always reset the initializing flag
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      } else {
        _isInitializing = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Debug: Track orientation changes
    final mediaQueryOrientation = MediaQuery.of(context).orientation;
    final newOrientation = mediaQueryOrientation == Orientation.portrait
        ? DeviceOrientation.portraitUp
        : DeviceOrientation.landscapeLeft;

    if (_currentOrientation != newOrientation) {
      _currentOrientation = newOrientation;
      Log.warning(
        '📱 [ORIENTATION] Device orientation changed! MediaQuery: $mediaQueryOrientation, DeviceOrientation: $newOrientation',
        category: LogCategory.video,
      );
      Log.warning(
        '📱 [ORIENTATION] MediaQuery size: ${MediaQuery.of(context).size}',
        category: LogCategory.video,
      );
    }

    if (_permissionDenied) {
      return _buildPermissionScreen();
    }

    if (_errorMessage != null) {
      return _buildErrorScreen();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer(
        builder: (context, ref, child) {
          final recordingState = ref.watch(vineRecordingProvider);

          // Listen for auto-stop (when recording stops without user action)
          ref.listen<VineRecordingUIState>(vineRecordingProvider, (
            previous,
            next,
          ) {
            if (previous != null &&
                previous.isRecording &&
                !next.isRecording &&
                !_isProcessing) {
              // Recording stopped - check if it was max duration, manual stop, or error
              if (next.hasSegments) {
                // Check if this was an auto-stop due to max duration (remaining time ~0ms)
                // vs. manual segment stop (remaining time > 50ms)
                // With 6.3s max duration, timer should stop at exactly 0ms remaining
                if (next.remainingDuration.inMilliseconds < 50) {
                  // Has segments + virtually no remaining time = legitimate max duration auto-stop
                  Log.info(
                    '📹 Recording auto-stopped at max duration',
                    category: LogCategory.video,
                  );
                  _handleRecordingAutoStop();
                } else {
                  // Has segments + time remaining = manual segment stop (user released button)
                  Log.debug(
                    '📹 Manual segment stop (${next.remainingDuration.inMilliseconds}ms remaining)',
                    category: LogCategory.video,
                  );
                  // Don't show "max time reached" message for manual stops
                }
              }
            }
          });

          // Sync clip manager duration with recording provider
          // This ensures the progress bar updates when clips are deleted in ClipManager
          ref.listen<ClipManagerState>(clipManagerProvider, (previous, next) {
            if (previous != null &&
                previous.totalDuration != next.totalDuration) {
              Log.info(
                '📹 ClipManager duration changed: ${previous.totalDuration.inMilliseconds}ms → ${next.totalDuration.inMilliseconds}ms',
                category: LogCategory.video,
              );
              ref
                  .read(vineRecordingProvider.notifier)
                  .setPreviouslyRecordedDuration(next.totalDuration);
            }
          });

          if (recordingState.isError) {
            return _buildErrorScreen(recordingState.errorMessage);
          }

          // Show processing overlay if processing (even if camera not initialized)
          if (_isProcessing) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: VineTheme.vineGreen),
                  SizedBox(height: 16),
                  Text(
                    'Processing video...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          // Auto-reinitialize camera if it was released (e.g., after back navigation)
          if (!recordingState.isInitialized &&
              !_isInitializing &&
              !_permissionDenied) {
            // Trigger re-initialization in next microtask to avoid build phase issues
            _isInitializing = true;
            Future.microtask(() async {
              try {
                Log.info(
                  '📹 Camera not initialized, triggering re-initialization',
                  category: LogCategory.video,
                );
                await ref.read(vineRecordingProvider.notifier).initialize();
                if (mounted) {
                  setState(() {
                    _isInitializing = false;
                  });
                }
              } catch (e) {
                Log.error(
                  '📹 Failed to re-initialize camera: $e',
                  category: LogCategory.video,
                );
                if (mounted) {
                  setState(() {
                    _isInitializing = false;
                    _errorMessage = 'Failed to initialize camera: $e';
                  });
                }
              }
            });
          }

          if (!recordingState.isInitialized) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: VineTheme.vineGreen),
                  SizedBox(height: 16),
                  Text(
                    'Initializing camera...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            );
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              // Camera preview - EXACTLY matching experimental app structure
              if (recordingState.isInitialized)
                ref.read(vineRecordingProvider.notifier).previewWidget
              else
                CameraPreviewPlaceholder(
                  isRecording: recordingState.isRecording,
                ),

              // Tap-anywhere-to-record gesture detector (MUST be before top bar so bar receives taps)
              Positioned.fill(
                child: GestureDetector(
                  onTapDown: !kIsWeb && recordingState.canRecord
                      ? (_) => _startRecording()
                      : null,
                  onTapUp: !kIsWeb && recordingState.isRecording
                      ? (_) => _stopRecording()
                      : null,
                  onTapCancel: !kIsWeb && recordingState.isRecording
                      ? () => _stopRecording()
                      : null,
                  behavior: HitTestBehavior.translucent,
                  child: const SizedBox.expand(),
                ),
              ),

              // Top progress bar - Vine-style full width at top (AFTER gesture detector so buttons work)
              Positioned(
                top: MediaQuery.of(context).padding.top,
                left: 0,
                right: 0,
                child: _buildTopProgressBar(recordingState),
              ),

              // Square crop mask overlay (only shown in square mode)
              // Positioned OUTSIDE ClipRect so it's not clipped away
              if (recordingState.aspectRatio == vine.AspectRatio.square &&
                  recordingState.isInitialized)
                LayoutBuilder(
                  builder: (context, constraints) {
                    Log.info(
                      '🎭 Building square crop mask overlay',
                      name: 'UniversalCameraScreenPure',
                      category: LogCategory.video,
                    );

                    // Use screen dimensions, not camera preview dimensions
                    final screenWidth = constraints.maxWidth;
                    final screenHeight = constraints.maxHeight;
                    final squareSize =
                        screenWidth; // Square uses full screen width

                    Log.info(
                      '🎭 Mask dimensions: screenWidth=$screenWidth, screenHeight=$screenHeight, squareSize=$squareSize',
                      name: 'UniversalCameraScreenPure',
                      category: LogCategory.video,
                    );

                    return _buildSquareCropMaskForPreview(
                      screenWidth,
                      screenHeight,
                    );
                  },
                ),

              // Sound selection and waveform display (above zoom selector)
              Positioned(
                bottom: 200,
                left: 16,
                right: 16,
                child: _buildSoundSelectionUI(recordingState),
              ),

              // Dynamic zoom selector (above recording controls)
              if (recordingState.isInitialized && !recordingState.isRecording)
                Positioned(
                  bottom: 180,
                  left: 0,
                  right: 0,
                  child: _buildZoomSelector(),
                ),

              // Recording controls overlay (bottom)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                  child: _buildRecordingControls(recordingState),
                ),
              ),

              // Camera controls (right side, vertically centered)
              if (recordingState.isInitialized && !recordingState.isRecording)
                Positioned(
                  top: 0,
                  bottom: 180, // Above the bottom recording controls
                  right: 16,
                  child: Center(child: _buildCameraControls(recordingState)),
                ),

              // Countdown overlay
              if (_countdownValue != null)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.5),
                    child: Center(
                      child: Text(
                        _countdownValue.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 72,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),

              // Processing overlay
              if (_isProcessing)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.7),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: VineTheme.vineGreen),
                          SizedBox(height: 16),
                          Text(
                            'Processing video...',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPermissionScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: VineTheme.vineGreen,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Camera Permission',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_off, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              const Text(
                'Camera Permission Required',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Divine needs access to your camera to record videos. Please grant camera permission in System Settings.',
                style: TextStyle(color: Colors.grey, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _openSystemSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: VineTheme.vineGreen,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                icon: const Icon(Icons.settings),
                label: const Text('Open System Settings'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _tryRequestPermission,
                child: const Text(
                  'Try Again',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScreen([String? customMessage]) {
    final message = customMessage ?? _errorMessage ?? 'Unknown error occurred';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: VineTheme.vineGreen,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Camera Error',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Camera Error',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _retryInitialization,
                style: ElevatedButton.styleFrom(
                  backgroundColor: VineTheme.vineGreen,
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Vine-style top bar with X (close), progress bar, and > (publish) buttons
  Widget _buildTopProgressBar(VineRecordingUIState recordingState) {
    final progress = recordingState.progress;
    final hasSegments = recordingState.hasSegments;
    // Also check if ClipManager has existing clips (from previous recording sessions)
    final clipManagerState = ref.watch(clipManagerProvider);
    final hasExistingClips = clipManagerState.hasClips;
    final canProceed = hasSegments || hasExistingClips;

    return Container(
      height: 44, // Taller to accommodate buttons
      color: VineTheme.vineGreen,
      child: Row(
        children: [
          // X button (close/cancel) on the left - pops back to previous screen
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Log.info(
                '📹 X CANCEL - navigating away from camera',
                category: LogCategory.video,
              );
              // Try to pop if possible, otherwise go home
              // Camera can be reached via push (from FAB) or go (from ClipManager)
              final router = GoRouter.of(context);
              if (router.canPop()) {
                router.pop();
              } else {
                // No screen to pop to (navigated via go), go home instead
                context.goHome();
              }
            },
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              child: const Icon(Icons.close, color: Colors.white, size: 28),
            ),
          ),
          // Progress bar in the middle (takes remaining space)
          Expanded(
            child: Container(
              height: 24,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 50),
                    width: double.infinity,
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.5),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // > button (publish/proceed) on the right
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: canProceed
                ? () {
                    Log.info(
                      '📹 > PUBLISH BUTTON PRESSED (hasSegments=$hasSegments, hasExistingClips=$hasExistingClips)',
                      category: LogCategory.video,
                    );
                    if (hasSegments) {
                      // New segments recorded - process them
                      _finishRecording();
                    } else {
                      // Only existing clips - go directly to ClipManager
                      context.push('/clip-manager');
                    }
                  }
                : null,
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              child: Icon(
                Icons.chevron_right,
                color: canProceed
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.3),
                size: 32,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingControls(dynamic recordingState) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ProofMode indicator - HIDDEN (now shown in Settings -> ProofMode Info)

        // Platform-specific instruction hint (reserve space to prevent layout shift)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            (!recordingState.isRecording && !recordingState.hasSegments)
                ? (kIsWeb
                      ? 'Tap to record' // Web: single-shot
                      : 'Tap and hold anywhere to record') // Mobile: press-and-hold segments anywhere on screen
                : '', // Empty but reserves space
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
        ),

        // Show segment count on mobile with clear button (reserve space to prevent layout shift)
        if (!kIsWeb)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  recordingState.hasSegments
                      ? '${recordingState.segmentCount} ${recordingState.segmentCount == 1 ? "clip" : "clips"}'
                      : '', // Empty but reserves space
                  style: TextStyle(
                    color: VineTheme.vineGreen.withValues(alpha: 0.9),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // Clear/Reset button - appears when there are segments or clips
                if (recordingState.hasSegments ||
                    ref.watch(clipManagerProvider).hasClips)
                  Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: GestureDetector(
                      onTap: _showClearConfirmation,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.delete_outline,
                              color: Colors.red.withValues(alpha: 0.9),
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Clear',
                              style: TextStyle(
                                color: Colors.red.withValues(alpha: 0.9),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

        GestureDetector(
          onTap: kIsWeb ? _toggleRecordingWeb : null,
          onTapDown: !kIsWeb && recordingState.canRecord
              ? (_) => _startRecording()
              : null,
          onTapUp: !kIsWeb && recordingState.isRecording
              ? (_) => _stopRecording()
              : null,
          onTapCancel: !kIsWeb && recordingState.isRecording
              ? () => _stopRecording()
              : null,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: recordingState.isRecording ? Colors.red : Colors.white,
              border: Border.all(
                color: recordingState.isRecording ? Colors.white : Colors.grey,
                width: 4,
              ),
            ),
            child: recordingState.isRecording
                ? Center(
                    child: Text(
                      _formatDuration(recordingState.recordingDuration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.fiber_manual_record,
                    color: Colors.red,
                    size: 32,
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildCameraControls(VineRecordingUIState recordingState) {
    final cameraInterface = ref
        .read(vineRecordingProvider.notifier)
        .cameraInterface;
    // Check if front camera is active for either camera interface type
    final isFrontCamera =
        (cameraInterface is EnhancedMobileCameraInterface &&
            cameraInterface.isFrontCamera) ||
        (cameraInterface is CamerAwesomeMobileCameraInterface &&
            cameraInterface.isFrontCamera);

    final selectedSound = ref.watch(selectedSoundProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Add sound button at top (only show when no sound selected)
        if (selectedSound == null) ...[
          _buildAddSoundCircularButton(),
          const SizedBox(height: 12),
        ],
        // Camera switch button (front/back)
        if (recordingState.canSwitchCamera) ...[
          CircularIconButton(
            onPressed: _switchCamera,
            icon: const Icon(
              Icons.flip_camera_ios,
              color: Colors.white,
              size: 26,
            ),
            backgroundOpacity: 0.5,
          ),
          const SizedBox(height: 12),
        ],
        // Flash toggle (only show for rear camera - front cameras don't have flash)
        if (!isFrontCamera) ...[
          CircularIconButton(
            onPressed: _toggleFlash,
            icon: Icon(_getFlashIcon(), color: Colors.white, size: 26),
            backgroundOpacity: 0.5,
          ),
          const SizedBox(height: 12),
        ],
        // Timer toggle
        CircularIconButton(
          onPressed: _toggleTimer,
          icon: Icon(_getTimerIcon(), color: Colors.white, size: 26),
          backgroundOpacity: 0.5,
        ),
        const SizedBox(height: 12),
        // Aspect ratio toggle
        _buildAspectRatioToggle(recordingState),
        const SizedBox(height: 12),
        // Clips library button
        _buildClipsLibraryButton(),
      ],
    );
  }

  Widget _buildClipsLibraryButton() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: const Icon(Icons.video_library, color: Colors.white, size: 28),
        tooltip: 'View clips library',
        onPressed: () => context.push('/clips'),
      ),
    );
  }

  /// Circular add sound button for side controls
  Widget _buildAddSoundCircularButton() {
    return CircularIconButton(
      onPressed: _openSoundBrowser,
      icon: Icon(Icons.music_note, color: VineTheme.vineGreen, size: 26),
      backgroundOpacity: 0.5,
    );
  }

  /// Build sound selection UI - shows selected sound with waveform (add button is in side controls)
  Widget _buildSoundSelectionUI(VineRecordingUIState recordingState) {
    final selectedSound = ref.watch(selectedSoundProvider);

    // Only show when sound is selected (add button moved to side controls)
    if (selectedSound == null) {
      return const SizedBox.shrink();
    }

    // Show selected sound display with waveform
    return _buildSelectedSoundDisplay(selectedSound, recordingState);
  }

  /// Build the selected sound display with name, waveform, and controls
  Widget _buildSelectedSoundDisplay(
    AudioEvent sound,
    VineRecordingUIState recordingState,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: VineTheme.vineGreen.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sound name and remove button row
          Row(
            children: [
              Icon(Icons.music_note, color: VineTheme.vineGreen, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  sound.title ?? 'Untitled sound',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // Remove button (hide while recording)
              if (!recordingState.isRecording)
                GestureDetector(
                  onTap: _removeSelectedSound,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),

          // Audio waveform visualization
          AudioWaveform(
            isPlaying: recordingState.isRecording,
            position: _audioPosition,
            duration: _audioDuration,
            height: 40,
            color: VineTheme.vineGreen,
          ),

          // Add voice toggle (only shown when headphones connected)
          if (_headphonesConnected && !recordingState.isRecording) ...[
            const SizedBox(height: 8),
            _buildAddVoiceToggle(),
          ],
        ],
      ),
    );
  }

  /// Build the "Add your voice" toggle for mixing mic audio with selected sound
  Widget _buildAddVoiceToggle() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _addVoiceEnabled = !_addVoiceEnabled;
        });
        _updateMicrophoneState();
        Log.info(
          '🎤 Add voice toggled: $_addVoiceEnabled',
          category: LogCategory.video,
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _addVoiceEnabled
              ? VineTheme.vineGreen.withValues(alpha: 0.3)
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _addVoiceEnabled
                ? VineTheme.vineGreen
                : Colors.white.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _addVoiceEnabled ? Icons.mic : Icons.mic_off,
              color: _addVoiceEnabled ? VineTheme.vineGreen : Colors.grey,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              'Add your voice',
              style: TextStyle(
                color: _addVoiceEnabled ? Colors.white : Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Open the sound browser screen to select a sound
  Future<void> _openSoundBrowser() async {
    Log.info('🎵 Opening sound browser', category: LogCategory.video);

    AudioEvent? selectedSound;

    // Navigate to sounds screen with callback to capture selected sound
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => SoundsScreen(
          onSoundSelected: (sound) {
            selectedSound = sound;
            Navigator.of(context).pop();
          },
        ),
      ),
    );

    final sound = selectedSound;
    if (sound != null && mounted) {
      Log.info(
        '🎵 Sound selected: ${sound.title ?? "Untitled"}',
        category: LogCategory.video,
      );
      ref.read(selectedSoundProvider.notifier).select(sound);

      // Preload the audio for playback during recording
      await _preloadAudio(sound);
    }
  }

  /// Remove the currently selected sound
  void _removeSelectedSound() {
    Log.info('🎵 Removing selected sound', category: LogCategory.video);
    ref.read(selectedSoundProvider.notifier).clear();
    _stopAudioPlayback();
    setState(() {
      _audioPosition = Duration.zero;
      _audioDuration = null;
    });
  }

  /// Check if headphones are connected
  Future<void> _checkHeadphoneConnection() async {
    try {
      final audioService = ref.read(audioPlaybackServiceProvider);

      // Check initial state
      _headphonesConnected = audioService.areHeadphonesConnected;

      // Listen for device changes using AudioPlaybackService
      audioService.headphonesConnectedStream.listen((connected) {
        _updateHeadphoneState(connected);
      });

      Log.info(
        '🎧 Initial headphone state: $_headphonesConnected',
        category: LogCategory.video,
      );
    } catch (e) {
      Log.error(
        '🎧 Failed to check headphone connection: $e',
        category: LogCategory.video,
      );
    }
  }

  /// Update headphone connection state based on audio service
  void _updateHeadphoneState(bool connected) {
    final wasConnected = _headphonesConnected;
    _headphonesConnected = connected;

    if (wasConnected != _headphonesConnected && mounted) {
      setState(() {});

      // Disable voice recording when headphones disconnected
      if (!_headphonesConnected && _addVoiceEnabled) {
        _addVoiceEnabled = false;
        _updateMicrophoneState();
      }

      Log.info(
        '🎧 Headphone state changed: $_headphonesConnected',
        category: LogCategory.video,
      );
    }
  }

  /// Update microphone state based on sound selection and voice toggle
  void _updateMicrophoneState() {
    final selectedSound = ref.read(selectedSoundProvider);

    // If sound is selected and voice is not enabled, mute the mic
    // This prevents feedback when not using headphones
    if (selectedSound != null && !_addVoiceEnabled) {
      ref.read(vineRecordingProvider.notifier).setMicrophoneEnabled(false);
      Log.info(
        '🎤 Microphone disabled (sound selected, voice disabled)',
        category: LogCategory.video,
      );
    } else {
      ref.read(vineRecordingProvider.notifier).setMicrophoneEnabled(true);
      Log.info('🎤 Microphone enabled', category: LogCategory.video);
    }
  }

  /// Preload audio for playback during recording
  Future<void> _preloadAudio(AudioEvent sound) async {
    if (sound.url == null || sound.url!.isEmpty) {
      Log.warning(
        '🎵 Cannot preload audio - no URL available for sound: ${sound.title}',
        category: LogCategory.video,
      );
      return;
    }

    try {
      final audioService = ref.read(audioPlaybackServiceProvider);
      await audioService.loadAudio(sound.url!);

      // Subscribe to position updates for waveform
      _positionSubscription?.cancel();
      _positionSubscription = audioService.positionStream.listen((position) {
        if (mounted) {
          setState(() {
            _audioPosition = position;
          });
        }
      });

      // Subscribe to duration updates
      _durationSubscription?.cancel();
      _durationSubscription = audioService.durationStream.listen((duration) {
        if (mounted && duration != null) {
          setState(() {
            _audioDuration = duration;
          });
        }
      });

      Log.info('🎵 Audio preloaded: ${sound.url}', category: LogCategory.video);
    } catch (e) {
      Log.error('🎵 Failed to preload audio: $e', category: LogCategory.video);
    }
  }

  /// Start audio playback for lip sync recording
  ///
  /// Seeks to the cumulative recorded duration so that when recording
  /// multiple segments, the audio continues from where it left off.
  Future<void> _startAudioPlayback() async {
    final selectedSound = ref.read(selectedSoundProvider);
    if (selectedSound == null) return;

    try {
      final audioService = ref.read(audioPlaybackServiceProvider);

      // Configure audio session for recording mode (allows playback during video recording)
      await audioService.configureForRecording();

      // Get cumulative recorded duration to sync audio with video segments
      // This ensures audio continues from where previous segment ended
      final recordingState = ref.read(vineRecordingProvider);
      final cumulativeDuration = recordingState.totalRecordedDuration;

      // Seek to the cumulative position and start playback
      await audioService.seek(cumulativeDuration);
      await audioService.play();

      Log.info(
        '🎵 Audio playback started for lip sync at ${cumulativeDuration.inMilliseconds}ms',
        category: LogCategory.video,
      );
    } catch (e) {
      Log.error(
        '🎵 Failed to start audio playback: $e',
        category: LogCategory.video,
      );
    }
  }

  /// Stop audio playback
  Future<void> _stopAudioPlayback() async {
    try {
      final audioService = ref.read(audioPlaybackServiceProvider);
      await audioService.pause();

      // Reset audio session to default mode after recording
      await audioService.resetAudioSession();

      Log.info('🎵 Audio playback stopped', category: LogCategory.video);
    } catch (e) {
      Log.error(
        '🎵 Failed to stop audio playback: $e',
        category: LogCategory.video,
      );
    }
  }

  Widget _buildAspectRatioToggle(VineRecordingUIState recordingState) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(
          recordingState.aspectRatio == vine.AspectRatio.square
              ? Icons
                    .crop_square // Square icon for 1:1
              : Icons.crop_portrait, // Portrait icon for 9:16
          color: Colors.white,
          size: 28,
        ),
        onPressed: recordingState.isRecording
            ? null
            : () {
                final currentRatio = recordingState.aspectRatio;
                final newRatio =
                    recordingState.aspectRatio == vine.AspectRatio.square
                    ? vine.AspectRatio.vertical
                    : vine.AspectRatio.square;
                Log.info(
                  '🎭 Aspect ratio button pressed: $currentRatio -> $newRatio',
                  name: 'UniversalCameraScreenPure',
                  category: LogCategory.video,
                );
                ref
                    .read(vineRecordingProvider.notifier)
                    .setAspectRatio(newRatio);
              },
      ),
    );
  }

  /// Build dynamic zoom selector if using CamerAwesome
  Widget _buildZoomSelector() {
    final cameraInterface = ref
        .read(vineRecordingProvider.notifier)
        .getCameraInterface();

    // Only show zoom selector for CamerAwesome interface (iOS)
    if (cameraInterface is CamerAwesomeMobileCameraInterface) {
      return DynamicZoomSelector(cameraInterface: cameraInterface);
    }

    // No zoom selector for other camera interfaces
    return const SizedBox.shrink();
  }

  /// Build square crop mask overlay centered on screen
  /// Shows semi-transparent overlay outside the 1:1 square
  Widget _buildSquareCropMaskForPreview(
    double screenWidth,
    double screenHeight,
  ) {
    // Square uses full screen width
    final squareSize = screenWidth;

    // Calculate top/bottom areas to darken (centered vertically on screen)
    final topBottomHeight = (screenHeight - squareSize) / 2;

    return Stack(
      children: [
        // Top darkened area
        if (topBottomHeight > 0)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topBottomHeight,
            child: Container(color: Colors.black.withValues(alpha: 0.6)),
          ),

        // Bottom darkened area
        if (topBottomHeight > 0)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: topBottomHeight,
            child: Container(color: Colors.black.withValues(alpha: 0.6)),
          ),

        // Square frame outline (visual guide)
        Positioned(
          top: topBottomHeight > 0 ? topBottomHeight : 0,
          left: 0,
          width: squareSize,
          height: squareSize,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: VineTheme.vineGreen, width: 3),
            ),
          ),
        ),
      ],
    );
  }

  IconData _getFlashIcon() {
    switch (_flashMode) {
      case FlashMode.off:
        return Icons.flash_off;
      case FlashMode.torch:
        return Icons.flashlight_on;
      case FlashMode.auto:
      case FlashMode.always:
        return Icons.flash_on;
    }
  }

  IconData _getTimerIcon() {
    switch (_timerDuration) {
      case TimerDuration.off:
        return Icons.timer;
      case TimerDuration.threeSeconds:
        return Icons.timer_3;
      case TimerDuration.tenSeconds:
        return Icons.timer_10;
    }
  }

  /// Web-specific: Toggle recording on/off with tap
  Future<void> _toggleRecordingWeb() async {
    final state = ref.read(vineRecordingProvider);

    if (state.isRecording) {
      // Stop recording
      _finishRecording();
    } else if (state.canRecord) {
      // Start recording
      _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      // Handle timer countdown if enabled
      if (_timerDuration != TimerDuration.off) {
        await _startCountdownTimer();
      }

      // Update microphone state based on sound selection before starting
      final selectedSound = ref.read(selectedSoundProvider);
      if (selectedSound != null) {
        _updateMicrophoneState();
      }

      final notifier = ref.read(vineRecordingProvider.notifier);
      Log.info('📹 Starting recording segment', category: LogCategory.video);
      await notifier.startRecording();

      // Start audio playback for lip sync if sound is selected
      if (selectedSound != null) {
        await _startAudioPlayback();
      }
    } catch (e) {
      Log.error(
        '📹 UniversalCameraScreenPure: Start recording failed: $e',
        category: LogCategory.video,
      );

      _showErrorSnackBar('Recording failed: $e');
    }
  }

  Future<void> _startCountdownTimer() async {
    final duration = _timerDuration == TimerDuration.threeSeconds ? 3 : 10;

    for (int i = duration; i > 0; i--) {
      if (!mounted) return;

      setState(() {
        _countdownValue = i;
      });

      await Future.delayed(const Duration(seconds: 1));
    }

    if (mounted) {
      setState(() {
        _countdownValue = null;
      });
    }
  }

  void _stopRecording() async {
    // Just stop the current segment - don't finish the recording
    // This allows the user to record multiple segments before finalizing
    try {
      final notifier = ref.read(vineRecordingProvider.notifier);
      Log.info(
        '📹 Stopping recording segment (not finishing)',
        category: LogCategory.video,
      );
      await notifier.stopSegment();

      // Stop audio playback when segment ends
      await _stopAudioPlayback();

      Log.info(
        '📹 Segment stopped, user can record more or tap Publish to finish',
        category: LogCategory.video,
      );

      // Reset processing state - we're NOT processing yet, just paused between segments
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    } catch (e) {
      Log.error(
        '📹 UniversalCameraScreenPure: Stop segment failed: $e',
        category: LogCategory.video,
      );

      _showErrorSnackBar('Stop recording failed: $e');
    }
  }

  void _finishRecording() async {
    // Set processing state immediately so UI shows "Processing video..."
    // during the entire FFmpeg processing time
    if (_isProcessing) {
      Log.warning(
        '📹 Already processing a recording, ignoring duplicate finish call',
        category: LogCategory.video,
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final notifier = ref.read(vineRecordingProvider.notifier);
      Log.info(
        '📹 Extracting individual segments (without concatenating)',
        category: LogCategory.video,
      );

      // Extract individual segment files instead of concatenating
      final segmentFiles = await notifier.extractSegmentFiles();
      Log.info(
        '📹 Extracted ${segmentFiles.length} segment files',
        category: LogCategory.video,
      );

      if (segmentFiles.isNotEmpty && mounted) {
        _processSegments(segmentFiles);
      } else {
        Log.warning(
          '📹 No segments extracted from recording',
          category: LogCategory.video,
        );
        // Reset processing state since nothing to process
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
      }
    } catch (e) {
      Log.error(
        '📹 UniversalCameraScreenPure: Finish recording failed: $e',
        category: LogCategory.video,
      );

      // Reset processing state on error
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }

      _showErrorSnackBar('Finish recording failed: $e');
    }
  }

  void _switchCamera() async {
    Log.info(
      '🔄 _switchCamera() UI button pressed',
      name: 'UniversalCameraScreenPure',
      category: LogCategory.system,
    );

    try {
      Log.info(
        '🔄 Calling vineRecordingProvider.notifier.switchCamera()...',
        name: 'UniversalCameraScreenPure',
        category: LogCategory.system,
      );
      await ref.read(vineRecordingProvider.notifier).switchCamera();
      Log.info(
        '🔄 vineRecordingProvider.notifier.switchCamera() completed',
        name: 'UniversalCameraScreenPure',
        category: LogCategory.system,
      );

      // Force rebuild by calling setState
      Log.info(
        '🔄 Calling setState() to force UI rebuild',
        name: 'UniversalCameraScreenPure',
        category: LogCategory.system,
      );
      setState(() {});
      Log.info(
        '🔄 setState() completed',
        name: 'UniversalCameraScreenPure',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        '📹 UniversalCameraScreenPure: Camera switch failed: $e',
        category: LogCategory.video,
      );
    }
  }

  void _toggleFlash() {
    Log.info('🔦 Flash button tapped', category: LogCategory.video);

    final cameraInterface = ref
        .read(vineRecordingProvider.notifier)
        .cameraInterface;

    // Update local state to cycle through: off → torch (for video recording)
    // For video, we use torch mode (continuous light) instead of flash
    setState(() {
      switch (_flashMode) {
        case FlashMode.off:
          _flashMode = FlashMode.torch;
          break;
        case FlashMode.torch:
        case FlashMode.auto:
        case FlashMode.always:
          _flashMode = FlashMode.off;
          break;
      }
    });

    Log.info(
      '🔦 Flash mode toggled to: $_flashMode',
      category: LogCategory.video,
    );

    // Apply the new flash mode to camera - support both camera interfaces
    if (cameraInterface is EnhancedMobileCameraInterface) {
      cameraInterface.setFlashMode(_flashMode);
    } else if (cameraInterface is CamerAwesomeMobileCameraInterface) {
      cameraInterface.setFlashMode(_flashMode);
    } else {
      Log.warning(
        '🔦 Camera interface does not support flash control',
        category: LogCategory.video,
      );
    }
  }

  void _handleRecordingAutoStop() async {
    try {
      // Auto-stop just pauses the current segment
      // User must press publish button to finish and concatenate
      Log.info(
        '📹 Recording auto-stopped (max duration reached)',
        category: LogCategory.video,
      );

      _showSuccessSnackBar(
        'Maximum recording time reached. Press ✓ to publish.',
      );
    } catch (e) {
      Log.error(
        '📹 Failed to handle auto-stop: $e',
        category: LogCategory.video,
      );
    }
  }

  void _toggleTimer() {
    setState(() {
      switch (_timerDuration) {
        case TimerDuration.off:
          _timerDuration = TimerDuration.threeSeconds;
          break;
        case TimerDuration.threeSeconds:
          _timerDuration = TimerDuration.tenSeconds;
          break;
        case TimerDuration.tenSeconds:
          _timerDuration = TimerDuration.off;
          break;
      }
    });
    Log.info(
      '📹 Timer duration changed to: $_timerDuration',
      category: LogCategory.video,
    );
  }

  /// Process individual segment files and add each as a separate clip to ClipManager
  /// This allows users to reorder/delete segments before final concatenation at export
  void _processSegments(List<ExtractedSegment> segmentFiles) async {
    try {
      Log.info(
        '📹 Processing ${segmentFiles.length} segments as individual clips',
        category: LogCategory.video,
      );

      // Keep processing state while generating thumbnails
      final clipManager = ref.read(clipManagerProvider.notifier);

      for (var i = 0; i < segmentFiles.length; i++) {
        final segment = segmentFiles[i];

        // Generate thumbnail for this segment
        Log.info(
          '📹 Generating thumbnail for segment $i',
          category: LogCategory.video,
        );

        final thumbnailPath = await VideoThumbnailService.extractThumbnail(
          videoPath: segment.file.path,
          timeMs: VideoThumbnailService.getOptimalTimestamp(segment.duration),
        );

        clipManager.addClip(
          filePath: segment.file.path,
          duration: segment.duration,
          thumbnailPath: thumbnailPath,
          aspectRatio: segment.aspectRatio,
          needsCrop: segment.needsCrop,
        );

        Log.info(
          '📹 Added segment $i to ClipManager: ${segment.file.path}, '
          'duration: ${segment.duration.inMilliseconds}ms, '
          'needsCrop: ${segment.needsCrop}, '
          'aspectRatio: ${segment.aspectRatio?.name ?? "none"}, '
          'thumbnail: ${thumbnailPath ?? "none"}',
          category: LogCategory.video,
        );
      }

      Log.info(
        '📹 Added ${segmentFiles.length} clips to ClipManager',
        category: LogCategory.video,
      );

      // Clear segments from provider since they're now in ClipManager
      // This prevents duplicate processing when user navigates back
      ref.read(vineRecordingProvider.notifier).clearSegments();

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        // Navigate to ClipManager screen
        context.push('/clip-manager');

        Log.info('📹 Navigated to clip-manager', category: LogCategory.video);
      }
    } catch (e) {
      Log.error(
        '📹 UniversalCameraScreenPure: Processing segments failed: $e',
        category: LogCategory.video,
      );

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        _showErrorSnackBar('Processing failed: $e');
      }
    }
  }

  void _retryInitialization() async {
    setState(() {
      _errorMessage = null;
      _permissionDenied = false;
    });

    await _initializeServices();
  }

  void _tryRequestPermission() async {
    try {
      Log.info('📹 Requesting camera permission', category: LogCategory.video);

      bool granted = false;

      // Platform-specific permission request
      if (Platform.isMacOS) {
        granted = await NativeMacOSCamera.requestPermission();
      } else if (Platform.isIOS || Platform.isAndroid) {
        // Check current status first
        final cameraStatus = await Permission.camera.status;
        final microphoneStatus = await Permission.microphone.status;

        // On iOS, if permission was previously denied, .request() won't show a dialog
        // We need to check for permanentlyDenied and direct user to Settings
        if (cameraStatus.isPermanentlyDenied ||
            microphoneStatus.isPermanentlyDenied) {
          Log.warning(
            '📹 Permissions permanently denied, opening Settings',
            category: LogCategory.video,
          );
          _openSystemSettings();
          return;
        }

        // Try to request permissions
        final Map<Permission, PermissionStatus> statuses = await [
          Permission.camera,
          Permission.microphone,
        ].request();

        final cameraGranted = statuses[Permission.camera]?.isGranted ?? false;
        final microphoneGranted =
            statuses[Permission.microphone]?.isGranted ?? false;

        granted = cameraGranted && microphoneGranted;

        Log.info(
          '📹 Permission request results - Camera: $cameraGranted, Microphone: $microphoneGranted',
          category: LogCategory.video,
        );

        // If still denied, it might be permanently denied now - guide to Settings
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Please grant camera and microphone permissions in Settings to record videos.',
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }
      }

      if (granted) {
        Log.info(
          '📹 Permission granted, initializing camera',
          category: LogCategory.video,
        );
        setState(() {
          _permissionDenied = false;
        });
        await _initializeServices();
      }
    } catch (e) {
      Log.error(
        '📹 Failed to request permission: $e',
        category: LogCategory.video,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to request permission: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openSystemSettings() async {
    try {
      // Use permission_handler's built-in method to open app settings
      // This works across all platforms (iOS, Android, macOS)
      final opened = await openAppSettings();

      if (!opened) {
        Log.warning('Failed to open app settings', category: LogCategory.video);
      } else {
        Log.info(
          'Opened app settings successfully',
          category: LogCategory.video,
        );
      }
    } catch (e) {
      Log.error(
        '📹 Failed to open system settings: $e',
        category: LogCategory.video,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please open System Settings manually and grant camera permission to Divine.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '$twoDigitMinutes:$twoDigitSeconds';
  }

  /// Show error snackbar at top of screen to avoid blocking controls
  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 150,
          left: 10,
          right: 10,
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Show success snackbar at top of screen
  void _showSuccessSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: VineTheme.vineGreen,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 150,
          left: 10,
          right: 10,
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Show confirmation dialog before clearing all segments and clips
  void _showClearConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Clear Recording?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will delete all recorded segments and clips. This action cannot be undone.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _clearAllRecordings();
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  /// Clear all segments from vineRecordingProvider and clips from ClipManager
  Future<void> _clearAllRecordings() async {
    try {
      Log.info(
        '📹 Clearing all recordings and clips',
        category: LogCategory.video,
      );

      // Clear clips from ClipManager
      ref.read(clipManagerProvider.notifier).clearAll();

      // Clear selected sound from lip sync flow
      ref.read(selectedSoundProvider.notifier).clear();

      // Clean up temp files and reset vineRecordingProvider
      await ref.read(vineRecordingProvider.notifier).cleanupAndReset();

      Log.info(
        '📹 All recordings and clips cleared',
        category: LogCategory.video,
      );

      _showSuccessSnackBar('All recordings cleared');
    } catch (e) {
      Log.error(
        '📹 Failed to clear recordings: $e',
        category: LogCategory.video,
      );
      _showErrorSnackBar('Failed to clear recordings: $e');
    }
  }
}

/// Timer duration options for delayed recording
enum TimerDuration { off, threeSeconds, tenSeconds }
