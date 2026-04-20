// ABOUTME: Retry policy for Nostr publishes — bounded attempts with
// ABOUTME: exponential backoff, retrying only transient relays per NIP-01.

import 'package:meta/meta.dart';

/// Configuration for bounded-retry publish via
/// [NostrClient.publishEventWithRetry].
///
/// Defaults chosen for typical user-initiated publishes: 3 attempts total
/// (initial + 2 retries), 2s initial delay doubling each retry, 15s
/// per-attempt timeout, 30s cap so long backoffs don't feel stalled.
@immutable
class RetryPolicy {
  const RetryPolicy({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(seconds: 2),
    this.timeoutPerAttempt = const Duration(seconds: 15),
    this.maxDelay = const Duration(seconds: 30),
  }) : assert(maxAttempts >= 1, 'maxAttempts must be at least 1');

  /// Maximum attempts including the initial try. `1` disables retry.
  final int maxAttempts;

  /// Delay before the 2nd attempt. Doubles each retry, capped by [maxDelay].
  final Duration baseDelay;

  /// Per-attempt publish timeout forwarded to `publishEventAwaitOk`.
  final Duration timeoutPerAttempt;

  /// Upper bound on the delay between attempts. Prevents runaway growth.
  final Duration maxDelay;

  /// Returns the delay before retry attempt [attemptIndex] (1-based: `1`
  /// is the delay before the 2nd attempt, `2` before the 3rd, …).
  ///
  /// Exponential: `baseDelay * 2^(attemptIndex-1)`, capped at [maxDelay].
  Duration delayFor(int attemptIndex) {
    assert(attemptIndex >= 1, 'attemptIndex is 1-based');
    // Cap shift to avoid int overflow on pathological policies.
    final safeShift = attemptIndex > 30 ? 30 : attemptIndex - 1;
    final millis = baseDelay.inMilliseconds * (1 << safeShift);
    final capped =
        millis > maxDelay.inMilliseconds ? maxDelay.inMilliseconds : millis;
    return Duration(milliseconds: capped);
  }
}
