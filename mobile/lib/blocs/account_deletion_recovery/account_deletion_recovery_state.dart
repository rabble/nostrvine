part of 'account_deletion_recovery_cubit.dart';

enum AccountDeletionRecoveryStatus {
  initial,
  loading,
  loadFailed,
  restorable,
  cancelInFlight,
  confirmingSubmission,
  processing,
  completingLocally,
  completed,
  cleanupFailed,
  terminalFailure,

  signingOut,
  signOutFailed,
  resolved,
}

enum AccountDeletionRecoveryFailure {
  signerUnavailable,
  statusLookup,
  usernameRestore,
  keychainCleanup,
  localDataCleanup,
  signOut,
}

final class AccountDeletionRecoveryState extends Equatable {
  const AccountDeletionRecoveryState({
    this.status = AccountDeletionRecoveryStatus.initial,
    this.attempt,
    this.failure,
    this.pollTickIndex = 0,
    this.pollingPaused = false,
  });

  final AccountDeletionRecoveryStatus status;
  final AccountDeletionAttempt? attempt;
  final AccountDeletionRecoveryFailure? failure;
  final int pollTickIndex;
  final bool pollingPaused;

  @override
  List<Object?> get props => [
    status,
    attempt,
    failure,
    pollTickIndex,
    pollingPaused,
  ];
}
