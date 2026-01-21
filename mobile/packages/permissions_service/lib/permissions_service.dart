/// A service for managing app permissions.
///
/// This package provides an abstraction layer over the `permission_handler`
/// plugin, offering a clean and testable API for checking and requesting
/// various app permissions.
///
/// Example usage:
/// ```dart
/// import 'package:permissions_service/permissions_service.dart';
///
/// final service = PermissionHandlerPermissionsService();
///
/// // Check camera permission
/// final cameraStatus = await service.checkCameraStatus();
///
/// if (cameraStatus == PermissionStatus.canRequest) {
///   await service.requestCameraPermission();
/// } else if (cameraStatus == PermissionStatus.requiresSettings) {
///   await service.openAppSettings();
/// }
/// ```
library;

export 'src/models/models.dart';
export 'src/permission_handler_permissions_service.dart';
export 'src/permissions_service.dart';

// TODO(macOS): Add permission handling for video recorder on macOS.
