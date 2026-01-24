// ABOUTME: Screen to handle email verification in two modes
// ABOUTME: Polling mode (after registration) and token mode (from deep link)
// ABOUTME: Supports auto-login on cold start via persisted verification data

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/email_verification/email_verification_cubit.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/welcome_screen.dart';
import 'package:openvine/utils/unified_logger.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  /// Route name for navigation
  static const String routeName = 'verify-email';

  /// Path for navigation
  static const String path = '/verify-email';

  const EmailVerificationScreen({
    super.key,
    this.token,
    this.deviceCode,
    this.verifier,
    this.email,
  });

  /// Token from deep link (token mode)
  final String? token;

  /// Device code from registration (polling mode)
  final String? deviceCode;

  /// PKCE verifier from registration (polling mode)
  final String? verifier;

  /// User's email address (polling mode)
  final String? email;

  /// Check if this is polling mode
  bool get isPollingMode =>
      deviceCode != null && deviceCode!.isNotEmpty && verifier != null;

  /// Check if this is token mode
  bool get isTokenMode => token != null && token!.isNotEmpty;

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  late final EmailVerificationCubit _cubit;

  @override
  void initState() {
    super.initState();

    final oauth = ref.read(oauthClientProvider);
    final authService = ref.read(authServiceProvider);

    _cubit = EmailVerificationCubit(
      oauthClient: oauth,
      authService: authService,
    );

    // Start the appropriate verification mode
    if (widget.isPollingMode) {
      Log.info(
        'Starting polling mode verification',
        name: 'EmailVerificationScreen',
        category: LogCategory.auth,
      );
      _cubit.startPolling(
        deviceCode: widget.deviceCode!,
        verifier: widget.verifier!,
        email: widget.email ?? '',
      );
    } else if (widget.isTokenMode) {
      // Token mode - check for persisted verification data for auto-login
      _initTokenModeWithPersistenceCheck();
    } else {
      Log.warning(
        'EmailVerificationScreen opened without token or deviceCode',
        name: 'EmailVerificationScreen',
        category: LogCategory.auth,
      );
    }
  }

  /// Initialize token mode, checking for persisted data for auto-login.
  ///
  /// If persisted verification data exists (from a previous registration),
  /// we can verify the email and then complete the OAuth flow automatically
  /// instead of requiring the user to log in manually.
  Future<void> _initTokenModeWithPersistenceCheck() async {
    final pendingService = ref.read(pendingVerificationServiceProvider);
    final pending = await pendingService.load();

    if (pending != null) {
      Log.info(
        'Found persisted verification data for ${pending.email}, '
        'attempting auto-login flow',
        name: 'EmailVerificationScreen',
        category: LogCategory.auth,
      );

      // Verify the email first, then start polling to complete login
      await _cubit.verifyEmailOnly(widget.token!);
      _cubit.startPolling(
        deviceCode: pending.deviceCode,
        verifier: pending.verifier,
        email: pending.email,
      );
    } else {
      Log.info(
        'No persisted verification data, using standard token mode',
        name: 'EmailVerificationScreen',
        category: LogCategory.auth,
      );
      _cubit.verifyWithToken(widget.token!);
    }
  }

  @override
  void didUpdateWidget(EmailVerificationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If we receive a token via deep link while polling, verify it
    // This marks the email as verified on the server, allowing the poll to complete
    // We don't cancel polling - it will complete after verification succeeds
    if (widget.isTokenMode && !oldWidget.isTokenMode) {
      Log.info(
        'Token received via deep link, calling verifyEmail',
        name: 'EmailVerificationScreen',
        category: LogCategory.auth,
      );
      _cubit.verifyEmailOnly(widget.token!);
    }
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  void _handleSuccess(EmailVerificationMode mode) {
    // Clear persisted verification data on successful login
    ref.read(pendingVerificationServiceProvider).clear();

    if (mode == EmailVerificationMode.polling) {
      // app_router should detect that we are authenticated
      // and route us to /home
    } else {
      // Token mode: redirect to login screen
      context.go(WelcomeScreen.authNativePath);
    }
  }

  void _handleCancel() {
    _cubit.cancelPolling();
    // Clear persisted verification data on cancel
    ref.read(pendingVerificationServiceProvider).clear();
    // Go back to previous screen (registration form)
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  void _handleGoBack() {
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [VineTheme.vineGreen, Color(0xFF2D8B6F)],
            ),
          ),
          child: SafeArea(
            child: BlocConsumer<EmailVerificationCubit, EmailVerificationState>(
              listener: (context, state) {
                if (state is EmailVerificationSuccess) {
                  _handleSuccess(state.mode);
                }
              },
              builder: (context, state) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _buildContent(state),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(EmailVerificationState state) {
    return switch (state) {
      EmailVerificationInitial() => _buildLoadingContent(null),
      EmailVerificationInProgress(:final mode, :final email) =>
        _buildLoadingContent(
          mode == EmailVerificationMode.polling ? email : null,
        ),
      EmailVerificationSuccess() => _buildSuccessContent(),
      EmailVerificationFailure(:final mode, :final errorMessage) =>
        _buildErrorContent(mode, errorMessage),
    };
  }

  Widget _buildLoadingContent(String? email) {
    final isPollingMode = widget.isPollingMode;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.email_outlined, color: Colors.white, size: 80),
        const SizedBox(height: 24),
        Text(
          isPollingMode ? 'Verify Your Email' : 'Verifying...',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (isPollingMode && email != null && email.isNotEmpty) ...[
          const Text(
            'We sent a verification link to:',
            style: TextStyle(color: Colors.white70, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            email,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Text(
            'Click the link in your email to complete registration.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ] else ...[
          const Text(
            'Please wait while we verify your email...',
            style: TextStyle(color: Colors.white70, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
        const SizedBox(height: 32),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
            SizedBox(width: 12),
            Text(
              'Waiting for verification...',
              style: TextStyle(color: Colors.white, fontSize: 14),
            ),
          ],
        ),
        if (isPollingMode) ...[
          const SizedBox(height: 32),
          TextButton(
            onPressed: _handleCancel,
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSuccessContent() {
    // Navigation happens automatically via BlocConsumer listener
    // This UI is shown briefly during the transition
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.check_circle_outline, color: Colors.white, size: 80),
        SizedBox(height: 24),
        Text(
          'Email Verified!',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 12),
        Text(
          'Signing you in...',
          style: TextStyle(color: Colors.white70, fontSize: 16),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildErrorContent(EmailVerificationMode mode, String errorMessage) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.error_outline, color: Colors.white, size: 80),
        const SizedBox(height: 24),
        const Text(
          'Verification Failed',
          style: TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          errorMessage,
          style: const TextStyle(color: Colors.white70, fontSize: 16),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _handleGoBack,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: VineTheme.vineGreen,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Go Back',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
