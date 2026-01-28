// ABOUTME: Native macOS camera interface using platform channels
// ABOUTME: Communicates with Swift AVFoundation implementation for real camera access

import 'dart:async';
import 'package:flutter/services.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Native macOS camera interface using platform channels
class NativeMacOSCamera {
  static const MethodChannel _channel = MethodChannel('openvine/native_camera');

  /// Error code thrown when camera permission is denied.
  static const String permissionDeniedCode = 'PERMISSION_DENIED';

  /// Request permission to access camera
  ///
  /// Returns true if permission is granted, false otherwise.
  /// If [openSettingsOnDenied] is true and permission was previously denied,
  /// will automatically open System Settings for the user to grant permission.
  ///
  /// Throws [PlatformException] with code 'PERMISSION_DENIED' if permission
  /// was previously denied and [openSettingsOnDenied] is false.
  static Future<bool> requestPermission({
    bool openSettingsOnDenied = false,
  }) async {
    try {
      final result = await _channel.invokeMethod<bool>('requestPermission');
      Log.debug(
        '📱 Camera permission result: $result',
        name: 'NativeMacosCamera',
        category: LogCategory.video,
      );
      return result ?? false;
    } on PlatformException catch (e) {
      if (e.code == permissionDeniedCode) {
        Log.warning(
          'Camera permission denied: ${e.message}',
          name: 'NativeMacosCamera',
          category: LogCategory.video,
        );

        if (openSettingsOnDenied) {
          Log.debug(
            '⚙️ Opening System Settings for camera permission',
            name: 'NativeMacosCamera',
            category: LogCategory.video,
          );
          await openSystemSettings();
        }

        // Re-throw so caller can handle appropriately
        rethrow;
      }

      Log.error(
        'Failed to request camera permission: $e',
        name: 'NativeMacosCamera',
        category: LogCategory.video,
      );
      return false;
    } catch (e) {
      Log.error(
        'Failed to request camera permission: $e',
        name: 'NativeMacosCamera',
        category: LogCategory.video,
      );
      return false;
    }
  }

  /// Open macOS System Settings to the Camera privacy page
  ///
  /// Allows the user to manually enable camera access if it was previously denied.
  static Future<void> openSystemSettings() async {
    try {
      await _channel.invokeMethod('openSystemSettings');
      Log.debug(
        '⚙️ Opened System Settings for camera permission',
        name: 'NativeMacosCamera',
        category: LogCategory.video,
      );
    } catch (e) {
      Log.error(
        'Failed to open System Settings: $e',
        name: 'NativeMacosCamera',
        category: LogCategory.video,
      );
    }
  }

  /// Check if camera permission is granted
  static Future<bool> hasPermission() async {
    try {
      final result = await _channel.invokeMethod<bool>('hasPermission');
      return result ?? false;
    } catch (e) {
      Log.error(
        'Failed to check camera permission: $e',
        name: 'NativeMacosCamera',
        category: LogCategory.video,
      );
      return false;
    }
  }
}
