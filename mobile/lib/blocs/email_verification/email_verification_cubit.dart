// ABOUTME: Cubit for email verification polling that survives navigation
// ABOUTME: Manages polling lifecycle, timeout, and auth completion

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:invite_api_client/invite_api_client.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/utils/invite_error_utils.dart';
import 'package:openvine/utils/sensitive_uri_for_logs.dart';
import 'package:unified_logger/unified_logger.dart';

part 'email_verification_state.dart';

enum EmailTokenVerificationStatus {
  success,
  terminalFailure,
  transientFailure,
}

final class EmailTokenVerificationResult extends Equatable {
  const EmailTokenVerificationResult._(this.status, {this.errorCode});

  const EmailTokenVerificationResult.success()
    : this._(EmailTokenVerificationStatus.success);

  const EmailTokenVerificationResult.terminalFailure(
    EmailVerificationError errorCode,
  ) : this._(
        EmailTokenVerificationStatus.terminalFailure,
        errorCode: errorCode,
      );

  const EmailTokenVerificationResult.transientFailure()
    : this._(EmailTokenVerificationStatus.transientFailure);

  final EmailTokenVerificationStatus status;
  final EmailVerificationError? errorCode;

  bool get isSuccess => status == EmailTokenVerificationStatus.success;

  @override
  List<Object?> get props => [status, errorCode];
}

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
    InviteApiClient? inviteApiClient,
  }) : _oauthClient = oauthClient,
       _authService = authService,
       _inviteApiClient = inviteApiClient,
       super(const EmailVerificationState());

  final KeycastOAuth _oauthClient;
  final AuthService _authService;
  final InviteApiClient? _inviteApiClient;

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
  String? _pendingInviteCode;
  String? _pendingVerificationToken;
  bool _isVerifyingEmailToken = false;

  /// Cubit-internal backoff counter for [_schedulePoll]. Lives outside
  /// state because the UI never reads it — analogous to [_pollTimer] and
  /// [_pendingDeviceCode]. See `rules/state_management.md` "No Mutable
  /// Instance Variables in BLoC" for the exception this falls under.
  int _pollTickIndex = 0;

  /// Reset the static completed device code tracking.
  /// Only for use in tests to ensure test isolation.
  @visibleForTesting
  static void resetCompletedDeviceCode() => _completedDeviceCode = null;

  /// Polling timeout duration (15 minutes)
  static const _pollingTimeout = Duration(minutes: 15);

  /// Bounded exponential backoff schedule for the verification poll.
  ///
  /// Reasons for the specific shape:
  /// - First two ticks at 3 s preserve snappy UX for users who click the
  ///   email link within a few seconds.
  /// - Subsequent ticks grow until they hit the 30 s cap, so a user who
  ///   never clicks costs roughly 33 polls over the 15-min window instead
  ///   of the 300 polls a fixed 3 s interval would issue.
  @visibleForTesting
  static const pollBackoffSchedule = <Duration>[
    Duration(seconds: 3),
    Duration(seconds: 3),
    Duration(seconds: 5),
    Duration(seconds: 8),
    Duration(seconds: 13),
    Duration(seconds: 21),
  ];

  @visibleForTesting
  static const pollBackoffCap = Duration(seconds: 30);

  static Duration _delayForTick(int tickIndex) {
    if (tickIndex < pollBackoffSchedule.length) {
      return pollBackoffSchedule[tickIndex];
    }
    return pollBackoffCap;
  }

  /// Start polling for email verification
  void startPolling({
    required String deviceCode,
    required String verifier,
    required String email,
    String? inviteCode,
  }) {
    Log.info(
      'startPolling called for ${redactEmailForLogs(email)} '
      '(cubit=$hashCode, authSvc=${_authService.hashCode}, '
      'hasExistingTimer=${_pollTimer != null})',
      name: 'EmailVerificationCubit',
      category: LogCategory.auth,
    );

    _pendingDeviceCode = deviceCode;
    _pendingVerifier = verifier;
    _pendingInviteCode = inviteCode == null
        ? null
        : InviteApiClient.normalizeCode(inviteCode);

    emit(
      EmailVerificationState(
        status: EmailVerificationStatus.polling,
        pendingEmail: email,
      ),
    );

    // Cancel any existing timers
    _pollTimer?.cancel();
    _timeoutTimer?.cancel();

    _pollTickIndex = 0;
    _schedulePoll();

    // Set timeout to stop polling after 15 minutes
    _timeoutTimer = Timer(_pollingTimeout, _onTimeout);
  }

  void _schedulePoll() {
    final delay = _delayForTick(_pollTickIndex);
    _pollTimer = Timer(delay, () async {
      _pollTickIndex++;
      await _poll();
      // Continue only while we still have a pending verification. _cleanup()
      // (called on success, terminal failure, or close) nulls
      // _pendingDeviceCode, which stops the recursion cleanly. Using the
      // pending state — not _pollTimer — as the guard keeps intent explicit
      // and survives future cleanup paths that forget to clear the timer.
      if (!isClosed && _pendingDeviceCode != null) {
        _schedulePoll();
      }
    });
  }

  /// Emit a failure state from outside the cubit (e.g., token verification).
  ///
  /// Callers must pass a reason code — state never carries English strings;
  /// the UI layer is responsible for mapping the code to localized copy.
  void emitFailure(EmailVerificationError errorCode, {String? pendingEmail}) {
    _cleanup();
    emit(
      EmailVerificationState(
        status: EmailVerificationStatus.failure,
        pendingEmail: pendingEmail,
        errorCode: errorCode,
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

  EmailVerificationError _errorForVerifyEmailResult(VerifyEmailResult result) {
    switch (result.failure) {
      case KeycastAuthFailure.emailAlreadyRegistered:
        return EmailVerificationError.emailAlreadyRegistered;
      case KeycastAuthFailure.network:
      case KeycastAuthFailure.temporary:
        return EmailVerificationError.verificationConnectionError;
      case KeycastAuthFailure.expiredVerification:
      case KeycastAuthFailure.unknown:
      case null:
        return EmailVerificationError.verificationLinkExpired;
    }
  }

  Future<EmailTokenVerificationResult> verifyEmailToken({
    required String token,
    String? pendingEmail,
    bool keepPollingOnTransient = false,
  }) async {
    if (keepPollingOnTransient) {
      _pendingVerificationToken = token;
    }

    return _verifyEmailTokenWithRetries(
      token: token,
      pendingEmail: pendingEmail,
      keepPollingOnTransient: keepPollingOnTransient,
    );
  }

  Future<EmailTokenVerificationResult> _verifyPendingTokenIfNeeded() async {
    final token = _pendingVerificationToken;
    if (token == null || _isVerifyingEmailToken) {
      return const EmailTokenVerificationResult.success();
    }

    return _verifyEmailTokenWithRetries(
      token: token,
      pendingEmail: state.pendingEmail,
      keepPollingOnTransient: true,
    );
  }

  Future<EmailTokenVerificationResult> _verifyEmailTokenWithRetries({
    required String token,
    required String? pendingEmail,
    required bool keepPollingOnTransient,
  }) async {
    _isVerifyingEmailToken = true;
    try {
      for (var attempt = 1; attempt <= _maxVerifyRetries; attempt++) {
        try {
          Log.info(
            'Verifying email token (attempt $attempt/$_maxVerifyRetries)',
            name: 'EmailVerificationCubit',
            category: LogCategory.auth,
          );
          final result = await _oauthClient.verifyEmail(token: token);
          if (result.success) {
            if (_pendingVerificationToken == token) {
              _pendingVerificationToken = null;
            }
            return const EmailTokenVerificationResult.success();
          }

          if (result.isTransientFailure) {
            final transientResult = await _handleTransientVerifyFailure(
              attempt: attempt,
              error: result.error,
              pendingEmail: pendingEmail,
              keepPollingOnTransient: keepPollingOnTransient,
            );
            if (transientResult != null) {
              return transientResult;
            }
            continue;
          }

          return _emitVerifyEmailFailure(result, pendingEmail: pendingEmail);
        } catch (e) {
          final transientResult = await _handleTransientVerifyFailure(
            attempt: attempt,
            error: e,
            pendingEmail: pendingEmail,
            keepPollingOnTransient: keepPollingOnTransient,
          );
          if (transientResult != null) {
            return transientResult;
          }
        }
      }
    } finally {
      _isVerifyingEmailToken = false;
    }

    return const EmailTokenVerificationResult.transientFailure();
  }

  Future<EmailTokenVerificationResult?> _handleTransientVerifyFailure({
    required int attempt,
    required Object? error,
    required String? pendingEmail,
    required bool keepPollingOnTransient,
  }) async {
    final isLastAttempt = attempt == _maxVerifyRetries;
    Log.warning(
      'Transient email-token verification failure '
      '(attempt $attempt/$_maxVerifyRetries): $error',
      name: 'EmailVerificationCubit',
      category: LogCategory.auth,
    );

    if (!isLastAttempt) {
      await Future<void>.delayed(_verifyRetryDelay);
      return null;
    }

    if (keepPollingOnTransient) {
      Log.warning(
        'Keeping verification poll active after transient token failure',
        name: 'EmailVerificationCubit',
        category: LogCategory.auth,
      );
      return const EmailTokenVerificationResult.transientFailure();
    }

    emitFailure(
      EmailVerificationError.verificationConnectionError,
      pendingEmail: _pendingEmailForFailure(
        EmailVerificationError.verificationConnectionError,
        pendingEmail,
      ),
    );
    return const EmailTokenVerificationResult.terminalFailure(
      EmailVerificationError.verificationConnectionError,
    );
  }

  EmailTokenVerificationResult _emitVerifyEmailFailure(
    VerifyEmailResult result, {
    required String? pendingEmail,
  }) {
    final errorCode = _errorForVerifyEmailResult(result);
    Log.warning(
      'Email verification failed: status=${result.statusCode}, '
      'code=${result.errorCode}, failure=${result.failure}, '
      'mappedError=$errorCode, error=${result.error}',
      name: 'EmailVerificationCubit',
      category: LogCategory.auth,
    );
    emitFailure(
      errorCode,
      pendingEmail: _pendingEmailForFailure(errorCode, pendingEmail),
    );
    return EmailTokenVerificationResult.terminalFailure(errorCode);
  }

  String? _pendingEmailForFailure(
    EmailVerificationError errorCode,
    String? pendingEmail,
  ) {
    if (errorCode != EmailVerificationError.emailAlreadyRegistered) {
      return null;
    }
    return pendingEmail ?? state.pendingEmail;
  }

  /// Reset to initial state unconditionally.
  ///
  /// Called when a new verification screen opens to clear stale state from
  /// a previous verification (e.g., User A verified, now User B's deep link
  /// arrives). Without this, the builder would render success UI from the
  /// previous verification instead of the new verification flow.
  void reset() {
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
        errorCode: EmailVerificationError.timeout,
      ),
    );
  }

  EmailVerificationError _errorForPollFailure(PollResult result) {
    switch (result.failure) {
      case KeycastAuthFailure.emailAlreadyRegistered:
        return EmailVerificationError.emailAlreadyRegistered;
      case KeycastAuthFailure.expiredVerification:
        return EmailVerificationError.verificationLinkExpired;
      case KeycastAuthFailure.temporary:
      case KeycastAuthFailure.network:
      case KeycastAuthFailure.unknown:
      case null:
        return EmailVerificationError.pollFailed;
    }
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

    // Guard: stop polling if user completed OAuth sign-in on this auth service.
    // Use isRegistered (not isAuthenticated) because anonymous users are
    // authenticated but still need polling to complete the secure-account flow.
    //
    // isAuthenticated is also required: isRegistered checks _authSource which
    // persists across sign-outs and remains divineOAuth even when authState is
    // unauthenticated. Without this gate, a new user registering on a device
    // that previously had a signed-out OAuth session would have polling killed
    // on the first tick — leaving them stuck on "Waiting for verification"
    // even after clicking the email link.
    if (_authService.isAuthenticated && _authService.isRegistered) {
      Log.info(
        'Auth already registered, stopping orphaned poll '
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
      final tokenResult = await _verifyPendingTokenIfNeeded();
      if (tokenResult.status == EmailTokenVerificationStatus.terminalFailure) {
        return;
      }

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
            // Edge case: completion detected but missing code or verifier.
            // Log presence only — BYOK verifiers embed the raw nsec and
            // captured logs are uploaded with bug reports.
            Log.error(
              'Verification complete but missing code or verifier! '
              'code=${result.code != null}, '
              'verifier=${_pendingVerifier != null}',
              name: 'EmailVerificationCubit',
              category: LogCategory.auth,
            );
            _cleanup();
            emit(
              const EmailVerificationState(
                status: EmailVerificationStatus.failure,
                errorCode: EmailVerificationError.missingAuthCode,
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
          if (result.isTransientFailure) {
            // Network errors are transient - keep polling
            Log.warning(
              'Transient error during poll, will retry: '
              'status=${result.statusCode}, code=${result.errorCode}, '
              'failure=${result.failure}, error=$errorMsg',
              name: 'EmailVerificationCubit',
              category: LogCategory.auth,
            );
            // Don't stop polling - it will retry in 3 seconds
          } else {
            final errorCode = _errorForPollFailure(result);
            final pendingEmail = state.pendingEmail;
            Log.error(
              'Email verification polling error (stopping): '
              'status=${result.statusCode}, code=${result.errorCode}, '
              'failure=${result.failure}, mappedError=$errorCode, '
              'error=$errorMsg',
              name: 'EmailVerificationCubit',
              category: LogCategory.auth,
            );
            _cleanup();
            emit(
              EmailVerificationState(
                status: EmailVerificationStatus.failure,
                pendingEmail:
                    errorCode == EmailVerificationError.emailAlreadyRegistered
                    ? pendingEmail
                    : null,
                errorCode: errorCode,
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

  /// Maximum retries for token verification on network errors
  static const _maxVerifyRetries = 3;

  /// Delay between exchange retries
  static const _exchangeRetryDelay = Duration(seconds: 2);

  /// Delay between token verification retries
  static const _verifyRetryDelay = Duration(seconds: 2);

  /// Maximum retries for invite consumption when the server returns
  /// HTTP 409 ("Another consumption is in progress; retry"). The conflict
  /// happens when the server is briefly serializing concurrent attempts
  /// for the same invite — clearing in a few hundred ms.
  static const _maxConsumeRetries = 3;

  /// Delay between invite-consumption retries on 409 conflict.
  static const _consumeRetryDelay = Duration(milliseconds: 500);

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
        await _consumeInviteWithSessionIfNeeded(session);

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
              errorCode: EmailVerificationError.signInFailed,
            ),
          );
        }

        return; // Success - exit the retry loop
      } on InviteApiException catch (e) {
        await _authService.clearPendingDivineOAuthSession();
        Log.error(
          'Invite activation failed: '
          '${InviteErrorUtils.activationFailureLogDetails(e)}',
          name: 'EmailVerificationCubit',
          category: LogCategory.auth,
        );
        final inviteCode = _pendingInviteCode;
        _cleanup();
        emit(
          EmailVerificationState(
            status: EmailVerificationStatus.failure,
            errorCode: InviteErrorUtils.toEmailVerificationError(e),
            showInviteGateRecovery: inviteCode != null,
            inviteRecoveryCode: inviteCode,
          ),
        );
        return;
      } on OAuthException catch (e) {
        // OAuth errors are not retryable (e.g., invalid code, expired code)
        Log.error(
          'OAuth exchange failed: ${e.message}',
          name: 'EmailVerificationCubit',
          category: LogCategory.auth,
        );
        _cleanup();
        emit(
          const EmailVerificationState(
            status: EmailVerificationStatus.failure,
            errorCode: EmailVerificationError.oauthExchange,
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
              errorCode: EmailVerificationError.networkExchange,
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
    _pollTickIndex = 0;
    _pendingDeviceCode = null;
    _pendingVerifier = null;
    _pendingInviteCode = null;
    _pendingVerificationToken = null;
  }

  Future<void> _consumeInviteWithSessionIfNeeded(KeycastSession session) async {
    final inviteCode = _pendingInviteCode;
    final inviteApiClient = _inviteApiClient;
    if (inviteCode == null || inviteApiClient == null) {
      return;
    }

    for (var attempt = 1; attempt <= _maxConsumeRetries; attempt++) {
      try {
        await inviteApiClient.consumeInviteWithSession(
          code: inviteCode,
          oauthConfig: _oauthClient.config,
          session: session,
        );
        return;
      } on InviteApiException catch (e) {
        final isLastAttempt = attempt == _maxConsumeRetries;
        if (e.statusCode != 409 || isLastAttempt) {
          rethrow;
        }
        Log.warning(
          'Invite consumption conflict, retrying in '
          '${_consumeRetryDelay.inMilliseconds}ms '
          '(attempt $attempt/$_maxConsumeRetries): ${e.message}',
          name: 'EmailVerificationCubit',
          category: LogCategory.auth,
        );
        await Future<void>.delayed(_consumeRetryDelay);
      }
    }
  }

  @override
  Future<void> close() {
    _cleanup();
    return super.close();
  }
}
