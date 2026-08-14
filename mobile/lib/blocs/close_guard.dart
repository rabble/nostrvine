// ABOUTME: Shared post-close guards for bloc/cubit state and event dispatch.
// ABOUTME: emitIfOpen and addIfOpen no-op instead of throwing after close().

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:meta/meta.dart';

/// Guarded `emit` for work that can resume after [BlocBase.close].
///
/// `BlocBase.emit` throws `Bad state: Cannot emit new states after calling
/// close` when the state controller is already closed, and an awaited future
/// is not cancelled by `close()` — it resumes into a disposed cubit and takes
/// the app down with it (#7293, #7356).
///
/// Apply the mixin and call [emitIfOpen] instead of `emit` on every path that
/// crosses an `await`, a stream callback, or a timer:
///
/// ```dart
/// class SettingsCubit extends Cubit<SettingsState>
///     with CloseGuardedEmit<SettingsState> {
///   Future<void> load() async {
///     final value = await _service.read();
///     emitIfOpen(state.copyWith(value: value));
///   }
/// }
/// ```
///
/// This is not a licence to leak: prefer cancelling the work when it is
/// cancellable. The guard is for genuinely uncancellable in-flight futures.
///
/// Blocs get the same guard for state; their event dispatch is covered by
/// [CloseGuardedAdd].
mixin CloseGuardedEmit<State> on BlocBase<State> {
  /// Emits [nextState] unless this instance is already closed.
  ///
  /// Returns `true` when the state was emitted, `false` when it was dropped
  /// because the bloc/cubit is closed — useful when the caller has follow-up
  /// work that only makes sense against a live instance.
  ///
  /// Carries the same visibility as the `BlocBase.emit` it wraps: mixing this
  /// in must not turn a cubit's state into something its callers can set.
  @protected
  @visibleForTesting
  bool emitIfOpen(State nextState) {
    if (isClosed) return false;
    emit(nextState);
    return true;
  }
}

/// Guarded `add` for event dispatch that can outlive the bloc.
///
/// `Bloc.close()` closes the event controller *before* draining the queue, so
/// `isClosed` flips to `true` while pending handlers are still running. Any
/// `add` from those handlers — or from a stream listener that has not been
/// cancelled yet — lands on a closed controller and throws `Bad state: Cannot
/// add new events after calling close` (#7293, #7356).
///
/// This is an extension rather than a mixin because `Bloc.add` is public, so
/// no `on` clause is needed to reach it.
extension CloseGuardedAdd<Event, State> on Bloc<Event, State> {
  /// Adds [event] unless this bloc is already closed.
  ///
  /// Returns `true` when the event was dispatched, `false` when it was dropped.
  bool addIfOpen(Event event) {
    if (isClosed) return false;
    add(event);
    return true;
  }
}
