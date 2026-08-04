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
abstract class PerformanceTraceMonitor {
  Future<void> startTrace(String traceName);

  Future<void> stopTrace(String traceName);

  /// Starts a trace and returns an operation-scoped [PerformanceTrace] handle.
  /// Prefer this over [startTrace] for any operation that can overlap another
  /// of the same name or complete before its trace round-trip settles. Returns
  /// a no-op handle when monitoring is unavailable.
  PerformanceTrace startOperationTrace(String traceName);

  void incrementMetric(String traceName, String metricName, int value);

  void setMetric(String traceName, String metricName, int value);

  void putAttribute(String traceName, String attribute, String value);
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
  Future<void> startTrace(String traceName) async {}

  @override
  Future<void> stopTrace(String traceName) async {}

  @override
  PerformanceTrace startOperationTrace(String traceName) =>
      const _NoOpPerformanceTrace();

  @override
  void incrementMetric(String traceName, String metricName, int value) {}

  @override
  void setMetric(String traceName, String metricName, int value) {}

  @override
  void putAttribute(String traceName, String attribute, String value) {}
}

/// Performance monitoring service for tracking app performance
class PerformanceMonitoringService implements PerformanceTraceMonitor {
  PerformanceMonitoringService();

  late final FirebasePerformance _performance;
  bool _initialized = false;

  /// Active traces for custom performance tracking
  final Map<String, Trace> _activeTraces = {};

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

  /// Start a custom trace for tracking operation performance
  @override
  Future<void> startTrace(String traceName) async {
    if (!_initialized) return;

    try {
      // Stop existing trace with same name if it exists
      await stopTrace(traceName);

      final trace = _performance.newTrace(traceName);
      await trace.start();
      _activeTraces[traceName] = trace;

      Log.debug(
        'Started performance trace: $traceName',
        name: 'PerformanceMonitoring',
      );
    } catch (e) {
      Log.error(
        'Failed to start trace $traceName: $e',
        name: 'PerformanceMonitoring',
      );
    }
  }

  /// Start an operation-scoped trace and return its handle.
  ///
  /// Unlike [startTrace], nothing is stored in [_activeTraces]: the caller
  /// owns the returned [PerformanceTrace] and tags/stops it directly, so
  /// overlapping operations of the same name keep independent traces. Start is
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

  /// Stop a custom trace and record the duration
  @override
  Future<void> stopTrace(String traceName) async {
    if (!_initialized) return;

    try {
      final trace = _activeTraces.remove(traceName);
      if (trace != null) {
        await trace.stop();
        Log.debug(
          'Stopped performance trace: $traceName',
          name: 'PerformanceMonitoring',
        );
      }
    } catch (e) {
      Log.error(
        'Failed to stop trace $traceName: $e',
        name: 'PerformanceMonitoring',
      );
    }
  }

  /// Add a metric to an active trace
  @override
  void incrementMetric(String traceName, String metricName, int value) {
    if (!_initialized) return;

    try {
      final trace = _activeTraces[traceName];
      if (trace != null) {
        trace.incrementMetric(metricName, value);
        Log.debug(
          'Incremented metric $metricName by $value for trace $traceName',
          name: 'PerformanceMonitoring',
        );
      } else {
        Log.warning(
          'Trace $traceName not found for metric $metricName',
          name: 'PerformanceMonitoring',
        );
      }
    } catch (e) {
      Log.error(
        'Failed to increment metric $metricName: $e',
        name: 'PerformanceMonitoring',
      );
    }
  }

  /// Set a metric value on an active trace
  @override
  void setMetric(String traceName, String metricName, int value) {
    if (!_initialized) return;

    try {
      final trace = _activeTraces[traceName];
      if (trace != null) {
        trace.setMetric(metricName, value);
        Log.debug(
          'Set metric $metricName to $value for trace $traceName',
          name: 'PerformanceMonitoring',
        );
      } else {
        Log.warning(
          'Trace $traceName not found for metric $metricName',
          name: 'PerformanceMonitoring',
        );
      }
    } catch (e) {
      Log.error(
        'Failed to set metric $metricName: $e',
        name: 'PerformanceMonitoring',
      );
    }
  }

  /// Add an attribute to an active trace for filtering in Firebase Console
  @override
  void putAttribute(String traceName, String attribute, String value) {
    if (!_initialized) return;

    try {
      final trace = _activeTraces[traceName];
      if (trace != null) {
        trace.putAttribute(attribute, value);
        Log.debug(
          'Set attribute $attribute=$value for trace $traceName',
          name: 'PerformanceMonitoring',
        );
      } else {
        Log.warning(
          'Trace $traceName not found for attribute $attribute',
          name: 'PerformanceMonitoring',
        );
      }
    } catch (e) {
      Log.error(
        'Failed to put attribute $attribute: $e',
        name: 'PerformanceMonitoring',
      );
    }
  }

  /// Create an HTTP metric for tracking network performance
  Future<HttpMetric> newHttpMetric(String url, HttpMethod httpMethod) async {
    if (!_initialized) {
      throw StateError('Performance monitoring not initialized');
    }

    return _performance.newHttpMetric(url, httpMethod);
  }

  /// Convenience method to track an async operation with automatic start/stop
  Future<T> trace<T>(String traceName, Future<T> Function() operation) async {
    await startTrace(traceName);
    try {
      final result = await operation();
      await stopTrace(traceName);
      return result;
    } catch (e) {
      await stopTrace(traceName);
      rethrow;
    }
  }
}
