import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
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

  @override
  Future<PermissionStatus> checkCameraStatus() async {
    // coverage:ignore-start
    final status = await ph.Permission.camera.status;
    return mapPermissionStatus(status);
    // coverage:ignore-end
  }

  @override
  Future<PermissionStatus> requestCameraPermission() async {
    // coverage:ignore-start
    final status = await ph.Permission.camera.request();
    return mapPermissionStatus(status);
    // coverage:ignore-end
  }

  @override
  Future<PermissionStatus> checkMicrophoneStatus() async {
    // coverage:ignore-start
    final status = await ph.Permission.microphone.status;
    return mapPermissionStatus(status);
    // coverage:ignore-end
  }

  @override
  Future<PermissionStatus> requestMicrophonePermission() async {
    // coverage:ignore-start
    final status = await ph.Permission.microphone.request();
    return mapPermissionStatus(status);
    // coverage:ignore-end
  }

  @override
  // coverage:ignore-start
  Future<bool> openAppSettings() => ph.openAppSettings();
  // coverage:ignore-end

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
    if (status.isGranted) {
      return PermissionStatus.granted;
    }

    if (status.isPermanentlyDenied || status.isRestricted) {
      return PermissionStatus.requiresSettings;
    }

    return PermissionStatus.canRequest;
  }
}
