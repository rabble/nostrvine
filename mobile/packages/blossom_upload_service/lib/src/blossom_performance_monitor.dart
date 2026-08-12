// ABOUTME: Abstract performance monitoring interface for upload metrics.
// ABOUTME: Decouples the package from Firebase Performance or any APM tool.

/// Optional performance monitoring interface for tracking upload metrics.
///
/// Provide a custom implementation to integrate with Firebase Performance
/// or another APM tool. If not provided, [NoOpPerformanceMonitor] is used.
abstract class BlossomPerformanceMonitor {
  /// Start a named performance trace.
  Future<void> startTrace(String traceName);

  /// Stop a named performance trace.
  Future<void> stopTrace(String traceName);

  /// Set a metric value on an active trace.
  void setMetric(String traceName, String metricName, int value);

  /// Set an attribute on an active trace, so the APM console can slice the
  /// duration distribution by it.
  ///
  /// Call before [stopTrace] — an attribute set after the trace is reported
  /// is dropped.
  void putAttribute(String traceName, String attribute, String value);
}

/// A no-op implementation that silently discards all performance calls.
class NoOpPerformanceMonitor implements BlossomPerformanceMonitor {
  /// Creates a [NoOpPerformanceMonitor].
  const NoOpPerformanceMonitor();

  @override
  Future<void> startTrace(String traceName) async {}

  @override
  Future<void> stopTrace(String traceName) async {}

  @override
  void setMetric(String traceName, String metricName, int value) {}

  @override
  void putAttribute(String traceName, String attribute, String value) {}
}
