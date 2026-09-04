// ABOUTME: Owns the interrupted account-deletion recovery state machine.
// ABOUTME: Coordinates loading, cancellation, polling, cleanup, and sign-out.

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart'
    show SecureKeyStorageException;
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/models/account_deletion_attempt.dart';
import 'package:openvine/models/signer_readiness.dart';
import 'package:openvine/repositories/account_deletion_recovery_repository.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';

part 'account_deletion_recovery_state.dart';

abstract class AccountDeletionRecoveryPolling {
  static const schedule = <Duration>[
    Duration(seconds: 2),
    Duration(seconds: 3),
    Duration(seconds: 5),
    Duration(seconds: 8),
    Duration(seconds: 13),
    Duration(seconds: 21),
  ];
  static const cap = Duration(seconds: 30);
  static const sessionBound = Duration(minutes: 15);

  static Duration delayForTick(int tickIndex) =>
      tickIndex < schedule.length ? schedule[tickIndex] : cap;
}

typedef RecoveryTimerFactory =
    Timer Function(Duration duration, void Function() callback);

class AccountDeletionRecoveryCubit extends Cubit<AccountDeletionRecoveryState>
    with CloseGuardedEmit<AccountDeletionRecoveryState> {
  AccountDeletionRecoveryCubit({
    required AccountDeletionRecoveryRepository repository,
    required AuthService authService,
    required void Function() onAttemptResolved,
    RecoveryTimerFactory timerFactory = Timer.new,
  }) : _repository = repository,
       _authService = authService,
       _onAttemptResolved = onAttemptResolved,
       _timerFactory = timerFactory,
       super(const AccountDeletionRecoveryState());

  final AccountDeletionRecoveryRepository _repository;
  final AuthService _authService;
  final void Function() _onAttemptResolved;
  final RecoveryTimerFactory _timerFactory;

  Timer? _pollTimer;
  var _generation = 0;
  Duration _pollingElapsed = Duration.zero;

  Future<void> load() async {
    final generation = _beginOperation();
    emit(
      const AccountDeletionRecoveryState(
        status: AccountDeletionRecoveryStatus.loading,
      ),
    );
    try {
      final attempt = await _repository.fetchCurrent();
      if (!_isCurrent(generation)) return;
      await _handleAttempt(attempt, generation: generation);
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!_isCurrent(generation)) return;
      emitIfOpen(
        const AccountDeletionRecoveryState(
          status: AccountDeletionRecoveryStatus.loadFailed,
          failure: AccountDeletionRecoveryFailure.statusLookup,
        ),
      );
    }
  }

  Future<void> retry() async {
    if (_authService.signerReadiness == SignerReadiness.unavailable) {
      final generation = _beginOperation();
      emitIfOpen(
        const AccountDeletionRecoveryState(
          status: AccountDeletionRecoveryStatus.loading,
        ),
      );
      final refreshed = await _authService.tryRefreshExpiredSession();
      if (!_isCurrent(generation)) return;
      if (refreshed) {
        await load();
      } else {
        signerUnavailable();
      }
      return;
    }
    return load();
  }

  /// Adopts an attempt this process already holds without a status lookup.
  ///
  /// After `submit` answers `processing` the coordinator deletes the Keycast
  /// user, so the lookup [load] starts with cannot be signed. Polling still
  /// runs from here; a failed poll keeps the known state rather than
  /// replacing it with a lookup failure.
  Future<void> resume(AccountDeletionAttempt attempt) async {
    final generation = _beginOperation();
    await _handleAttempt(attempt, generation: generation);
  }

  /// Reports that the signer is permanently unavailable.
  ///
  /// With no [attempt], or one the user could still cancel after signing in
  /// again, this holds the session-expired copy with retry and sign-out. A
  /// `processing` attempt cannot be cancelled and its Keycast account is what
  /// the signer just lost, so the session is over: the cubit emits
  /// [AccountDeletionRecoveryStatus.sessionEnded] and signs out (#8583).
  /// Terminal states need no signer and are handled as if fetched.
  Future<void> signerUnavailable({AccountDeletionAttempt? attempt}) async {
    switch (attempt?.status) {
      case null:
      case AccountDeletionAttemptStatus.preparing:
      case AccountDeletionAttemptStatus.recoverable:
        _beginOperation();
        emitIfOpen(
          const AccountDeletionRecoveryState(
            status: AccountDeletionRecoveryStatus.loadFailed,
            failure: AccountDeletionRecoveryFailure.signerUnavailable,
          ),
        );
      case AccountDeletionAttemptStatus.processing:
        _beginOperation();
        emitIfOpen(
          AccountDeletionRecoveryState(
            status: AccountDeletionRecoveryStatus.sessionEnded,
            attempt: attempt,
          ),
        );
        await signOut();
      case AccountDeletionAttemptStatus.completed:
      case AccountDeletionAttemptStatus.cancelled:
      case AccountDeletionAttemptStatus.terminalFailure:
        await resume(attempt!);
    }
  }

  Future<void> cancel() async {
    final attempt = state.attempt;
    if (attempt == null ||
        state.status != AccountDeletionRecoveryStatus.restorable) {
      return;
    }
    final generation = _beginOperation();
    emit(
      AccountDeletionRecoveryState(
        status: AccountDeletionRecoveryStatus.cancelInFlight,
        attempt: attempt,
      ),
    );
    try {
      final ready = await _prepareForCancellation(attempt);
      if (!_isCurrent(generation)) return;
      final result = await _repository.cancel(attemptId: ready.id);
      if (!_isCurrent(generation)) return;
      await _handleAttempt(result, generation: generation);
    } on AccountDeletionRecoveryException catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!_isCurrent(generation)) return;
      if (_requiresStatusRefresh(error.code)) {
        await _reloadAfterConflict(generation);
        return;
      }
      emitIfOpen(
        AccountDeletionRecoveryState(
          status: AccountDeletionRecoveryStatus.restorable,
          attempt: attempt,
          failure: attempt.username == null
              ? AccountDeletionRecoveryFailure.statusLookup
              : AccountDeletionRecoveryFailure.usernameRestore,
        ),
      );
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!_isCurrent(generation)) return;
      emitIfOpen(
        AccountDeletionRecoveryState(
          status: AccountDeletionRecoveryStatus.restorable,
          attempt: attempt,
          failure: attempt.username == null
              ? AccountDeletionRecoveryFailure.statusLookup
              : AccountDeletionRecoveryFailure.usernameRestore,
        ),
      );
    }
  }

  Future<void> completeLocalCleanup() async {
    final attempt = state.attempt;
    if (attempt?.status != AccountDeletionAttemptStatus.completed) return;
    final generation = _beginOperation();
    emit(
      AccountDeletionRecoveryState(
        status: AccountDeletionRecoveryStatus.completingLocally,
        attempt: attempt,
      ),
    );
    try {
      await _authService.signOut(deleteKeys: true, deleteLocalUserData: true);
      if (!_isCurrent(generation)) return;
      _resolve();
    } on SecureKeyStorageException catch (error, stackTrace) {
      addError(error, stackTrace);
      _emitCleanupFailure(
        generation,
        attempt!,
        AccountDeletionRecoveryFailure.keychainCleanup,
      );
    } on UserDataCleanupException catch (error, stackTrace) {
      addError(error, stackTrace);
      _emitCleanupFailure(
        generation,
        attempt!,
        AccountDeletionRecoveryFailure.localDataCleanup,
      );
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      _emitCleanupFailure(
        generation,
        attempt!,
        AccountDeletionRecoveryFailure.localDataCleanup,
      );
    }
  }

  Future<void> signOut() async {
    if (state.status == AccountDeletionRecoveryStatus.signingOut) return;
    final attempt = state.attempt;
    final generation = _beginOperation();
    emit(
      AccountDeletionRecoveryState(
        status: AccountDeletionRecoveryStatus.signingOut,
        attempt: attempt,
      ),
    );
    try {
      await _authService.signOut();
      if (!_isCurrent(generation)) return;
      _resolve();
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!_isCurrent(generation)) return;
      emitIfOpen(
        AccountDeletionRecoveryState(
          status: AccountDeletionRecoveryStatus.signOutFailed,
          attempt: attempt,
          failure: AccountDeletionRecoveryFailure.signOut,
        ),
      );
    }
  }

  Future<AccountDeletionAttempt> _prepareForCancellation(
    AccountDeletionAttempt attempt,
  ) async {
    if (attempt.status == AccountDeletionAttemptStatus.preparing &&
        !attempt.isCancellationInFlight &&
        attempt.username != null) {
      return _repository.resumePreparation(attempt);
    }
    return attempt;
  }

  Future<void> _reloadAfterConflict(int generation) async {
    try {
      final current = await _repository.fetchCurrent();
      if (!_isCurrent(generation)) return;
      await _handleAttempt(current, generation: generation);
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!_isCurrent(generation)) return;
      emitIfOpen(
        const AccountDeletionRecoveryState(
          status: AccountDeletionRecoveryStatus.loadFailed,
          failure: AccountDeletionRecoveryFailure.statusLookup,
        ),
      );
    }
  }

  bool _requiresStatusRefresh(String? code) => const {
    'cancellation_after_commit',
    'illegal_transition',
    'attempt_not_found',
  }.contains(code);

  Future<void> _handleAttempt(
    AccountDeletionAttempt? attempt, {
    required int generation,
  }) async {
    if (!_isCurrent(generation)) return;
    if (attempt == null ||
        attempt.status == AccountDeletionAttemptStatus.cancelled) {
      _resolve();
      return;
    }
    switch (attempt.status) {
      case AccountDeletionAttemptStatus.preparing:
        if (attempt.isCancellationInFlight) {
          _emitPollingState(
            AccountDeletionRecoveryStatus.cancelInFlight,
            attempt,
            generation,
          );
        } else {
          emitIfOpen(
            AccountDeletionRecoveryState(
              status: AccountDeletionRecoveryStatus.restorable,
              attempt: attempt,
            ),
          );
        }
      case AccountDeletionAttemptStatus.recoverable:
        emitIfOpen(
          AccountDeletionRecoveryState(
            status: AccountDeletionRecoveryStatus.restorable,
            attempt: attempt,
          ),
        );
      case AccountDeletionAttemptStatus.processing:
        _emitPollingState(
          AccountDeletionRecoveryStatus.processing,
          attempt,
          generation,
        );
      case AccountDeletionAttemptStatus.completed:
        emitIfOpen(
          AccountDeletionRecoveryState(
            status: AccountDeletionRecoveryStatus.completingLocally,
            attempt: attempt,
          ),
        );
        await completeLocalCleanup();
      case AccountDeletionAttemptStatus.terminalFailure:
        emitIfOpen(
          AccountDeletionRecoveryState(
            status: AccountDeletionRecoveryStatus.terminalFailure,
            attempt: attempt,
          ),
        );
      case AccountDeletionAttemptStatus.cancelled:
        _resolve();
    }
  }

  void _emitPollingState(
    AccountDeletionRecoveryStatus status,
    AccountDeletionAttempt attempt,
    int generation,
  ) {
    emitIfOpen(
      AccountDeletionRecoveryState(
        status: status,
        attempt: attempt,
        pollTickIndex: state.pollTickIndex,
      ),
    );
    _schedulePoll(generation);
  }

  void _schedulePoll(int generation) {
    _pollTimer?.cancel();
    final tickIndex = state.pollTickIndex;
    final delay = AccountDeletionRecoveryPolling.delayForTick(tickIndex);
    if (_pollingElapsed + delay > AccountDeletionRecoveryPolling.sessionBound) {
      emitIfOpen(
        AccountDeletionRecoveryState(
          status: state.status,
          attempt: state.attempt,
          pollTickIndex: tickIndex,
          pollingPaused: true,
        ),
      );
      return;
    }
    _pollingElapsed += delay;
    _pollTimer = _timerFactory(delay, () => _poll(generation));
  }

  Future<void> _poll(int generation) async {
    if (!_isCurrent(generation)) return;
    final expectedAttemptId = state.attempt?.id;
    final tickIndex = state.pollTickIndex + 1;
    try {
      final current = await _repository.fetchCurrent();
      if (!_isCurrent(generation)) return;
      if (current == null || current.id != expectedAttemptId) {
        emitIfOpen(
          const AccountDeletionRecoveryState(
            status: AccountDeletionRecoveryStatus.loadFailed,
            failure: AccountDeletionRecoveryFailure.statusLookup,
          ),
        );
        return;
      }
      emitIfOpen(
        AccountDeletionRecoveryState(
          status: state.status,
          attempt: current,
          pollTickIndex: tickIndex,
        ),
      );
      await _handleAttempt(current, generation: generation);
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!_isCurrent(generation)) return;
      emitIfOpen(
        AccountDeletionRecoveryState(
          status: state.status,
          attempt: state.attempt,
          pollTickIndex: tickIndex,
        ),
      );
      _schedulePoll(generation);
    }
  }

  int _beginOperation() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollingElapsed = Duration.zero;
    return ++_generation;
  }

  bool _isCurrent(int generation) => !isClosed && generation == _generation;

  void _emitCleanupFailure(
    int generation,
    AccountDeletionAttempt attempt,
    AccountDeletionRecoveryFailure failure,
  ) {
    if (!_isCurrent(generation)) return;
    emitIfOpen(
      AccountDeletionRecoveryState(
        status: AccountDeletionRecoveryStatus.cleanupFailed,
        attempt: attempt,
        failure: failure,
      ),
    );
  }

  void _resolve() {
    _pollTimer?.cancel();
    emitIfOpen(
      const AccountDeletionRecoveryState(
        status: AccountDeletionRecoveryStatus.resolved,
      ),
    );
    if (!isClosed) _onAttemptResolved();
  }

  @override
  Future<void> close() {
    _generation++;
    _pollTimer?.cancel();
    return super.close();
  }
}
