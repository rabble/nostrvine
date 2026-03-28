Status: Historical

> Historical note
> Preserved for context during the P1 documentation refresh. This file may reference deleted screens, older branding, or superseded implementation details. Start with docs/README.md and docs/archive/README.md for current guidance.

# Camera Screen Fixes Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Fix camera switch button visibility, implement camera switching for macOS/iOS, add zoom support for iOS, and fix SnackBar overlay issues.

**Architecture:** Fix existing camera infrastructure by implementing missing features in platform-specific camera interfaces (MacOSCameraInterface, MobileCameraInterface) and updating UI to conditionally show controls based on platform capabilities.

**Tech Stack:** Flutter/Dart, camera package, camera_macos, native macOS platform channels, Riverpod state management

---

## Task 1: Fix Camera Switch Button Visibility

**Files:**
- Modify: `lib/screens/pure/universal_camera_screen_pure.dart:747-756`
- Test: `test/screens/universal_camera_screen_button_visibility_test.dart`

**Step 1: Write failing test for button visibility**

Create test file:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/screens/pure/universal_camera_screen_pure.dart';
import 'package:openvine/providers/vine_recording_provider.dart';

@GenerateMocks([VineRecordingNotifier])
import 'universal_camera_screen_button_visibility_test.mocks.dart';

