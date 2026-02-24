// ABOUTME: Cubit for email verification polling that survives navigation
// ABOUTME: Manages polling lifecycle, timeout, and auth completion

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
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

  /// Tracks the device code that was already successfully exchanged.
  ///
  /// Static so it persists across cubit instances within the same Dart isolate
  /// (which survives Flutter engine restarts on Android). When one cubit
  /// completes exchange for a device code, zombie cubits polling with the same
  /// device code will see the match and stop. Safe for re-registration because
  /// new registrations receive a different device code.
  static String? _completedDeviceCode;

  Timer? _pollTimer;
  Timer? _timeoutTimer;
  String? _pendingDeviceCode;
  String? _pendingVerifier;

  /// Reset the static completed device code tracking.
  /// Only for use in tests to ensure test isolation.
  @visibleForTesting
  static void resetCompletedDeviceCode() => _completedDeviceCode = null;

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
      'startPolling called for $email '
      '(cubit=$hashCode, authSvc=${_authService.hashCode}, '
      'hasExistingTimer=${_pollTimer != null})',
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

  /// Emit a failure state from outside the cubit (e.g., token verification).
  void emitFailure(String error) {
    _cleanup();
    emit(
      EmailVerificationState(
        status: EmailVerificationStatus.failure,
        error: error,
      ),
    );
  }

  /// Stop polling (e.g., user cancelled)
  void stopPolling() {
    Log.info(
      'stopPolling called (cubit=$hashCode, hasTimer=${_pollTimer != null})',
      name: 'EmailVerificationCubit',
      category: LogCategory.auth,
    );
    _cleanup();
    // Don't reset to initial state if verification already succeeded —
    // cleanup was already performed by the cubit and resetting would cause
    // a brief UI flash of the pre-verification content before navigation.
    if (state.status != EmailVerificationStatus.success) {
      emit(const EmailVerificationState());
    }
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
    // Guard: stop polling if another cubit already completed this device code.
    // Handles orphaned cubits from Flutter engine restarts where a different
    // cubit instance completed verification but this one's timer survived.
    // The static field crosses instance boundaries within the Dart isolate.
    if (_completedDeviceCode != null &&
        _completedDeviceCode == _pendingDeviceCode) {
      Log.info(
        'Device code already completed by another cubit, stopping zombie poll '
        '(cubit=$hashCode)',
        name: 'EmailVerificationCubit',
        category: LogCategory.auth,
      );
      _cleanup();
      // Emit success so the screen's BlocConsumer navigates away instead of
      // staying stuck on "Waiting for verification..."
      emit(
        const EmailVerificationState(status: EmailVerificationStatus.success),
      );
      return;
    }

    // Guard: stop polling if user is already authenticated on this auth service.
    if (_authService.isAuthenticated) {
      Log.info(
        'Auth already authenticated, stopping orphaned poll '
        '(cubit=$hashCode)',
        name: 'EmailVerificationCubit',
        category: LogCategory.auth,
      );
      _cleanup();
      return;
    }

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
        'Polling for email verification '
        '(cubit=$hashCode, authSvc=${_authService.hashCode}, '
        'isAuth=${_authService.isAuthenticated}, '
        'hasTimer=${_pollTimer != null})',
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

        final session = KeycastSession.fromTokenResponse(tokenResponse);

        Log.info(
          'Token exchange successful, showing verification confirmation',
          name: 'EmailVerificationCubit',
          category: LogCategory.auth,
        );

        // Mark this device code as completed so zombie cubits from engine
        // restarts (which hold different AuthService instances) will stop.
        _completedDeviceCode = _pendingDeviceCode;

        // Emit success BEFORE signing in, because signInWithDivineOAuth
        // triggers an auth state change that causes GoRouter to redirect
        // to the home screen immediately. By emitting first, the UI can
        // display "Email Verified!" before the redirect occurs.
        _cleanup();
        emit(
          const EmailVerificationState(status: EmailVerificationStatus.success),
        );

        // Brief pause so the user sees the success confirmation
        await Future<void>.delayed(const Duration(milliseconds: 600));

        // Now sign in — this triggers GoRouter redirect to home
        await _authService.signInWithDivineOAuth(session);

        // Verify sign-in actually succeeded (signInWithDivineOAuth catches
        // errors internally and sets state to unauthenticated without throwing)
        if (_authService.isAnonymous) {
          Log.error(
            'Sign-in failed after email verification',
            name: 'EmailVerificationCubit',
            category: LogCategory.auth,
          );
          emit(
            const EmailVerificationState(
              status: EmailVerificationStatus.failure,
              error: 'Sign-in failed. Please try logging in manually.',
            ),
          );
        }

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
    Log.info(
      '_cleanup (cubit=$hashCode, hadPollTimer=${_pollTimer != null}, '
      'hadTimeoutTimer=${_timeoutTimer != null})',
      name: 'EmailVerificationCubit',
      category: LogCategory.auth,
    );
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
