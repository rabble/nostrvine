// ABOUTME: State for EmailVerificationBloc
// ABOUTME: Tracks polling status, pending email, and error state

part of 'email_verification_cubit.dart';

/// Status of email verification polling
enum EmailVerificationStatus {
  /// Not polling
  initial,

  /// Actively polling for verification
  polling,

  /// Verification completed successfully
  success,

  /// Polling failed with an error
  failure,
}

/// State for email verification polling
final class EmailVerificationState extends Equatable {
  const EmailVerificationState({
    this.status = EmailVerificationStatus.initial,
    this.pendingEmail,
    this.error,
    this.showInviteGateRecovery = false,
    this.inviteRecoveryCode,
  });

  /// Current polling status
  final EmailVerificationStatus status;

  /// Email address being verified (if polling)
  final String? pendingEmail;

  /// Error message (if failed)
  final String? error;

  /// Whether the failure should send the user back through the invite gate.
  final bool showInviteGateRecovery;

  /// Invite code to prefill when recovering through the invite gate.
  final String? inviteRecoveryCode;

  /// Whether currently polling
  bool get isPolling => status == EmailVerificationStatus.polling;

  EmailVerificationState copyWith({
    EmailVerificationStatus? status,
    String? pendingEmail,
    String? error,
    bool? showInviteGateRecovery,
    String? inviteRecoveryCode,
  }) {
    return EmailVerificationState(
      status: status ?? this.status,
      pendingEmail: pendingEmail ?? this.pendingEmail,
      error: error,
      showInviteGateRecovery:
          showInviteGateRecovery ?? this.showInviteGateRecovery,
      inviteRecoveryCode: inviteRecoveryCode ?? this.inviteRecoveryCode,
    );
  }

  @override
  List<Object?> get props => [
    status,
    pendingEmail,
    error,
    showInviteGateRecovery,
    inviteRecoveryCode,
  ];
}
