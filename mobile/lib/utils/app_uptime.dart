// ABOUTME: Records the process start time so diagnostics (log export header)
// ABOUTME: can report how long the app has been running.

import 'package:flutter/foundation.dart';

/// Tracks when the app process started.
///
/// [markStarted] is called once from `main()`; [uptime] returns `null` until
/// then so callers can omit the information instead of reporting a bogus
/// duration.
abstract final class AppUptime {
  static DateTime? _startedAt;

  /// Records the app start time. Subsequent calls are no-ops so hot restarts
  /// of individual widgets can't reset the clock.
  static void markStarted() => _startedAt ??= DateTime.now();

  /// Time elapsed since [markStarted], or `null` if it was never called.
  static Duration? get uptime {
    final startedAt = _startedAt;
    return startedAt == null ? null : DateTime.now().difference(startedAt);
  }

  /// Clears the recorded start time between tests.
  @visibleForTesting
  static void reset() => _startedAt = null;
}
