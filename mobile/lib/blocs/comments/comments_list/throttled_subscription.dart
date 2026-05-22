// ABOUTME: Token-bucket throttle for a stream of incoming comments.
// ABOUTME: Extracted from comments_list_bloc.dart to keep the bloc under the
// ABOUTME: 500-line decomposition budget (issue #4516 acceptance criterion).

import 'dart:async';

/// Listens to [stream] but drops events that exceed [maxPerSecond].
///
/// Uses a simple token-bucket approach: each second refills the budget.
/// Events arriving after the budget is exhausted are silently dropped
/// until the next second window, preventing UI thrashing on viral videos.
///
/// The returned [StreamSubscription] also cancels the refill [Timer] when
/// cancelled, avoiding a periodic-timer leak per comments-sheet open/close.
StreamSubscription<T> throttledListen<T>(
  Stream<T> stream, {
  required int maxPerSecond,
  required void Function(T) onData,
  void Function(Object)? onError,
}) {
  var budget = maxPerSecond;
  final refillTimer = Timer.periodic(const Duration(seconds: 1), (_) {
    budget = maxPerSecond;
  });

  final subscription = stream.listen(
    (event) {
      if (budget > 0) {
        budget--;
        onData(event);
      }
    },
    onError: onError,
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
