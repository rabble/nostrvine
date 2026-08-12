// ABOUTME: Performance monitoring service for tracking app performance metrics
// ABOUTME: Uses Firebase Performance Monitoring to track screen transitions, network requests, and custom operations

import 'package:firebase_performance/firebase_performance.dart';
import 'package:unified_logger/unified_logger.dart';

/// A handle to a single started performance trace.
///
/// Callers capture the handle returned by
/// [PerformanceTraceMonitor.startOperationTrace] and tag/stop *that* handle, so
/// each operation owns its own trace. This avoids the name-keyed pitfalls of
/// the legacy [PerformanceTraceMonitor.startTrace] API: a fast operation can't
/// tag/stop before a shared registration completes, and two overlapping
/// operations can't stop or re-attribute each other's trace.
abstract class PerformanceTrace {
  /// Adds an attribute for filtering in the Firebase console.
  void putAttribute(String attribute, String value);

  /// Sets a custom metric on this trace, so an operation can report a
  /// breakdown (per-phase durations, payload sizes) next to its duration.
  void setMetric(String metric, int value);

  /// Stops the trace and records its duration.
  Future<void> stop();
}

/// Minimal trace API used by services that need testable performance spans.
///
/// Deliberately handle-only. The name-keyed API this replaced treated the
/// trace *name* as the identity of a measurement, so starting a second trace
/// of the same name reported the first one wherever it happened to be —
/// truncating it — and a trace that was never stopped stayed open until some
/// later start reported it, which is how a 23.6-hour `feed_load_profile`
/// sample reached the console (#7119).
abstract class PerformanceTraceMonitor {
  /// Starts a trace and returns the handle that owns it.
  ///
  /// Returns a no-op handle when monitoring is unavailable, so callers never
  /// need to null-check.
  PerformanceTrace startOperationTrace(String traceName);
}

/// No-op [PerformanceTrace] returned when monitoring is unavailable.
class _NoOpPerformanceTrace implements PerformanceTrace {
  const _NoOpPerformanceTrace();

  @override
  void putAttribute(String attribute, String value) {}

  @override
  void setMetric(String metric, int value) {}

  @override
  Future<void> stop() async {}
}

/// A [PerformanceTrace] backed by a live Firebase [Trace].
class _FirebasePerformanceTrace implements PerformanceTrace {
  _FirebasePerformanceTrace(this._trace, this._started);

  final Trace _trace;

  /// Completion of the trace's start round-trip. [stop] waits on it because
  /// the plugin drops a stop that arrives before the platform handed back a
  /// trace handle — the trace is then never reported *and* leaks natively.
  /// Operations that fail fast (an auth or ownership check that returns after
  /// a single await) are exactly the ones that would race it.
  final Future<void> _started;

  @override
  void putAttribute(String attribute, String value) {
    try {
      _trace.putAttribute(attribute, value);
    } catch (e) {
      Log.error(
        'Failed to put attribute $attribute: $e',
        name: 'PerformanceMonitoring',
      );
    }
  }

  @override
  void setMetric(String metric, int value) {
    try {
      _trace.setMetric(metric, value);
    } catch (e) {
      Log.error(
        'Failed to set metric $metric: $e',
        name: 'PerformanceMonitoring',
      );
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _started;
      await _trace.stop();
    } catch (e) {
      Log.error('Failed to stop trace: $e', name: 'PerformanceMonitoring');
    }
  }
}

/// No-op [PerformanceTraceMonitor] used as the default when no real monitor is
/// injected (e.g. in tests). Mirrors the prior behaviour of the uninitialised
/// singleton, whose methods early-returned without touching Firebase.
class NoOpPerformanceTraceMonitor implements PerformanceTraceMonitor {
  const NoOpPerformanceTraceMonitor();

  @override
  PerformanceTrace startOperationTrace(String traceName) =>
      const _NoOpPerformanceTrace();
}

/// Performance monitoring service for tracking app performance
class PerformanceMonitoringService implements PerformanceTraceMonitor {
  PerformanceMonitoringService();

  late final FirebasePerformance _performance;
  bool _initialized = false;

  /// Whether [initialize] has completed and Firebase Performance is usable.
  ///
  /// Sampled per operation by consumers built before startup finishes — an
  /// instrumented HTTP client is constructed with the provider graph, well
  /// before [initialize] resolves.
  bool get isEnabled => _initialized;

  /// Initialize performance monitoring
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _performance = FirebasePerformance.instance;

      // Enable performance collection
      await _performance.setPerformanceCollectionEnabled(true);

      _initialized = true;
      Log.info(
        'Performance monitoring initialized successfully',
        name: 'PerformanceMonitoring',
      );
    } catch (e) {
      Log.error(
        'Failed to initialize performance monitoring: $e',
        name: 'PerformanceMonitoring',
      );
      // Don't throw - app should continue even if performance monitoring fails
    }
  }

  /// Start an operation-scoped trace and return its handle.
  ///
  /// The caller owns the returned [PerformanceTrace] and tags/stops it
  /// directly, so overlapping operations of the same name keep independent
  /// traces and a handle that is never stopped simply never reports. Start is
  /// fire-and-forget so callers stay synchronous; attributes and metrics are
  /// buffered until stop, and stop itself waits for the start round-trip so a
  /// short operation cannot end its trace before the platform opened it.
  @override
  PerformanceTrace startOperationTrace(String traceName) {
    if (!_initialized) return const _NoOpPerformanceTrace();

    try {
      final trace = _performance.newTrace(traceName);
      final started = trace.start().catchError((Object e) {
        Log.error(
          'Failed to start trace $traceName: $e',
          name: 'PerformanceMonitoring',
        );
      });
      return _FirebasePerformanceTrace(trace, started);
    } catch (e) {
      Log.error(
        'Failed to start trace $traceName: $e',
        name: 'PerformanceMonitoring',
      );
      return const _NoOpPerformanceTrace();
    }
  }
}
