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
  });

  /// Current polling status
  final EmailVerificationStatus status;

  /// Email address being verified (if polling)
  final String? pendingEmail;

  /// Error message (if failed)
  final String? error;

  /// Whether currently polling
  bool get isPolling => status == EmailVerificationStatus.polling;

  EmailVerificationState copyWith({
    EmailVerificationStatus? status,
    String? pendingEmail,
    String? error,
  }) {
    return EmailVerificationState(
      status: status ?? this.status,
      pendingEmail: pendingEmail ?? this.pendingEmail,
      error: error,
    );
  }

  @override
  List<Object?> get props => [status, pendingEmail, error];
}
