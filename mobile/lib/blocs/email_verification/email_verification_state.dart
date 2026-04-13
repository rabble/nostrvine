// ABOUTME: State for EmailVerificationBloc
// ABOUTME: Tracks polling status, pending email, and error reason code

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

/// Reason codes for a verification failure.
///
/// State must never carry user-facing English strings — the UI layer maps
/// these codes to localized copy via `context.l10n` when rendering.
enum EmailVerificationError {
  /// Polling exceeded the 15 minute timeout.
  timeout,

  /// OAuth completion detected but the authorization code or verifier was
  /// missing from the response.
  missingAuthCode,

  /// OAuth server returned a non-transient error during polling.
  pollFailed,

  /// Token exchange failed with a network error after retries were exhausted.
  networkExchange,

  /// OAuth server rejected the token exchange (invalid / expired code).
  oauthExchange,

  /// Sign-in completed token exchange but left the session unauthenticated.
  signInFailed,

  /// Token-based verification link is expired or no longer valid.
  verificationLinkExpired,

  /// Connection error while verifying via a token link.
  verificationConnectionError,

  /// Invite activation failed because the invite was already used.
  inviteAlreadyUsed,

  /// Invite activation failed because the invite is invalid or revoked.
  inviteInvalid,

  /// Invite activation failed because of a temporary server / network issue.
  inviteTemporary,

  /// Invite activation failed for an unspecified reason.
  inviteUnknown,
}

/// State for email verification polling
final class EmailVerificationState extends Equatable {
  const EmailVerificationState({
    this.status = EmailVerificationStatus.initial,
    this.pendingEmail,
    this.errorCode,
    this.showInviteGateRecovery = false,
    this.inviteRecoveryCode,
  });

  /// Current polling status
  final EmailVerificationStatus status;

  /// Email address being verified (if polling)
  final String? pendingEmail;

  /// Reason code for the failure (if status is [EmailVerificationStatus.failure]).
  ///
  /// Always `null` on non-failure states. Mapped to a localized string in the
  /// UI layer — never store or render a raw English string here.
  final EmailVerificationError? errorCode;

  /// Whether the failure should send the user back through the invite gate.
  final bool showInviteGateRecovery;

  /// Invite code to prefill when recovering through the invite gate.
  final String? inviteRecoveryCode;

  /// Whether currently polling
  bool get isPolling => status == EmailVerificationStatus.polling;

  EmailVerificationState copyWith({
    EmailVerificationStatus? status,
    String? pendingEmail,
    EmailVerificationError? errorCode,
    bool? showInviteGateRecovery,
    String? inviteRecoveryCode,
  }) {
    return EmailVerificationState(
      status: status ?? this.status,
      pendingEmail: pendingEmail ?? this.pendingEmail,
      errorCode: errorCode,
      showInviteGateRecovery:
          showInviteGateRecovery ?? this.showInviteGateRecovery,
      inviteRecoveryCode: inviteRecoveryCode ?? this.inviteRecoveryCode,
    );
  }

  @override
  List<Object?> get props => [
    status,
    pendingEmail,
    errorCode,
    showInviteGateRecovery,
    inviteRecoveryCode,
  ];
}
