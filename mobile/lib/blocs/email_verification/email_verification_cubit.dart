// ABOUTME: Cubit for email verification polling that survives navigation
// ABOUTME: Manages polling lifecycle, timeout, and auth completion

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/utils/unified_logger.dart';

part 'email_verification_state.dart';

/// Cubit for managing email verification polling independently of widget
/// lifecycle.
///
/// Handles:
/// - Starting/stopping polling for email verification
/// - Periodic polling every 3 seconds
/// - Timeout after 15 minutes
/// - Code exchange and authentication on success
/// - Transient network error handling (continues polling)
/// - Auth errors (stops polling with error state)
class EmailVerificationCubit extends Cubit<EmailVerificationState> {
  EmailVerificationCubit({
    required KeycastOAuth oauthClient,
    required AuthService authService,
  }) : _oauthClient = oauthClient,
       _authService = authService,
       super(const EmailVerificationState());

  final KeycastOAuth _oauthClient;
  final AuthService _authService;

  Timer? _pollTimer;
  Timer? _timeoutTimer;
  String? _pendingDeviceCode;
  String? _pendingVerifier;

  /// Polling interval duration
  static const _pollInterval = Duration(seconds: 3);

  /// Polling timeout duration (15 minutes)
  static const _pollingTimeout = Duration(minutes: 15);

  /// Start polling for email verification
  void startPolling({
    required String deviceCode,
    required String verifier,
    required String email,
  }) {
    Log.info(
      'Starting email verification polling for $email',
      name: 'EmailVerificationCubit',
      category: LogCategory.auth,
    );

    _pendingDeviceCode = deviceCode;
    _pendingVerifier = verifier;

    emit(
      EmailVerificationState(
        status: EmailVerificationStatus.polling,
        pendingEmail: email,
      ),
    );

    // Cancel any existing timers
    _pollTimer?.cancel();
    _timeoutTimer?.cancel();

    // Start periodic polling
    _pollTimer = Timer.periodic(_pollInterval, (_) => _poll());

    // Set timeout to stop polling after 15 minutes
    _timeoutTimer = Timer(_pollingTimeout, _onTimeout);
  }

  /// Stop polling (e.g., user cancelled)
  void stopPolling() {
    Log.info(
      'Stopping email verification polling',
      name: 'EmailVerificationCubit',
      category: LogCategory.auth,
    );
    _cleanup();
    emit(const EmailVerificationState());
  }

  void _onTimeout() {
    Log.warning(
      'Email verification polling timed out after '
      '${_pollingTimeout.inMinutes} minutes',
      name: 'EmailVerificationCubit',
      category: LogCategory.auth,
    );
    _cleanup();
    emit(
      const EmailVerificationState(
        status: EmailVerificationStatus.failure,
        error: 'Verification timed out. Please try registering again.',
      ),
    );
  }

  Future<void> _poll() async {
    if (_pendingDeviceCode == null) {
      Log.warning(
        'Poll called but _pendingDeviceCode is null, cleaning up',
        name: 'EmailVerificationCubit',
        category: LogCategory.auth,
      );
      _cleanup();
      return;
    }

    try {
      Log.info(
        'Polling for email verification',
        name: 'EmailVerificationCubit',
        category: LogCategory.auth,
      );
      final result = await _oauthClient.pollForCode(_pendingDeviceCode!);

      Log.info(
        'Poll result: status=${result.status}, hasCode=${result.code != null}, '
        'error=${result.error}',
        name: 'EmailVerificationCubit',
        category: LogCategory.auth,
      );

      switch (result.status) {
        case PollStatus.complete:
          Log.info(
            'Email verification complete! code=${result.code != null}, '
            'verifier=${_pendingVerifier != null}',
            name: 'EmailVerificationCubit',
            category: LogCategory.auth,
          );
          _pollTimer?.cancel();
          if (result.code != null && _pendingVerifier != null) {
            await _exchangeCodeAndLogin(result.code!, _pendingVerifier!);
          } else {
            // Edge case: completion detected but missing code or verifier
            Log.error(
              'Verification complete but missing code or verifier! '
              'code=${result.code}, verifier=$_pendingVerifier',
              name: 'EmailVerificationCubit',
              category: LogCategory.auth,
            );
            _cleanup();
            emit(
              const EmailVerificationState(
                status: EmailVerificationStatus.failure,
                error: 'Verification failed - missing authorization code',
              ),
            );
          }

        case PollStatus.pending:
          // Keep polling - use info level so it's visible in logs
          Log.info(
            'Email verification still pending, will poll again in 3s',
            name: 'EmailVerificationCubit',
            category: LogCategory.auth,
          );

        case PollStatus.error:
          final errorMsg = result.error ?? 'Verification failed';
          // Check if this is a transient network error vs a real auth error
          final isNetworkError =
              errorMsg.contains('Network error') ||
              errorMsg.contains('SocketException') ||
              errorMsg.contains('ClientException') ||
              errorMsg.contains('host lookup');

          if (isNetworkError) {
            // Network errors are transient - keep polling
            Log.warning(
              'Transient network error during poll, will retry: $errorMsg',
              name: 'EmailVerificationCubit',
              category: LogCategory.auth,
            );
            // Don't stop polling - it will retry in 3 seconds
          } else {
            // Real auth error (e.g., expired code, invalid code) - stop polling
            Log.error(
              'Email verification polling error (stopping): $errorMsg',
              name: 'EmailVerificationCubit',
              category: LogCategory.auth,
            );
            _cleanup();
            emit(
              EmailVerificationState(
                status: EmailVerificationStatus.failure,
                error: errorMsg,
              ),
            );
          }
      }
    } catch (e, stackTrace) {
      Log.error(
        'Email verification polling exception: $e\n$stackTrace',
        name: 'EmailVerificationCubit',
        category: LogCategory.auth,
      );
      // Don't stop polling on transient errors, just log
    }
  }

