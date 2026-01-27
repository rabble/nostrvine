// ABOUTME: States for email verification cubit
// ABOUTME: Supports both polling mode (after registration) and token mode (deep link)

part of 'email_verification_cubit.dart';

/// Mode of email verification
enum EmailVerificationMode {
  /// Polling mode: after registration, poll server until email is verified
  polling,

  /// Token mode: verify email via token from deep link
  token,
}

/// State for email verification cubit
sealed class EmailVerificationState extends Equatable {
  const EmailVerificationState();

  @override
  List<Object?> get props => [];
}

/// Initial state before verification starts
class EmailVerificationInitial extends EmailVerificationState {
  const EmailVerificationInitial();
}

/// Verification in progress (polling or token verification)
class EmailVerificationInProgress extends EmailVerificationState {
  const EmailVerificationInProgress({required this.mode, this.email});

  final EmailVerificationMode mode;
  final String? email;

  @override
  List<Object?> get props => [mode, email];
}

/// Email verification successful
class EmailVerificationSuccess extends EmailVerificationState {
  const EmailVerificationSuccess({required this.mode});

  final EmailVerificationMode mode;

  @override
  List<Object?> get props => [mode];
}

/// Email verification failed
class EmailVerificationFailure extends EmailVerificationState {
  const EmailVerificationFailure({
    required this.mode,
    required this.errorMessage,
  });

  final EmailVerificationMode mode;
  final String errorMessage;

  @override
  List<Object?> get props => [mode, errorMessage];
}
