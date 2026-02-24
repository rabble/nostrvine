// ABOUTME: Cubit for managing diVine authentication flow
// ABOUTME: Handles sign in, sign up, and email verification states

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/pending_verification_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/utils/validators.dart';

part 'divine_auth_state.dart';

/// Cubit for managing diVine authentication flow.
///
/// Handles:
/// - Switching between sign in and sign up modes
/// - Form field updates and validation
/// - Submitting login/register requests
/// - Email verification flow
class DivineAuthCubit extends Cubit<DivineAuthState> {
  DivineAuthCubit({
    required KeycastOAuth oauthClient,
    required AuthService authService,
    required PendingVerificationService pendingVerificationService,
  }) : _oauthClient = oauthClient,
       _authService = authService,
       _pendingVerificationService = pendingVerificationService,
       super(const DivineAuthInitial());

  final KeycastOAuth _oauthClient;
  final AuthService _authService;
  final PendingVerificationService _pendingVerificationService;

  /// Initialize form with default state (sign up mode)
  void initialize({bool isSignIn = false, String? initialEmail}) {
    emit(DivineAuthFormState(isSignIn: isSignIn, email: initialEmail ?? ''));
  }

  /// Update email field
  void updateEmail(String email) {
    final current = state;
    if (current is! DivineAuthFormState) return;

    emit(
      current.copyWith(
        email: email,
        clearEmailError: true,
        clearGeneralError: true,
      ),
    );
  }

  /// Update password field
  void updatePassword(String password) {
    final current = state;
    if (current is! DivineAuthFormState) return;

    emit(
      current.copyWith(
        password: password,
        clearPasswordError: true,
        clearGeneralError: true,
      ),
    );
  }

  /// Toggle password visibility
  void togglePasswordVisibility() {
    final current = state;
    if (current is! DivineAuthFormState) return;

    emit(current.copyWith(obscurePassword: !current.obscurePassword));
  }

  /// Validate and submit the form
  Future<void> submit() async {
    final current = state;
    if (current is! DivineAuthFormState) return;
    if (current.isSubmitting || current.isSkipping) return;

    // Validate fields
    final emailError = Validators.validateEmail(current.email);
    final passwordError = Validators.validatePassword(current.password);

    if (emailError != null || passwordError != null) {
      emit(
        current.copyWith(emailError: emailError, passwordError: passwordError),
      );
      return;
    }

    // Start submission
    emit(current.copyWith(isSubmitting: true, clearGeneralError: true));

    try {
      if (current.isSignIn) {
        await _handleSignIn(current.email, current.password);
      } else {
        await _handleSignUp(current.email, current.password);
      }
    } catch (e) {
      Log.error(
        'Auth submission error: $e',
        name: 'DivineAuthCubit',
        category: LogCategory.auth,
      );

      final currentState = state;
      if (currentState is DivineAuthFormState) {
        emit(
          currentState.copyWith(
            isSubmitting: false,
            generalError: 'An unexpected error occurred. Please try again.',
          ),
        );
      }
    }
  }

  Future<void> _handleSignIn(String email, String password) async {
    Log.info(
      'Attempting sign in using email and password',
      name: 'DivineAuthCubit',
      category: LogCategory.auth,
    );

    final (result, verifier) = await _oauthClient.headlessLogin(
      email: email,
      password: password,
      scope: 'policy:full',
    );

    if (!result.success || result.code == null) {
      final errorMsg =
          result.errorDescription ?? result.error ?? 'Sign in failed';
      Log.warning(
        'Sign in failed: $errorMsg',
        name: 'DivineAuthCubit',
        category: LogCategory.auth,
      );

      final current = state;
      if (current is DivineAuthFormState) {
        emit(current.copyWith(isSubmitting: false, generalError: errorMsg));
      }
      return;
    }

    // Exchange code for tokens
    await _exchangeCodeAndLogin(result.code!, verifier);
  }

  Future<void> _handleSignUp(String email, String password) async {
    Log.info(
      'Attempting sign up using email and password',
      name: 'DivineAuthCubit',
      category: LogCategory.auth,
    );

    final (result, verifier) = await _oauthClient.headlessRegister(
      email: email,
      password: password,
      scope: 'policy:full',
    );

    if (!result.success) {
      // Log the error code and description for debugging/monitoring
      Log.warning(
        'Sign up failed: errorCode=${result.errorCode}, '
        'errorDescription=${result.errorDescription}',
        name: 'DivineAuthCubit',
        category: LogCategory.auth,
      );

      // Convert server error codes to localized messages
      final errorMsg = _getLocalizedRegistrationError(
        result.errorCode,
        result.errorDescription,
      );

      final current = state;
      if (current is DivineAuthFormState) {
        emit(current.copyWith(isSubmitting: false, generalError: errorMsg));
      }
      return;
    }

    if (result.verificationRequired && result.deviceCode != null) {
      Log.info(
        'Email verification required for $email',
        name: 'DivineAuthCubit',
        category: LogCategory.auth,
      );

      // Persist verification data for cold-start deep link scenario
      await _pendingVerificationService.save(
        deviceCode: result.deviceCode!,
        verifier: verifier,
        email: email,
      );

      // Emit email verification state
      emit(
        DivineAuthEmailVerification(
          email: email,
          deviceCode: result.deviceCode!,
          verifier: verifier,
        ),
      );
    } else {
      final current = state;
      if (current is DivineAuthFormState) {
        emit(
          current.copyWith(
            isSubmitting: false,
            generalError: 'Registration complete. Please check your email.',
          ),
        );
      }
    }
  }

