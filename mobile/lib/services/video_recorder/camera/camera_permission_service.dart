// ABOUTME: Service for handling camera and microphone permission requests
// ABOUTME: Centralizes permission logic with comprehensive logging

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:openvine/platform_io.dart';
import 'package:openvine/services/camera/native_macos_camera.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service for managing camera and microphone permissions.
///
/// Provides methods to check and request permissions with detailed logging.
class CameraPermissionService {
  /// Checks and requests camera and microphone permissions with UI feedback.
  ///
  /// Shows an alert dialog if permissions are permanently denied, offering
  /// to open app settings. Returns true if all required permissions are granted.
  static Future<bool> ensurePermissionsWithDialog(BuildContext context) async {
    // macOS uses native camera permission handling
    if (!kIsWeb && Platform.isMacOS) {
      return _ensureMacOSPermissionsWithDialog(context);
    }

    final cameraStatus = await Permission.camera.status;
    final micStatus = await Permission.microphone.status;

    // Check if any permission is permanently denied
    if (cameraStatus.isPermanentlyDenied || micStatus.isPermanentlyDenied) {
      final String deniedPermissions;
      if (cameraStatus.isPermanentlyDenied && micStatus.isPermanentlyDenied) {
        deniedPermissions = 'Camera and microphone';
      } else if (cameraStatus.isPermanentlyDenied) {
        deniedPermissions = 'Camera';
      } else {
        deniedPermissions = 'Microphone';
      }

      if (!context.mounted) return false;

      final shouldOpenSettings = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Permission Required'),
          content: Text(
            '$deniedPermissions permission is permanently denied. '
            'Please enable it in app settings to record videos.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );

      if (shouldOpenSettings ?? false) {
        await _openAppSettings();
      }

      return false;
    }

    // Try to get permissions normally
    return ensurePermissions();
  }

  /// Checks and requests camera and microphone permissions.
  ///
  /// Returns true if all required permissions are granted, false otherwise.
  /// Logs all permission status changes and requests.
  static Future<bool> ensurePermissions() async {
    // macOS uses native camera permission handling
    if (!kIsWeb && Platform.isMacOS) {
      return _ensureMacOSPermissions();
    }

    final cameraGranted = await _ensureCameraPermission();
    if (!cameraGranted) {
      return false;
    }

    final microphoneGranted = await _ensureMicrophonePermission();
    if (!microphoneGranted) {
      return false;
    }

    Log.info(
      '✅ All camera permissions granted',
      name: 'CameraPermissionService',
      category: .video,
    );

    return true;
  }

  /// Checks camera permission status.
  ///
  /// Returns true if granted, false otherwise.
  static Future<bool> hasCameraPermission() async {
    if (!kIsWeb && Platform.isMacOS) {
      return NativeMacOSCamera.hasPermission();
    }
    final status = await Permission.camera.status;
    return status.isGranted;
  }

  /// Checks microphone permission status.
  ///
  /// Returns true if granted, false otherwise.
  static Future<bool> hasMicrophonePermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }

  /// Ensures camera permission is granted.
  ///
  /// Requests permission if not already granted.
  /// Returns true if granted, false if denied.
  static Future<bool> _ensureCameraPermission() async {
    final status = await Permission.camera.status;

    Log.info(
      '📷 Camera permission status: ${status.name}',
      name: 'CameraPermissionService',
      category: .video,
    );

    if (status.isGranted) {
      return true;
    }

    // Check if we can request permission
    if (status.isPermanentlyDenied) {
      Log.error(
        '📷 Camera permission permanently denied - please enable in settings',
        name: 'CameraPermissionService',
        category: .video,
      );
      return false;
    }

    Log.info(
      '📷 Requesting camera permission',
      name: 'CameraPermissionService',
      category: .video,
    );

    final result = await Permission.camera.request();

    if (result.isGranted) {
      Log.info(
        '📷 Camera permission granted',
        name: 'CameraPermissionService',
        category: .video,
      );
      return true;
    }

    Log.error(
      '📷 Camera permission denied',
      name: 'CameraPermissionService',
      category: .video,
    );
    return false;
  }

