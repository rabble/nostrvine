// ABOUTME: Abstract performance monitoring interface for upload metrics.
// ABOUTME: Decouples the package from Firebase Performance or any APM tool.

/// Trace name for the in-process transfer run by
/// `BlossomUploadService.uploadVideo`.
///
/// Spans the whole in-process transfer. Deliberately *not* shared with
/// [enqueueTraceName]: the two measure different things, and reporting both
/// under one name blends two incompatible distributions into a number nobody
/// can read (#7119).
///
/// Not comparable to the publish timeline's `transfer_ms`, which stopwatches
/// the whole `uploadVideoWithResume` call — OS attempt plus any fallback — on
/// every publish. This trace only opens once the in-process leg actually runs,
/// which in the shipping config means the OS attempt did not succeed first
/// try. Its population is that biased-slow subset, not all publishes.
const String uploadTraceName = 'video_upload';

/// Trace name for the setup-and-enqueue leg of
/// `BlossomUploadService.uploadVideoInBackground`.
///
/// Covers only the in-process work that hands the transfer to the OS. The
/// transfer itself is owned by the OS, can span an app suspension, and is not
/// measured here.
const String enqueueTraceName = 'video_upload_enqueue';

/// A handle to a single started trace.
///
/// The handle — not a trace name — is the identity of the measurement, so two
/// overlapping uploads keep independent traces. The name-keyed API this
/// replaced reported an in-flight trace whenever a second one of the same name
/// started, which truncated the first and left multi-hour samples in the tail
/// whenever one was never stopped (#7119).
abstract class BlossomPerformanceTrace {
  /// Sets a metric value on this trace.
  void setMetric(String metricName, int value);

  /// Adds an attribute for filtering in the APM console.
  void putAttribute(String attribute, String value);

  /// Stops the trace and records its duration.
  Future<void> stop();
}

/// Optional performance monitoring interface for tracking upload metrics.
///
/// Provide a custom implementation to integrate with Firebase Performance
/// or another APM tool. If not provided, [NoOpPerformanceMonitor] is used.
///
// Kept as a named port rather than the bare function `one_member_abstracts`
// suggests: the call sites read as `startOperationTrace(uploadTraceName)`, and
// the app-layer adapter and the test doubles are classes that implement it.
// ignore: one_member_abstracts
abstract class BlossomPerformanceMonitor {
  /// Starts a trace and returns the handle that owns it.
  BlossomPerformanceTrace startOperationTrace(String traceName);
}

/// A no-op [BlossomPerformanceTrace] that silently discards every call.
class NoOpPerformanceTrace implements BlossomPerformanceTrace {
  /// Creates a [NoOpPerformanceTrace].
  const NoOpPerformanceTrace();

  @override
  void setMetric(String metricName, int value) {}

  @override
  void putAttribute(String attribute, String value) {}

  @override
  Future<void> stop() async {}
}

/// A no-op implementation that silently discards all performance calls.
class NoOpPerformanceMonitor implements BlossomPerformanceMonitor {
  /// Creates a [NoOpPerformanceMonitor].
  const NoOpPerformanceMonitor();

  @override
  BlossomPerformanceTrace startOperationTrace(String traceName) =>
      const NoOpPerformanceTrace();
}
