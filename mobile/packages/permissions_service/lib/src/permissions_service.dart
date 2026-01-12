import 'package:permissions_service/src/models/models.dart';

/// {@template permissions_service}
/// Abstract interface for managing app permissions.
///
/// This service provides a unified API for checking and requesting
/// various app permissions, abstracting away the underlying
/// platform-specific implementation.
///
/// Use `PermissionHandlerPermissionsService` for the default implementation
/// that wraps the `permission_handler` plugin.
/// {@endtemplate}
abstract class PermissionsService {
  /// Checks the current status of the camera permission.
  Future<PermissionStatus> checkCameraStatus();

  /// Requests camera permission from the OS.
  ///
  /// Returns the resulting [PermissionStatus] after the request completes.
  Future<PermissionStatus> requestCameraPermission();

  /// Checks the current status of the microphone permission.
  Future<PermissionStatus> checkMicrophoneStatus();

  /// Requests microphone permission from the OS.
  ///
  /// Returns the resulting [PermissionStatus] after the request completes.
  Future<PermissionStatus> requestMicrophonePermission();

  /// Opens the app settings page for manual permission configuration.
  ///
  /// Returns `true` if the settings page was opened successfully,
  /// `false` otherwise.
  Future<bool> openAppSettings();
}