  /// Ensures microphone permission is granted.
  ///
  /// Requests permission if not already granted.
  /// Returns true if granted, false if denied.
  static Future<bool> _ensureMicrophonePermission() async {
    final status = await Permission.microphone.status;

    Log.info(
      '🎤 Microphone permission status: ${status.name}',
      name: 'CameraPermissionService',
      category: .video,
    );

    if (status.isGranted) {
      return true;
    }

    // Check if we can request permission
    if (status.isPermanentlyDenied) {
      Log.error(
        '🎤 Microphone permission permanently denied - please enable in '
        'settings',
        name: 'CameraPermissionService',
        category: .video,
      );
      return false;
    }

    Log.info(
      '🎤 Requesting microphone permission',
      name: 'CameraPermissionService',
      category: .video,
    );

    final result = await Permission.microphone.request();

    if (result.isGranted) {
      Log.info(
        '🎤 Microphone permission granted',
        name: 'CameraPermissionService',
        category: .video,
      );
      return true;
    }

    Log.error(
      '🎤 Microphone permission denied',
      name: 'CameraPermissionService',
      category: .video,
    );
    return false;
  }

  /// Opens the app settings page for the user to manually enable permissions.
  ///
  /// Useful when permissions are permanently denied.
  static Future<bool> _openAppSettings() async {
    Log.info(
      '⚙️ Opening app settings',
      name: 'CameraPermissionService',
      category: .video,
    );

    return openAppSettings();
  }

  /// Ensures macOS permissions with dialog support
  static Future<bool> _ensureMacOSPermissionsWithDialog(
    BuildContext context,
  ) async {
    try {
      // Try to request permission
      final granted = await NativeMacOSCamera.requestPermission();
      if (granted) {
        Log.info(
          '✅ macOS camera permission granted',
          name: 'CameraPermissionService',
          category: LogCategory.video,
        );
        return true;
      }
      return false;
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION_DENIED') {
        Log.warning(
          '📷 macOS camera permission denied',
          name: 'CameraPermissionService',
          category: LogCategory.video,
        );

        if (!context.mounted) return false;

        final shouldOpenSettings = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: const Text('Camera Permission Required'),
            content: const Text(
              'Camera permission is denied. '
              'Please enable it in System Settings:\n\n'
              '1. Open System Settings\n'
              '2. Go to Privacy & Security\n'
              '3. Click on Camera\n'
              '4. Enable access for Divine\n\n'
              'Note: If Divine is not in the list, restart the app and try '
              'again.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );

        if (shouldOpenSettings ?? false) {
          await NativeMacOSCamera.openSystemSettings();
        }

        return false;
      }
      rethrow;
    }
  }

  /// Ensures macOS permissions without dialog
  static Future<bool> _ensureMacOSPermissions() async {
    try {
      final granted = await NativeMacOSCamera.requestPermission();

      if (granted) {
        Log.info(
          '✅ macOS camera permission granted',
          name: 'CameraPermissionService',
          category: LogCategory.video,
        );
        return true;
      }

      Log.error(
        '📷 macOS camera permission denied',
        name: 'CameraPermissionService',
        category: LogCategory.video,
      );
      return false;
    } on PlatformException catch (e) {
      if (e.code == 'PERMISSION_DENIED') {
        Log.error(
          '📷 macOS camera permission permanently denied - please enable in '
          'System Settings',
          name: 'CameraPermissionService',
          category: LogCategory.video,
        );
        return false;
      }

      Log.error(
        '📷 macOS camera permission error: ${e.message}',
        name: 'CameraPermissionService',
        category: LogCategory.video,
      );
      return false;
    }
  }
}
