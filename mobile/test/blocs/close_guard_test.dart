// ABOUTME: Tests for CloseGuardedEmit / CloseGuardedAdd (lib/blocs/close_guard.dart)
// ABOUTME: Pins that guarded emit/add drop silently where raw emit/add throw.

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/close_guard.dart';

/// A cubit whose load parks on a completer, the shape that produced the
/// `Cannot emit new states after calling close` aggregate in #7293: `close()`
/// does not cancel the awaited future, so it resumes into a disposed cubit.
class _LoadCubit extends Cubit<int> with CloseGuardedEmit<int> {
  _LoadCubit() : super(0);

  final gate = Completer<int>();

  /// Resumes with the guard — the emit is dropped once closed.
  Future<void> loadGuarded() async {
    final value = await gate.future;
    emitIfOpen(value);
  }

  /// Resumes without it — the emit throws once closed. Kept as the negative
  /// control: without it, `loadGuarded` passing proves nothing.
  Future<void> loadUnguarded() async {
    final value = await gate.future;
    emit(value);
  }
}

sealed class _Event {}

class _Bumped implements _Event {}

/// A bloc that dispatches from a stream it owns — the shape behind the
/// `Cannot add new events after calling close` aggregate, since `Bloc.close()`
/// closes the event controller before the queue drains.
class _RelayBloc extends Bloc<_Event, int> {
  _RelayBloc() : super(0) {
    on<_Bumped>((event, emit) => emit(state + 1));
  }

  void relayGuarded() => addIfOpen(_Bumped());

  void relayUnguarded() => add(_Bumped());
}

void main() {
  group(CloseGuardedEmit, () {
    test('emits and reports true while open', () {
      final cubit = _LoadCubit();
      addTearDown(cubit.close);

      expect(cubit.emitIfOpen(7), isTrue);
      expect(cubit.state, 7);
    });

    test('drops the state and reports false once closed', () async {
      final cubit = _LoadCubit();
      await cubit.close();

      expect(cubit.emitIfOpen(7), isFalse);
      expect(cubit.state, 0);
    });

    test('a load that resumes after close drops its emit', () async {
      final cubit = _LoadCubit();
      final states = <int>[];
      final subscription = cubit.stream.listen(states.add);
      addTearDown(subscription.cancel);

      final load = cubit.loadGuarded();
      await cubit.close();
      cubit.gate.complete(7);

      await expectLater(load, completes);
      expect(states, isEmpty);
      expect(cubit.state, 0);
    });

    test('the same load without the guard throws (negative control)', () async {
      final cubit = _LoadCubit();

      final load = cubit.loadUnguarded();
      await cubit.close();
      cubit.gate.complete(7);

      await expectLater(
        load,
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Cannot emit new states after calling close'),
          ),
        ),
      );
    });
  });

  group('CloseGuardedAdd', () {
    test('dispatches and reports true while open', () async {
      final bloc = _RelayBloc();
      addTearDown(bloc.close);

      expect(bloc.relayGuarded, returnsNormally);
      await expectLater(bloc.stream, emits(1));
    });

    test('drops the event and reports false once closed', () async {
      final bloc = _RelayBloc();
      await bloc.close();

      expect(bloc.addIfOpen(_Bumped()), isFalse);
      expect(bloc.state, 0);
    });

    test(
      'the same dispatch without the guard throws (negative control)',
      () async {
        final bloc = _RelayBloc();
        await bloc.close();

        expect(
          bloc.relayUnguarded,
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Cannot add new events after calling close'),
            ),
          ),
        );
      },
    );
  });
}
