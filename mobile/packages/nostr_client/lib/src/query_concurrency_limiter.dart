import 'dart:async';

/// Bounds the number of concurrent one-shot relay queries (REQs) in flight.
///
/// A single high-fan-out screen can otherwise open dozens of REQs at once —
/// e.g. opening a profile with many videos fans out into per-item like-count,
/// badge, profile and repost-source fetches — and trip a relay's
/// per-connection "too many concurrent REQs" limit. The relay then rejects or
/// queues traffic, which stalls loading and janks the UI.
///
/// Callers [acquire] a slot before sending the REQ and [release] it when the
/// query completes (or times out). Excess callers wait FIFO until an in-flight
/// query frees a slot. Because every acquired slot is released in a `finally`
/// (and each underlying query is itself time-bounded), the limiter cannot
/// deadlock.
class QueryConcurrencyLimiter {
  /// Creates a limiter allowing at most [maxConcurrent] queries at once.
  QueryConcurrencyLimiter(this.maxConcurrent)
    : assert(maxConcurrent > 0, 'maxConcurrent must be > 0');

  /// Maximum number of queries permitted to run concurrently.
  final int maxConcurrent;

  int _active = 0;
  final _waiters = <Completer<void>>[];

  /// Number of queries currently holding a slot. Exposed for tests.
  int get activeCount => _active;

  /// Number of callers waiting for a slot. Exposed for tests.
  int get waitingCount => _waiters.length;

  /// Reserves a slot, completing immediately when one is free or once an
  /// in-flight query releases. Always pair with a [release] in a `finally`.
  Future<void> acquire() {
    if (_active < maxConcurrent) {
      _active++;
      return Future<void>.value();
    }
    final completer = Completer<void>();
    _waiters.add(completer);
    return completer.future;
  }

  /// Frees a slot, handing it to the next waiter (if any) so the active count
  /// stays at the cap until the backlog drains.
  void release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete();
    } else if (_active > 0) {
      _active--;
    }
  }
}
