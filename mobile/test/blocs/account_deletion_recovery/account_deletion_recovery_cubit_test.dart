// ABOUTME: State-machine tests for interrupted account-deletion recovery.
// ABOUTME: Pins coordinator transitions, polling, cleanup, and close safety.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/blocs/account_deletion_recovery/account_deletion_recovery_cubit.dart';
import 'package:openvine/models/account_deletion_attempt.dart';
import 'package:openvine/repositories/account_deletion_recovery_repository.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';

class _MockRepository extends Mock
    implements AccountDeletionRecoveryRepository {}

class _MockAuthService extends Mock implements AuthService {}

class _ManualTimer implements Timer {
  _ManualTimer(this._callback);

  final void Function() _callback;
  var _active = true;

  void fire() {
    if (!_active) return;
    _active = false;
    _callback();
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => _active ? 0 : 1;
}

class _ManualTimers {
  final timers = <_ManualTimer>[];

  Timer create(Duration _, void Function() callback) {
    final timer = _ManualTimer(callback);
    timers.add(timer);
    return timer;
  }

  Future<void> fireNext() async {
    timers.firstWhere((timer) => timer.isActive).fire();
    await Future<void>.delayed(Duration.zero);
  }
}

const _preparing = AccountDeletionAttempt(
  id: 'attempt-id',
  status: AccountDeletionAttemptStatus.preparing,
  username: 'alice',
);
const _recoverable = AccountDeletionAttempt(
  id: 'attempt-id',
  status: AccountDeletionAttemptStatus.recoverable,
  username: 'alice',
);
const _cancelling = AccountDeletionAttempt(
  id: 'attempt-id',
  status: AccountDeletionAttemptStatus.preparing,
  operation: AccountDeletionAttemptOperation.cancelling,
  username: 'alice',
);
const _processing = AccountDeletionAttempt(
  id: 'attempt-id',
  status: AccountDeletionAttemptStatus.processing,
);
const _completed = AccountDeletionAttempt(
  id: 'attempt-id',
  status: AccountDeletionAttemptStatus.completed,
);
const _cancelled = AccountDeletionAttempt(
  id: 'attempt-id',
  status: AccountDeletionAttemptStatus.cancelled,
);

void main() {
  late _MockRepository repository;
  late _MockAuthService authService;
  late _ManualTimers timers;
  late int resolvedCalls;

  AccountDeletionRecoveryCubit buildCubit() => AccountDeletionRecoveryCubit(
    repository: repository,
    authService: authService,
    onAttemptResolved: () => resolvedCalls++,
    timerFactory: timers.create,
  );

  setUpAll(() {
    registerFallbackValue(_preparing);
  });

  setUp(() {
    repository = _MockRepository();
    authService = _MockAuthService();
    timers = _ManualTimers();
    resolvedCalls = 0;
  });

  group('load', () {
    final cases = <(AccountDeletionAttempt, AccountDeletionRecoveryStatus)>[
      (_preparing, AccountDeletionRecoveryStatus.restorable),
      (_recoverable, AccountDeletionRecoveryStatus.restorable),
      (_cancelling, AccountDeletionRecoveryStatus.cancelInFlight),
      (_processing, AccountDeletionRecoveryStatus.processing),
      (
        const AccountDeletionAttempt(
          id: 'attempt-id',
          status: AccountDeletionAttemptStatus.terminalFailure,
        ),
        AccountDeletionRecoveryStatus.terminalFailure,
      ),
    ];

    for (final (attempt, expectedStatus) in cases) {
      test('${attempt.status.name} + ${attempt.operation.name}', () async {
        when(repository.fetchCurrent).thenAnswer((_) async => attempt);
        final cubit = buildCubit();

        await cubit.load();

        expect(cubit.state.status, expectedStatus);
        expect(cubit.state.attempt, same(attempt));
        await cubit.close();
      });
    }

    test(
      'completed deletes local credentials only after server completion',
      () async {
        when(repository.fetchCurrent).thenAnswer((_) async => _completed);
        when(
          () => authService.signOut(
            deleteKeys: true,
            deleteLocalUserData: true,
          ),
        ).thenAnswer((_) async {});
        final cubit = buildCubit();

        await cubit.load();

        expect(cubit.state.status, AccountDeletionRecoveryStatus.resolved);
        verify(
          () => authService.signOut(
            deleteKeys: true,
            deleteLocalUserData: true,
          ),
        ).called(1);
        expect(resolvedCalls, 1);
        await cubit.close();
      },
    );

    test(
      'absent and cancelled attempts resolve without local deletion',
      () async {
        when(repository.fetchCurrent).thenAnswer((_) async => null);
        final absentCubit = buildCubit();
        await absentCubit.load();
        expect(
          absentCubit.state.status,
          AccountDeletionRecoveryStatus.resolved,
        );
        await absentCubit.close();

        when(repository.fetchCurrent).thenAnswer((_) async => _cancelled);
        final cancelledCubit = buildCubit();
        await cancelledCubit.load();
        expect(
          cancelledCubit.state.status,
          AccountDeletionRecoveryStatus.resolved,
        );
        verifyNever(
          () => authService.signOut(
            deleteKeys: any(named: 'deleteKeys'),
            deleteLocalUserData: any(named: 'deleteLocalUserData'),
          ),
        );
        await cancelledCubit.close();
      },
    );

    test('lookup error fails closed without carrying an exception', () async {
      when(repository.fetchCurrent).thenThrow(const FormatException('bad'));
      final cubit = buildCubit();

      await cubit.load();

      expect(cubit.state.status, AccountDeletionRecoveryStatus.loadFailed);
      expect(
        cubit.state.failure,
        AccountDeletionRecoveryFailure.statusLookup,
      );
      await cubit.close();
    });
  });

  group('cancel', () {
    test(
      'preparing username completes handshake before 200 cancellation',
      () async {
        when(repository.fetchCurrent).thenAnswer((_) async => _preparing);
        when(
          () => repository.resumePreparation(_preparing),
        ).thenAnswer((_) async => _recoverable);
        when(
          () => repository.cancel(attemptId: 'attempt-id'),
        ).thenAnswer((_) async => _cancelled);
        final cubit = buildCubit();
        await cubit.load();

        await cubit.cancel();

        verify(() => repository.resumePreparation(_preparing)).called(1);
        expect(cubit.state.status, AccountDeletionRecoveryStatus.resolved);
        await cubit.close();
      },
    );

    test(
      '202 cancellation enters polling and repeated cancel is ignored',
      () async {
        when(repository.fetchCurrent).thenAnswer((_) async => _recoverable);
        when(
          () => repository.cancel(attemptId: 'attempt-id'),
        ).thenAnswer((_) async => _cancelling);
        final cubit = buildCubit();
        await cubit.load();

        await cubit.cancel();
        await cubit.cancel();

        expect(
          cubit.state.status,
          AccountDeletionRecoveryStatus.cancelInFlight,
        );
        verify(() => repository.cancel(attemptId: 'attempt-id')).called(1);
        verifyNever(() => repository.resumePreparation(any()));
        await cubit.close();
      },
    );

    test('cancellation after commit reloads processing state', () async {
      var fetches = 0;
      when(repository.fetchCurrent).thenAnswer((_) async {
        fetches++;
        return fetches == 1 ? _recoverable : _processing;
      });
      when(
        () => repository.cancel(attemptId: 'attempt-id'),
      ).thenThrow(
        const AccountDeletionRecoveryException(
          'conflict',
          code: 'cancellation_after_commit',
        ),
      );
      final cubit = buildCubit();
      await cubit.load();

      await cubit.cancel();

      expect(cubit.state.status, AccountDeletionRecoveryStatus.processing);
      await cubit.close();
    });
  });

  test('polling retries transient failure and completes cleanup', () async {
    var fetches = 0;
    when(repository.fetchCurrent).thenAnswer((_) async {
      fetches++;
      if (fetches == 1) return _processing;
      if (fetches == 2) {
        throw const AccountDeletionRecoveryException('offline');
      }
      return _completed;
    });
    when(
      () => authService.signOut(
        deleteKeys: true,
        deleteLocalUserData: true,
      ),
    ).thenAnswer((_) async {});
    final cubit = buildCubit();
    await cubit.load();

    await timers.fireNext();
    expect(cubit.state.status, AccountDeletionRecoveryStatus.processing);
    expect(cubit.state.pollTickIndex, 1);
    await timers.fireNext();

    expect(cubit.state.status, AccountDeletionRecoveryStatus.resolved);
    expect(fetches, 3);
    await cubit.close();
  });

  test('polling fails closed when the attempt identity changes', () async {
    var fetches = 0;
    when(repository.fetchCurrent).thenAnswer((_) async {
      fetches++;
      return fetches == 1
          ? _processing
          : const AccountDeletionAttempt(
              id: 'different-attempt-id',
              status: AccountDeletionAttemptStatus.processing,
            );
    });
    final cubit = buildCubit();
    await cubit.load();

    await timers.fireNext();

    expect(cubit.state.status, AccountDeletionRecoveryStatus.loadFailed);
    expect(timers.timers.where((timer) => timer.isActive), isEmpty);
    await cubit.close();
  });

  test('polling pauses at the session bound and keeps manual retry', () async {
    when(repository.fetchCurrent).thenAnswer((_) async => _processing);
    final cubit = buildCubit();
    await cubit.load();

    while (timers.timers.any((timer) => timer.isActive)) {
      await timers.fireNext();
    }

    expect(cubit.state.status, AccountDeletionRecoveryStatus.processing);
    expect(cubit.state.pollingPaused, isTrue);
    final fetchesBeforeRetry = cubit.state.pollTickIndex + 1;
    await cubit.retry();
    verify(repository.fetchCurrent).called(fetchesBeforeRetry + 1);
    expect(cubit.state.pollingPaused, isFalse);
    await cubit.close();
  });

  test(
    'cleanup failure records a typed reason and remains retryable',
    () async {
      when(repository.fetchCurrent).thenAnswer((_) async => _completed);
      when(
        () => authService.signOut(
          deleteKeys: true,
          deleteLocalUserData: true,
        ),
      ).thenThrow(const SecureKeyStorageException('locked'));
      final cubit = buildCubit();

      await cubit.load();

      expect(cubit.state.status, AccountDeletionRecoveryStatus.cleanupFailed);
      expect(
        cubit.state.failure,
        AccountDeletionRecoveryFailure.keychainCleanup,
      );
      await cubit.close();
    },
  );

  test('local data cleanup failure has a distinct typed reason', () async {
    when(repository.fetchCurrent).thenAnswer((_) async => _completed);
    when(
      () => authService.signOut(
        deleteKeys: true,
        deleteLocalUserData: true,
      ),
    ).thenThrow(const UserDataCleanupException('failed'));
    final cubit = buildCubit();

    await cubit.load();

    expect(
      cubit.state.failure,
      AccountDeletionRecoveryFailure.localDataCleanup,
    );
    await cubit.close();
  });

  test('close during an in-flight request drops the resumed emit', () async {
    final completer = Completer<AccountDeletionAttempt?>();
    when(repository.fetchCurrent).thenAnswer((_) => completer.future);
    final cubit = buildCubit();
    final load = cubit.load();
    expect(cubit.state.status, AccountDeletionRecoveryStatus.loading);

    await cubit.close();
    completer.complete(_recoverable);
    await load;

    expect(cubit.state.status, AccountDeletionRecoveryStatus.loading);
  });
}
