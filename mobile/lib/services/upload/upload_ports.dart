// ABOUTME: Port interfaces decoupling the extracted upload concerns from
// ABOUTME: app-layer services (Firebase crash reporting) for the package lift.

/// Crash/diagnostics reporting port for the upload pipeline.
///
/// Lets the extracted upload concerns (e.g. `UploadProgressReporter`) record
/// diagnostics without importing the Firebase-backed `CrashReportingService`,
/// so they can move into a pure-Dart package. The app layer supplies an
/// adapter that forwards to `CrashReportingService.instance`.
abstract interface class UploadCrashReporter {
  /// Attach a custom key/value to subsequent crash reports.
  Future<void> setCustomKey(String key, Object value);

  /// Log a breadcrumb message to the crash reporter.
  void log(String message);

  /// Record a non-fatal error with an optional [reason].
  Future<void> recordError(Object error, StackTrace? stack, {String? reason});
}
