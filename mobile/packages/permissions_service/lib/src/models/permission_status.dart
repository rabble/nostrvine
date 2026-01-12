/// {@template permission_status}
/// Generic permission status that can apply to any permission type.
///
/// This enum represents the possible states of a permission request,
/// abstracting away platform-specific details from the permission_handler
/// plugin.
/// {@endtemplate}
enum PermissionStatus {
  /// Permission has been granted by the user.
  granted,

  /// Permission can be requested via the OS permission dialog.
  ///
  /// This is the initial state for most permissions, or when the user
  /// has previously denied but not permanently denied the permission.
  canRequest,

  /// Permission is permanently denied or restricted by the system.
  ///
  /// The user must manually enable the permission in app settings.
  /// This occurs when:
  /// - User selected "Don't ask again" (permanently denied)
  /// - Permission is restricted by parental controls or device policy
  requiresSettings,
}