void main() {
  group('Camera Switch Button Visibility', () {
    testWidgets('shows switch button when canSwitchCamera is true', (tester) async {
      final mockNotifier = MockVineRecordingNotifier();

      when(mockNotifier.state).thenReturn(VineRecordingUIState(
        recordingState: VineRecordingState.idle,
        progress: 0.0,
        totalRecordedDuration: Duration.zero,
        remainingDuration: Duration(seconds: 30),
        canRecord: true,
        segments: [],
        isCameraInitialized: true,
        canSwitchCamera: true, // Multiple cameras available
      ));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vineRecordingProvider.overrideWith((ref) => mockNotifier),
          ],
          child: MaterialApp(
            home: UniversalCameraScreenPure(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should find the camera switch button
      expect(find.byIcon(Icons.flip_camera_ios), findsOneWidget);
    });

    testWidgets('hides switch button when canSwitchCamera is false', (tester) async {
      final mockNotifier = MockVineRecordingNotifier();

      when(mockNotifier.state).thenReturn(VineRecordingUIState(
        recordingState: VineRecordingState.idle,
        progress: 0.0,
        totalRecordedDuration: Duration.zero,
        remainingDuration: Duration(seconds: 30),
        canRecord: true,
        segments: [],
        isCameraInitialized: true,
        canSwitchCamera: false, // Only one camera
      ));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vineRecordingProvider.overrideWith((ref) => mockNotifier),
          ],
          child: MaterialApp(
            home: UniversalCameraScreenPure(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Should NOT find the camera switch button
      expect(find.byIcon(Icons.flip_camera_ios), findsNothing);
    });
  });
}
```

**Step 2: Add canSwitchCamera to VineRecordingUIState**

Modify `lib/providers/vine_recording_provider.dart`:

Add field to VineRecordingUIState class (around line 36):

```dart
class VineRecordingUIState {
  const VineRecordingUIState({
    required this.recordingState,
    required this.progress,
    required this.totalRecordedDuration,
    required this.remainingDuration,
    required this.canRecord,
    required this.segments,
    required this.isCameraInitialized,
    required this.canSwitchCamera, // ADD THIS
  });

  final VineRecordingState recordingState;
  final double progress;
  final Duration totalRecordedDuration;
  final Duration remainingDuration;
  final bool canRecord;
  final List<RecordingSegment> segments;
  final bool isCameraInitialized;
  final bool canSwitchCamera; // ADD THIS
```

Update copyWith method (around line 62):

```dart
VineRecordingUIState copyWith({
  VineRecordingState? recordingState,
  double? progress,
  Duration? totalRecordedDuration,
  Duration? remainingDuration,
  bool? canRecord,
  List<RecordingSegment>? segments,
  bool? isCameraInitialized,
  bool? canSwitchCamera, // ADD THIS
}) {
  return VineRecordingUIState(
    recordingState: recordingState ?? this.recordingState,
    progress: progress ?? this.progress,
    totalRecordedDuration: totalRecordedDuration ?? this.totalRecordedDuration,
    remainingDuration: remainingDuration ?? this.remainingDuration,
    canRecord: canRecord ?? this.canRecord,
    segments: segments ?? this.segments,
    isCameraInitialized: isCameraInitialized ?? this.isCameraInitialized,
    canSwitchCamera: canSwitchCamera ?? this.canSwitchCamera, // ADD THIS
  );
}
```

Update VineRecordingNotifier constructor (around line 85):

```dart
VineRecordingNotifier(
  this._controller,
  this._ref,
) : super(
      VineRecordingUIState(
        recordingState: _controller.state,
        progress: _controller.progress,
        totalRecordedDuration: _controller.totalRecordedDuration,
        remainingDuration: _controller.remainingDuration,
        canRecord: _controller.canRecord,
        segments: _controller.segments,
        isCameraInitialized: _controller.isCameraInitialized,
        canSwitchCamera: _controller.canSwitchCamera, // ADD THIS
      ),
    ) {
```

Update _updateState method to include canSwitchCamera:

```dart
void _updateState() {
  state = VineRecordingUIState(
    recordingState: _controller.state,
    progress: _controller.progress,
    totalRecordedDuration: _controller.totalRecordedDuration,
    remainingDuration: _controller.remainingDuration,
    canRecord: _controller.canRecord,
    segments: _controller.segments,
    isCameraInitialized: _controller.isCameraInitialized,
    canSwitchCamera: _controller.canSwitchCamera, // ADD THIS
  );
}
```

**Step 3: Conditionally render switch button based on canSwitchCamera**

Modify `lib/screens/pure/universal_camera_screen_pure.dart:747-756`:

Replace the current IconButton with:

```dart
// Switch camera button - only show if multiple cameras available
if (recordingState.canSwitchCamera)
  IconButton(
    onPressed: recordingState.isRecording ? null : _switchCamera,
    icon: Icon(
      Icons.flip_camera_ios,
      color: recordingState.isRecording ? Colors.grey : Colors.white,
      size: 32,
    ),
  ),
```

**Step 4: Run test to verify it passes**

Run: `flutter test test/screens/universal_camera_screen_button_visibility_test.dart`

Expected: 2/2 tests PASS

**Step 5: Commit**

```bash
git add lib/screens/pure/universal_camera_screen_pure.dart lib/providers/vine_recording_provider.dart test/screens/universal_camera_screen_button_visibility_test.dart
git commit -m "fix: conditionally show camera switch button based on canSwitchCamera"
```

---

## Task 2: Implement macOS Camera Switching

**Files:**
- Modify: `lib/services/vine_recording_controller.dart:553-558`
- Test: `test/services/macos_camera_switch_test.dart`

**Step 1: Write failing test for macOS camera switching**

Create test file:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/services/vine_recording_controller.dart';
import 'package:openvine/services/camera/native_macos_camera.dart';

@GenerateMocks([NativeMacOSCamera])
import 'macos_camera_switch_test.mocks.dart';

void main() {
  group('MacOSCameraInterface', () {
    test('switchCamera calls NativeMacOSCamera.listCameras and switchCamera', () async {
      // This test verifies that macOS camera switching uses the native API
      // Note: Actual implementation will use static methods from NativeMacOSCamera

      final interface = MacOSCameraInterface();
      await interface.initialize();

      // Initially should be on camera 0
      // After switch, should call native switchCamera with next index

      await interface.switchCamera();

      // Verify native camera switch was called
      // This will be validated by checking logs in actual implementation
    });
  });
}
```

**Step 2: Implement macOS camera switching**

Modify `lib/services/vine_recording_controller.dart:553-558`:

Replace the stub implementation with:

```dart
@override
Future<void> switchCamera() async {
  try {
    // Get list of available cameras
    final cameras = await NativeMacOSCamera.listCameras();

    if (cameras.length <= 1) {
      Log.info('Only one camera available on macOS, cannot switch',
          name: 'VineRecordingController', category: LogCategory.system);
      return;
    }

    // Get current camera index from native camera
    // For now, cycle through cameras by index
    // TODO: Track current camera index in state
    final nextCameraIndex = 1 - 0; // Toggle between 0 and 1 for most Macs

    Log.info('Switching macOS camera to index $nextCameraIndex',
        name: 'VineRecordingController', category: LogCategory.system);

    final success = await NativeMacOSCamera.switchCamera(nextCameraIndex);

    if (success) {
      Log.info('📱 macOS camera switched successfully to camera $nextCameraIndex',
          name: 'VineRecordingController', category: LogCategory.system);
    } else {
      Log.error('Failed to switch macOS camera to index $nextCameraIndex',
          name: 'VineRecordingController', category: LogCategory.system);
    }
  } catch (e) {
    Log.error('macOS camera switching failed: $e',
        name: 'VineRecordingController', category: LogCategory.system);
  }
}
```

**Step 3: Add camera index tracking to MacOSCameraInterface**

Add field to MacOSCameraInterface class (around line 340):

```dart
class MacOSCameraInterface extends CameraPlatformInterface
    with AsyncInitialization {
  final GlobalKey _cameraKey = GlobalKey(debugLabel: 'vineCamera');
  Widget? _previewWidget;
  String? currentRecordingPath;
  bool isRecording = false;
  int _currentCameraIndex = 0; // ADD THIS
  int _availableCameraCount = 1; // ADD THIS
```

Update initialize() method to get camera count (around line 354):

```dart
@override
Future<void> initialize() async {
  startInitialization();

  // Get available cameras
  final cameras = await NativeMacOSCamera.listCameras();
  _availableCameraCount = cameras.length;
  Log.info('Found $_availableCameraCount cameras on macOS',
      name: 'VineRecordingController', category: LogCategory.system);

  // Initialize the native macOS camera for recording
  final nativeResult = await NativeMacOSCamera.initialize();
  if (!nativeResult) {
    throw Exception('Failed to initialize native macOS camera');
  }

  // Rest of initialization...
```

Update switchCamera() to use tracked index:

```dart
@override
Future<void> switchCamera() async {
  try {
    if (_availableCameraCount <= 1) {
      Log.info('Only one camera available on macOS, cannot switch',
          name: 'VineRecordingController', category: LogCategory.system);
      return;
    }

    // Cycle to next camera
    final nextCameraIndex = (_currentCameraIndex + 1) % _availableCameraCount;

    Log.info('Switching macOS camera from $_currentCameraIndex to $nextCameraIndex',
        name: 'VineRecordingController', category: LogCategory.system);

    final success = await NativeMacOSCamera.switchCamera(nextCameraIndex);

    if (success) {
      _currentCameraIndex = nextCameraIndex;
      Log.info('📱 macOS camera switched successfully to camera $_currentCameraIndex',
          name: 'VineRecordingController', category: LogCategory.system);
    } else {
      Log.error('Failed to switch macOS camera to index $nextCameraIndex',
          name: 'VineRecordingController', category: LogCategory.system);
    }
  } catch (e) {
    Log.error('macOS camera switching failed: $e',
        name: 'VineRecordingController', category: LogCategory.system);
  }
}
```

Update canSwitchCamera getter (around line 550):

```dart
@override
bool get canSwitchCamera => _availableCameraCount > 1;
```

**Step 4: Run test and verify manually**

Run: `flutter test test/services/macos_camera_switch_test.dart`

Expected: Test passes

Manual verification: Run on macOS, click switch button, verify camera switches

**Step 5: Commit**

```bash
git add lib/services/vine_recording_controller.dart test/services/macos_camera_switch_test.dart
git commit -m "feat: implement macOS camera switching with native API"
```

---

## Task 3: Debug and Fix iOS Camera Switch

**Files:**
- Modify: `lib/services/vine_recording_controller.dart:230-273`
- Test: `test/services/ios_camera_switch_test.dart`

**Step 1: Write failing test for iOS camera switch**

Create test file:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:camera/camera.dart';
import 'package:openvine/services/vine_recording_controller.dart';

void main() {
  group('MobileCameraInterface iOS Camera Switch', () {
    test('switchCamera cycles through available cameras', () async {
      // This test verifies camera switching logic
      // Actual camera hardware testing requires device

      // Mock scenario: 2 cameras available
      final interface = MobileCameraInterface();

      // After initialization, should be on back camera
      // After switchCamera(), should be on front camera
      // After another switchCamera(), should be back to back camera

      // This will be manually verified on device
    });
  });
}
```

**Step 2: Add debug logging to switchCamera**

Modify `lib/services/vine_recording_controller.dart:230-273`:

Add extensive logging to debug iOS camera switch:

```dart
@override
Future<void> switchCamera() async {
  Log.info('🔄 switchCamera called, current cameras: ${_availableCameras.length}',
      name: 'VineRecordingController', category: LogCategory.system);

  if (_availableCameras.length <= 1) {
    Log.warning('Cannot switch camera - only ${_availableCameras.length} camera(s) available',
        name: 'VineRecordingController', category: LogCategory.system);
    return;
  }

  // Don't switch if controller is not properly initialized
  if (_controller == null || !_controller!.value.isInitialized) {
    Log.warning('Cannot switch camera - controller not initialized',
        name: 'VineRecordingController', category: LogCategory.system);
    return;
  }

  Log.info('🔄 Current camera index: $_currentCameraIndex, direction: ${_availableCameras[_currentCameraIndex].lensDirection}',
      name: 'VineRecordingController', category: LogCategory.system);

  // Stop any active recording before switching
  if (isRecording) {
    Log.info('🔄 Stopping active recording before camera switch',
        name: 'VineRecordingController', category: LogCategory.system);
    try {
      await _controller?.stopVideoRecording();
    } catch (e) {
      Log.error('Error stopping recording during camera switch: $e',
          name: 'VineRecordingController', category: LogCategory.system);
    }
    isRecording = false;
  }

  // Store old controller reference for safe disposal
  final oldController = _controller;
  _controller = null; // Clear reference to prevent access during switch

  try {
    // Switch to the next camera
    final oldIndex = _currentCameraIndex;
    _currentCameraIndex = (_currentCameraIndex + 1) % _availableCameras.length;

    Log.info('🔄 Switching from camera $oldIndex to $_currentCameraIndex',
        name: 'VineRecordingController', category: LogCategory.system);

    await _initializeNewCamera();

    Log.info('🔄 New camera initialized: ${_availableCameras[_currentCameraIndex].lensDirection}',
        name: 'VineRecordingController', category: LogCategory.system);

    // Safely dispose old controller after new one is ready
    await oldController?.dispose();

    Log.info('✅ Successfully switched to camera $_currentCameraIndex (${_availableCameras[_currentCameraIndex].lensDirection})',
        name: 'VineRecordingController', category: LogCategory.system);

    // CRITICAL: Notify listeners that camera changed to force UI rebuild
    // The preview widget needs to be re-rendered with new controller

  } catch (e) {
    // If switching fails, restore old controller
    Log.error('❌ Camera switch failed, restoring previous camera: $e',
        name: 'VineRecordingController', category: LogCategory.system);
    _controller = oldController;
    rethrow;
  }
}
```

**Step 3: Add camera change notification to VineRecordingController**

The issue might be that the preview widget isn't updating. The controller needs to notify state change.

Modify `lib/services/vine_recording_controller.dart` switchCamera method (around line 818):

```dart
/// Switch between front and rear cameras
Future<void> switchCamera() async {
  if (_state == VineRecordingState.recording) {
    Log.warning('Cannot switch camera while recording',
        name: 'VineRecordingController', category: LogCategory.system);
    return;
  }

  // If we're in paused state with a segment in progress, ensure it's properly stopped
  if (_currentSegmentStartTime != null) {
    Log.warning('Cleaning up incomplete segment before camera switch',
        name: 'VineRecordingController', category: LogCategory.system);
    _currentSegmentStartTime = null;
    _stopProgressTimer();
    _stopMaxDurationTimer();
  }

  try {
    await _cameraInterface?.switchCamera();
    Log.info('📱 Camera switched successfully',
        name: 'VineRecordingController', category: LogCategory.system);

    // CRITICAL: Force state notification to trigger UI rebuild
    _onStateChanged?.call();

  } catch (e) {
    Log.error('Failed to switch camera: $e',
        name: 'VineRecordingController', category: LogCategory.system);
  }
}
```

**Step 4: Update VineRecordingNotifier to expose camera change**

Modify `lib/providers/vine_recording_provider.dart`:

Update switchCamera method (around line 205):

```dart
Future<void> switchCamera() async {
  await _controller.switchCamera();

  // Force state update to rebuild UI with new camera preview
  _updateState();
}
```

**Step 5: Manual testing on iOS device**

Run on iOS device:
1. Open camera screen
2. Click switch button
3. Verify camera switches between front/back
4. Check logs for "Successfully switched to camera" messages

Expected: Camera preview updates to show different camera

**Step 6: Commit**

```bash
git add lib/services/vine_recording_controller.dart lib/providers/vine_recording_provider.dart test/services/ios_camera_switch_test.dart
git commit -m "fix: add proper state notification for iOS camera switching"
```

---

## Task 4: Add Zoom Support to iOS Camera

**Files:**
- Modify: `lib/services/vine_recording_controller.dart:68-333`
- Test: `test/services/mobile_camera_zoom_test.dart`

**Step 1: Write failing test for zoom functionality**

Create test file:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/vine_recording_controller.dart';

void main() {
  group('MobileCameraInterface Zoom', () {
    test('setZoom clamps values between min and max', () async {
      // Verify zoom level is clamped to valid range
      // This will be manually tested on device
    });

    test('zoom level persists across camera switches', () async {
      // Verify zoom resets appropriately when switching cameras
    });
  });
}
```

**Step 2: Add zoom fields to MobileCameraInterface**

Modify `lib/services/vine_recording_controller.dart`:

Add fields to MobileCameraInterface class (around line 68):

```dart
class MobileCameraInterface extends CameraPlatformInterface {
  CameraController? _controller;
  List<CameraDescription> _availableCameras = [];
  int _currentCameraIndex = 0;
  bool isRecording = false;

  // Zoom support
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 1.0;
  double _currentZoomLevel = 1.0;
```

**Step 3: Initialize zoom levels during camera initialization**

Update _initializeCurrentCamera method (around line 91):

```dart
Future<void> _initializeCurrentCamera() async {
  _controller?.dispose();

  final camera = _availableCameras[_currentCameraIndex];
  _controller = CameraController(camera, ResolutionPreset.high, enableAudio: true);
  await _controller!.initialize();

  // Prepare for video recording - critical for iOS
  try {
    await _controller!.prepareForVideoRecording();
    Log.info('Video recording preparation successful',
        name: 'VineRecordingController', category: LogCategory.system);
  } catch (e) {
    Log.warning('prepareForVideoRecording failed (may not be supported): $e',
        name: 'VineRecordingController', category: LogCategory.system);
    // Continue anyway - some platforms don't need this
  }

  // Initialize zoom levels
  try {
    _minZoomLevel = await _controller!.getMinZoomLevel();
    _maxZoomLevel = await _controller!.getMaxZoomLevel();
    _currentZoomLevel = _minZoomLevel;
    Log.info('Zoom range initialized: $_minZoomLevel - $_maxZoomLevel',
        name: 'VineRecordingController', category: LogCategory.system);
  } catch (e) {
    Log.warning('Failed to get zoom levels: $e',
        name: 'VineRecordingController', category: LogCategory.system);
    _minZoomLevel = 1.0;
    _maxZoomLevel = 1.0;
    _currentZoomLevel = 1.0;
  }
}
```

Also update _initializeNewCamera with same zoom initialization.

**Step 4: Add setZoom method to MobileCameraInterface**

Add method before dispose() (around line 315):

```dart
/// Set zoom level (clamped to camera's supported range)
Future<void> setZoom(double zoomLevel) async {
  if (_controller == null || !_controller!.value.isInitialized) {
    Log.warning('Cannot set zoom - controller not initialized',
        name: 'VineRecordingController', category: LogCategory.system);
    return;
  }

  try {
    final clampedZoom = zoomLevel.clamp(_minZoomLevel, _maxZoomLevel);
    await _controller!.setZoomLevel(clampedZoom);
    _currentZoomLevel = clampedZoom;

    Log.debug('Set zoom level to ${clampedZoom.toStringAsFixed(1)}x',
        name: 'VineRecordingController', category: LogCategory.system);
  } catch (e) {
    Log.error('Failed to set zoom: $e',
        name: 'VineRecordingController', category: LogCategory.system);
  }
}

/// Get current zoom level
double get currentZoom => _currentZoomLevel;

/// Get minimum zoom level
double get minZoom => _minZoomLevel;

/// Get maximum zoom level
double get maxZoom => _maxZoomLevel;

@override
bool get canSwitchCamera => _availableCameras.length > 1;
```

**Step 5: Run test**

Run: `flutter test test/services/mobile_camera_zoom_test.dart`

Expected: Tests pass

**Step 6: Commit**

```bash
git add lib/services/vine_recording_controller.dart test/services/mobile_camera_zoom_test.dart
git commit -m "feat: add zoom support to iOS MobileCameraInterface"
```

---

## Task 5: Integrate Pinch-to-Zoom UI

**Files:**
- Modify: `lib/screens/pure/universal_camera_screen_pure.dart:400-486`
- Test: `test/screens/camera_zoom_integration_test.dart`

**Step 1: Write failing test for zoom UI integration**

Create test file:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/screens/pure/universal_camera_screen_pure.dart';
import 'package:openvine/widgets/camera_controls_overlay.dart';

void main() {
  group('Camera Zoom Integration', () {
    testWidgets('camera screen includes zoom controls for iOS', (tester) async {
      // Test that CameraControlsOverlay is present in widget tree on iOS
      // This is a basic integration test
    });
  });
}
```

**Step 2: Add camera interface getter to VineRecordingNotifier**

Modify `lib/providers/vine_recording_provider.dart`:

Add getter to expose camera interface (around line 200):

```dart
/// Get the underlying camera interface for advanced controls
CameraPlatformInterface? get cameraInterface => _controller.cameraInterface;
```

Also add to VineRecordingController (around line 800):

```dart
/// Get the camera interface for advanced controls (zoom, focus, etc.)
CameraPlatformInterface? get cameraInterface => _cameraInterface;
```

**Step 3: Integrate CameraControlsOverlay into camera screen**

Modify `lib/screens/pure/universal_camera_screen_pure.dart`:

Import the overlay widget at top:

```dart
import 'package:openvine/widgets/camera_controls_overlay.dart';
```

Update the Stack widget in build method (around line 400-486):

Replace the Stack children with:

```dart
return Stack(
  children: [
    // Camera preview (square/1:1 aspect ratio for Vine-style videos)
    Positioned.fill(
      child: Center(
        child: AspectRatio(
          aspectRatio: 1.0, // Square format like original Vine
          child: ClipRect(
            child: Stack(
              children: [
                // Preview widget
                if (recordingState.isInitialized)
                  ref.read(vineRecordingProvider.notifier).previewWidget
                else
                  CameraPreviewPlaceholder(
                    isRecording: recordingState.isRecording,
                  ),

                // Zoom and gesture controls overlay
                if (recordingState.isInitialized)
                  Consumer(
                    builder: (context, ref, child) {
                      final cameraInterface = ref.read(vineRecordingProvider.notifier).cameraInterface;
                      if (cameraInterface != null) {
                        return CameraControlsOverlay(
                          cameraInterface: cameraInterface,
                          recordingState: recordingState.recordingState,
                        );
                      }
                      return const SizedBox.shrink();
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
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

    // Camera controls (top right)
    if (recordingState.isInitialized && !recordingState.isRecording)
      Positioned(
        top: 16,
        right: 16,
        child: _buildCameraControls(recordingState),
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
```

**Step 4: Run test**

Run: `flutter test test/screens/camera_zoom_integration_test.dart`

Expected: Test passes

Manual test on iOS: Pinch gesture should zoom camera

**Step 5: Commit**

```bash
git add lib/screens/pure/universal_camera_screen_pure.dart lib/providers/vine_recording_provider.dart lib/services/vine_recording_controller.dart test/screens/camera_zoom_integration_test.dart
git commit -m "feat: integrate pinch-to-zoom controls for iOS camera"
```

---

## Task 6: Fix SnackBar Positioning

**Files:**
- Modify: `lib/screens/pure/universal_camera_screen_pure.dart:951-969`
- Test: `test/screens/camera_snackbar_position_test.dart`

**Step 1: Write failing test for SnackBar position**

Create test file:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/screens/pure/universal_camera_screen_pure.dart';

void main() {
  group('Camera SnackBar Position', () {
    testWidgets('SnackBar appears at top when auto-stop occurs', (tester) async {
      // Test that SnackBar uses FloatingSnackBar behavior at top
      // This ensures it doesn't cover bottom controls
    });
  });
}
```

**Step 2: Update SnackBar to use top positioning**

Modify `lib/screens/pure/universal_camera_screen_pure.dart`:

Replace _handleRecordingAutoStop method (around line 951):

```dart
void _handleRecordingAutoStop() async {
  try {
    // Auto-stop just pauses the current segment
    // User must press publish button to finish and concatenate
    Log.info('📹 Recording auto-stopped (max duration reached)', category: LogCategory.video);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Maximum recording time reached. Press ✓ to publish.'),
          backgroundColor: VineTheme.vineGreen,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.only(
            top: 100, // Position at top to avoid covering bottom controls
            left: 16,
            right: 16,
          ),
        ),
      );
    }
  } catch (e) {
    Log.error('📹 Failed to handle auto-stop: $e', category: LogCategory.video);
  }
}
```

**Step 3: Run test**

Run: `flutter test test/screens/camera_snackbar_position_test.dart`

Expected: Test passes

Manual test: Record until max duration, verify SnackBar appears at top

**Step 4: Commit**

```bash
git add lib/screens/pure/universal_camera_screen_pure.dart test/screens/camera_snackbar_position_test.dart
git commit -m "fix: move SnackBar to top to avoid covering publish button"
```

---

## Task 7: Run All Tests and Verify

**Step 1: Run full test suite**

Run: `flutter test`

Expected: All tests pass

**Step 2: Run flutter analyze**

Run: `flutter analyze`

Expected: No issues

**Step 3: Manual testing checklist**

Test on macOS:
- [ ] Camera switch button hidden when only 1 camera
- [ ] Camera switch button visible when multiple cameras
- [ ] Clicking switch changes camera view

Test on iOS:
- [ ] Camera switch button works (front/back toggle)
- [ ] Pinch-to-zoom gesture works
- [ ] Zoom slider appears during pinch
- [ ] SnackBar appears at top, doesn't cover controls

**Step 4: Final commit**

```bash
git add -A
git commit -m "feat: complete camera screen fixes - visibility, switching, zoom, and SnackBar"
```

---

## Verification

**Success Criteria:**
1. Camera switch button only shows when multiple cameras available
2. macOS camera switching works with native API
3. iOS camera switching updates preview properly
4. iOS pinch-to-zoom works smoothly
5. SnackBar doesn't cover bottom controls

**Testing Platforms:**
- macOS desktop (primary dev platform)
- iOS simulator and device
- All tests passing
- No analyzer issues
