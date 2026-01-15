// ABOUTME: Mixin providing shared email verification polling logic for auth screens
// ABOUTME: Handles device code polling, verification dialogs, and OAuth code exchange

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Mixin providing email verification polling logic for auth screens.
///
/// Requires the mixing class to:
/// - Be a ConsumerState<T>
/// - Call disposeVerification() in dispose()
/// - Provide setErrorMessage() callback for error handling
mixin EmailVerificationMixin<T extends ConsumerStatefulWidget>
    on ConsumerState<T> {
  // Pending verification state
  String? _pendingDeviceCode;
  String? _pendingVerifier;
  String? _pendingEmail;
  Timer? _pollTimer;

  // Getters for state
  String? get pendingDeviceCode => _pendingDeviceCode;
  String? get pendingVerifier => _pendingVerifier;
  String? get pendingEmail => _pendingEmail;

  /// Override this to handle error messages
  void setErrorMessage(String? message);

  /// Set pending verification state after registration
  void setPendingVerification({
    required String deviceCode,
    required String verifier,
    required String email,
  }) {
    _pendingDeviceCode = deviceCode;
    _pendingVerifier = verifier;
    _pendingEmail = email;
  }

  /// Clear pending verification state
  void clearPendingVerification() {
    _pendingDeviceCode = null;
    _pendingVerifier = null;
    _pendingEmail = null;
  }

  /// Start polling for email verification
  void startVerificationPolling(KeycastOAuth oauth) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_pendingDeviceCode == null || !mounted) {
        timer.cancel();
        return;
      }

      final result = await oauth.pollForCode(_pendingDeviceCode!);

      switch (result.status) {
        case PollStatus.complete:
          timer.cancel();
          if (result.code != null && _pendingVerifier != null) {
            await exchangeCodeAndLogin(oauth, result.code!, _pendingVerifier!);
          }
        case PollStatus.pending:
          // Keep polling
          break;
        case PollStatus.error:
          timer.cancel();
          if (mounted) {
            setErrorMessage(result.error ?? 'Verification failed');
          }
      }
    });
  }

  /// Show the email verification dialog
  void showVerificationDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: VineTheme.cardBackground,
        title: const Row(
          children: [
            Icon(Icons.email_outlined, color: VineTheme.vineGreen),
            SizedBox(width: 12),
            Text('Verify Your Email', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'We sent a verification link to:',
              style: TextStyle(color: Colors.grey[400]),
            ),
            const SizedBox(height: 8),
            Text(
              _pendingEmail ?? '',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Click the link in your email to complete registration. '
              'You can continue using the app in the meantime.',
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: VineTheme.vineGreen,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  'Waiting for verification...',
                  style: TextStyle(color: VineTheme.vineGreen, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              continueToApp();
            },
            child: const Text(
              'Continue to App',
              style: TextStyle(color: VineTheme.vineGreen),
            ),
          ),
        ],
      ),
    );
  }

  /// Navigate to app after verification (polling continues in background)
  void continueToApp() {
    if (mounted) {
      context.go('/home/0');
    }
  }

  /// Exchange authorization code for tokens and complete login
  Future<void> exchangeCodeAndLogin(
    KeycastOAuth oauth,
    String code,
    String verifier,
  ) async {
    try {
      final tokenResponse = await oauth.exchangeCode(
        code: code,
        verifier: verifier,
      );

      // Get the session and sign in
      final session = KeycastSession.fromTokenResponse(tokenResponse);
      final authService = ref.read(authServiceProvider);
      await authService.signInWithDivineOAuth(session);

      // Clear pending state
      clearPendingVerification();

      // Navigation will be handled by auth state listener
    } on OAuthException catch (e) {
      setErrorMessage(e.message);
    } catch (e) {
      Log.error(
        'Error exchanging code: $e',
        name: 'EmailVerificationMixin',
        category: LogCategory.auth,
      );
      setErrorMessage('Failed to complete authentication');
    }
  }

  /// Clean up polling timer - call this in dispose()
  void disposeVerification() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }
}
