// ABOUTME: Durable server-side account-deletion attempt state.
// ABOUTME: Drives recovery routing without relying on process-local progress.

enum AccountDeletionAttemptStatus {
  preparing,
  recoverable,
  processing,
  cancelled,
  completed,
  terminalFailure;

  static AccountDeletionAttemptStatus fromJson(String value) => switch (value) {
    'preparing' => preparing,
    'recoverable' => recoverable,
    'processing' => processing,
    'cancelled' => cancelled,
    'completed' => completed,
    'terminal_failure' => terminalFailure,
    _ => throw FormatException('Unknown deletion attempt status: $value'),
  };
}

class AccountDeletionAttempt {
  const AccountDeletionAttempt({
    required this.id,
    required this.status,
    this.username,
    this.usernameExpiresAt,
    this.failureCode,
    this.failureMessage,
  });

  factory AccountDeletionAttempt.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String?;
    final status = json['status'] as String?;
    if (id == null || id.isEmpty || status == null) {
      throw const FormatException('Invalid deletion attempt response');
    }
    return AccountDeletionAttempt(
      id: id,
      status: AccountDeletionAttemptStatus.fromJson(status),
      username: json['username'] as String?,
      usernameExpiresAt: (json['username_expires_at'] as num?)?.toInt(),
      failureCode: json['failure_code'] as String?,
      failureMessage: json['failure_message'] as String?,
    );
  }

  final String id;
  final AccountDeletionAttemptStatus status;
  final String? username;
  final int? usernameExpiresAt;
  final String? failureCode;
  final String? failureMessage;

  /// Whether this state must hold the user on the full-screen recovery gate.
  ///
  /// Terminal failures stay on the recovery screen because it renders the
  /// stable server failure details and provides reachable Support and Sign out
  /// actions; unlike the old retry-only screen, this state is not a trap.
  bool get requiresRecoveryScreen =>
      status == AccountDeletionAttemptStatus.preparing ||
      status == AccountDeletionAttemptStatus.recoverable ||
      status == AccountDeletionAttemptStatus.processing ||
      status == AccountDeletionAttemptStatus.completed ||
      status == AccountDeletionAttemptStatus.terminalFailure;
}
