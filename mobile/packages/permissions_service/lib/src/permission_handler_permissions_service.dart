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
    final status = await ph.Permission.camera.status;
    return mapPermissionStatus(status);
  }

  @override
  Future<PermissionStatus> requestCameraPermission() async {
    final status = await ph.Permission.camera.request();
    return mapPermissionStatus(status);
  }

  @override
  Future<PermissionStatus> checkMicrophoneStatus() async {
    final status = await ph.Permission.microphone.status;
    return mapPermissionStatus(status);
  }

  @override
  Future<PermissionStatus> requestMicrophonePermission() async {
    final status = await ph.Permission.microphone.request();
    return mapPermissionStatus(status);
  }

  @override
  Future<bool> openAppSettings() => ph.openAppSettings();

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
