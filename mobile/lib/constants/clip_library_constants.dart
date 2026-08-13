// ABOUTME: Shared constants for the clip library's retention behaviour.
// ABOUTME: Lets the UI read the trash window without importing the service.

/// Constants shared between the clip library's service and its UI.
abstract final class ClipLibraryConstants {
  /// How long a soft-deleted clip stays in the trash bin before the startup
  /// purge sweep permanently removes it.
  ///
  /// Lives here rather than on `ClipLibraryService` so the trash list can
  /// render its "Auto-deletes in N days" countdown from the same value
  /// without reaching across the UI/service boundary.
  static const Duration trashRetention = Duration(days: 30);
}
