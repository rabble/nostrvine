import 'dart:async';

import 'package:unified_logger/unified_logger.dart';

/// Listens to [stream] but drops events that exceed [maxPerSecond].
///
/// Uses a simple token-bucket approach: each second refills the budget.
/// Events arriving after the budget is exhausted are silently dropped
/// until the next second window, preventing UI thrashing on viral videos.
///
/// The returned [StreamSubscription] cancels the refill [Timer] when
/// cancelled — and the wrapper also cancels the timer if the underlying
/// stream terminates with an error (the default `cancelOnError: false` would
/// otherwise leak the periodic Timer while the half-dead subscription waits
/// for an explicit close).
StreamSubscription<T> throttledListen<T>(
  Stream<T> stream, {
  required int maxPerSecond,
  required void Function(T) onData,
  void Function(Object)? onError,
}) {
  var budget = maxPerSecond;
  var didLogBudgetExhaustion = false;
  final refillTimer = Timer.periodic(const Duration(seconds: 1), (_) {
    budget = maxPerSecond;
    didLogBudgetExhaustion = false;
  });

  final subscription = stream.listen(
    (event) {
      if (budget > 0) {
        budget--;
        onData(event);
        return;
      }
      if (!didLogBudgetExhaustion) {
        didLogBudgetExhaustion = true;
        Log.debug(
          'Dropped comment events after exhausting $maxPerSecond/sec budget',
          name: 'CommentsListThrottle',
          category: LogCategory.ui,
        );
      }
    },
    onError: (Object error) {
      // Tear down the refill timer alongside surfacing the error so a stream
      // that fails mid-flight doesn't leak Timer.periodic for the bloc
      // lifetime. The user-supplied onError still runs after cleanup.
      refillTimer.cancel();
      onError?.call(error);
    },
    onDone: refillTimer.cancel,
  );
  return _ThrottledSubscription<T>(subscription, refillTimer);
}

class _ThrottledSubscription<T> implements StreamSubscription<T> {
  _ThrottledSubscription(this._inner, this._refillTimer);

  final StreamSubscription<T> _inner;
  final Timer _refillTimer;

  @override
  Future<void> cancel() {
    _refillTimer.cancel();
    return _inner.cancel();
  }

  @override
  void onData(void Function(T data)? handleData) => _inner.onData(handleData);

  @override
  void onError(Function? handleError) => _inner.onError(handleError);

  @override
  void onDone(void Function()? handleDone) => _inner.onDone(handleDone);

  @override
  bool get isPaused => _inner.isPaused;

  @override
  void pause([Future<void>? resumeSignal]) => _inner.pause(resumeSignal);

  @override
  void resume() => _inner.resume();

  @override
  Future<E> asFuture<E>([E? futureValue]) => _inner.asFuture<E>(futureValue);
}