  /// Maximum retries for token exchange on network errors
  static const _maxExchangeRetries = 3;

  /// Delay between exchange retries
  static const _exchangeRetryDelay = Duration(seconds: 2);

  Future<void> _exchangeCodeAndLogin(String code, String verifier) async {
    for (var attempt = 1; attempt <= _maxExchangeRetries; attempt++) {
      try {
        Log.info(
          'Attempting token exchange (attempt $attempt/$_maxExchangeRetries)',
          name: 'EmailVerificationCubit',
          category: LogCategory.auth,
        );

        final tokenResponse = await _oauthClient.exchangeCode(
          code: code,
          verifier: verifier,
        );

        // Get the session and sign in
        final session = KeycastSession.fromTokenResponse(tokenResponse);
        await _authService.signInWithDivineOAuth(session);

        // Verify sign-in actually succeeded (signInWithDivineOAuth catches
        // errors internally and sets state to unauthenticated without throwing)
        if (_authService.isAnonymous) {
          // Sign-in failed silently - treat as network error and retry
          throw Exception('Sign-in failed - auth service reports anonymous');
        }

        Log.info(
          'Successfully signed in after email verification',
          name: 'EmailVerificationCubit',
          category: LogCategory.auth,
        );

        // Clear state and emit success
        _cleanup();
        emit(
          const EmailVerificationState(status: EmailVerificationStatus.success),
        );
        return; // Success - exit the retry loop
      } on OAuthException catch (e) {
        // OAuth errors are not retryable (e.g., invalid code, expired code)
        Log.error(
          'OAuth exchange failed: ${e.message}',
          name: 'EmailVerificationCubit',
          category: LogCategory.auth,
        );
        _cleanup();
        emit(
          EmailVerificationState(
            status: EmailVerificationStatus.failure,
            error: e.message,
          ),
        );
        return; // Don't retry OAuth errors
      } catch (e) {
        // Network errors - retry if we have attempts left
        final isLastAttempt = attempt == _maxExchangeRetries;
        Log.warning(
          'Token exchange network error (attempt $attempt/$_maxExchangeRetries): $e',
          name: 'EmailVerificationCubit',
          category: LogCategory.auth,
        );

        if (isLastAttempt) {
          Log.error(
            'Token exchange failed after $_maxExchangeRetries attempts',
            name: 'EmailVerificationCubit',
            category: LogCategory.auth,
          );
          _cleanup();
          emit(
            const EmailVerificationState(
              status: EmailVerificationStatus.failure,
              error: 'Network error during sign-in. Please try again.',
            ),
          );
          return;
        }

        // Wait before retrying
        await Future<void>.delayed(_exchangeRetryDelay);
      }
    }
  }

  void _cleanup() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _pendingDeviceCode = null;
    _pendingVerifier = null;
  }

  @override
  Future<void> close() {
    _cleanup();
    return super.close();
  }
}
