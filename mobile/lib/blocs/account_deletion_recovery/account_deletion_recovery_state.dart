part of 'account_deletion_recovery_cubit.dart';

enum AccountDeletionRecoveryStatus {
  initial,
  loading,
  loadFailed,
  restorable,
  cancelInFlight,
  processing,
  completingLocally,
  cleanupFailed,
  terminalFailure,

  /// The signer is gone while the attempt is past the point of no return.
  ///
  /// Transient: the cubit signs out right after emitting it, so the view can
  /// surface the deletion outcome before the redirect to Welcome.
  sessionEnded,
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
