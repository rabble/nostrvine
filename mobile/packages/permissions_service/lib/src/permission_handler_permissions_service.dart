import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart';
import 'package:meta/meta.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:permissions_service/src/models/models.dart';
import 'package:permissions_service/src/permissions_service.dart';

/// {@template permission_handler_permissions_service}
/// Concrete implementation of [PermissionsService] using the
/// `permission_handler` plugin.
///
/// This class wraps the permission_handler plugin to provide a clean,
/// testable interface for managing app permissions.
///
/// Example usage:
/// ```dart
/// final service = PermissionHandlerPermissionsService();
/// final cameraStatus = await service.checkCameraStatus();
/// if (cameraStatus == PermissionStatus.canRequest) {
///   await service.requestCameraPermission();
/// }
/// ```
/// {@endtemplate}
class PermissionHandlerPermissionsService implements PermissionsService {
  /// {@macro permission_handler_permissions_service}
  const PermissionHandlerPermissionsService();

  static const MethodChannel _nativeCameraChannel = MethodChannel(
    'openvine/native_camera',
  );

  @override
  Future<PermissionStatus> checkCameraStatus() async {
    if (_usesMacOSNativeMediaPermissions) {
      final status = await _nativeCameraChannel.invokeMethod<String>(
        'cameraPermissionStatus',
      );
      return mapMacOSAuthorizationStatus(status);
    }

    // coverage:ignore-start
    final status = await ph.Permission.camera.status;
    return mapPermissionStatus(status);
    // coverage:ignore-end
  }

  @override
  Future<PermissionStatus> requestCameraPermission() async {
    if (_usesMacOSNativeMediaPermissions) {
      final status = await _nativeCameraChannel.invokeMethod<String>(
        'requestCameraPermission',
      );
      return mapMacOSAuthorizationStatus(status);
    }

    // coverage:ignore-start
    final status = await ph.Permission.camera.request();
    return mapPermissionStatus(status);
    // coverage:ignore-end
  }

  @override
  Future<PermissionStatus> checkMicrophoneStatus() async {
    if (_usesMacOSNativeMediaPermissions) {
      final status = await _nativeCameraChannel.invokeMethod<String>(
        'microphonePermissionStatus',
      );
      return mapMacOSAuthorizationStatus(status);
    }

    // coverage:ignore-start
    final status = await ph.Permission.microphone.status;
    return mapPermissionStatus(status);
    // coverage:ignore-end
  }

  @override
  Future<PermissionStatus> requestMicrophonePermission() async {
    if (_usesMacOSNativeMediaPermissions) {
      final status = await _nativeCameraChannel.invokeMethod<String>(
        'requestMicrophonePermission',
      );
      return mapMacOSAuthorizationStatus(status);
    }

    // coverage:ignore-start
    final status = await ph.Permission.microphone.request();
    return mapPermissionStatus(status);
    // coverage:ignore-end
  }

  @override
  Future<bool> openAppSettings() async {
    if (_usesMacOSNativeMediaPermissions) {
      final opened = await _nativeCameraChannel.invokeMethod<bool>(
        'openSystemSettings',
      );
      return opened ?? false;
    }

    // coverage:ignore-start
    return ph.openAppSettings();
    // coverage:ignore-end
  }

  @override
  Future<PermissionStatus> checkGalleryStatus() async {
    // coverage:ignore-start
    // Web: No permissions needed, browser handles downloads
    if (kIsWeb) return PermissionStatus.granted;

    // Android: Check SDK version
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      // Android 11+ (API 30+): No permission needed (Scoped Storage)
      if (sdkInt >= 30) return PermissionStatus.granted;

      // Android 6-10 (API 23-29): WRITE_EXTERNAL_STORAGE required
      // Android < 6 (API < 23): No runtime permission (install-time)
      if (sdkInt >= 23) {
        final status = await ph.Permission.storage.status;
        return mapPermissionStatus(status);
      }

      return PermissionStatus.granted;
    }

    // iOS/macOS: photosAddOnly for saving media (write-only, no read access)
    final status = await ph.Permission.photosAddOnly.status;
    return mapPermissionStatus(status);
    // coverage:ignore-end
  }

  @override
  Future<PermissionStatus> requestGalleryPermission() async {
    // coverage:ignore-start
    // Web: No permissions needed, browser handles downloads
    if (kIsWeb) return PermissionStatus.granted;

    // Android: Check SDK version
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;

      // Android 11+ (API 30+): No permission needed (Scoped Storage)
      if (sdkInt >= 30) return PermissionStatus.granted;

      // Android 6-10 (API 23-29): WRITE_EXTERNAL_STORAGE required
      if (sdkInt >= 23) {
        final status = await ph.Permission.storage.request();
        return mapPermissionStatus(status);
      }

      return PermissionStatus.granted;
    }

    // iOS/macOS: photosAddOnly for saving media (write-only, no read access)
    final status = await ph.Permission.photosAddOnly.request();
    return mapPermissionStatus(status);
    // coverage:ignore-end
  }

  /// Maps a permission_handler [ph.PermissionStatus] to our domain
  /// [PermissionStatus].
  @visibleForTesting
  @internal
  PermissionStatus mapPermissionStatus(ph.PermissionStatus status) {
    // isGranted covers full access
    // isLimited covers iOS 14+ "Limited Photos Access" - sufficient for saving
    if (status.isGranted || status.isLimited) {
      return PermissionStatus.granted;
    }

    if (status.isPermanentlyDenied || status.isRestricted) {
      return PermissionStatus.requiresSettings;
    }

    return PermissionStatus.canRequest;
  }

  /// Maps a macOS AVFoundation authorization status string (as returned by
  /// `NativeCameraPlugin`) to our domain [PermissionStatus].
  ///
  /// `denied`/`restricted` require a System Settings trip on macOS; an
  /// unknown or `notDetermined` status is still requestable.
  @visibleForTesting
  @internal
  PermissionStatus mapMacOSAuthorizationStatus(String? status) {
    return switch (status) {
      'authorized' => PermissionStatus.granted,
      'denied' || 'restricted' => PermissionStatus.requiresSettings,
      _ => PermissionStatus.canRequest,
    };
  }

  bool get _usesMacOSNativeMediaPermissions =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
}
