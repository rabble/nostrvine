---
name: flutter-macos-permission-handler-camera-failure
description: |
  Fix silent camera/microphone failure on Flutter macOS when using permission_handler plugin.
  Use when: (1) Camera screen shows placeholder but no error on macOS, (2) CameraPermissionError
  state is emitted but cause is unclear, (3) permission_handler checkCameraStatus() or
  checkMicrophoneStatus() throws exceptions on macOS desktop, (4) Camera works on iOS/Android
  but fails silently on macOS. The permission_handler plugin doesn't work reliably on macOS -
  bypass it and let macOS handle permissions at the system level.
author: Claude Code
version: 1.0.0
date: 2026-01-28
---

# Flutter macOS permission_handler Camera Failure

## Problem
Camera/microphone permission checks using the `permission_handler` Flutter plugin throw
exceptions on macOS desktop, causing permission gates to emit error states. The camera
screen never renders, but the user sees a placeholder UI with no clear error message.

## Context / Trigger Conditions

Use this skill when:
- Flutter app works on iOS/Android but camera fails on macOS
- Permission gate shows loading or error state on macOS
- Logs show `CameraPermissionError` state being emitted
- `Permission.camera.status` or `Permission.microphone.status` throws exceptions
- Camera placeholder UI appears but `VideoRecorderScreen` (or equivalent) never initializes
- No camera-related logs appear after navigation to camera screen

**Key diagnostic pattern:**
```
🔐 CameraPermissionGate initState
🔐 Building with state: CameraPermissionInitial
🔐 Triggering permission refresh
🔐 Permission state changed: CameraPermissionError  <-- This is the tell
```

## Root Cause

The `permission_handler` plugin uses platform channels that don't work reliably on macOS
desktop. When `checkCameraStatus()` or `checkMicrophoneStatus()` is called:
- On iOS/Android: Returns proper permission status
- On macOS: Throws exception → BLoC catches → Emits error state → Screen blocked

macOS handles camera/microphone permissions at the system level - the first time an app
tries to access the camera, macOS shows its own permission dialog.

## Solution

Bypass `permission_handler` on macOS and assume permissions are authorized:

```dart
Future<void> _onRefresh(
  CameraPermissionRefresh event,
  Emitter<CameraPermissionState> emit,
) async {
  // On macOS desktop, permission_handler doesn't work reliably.
  // macOS handles camera permissions at the system level when the app
  // actually tries to access the camera, showing its own permission dialog.
  if (!kIsWeb && Platform.isMacOS) {
    emit(const CameraPermissionLoaded(CameraPermissionStatus.authorized));
    return;
  }

  // Normal permission check for iOS/Android
  try {
    final status = await checkPermissions();
    emit(CameraPermissionLoaded(status));
  } catch (e) {
    emit(const CameraPermissionError());
  }
}
```

**Required imports:**
```dart
import 'dart:io';
import 'package:flutter/foundation.dart';
```

## Verification

After implementing the fix:
1. Logs should show: `🔐 macOS detected - bypassing permission_handler, assuming authorized`
2. Permission state changes to `CameraPermissionLoaded` with status `authorized`
3. Camera screen actually renders and camera initialization logs appear
4. macOS shows its native permission dialog on first camera access (if not already granted)

## Debugging Layers

When debugging silent camera failures, check these layers in order:

1. **Permission layer**: Is the camera screen even being rendered? Check permission gate state.
2. **Initialization layer**: Is `initialize()` being called? Check for initialization logs.
3. **Device detection layer**: Are camera devices found? Check `listDevices()` results.
4. **Controller layer**: Does camera controller initialize? Check for controller errors.

Add logging at each layer to trace where the flow stops.

## Related Fixes

When implementing this fix, also add:

1. **Error tracking in camera service**: Add `initializationError` getter to report why
   camera failed (no devices, permission denied by macOS, etc.)

2. **UI error display**: Pass error messages to placeholder widgets so users see what's wrong

3. **Try-catch around native calls**: `CameraMacOS.instance.listDevices()` can also throw -
   wrap in try-catch and set error state

## Example: Complete Fix

```dart
// In CameraPermissionBloc
Future<void> _onRefresh(...) async {
  if (!kIsWeb && Platform.isMacOS) {
    log('macOS detected - bypassing permission_handler');
    emit(const CameraPermissionLoaded(CameraPermissionStatus.authorized));
    return;
  }
  // ... normal flow for mobile
}

// In CameraMacOSService
@override
Future<void> initialize() async {
  try {
    _videoDevices = await CameraMacOS.instance.listDevices(...);
  } catch (e) {
    _initializationError = 'Failed to detect cameras: $e';
    return;
  }

  if (_videoDevices?.isEmpty ?? true) {
    _initializationError = 'No camera found. Please connect a camera.';
    return;
  }
  // ... continue initialization
}
```

## Notes

- This is a platform-specific workaround, not a bug in your code
- macOS Ventura+ has stricter permission handling; the native dialog will still appear
- Test on actual macOS hardware, not just simulators
- The `camera_macos` or `camera_macos_plus` packages handle the native permission dialog
- Consider adding a "Camera permission required" UI that appears if macOS denies access

## References

- [permission_handler plugin](https://pub.dev/packages/permission_handler) - Check platform support matrix
- [macOS Camera Privacy](https://developer.apple.com/documentation/avfoundation/capture_setup/requesting_authorization_to_capture_and_save_media) - How macOS handles camera permissions
- [camera_macos package](https://pub.dev/packages/camera_macos) - macOS-specific camera implementation
