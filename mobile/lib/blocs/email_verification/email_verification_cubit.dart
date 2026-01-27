// ABOUTME: Cubit for managing email verification state
// ABOUTME: Supports polling mode (after registration) and token mode (deep link)

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/utils/unified_logger.dart';

part 'email_verification_state.dart';

/// Cubit for managing email verification flow.
///
/// Supports two modes:
/// - **Polling mode**: After registration, polls the server until email is
///   verified, then exchanges the authorization code for tokens and logs the
///   user in.
/// - **Token mode**: Verifies email using a token from a deep link, then
///   redirects to login screen.
class EmailVerificationCubit extends Cubit<EmailVerificationState> {
  EmailVerificationCubit({
    required KeycastOAuth oauthClient,
    required AuthService authService,
  }) : _oauthClient = oauthClient,
       _authService = authService,
       super(const EmailVerificationInitial());

  final KeycastOAuth _oauthClient;
  final AuthService _authService;
  Timer? _pollTimer;

  // Polling mode state
  String? _deviceCode;
  String? _verifier;

  /// Start polling mode verification (after registration)
  ///
  /// [deviceCode] - Device code from registration response
  /// [verifier] - PKCE verifier for code exchange
  /// [email] - User's email address for display
  void startPolling({
    required String deviceCode,
    required String verifier,
    required String email,
  }) {
    _deviceCode = deviceCode;
    _verifier = verifier;

    Log.info(
      'Starting email verification polling for $email',
      name: 'EmailVerificationCubit',
      category: LogCategory.auth,
    );

    emit(
      EmailVerificationInProgress(
        mode: EmailVerificationMode.polling,
        email: email,
      ),
    );

    _startPollingTimer();
  }

  /// Start token mode verification (from deep link)
  ///
  /// [token] - Verification token from email link
  Future<void> verifyWithToken(String token) async {
    Log.info(
      'Starting email verification with token',
      name: 'EmailVerificationCubit',
      category: LogCategory.auth,
    );

    emit(const EmailVerificationInProgress(mode: EmailVerificationMode.token));

    try {
      final result = await _oauthClient.verifyEmail(token: token);

      if (!result.success) {
        Log.warning(
          'Email verification failed: ${result.error}',
          name: 'EmailVerificationCubit',
          category: LogCategory.auth,
        );
        emit(
          EmailVerificationFailure(
            mode: EmailVerificationMode.token,
            errorMessage: result.error ?? 'Failed to verify email',
          ),
        );
        return;
      }

      Log.info(
        'Email verification successful (token mode)',
        name: 'EmailVerificationCubit',
        category: LogCategory.auth,
      );
      emit(const EmailVerificationSuccess(mode: EmailVerificationMode.token));
    } catch (e) {
      Log.error(
        'Email verification error: $e',
        name: 'EmailVerificationCubit',
        category: LogCategory.auth,
      );
      emit(
        EmailVerificationFailure(
          mode: EmailVerificationMode.token,
          errorMessage: 'Network error: $e',
        ),
      );
    }
  }

  /// Verify email with token without changing state (used during polling mode)
  ///
  /// When a deep link arrives while polling, we call verifyEmail to mark
  /// the email as verified on the server. The polling will then complete
  /// and handle the login flow.
  Future<void> verifyEmailOnly(String token) async {
    Log.info(
      'Verifying email (polling mode active)',
      name: 'EmailVerificationCubit',
      category: LogCategory.auth,
    );

    try {
      final result = await _oauthClient.verifyEmail(token: token);

      if (!result.success) {
        Log.warning(
          'Email verification failed: ${result.error}',
          name: 'EmailVerificationCubit',
          category: LogCategory.auth,
        );
        // Don't emit failure - let polling continue and handle errors
        return;
      }

      Log.info(
        'Email verified successfully, polling will complete login',
        name: 'EmailVerificationCubit',
        category: LogCategory.auth,
      );
      // Don't emit success - polling will handle the login flow
    } catch (e) {
      Log.error(
        'Email verification error: $e',
        name: 'EmailVerificationCubit',
        category: LogCategory.auth,
      );
      // Don't emit failure - let polling continue
    }
  }

  void _startPollingTimer() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  Future<void> _poll() async {
    if (_deviceCode == null) {
      _pollTimer?.cancel();
      return;
    }

    try {
      final result = await _oauthClient.pollForCode(_deviceCode!);

      switch (result.status) {
        case PollStatus.complete:
          _pollTimer?.cancel();
          if (result.code != null && _verifier != null) {
            await _exchangeCodeAndLogin(result.code!, _verifier!);
          } else {
            emit(
              const EmailVerificationFailure(
                mode: EmailVerificationMode.polling,
                errorMessage: 'Missing authorization code or verifier',
              ),
            );
          }

        case PollStatus.pending:
          // Keep polling
          break;

        case PollStatus.error:
          Log.error(
            'Polling error: ${result.error}',
            name: 'EmailVerificationCubit',
            category: LogCategory.auth,
          );
          // Don't stop polling on transient errors, but log them
          break;
      }
    } catch (e) {
      Log.error(
        'Poll exception: $e',
        name: 'EmailVerificationCubit',
        category: LogCategory.auth,
      );
      // Continue polling despite errors
    }
  }

  Future<void> _exchangeCodeAndLogin(String code, String verifier) async {
    try {
      Log.info(
        'Exchanging authorization code for tokens',
        name: 'EmailVerificationCubit',
        category: LogCategory.auth,
      );

      final tokenResponse = await _oauthClient.exchangeCode(
        code: code,
        verifier: verifier,
      );

      // Create session and sign in
      final session = KeycastSession.fromTokenResponse(tokenResponse);
      await _authService.signInWithDivineOAuth(session);

      Log.info(
        'Email verification and login successful (polling mode)',
        name: 'EmailVerificationCubit',
        category: LogCategory.auth,
      );

      emit(const EmailVerificationSuccess(mode: EmailVerificationMode.polling));
    } on OAuthException catch (e) {
      Log.error(
        'OAuth exception during code exchange: ${e.message}',
        name: 'EmailVerificationCubit',
        category: LogCategory.auth,
      );
      emit(
        EmailVerificationFailure(
          mode: EmailVerificationMode.polling,
          errorMessage: e.message,
        ),
      );
    } catch (e) {
      Log.error(
        'Error exchanging code: $e',
        name: 'EmailVerificationCubit',
        category: LogCategory.auth,
      );
      emit(
        const EmailVerificationFailure(
          mode: EmailVerificationMode.polling,
          errorMessage: 'Failed to complete authentication',
        ),
      );
    }
  }

  /// Cancel polling and clean up
  void cancelPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _deviceCode = null;
    _verifier = null;
  }

  @override
  Future<void> close() {
    _pollTimer?.cancel();
    return super.close();
  }
}
