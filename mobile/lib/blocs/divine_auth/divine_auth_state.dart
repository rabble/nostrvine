// ABOUTME: States for Divine authentication cubit
// ABOUTME: Tracks sign in/sign up form state and email verification

part of 'divine_auth_cubit.dart';

/// State for Divine authentication cubit
sealed class DivineAuthState extends Equatable {
  const DivineAuthState();

  @override
  List<Object?> get props => [];
}

/// Initial state before form is ready
class DivineAuthInitial extends DivineAuthState {
  const DivineAuthInitial();
}

/// State when auth form is displayed and interactive
class DivineAuthFormState extends DivineAuthState {
  const DivineAuthFormState({
    this.email = '',
    this.password = '',
    this.isSignIn = false,
    this.emailError,
    this.passwordError,
    this.generalError,
    this.showInviteGateRecovery = false,
    this.inviteRecoveryCode,
    this.inviteRecoverySourceSlug,
    this.obscurePassword = true,
    this.isSubmitting = false,
    this.isSkipping = false,
  });

  /// User's email address
  final String email;

  /// User's password
  final String password;

  /// True for sign in mode, false for sign up mode
  final bool isSignIn;

  /// Error message for email field validation
  final String? emailError;

  /// Error message for password field validation
  final String? passwordError;

  /// General error message (e.g., network error, auth failure)
  final String? generalError;

  /// Whether the user should be sent back through the invite gate.
  final bool showInviteGateRecovery;

  /// Invite code to prefill if recovery should return to the invite gate.
  final String? inviteRecoveryCode;

  /// Creator source slug to preserve when recovery falls back to waitlist.
  final String? inviteRecoverySourceSlug;

  /// Whether password is obscured in the UI
  final bool obscurePassword;

  /// Whether form is currently being submitted
  final bool isSubmitting;

  /// Whether anonymous account creation is in progress
  final bool isSkipping;

  /// Returns true if form has no validation errors and fields are filled
  bool get canSubmit =>
      email.isNotEmpty &&
      password.isNotEmpty &&
      emailError == null &&
      passwordError == null &&
      !isSubmitting &&
      !isSkipping;

  DivineAuthFormState copyWith({
    String? email,
    String? password,
    bool? isSignIn,
    String? emailError,
    String? passwordError,
    String? generalError,
    bool? showInviteGateRecovery,
    String? inviteRecoveryCode,
    String? inviteRecoverySourceSlug,
    bool? obscurePassword,
    bool? isSubmitting,
    bool? isSkipping,
    bool clearEmailError = false,
    bool clearPasswordError = false,
    bool clearGeneralError = false,
    bool clearInviteGateRecovery = false,
  }) {
    return DivineAuthFormState(
      email: email ?? this.email,
      password: password ?? this.password,
      isSignIn: isSignIn ?? this.isSignIn,
      emailError: clearEmailError ? null : (emailError ?? this.emailError),
      passwordError: clearPasswordError
          ? null
          : (passwordError ?? this.passwordError),
      generalError: clearGeneralError
          ? null
          : (generalError ?? this.generalError),
      showInviteGateRecovery:
          !clearInviteGateRecovery &&
          (showInviteGateRecovery ?? this.showInviteGateRecovery),
      inviteRecoveryCode: clearInviteGateRecovery
          ? null
          : (inviteRecoveryCode ?? this.inviteRecoveryCode),
      inviteRecoverySourceSlug: clearInviteGateRecovery
          ? null
          : (inviteRecoverySourceSlug ?? this.inviteRecoverySourceSlug),
      obscurePassword: obscurePassword ?? this.obscurePassword,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSkipping: isSkipping ?? this.isSkipping,
    );
  }

  @override
  List<Object?> get props => [
    email,
    password,
    isSignIn,
    emailError,
    passwordError,
    generalError,
    showInviteGateRecovery,
    inviteRecoveryCode,
    inviteRecoverySourceSlug,
    obscurePassword,
    isSubmitting,
    isSkipping,
  ];
}

/// State when email verification is required after registration
class DivineAuthEmailVerification extends DivineAuthState {
  const DivineAuthEmailVerification({
    required this.email,
    required this.deviceCode,
    required this.verifier,
  });

  /// Email address that needs verification
  final String email;

  /// Device code for polling verification status
  final String deviceCode;

  /// PKCE verifier for code exchange
  final String verifier;

  @override
  List<Object?> get props => [email, deviceCode, verifier];
}

/// State after successful authentication
class DivineAuthSuccess extends DivineAuthState {
  const DivineAuthSuccess();
}