  Future<void> _exchangeCodeAndLogin(String code, String verifier) async {
    try {
      Log.info(
        'Exchanging code for tokens',
        name: 'DivineAuthCubit',
        category: LogCategory.auth,
      );

      final tokenResponse = await _oauthClient.exchangeCode(
        code: code,
        verifier: verifier,
      );

      // Get the session and sign in
      final session = KeycastSession.fromTokenResponse(tokenResponse);
      await _authService.signInWithDivineOAuth(session);

      Log.info(
        'Successfully signed in',
        name: 'DivineAuthCubit',
        category: LogCategory.auth,
      );

      emit(const DivineAuthSuccess());
    } on OAuthException catch (e) {
      Log.error(
        'OAuth exchange failed: ${e.message}',
        name: 'DivineAuthCubit',
        category: LogCategory.auth,
      );

      final current = state;
      if (current is DivineAuthFormState) {
        emit(current.copyWith(isSubmitting: false, generalError: e.message));
      }
    } catch (e) {
      Log.error(
        'Error exchanging code: $e',
        name: 'DivineAuthCubit',
        category: LogCategory.auth,
      );

      final current = state;
      if (current is DivineAuthFormState) {
        emit(
          current.copyWith(
            isSubmitting: false,
            generalError: 'Failed to complete authentication',
          ),
        );
      }
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    Log.info(
      'Sending password reset email to $email',
      name: 'DivineAuthCubit',
      category: LogCategory.auth,
    );

    try {
      final result = await _oauthClient.sendPasswordResetEmail(email);

      if (!result.success) {
        Log.warning(
          'Password reset failed: ${result.error}',
          name: 'DivineAuthCubit',
          category: LogCategory.auth,
        );
      }
    } catch (e) {
      Log.error(
        'Password reset error: $e',
        name: 'DivineAuthCubit',
        category: LogCategory.auth,
      );
    }
  }

  /// Create an anonymous account (skip email/password registration).
  ///
  /// Throws if identity creation fails.
  Future<void> skipWithAnonymousAccount() async {
    final current = state;
    if (current is! DivineAuthFormState) return;
    if (current.isSubmitting || current.isSkipping) return;

    emit(current.copyWith(isSkipping: true, clearGeneralError: true));

    try {
      await _authService.createAnonymousAccount();

      Log.info(
        'Anonymous account created successfully',
        name: 'DivineAuthCubit',
        category: LogCategory.auth,
      );

      emit(const DivineAuthSuccess());
    } catch (e) {
      Log.error(
        'Anonymous account creation failed: $e',
        name: 'DivineAuthCubit',
        category: LogCategory.auth,
      );

      final currentState = state;
      if (currentState is DivineAuthFormState) {
        emit(
          currentState.copyWith(
            isSkipping: false,
            generalError: 'Failed to create account. Please try again.',
          ),
        );
      }
    }
  }

  /// Return to form from email verification state
  void returnToForm() {
    final current = state;
    if (current is DivineAuthEmailVerification) {
      emit(DivineAuthFormState(email: current.email, isSignIn: false));
    } else {
      emit(const DivineAuthFormState());
    }
  }

  /// Convert server error codes to localized messages for registration errors.
  ///
  /// Known error codes from the server:
  /// - 'email_exists': Email is already registered
  /// - 'invalid_email': Email format is invalid
  /// - 'weak_password': Password doesn't meet requirements
  /// - 'registration_failed': Generic registration failure
  String _getLocalizedRegistrationError(
    String? errorCode,
    String? serverDescription,
  ) {
    switch (errorCode) {
      case 'CONFLICT':
        return 'This email is already registered. Please sign in instead.';
      case 'invalid_email':
        return 'Please enter a valid email address.';
      case 'weak_password':
        return 'Password is too weak. Please use a stronger password.';
      case 'rate_limited':
        return 'Too many attempts. Please try again later.';
      case 'server_error':
        return 'Server error. Please try again later.';
      case 'connection_error':
      case 'network_error':
        return 'Cannot connect to server. Please check your internet connection.';
      default:
        // For unknown error codes, log it so we can add handling later
        if (errorCode != null && errorCode != 'registration_failed') {
          Log.info(
            'Unhandled registration error code: $errorCode',
            name: 'DivineAuthCubit',
            category: LogCategory.auth,
          );
        }
        // Fall back to server description or generic message
        return serverDescription ?? 'Registration failed. Please try again.';
    }
  }
}
