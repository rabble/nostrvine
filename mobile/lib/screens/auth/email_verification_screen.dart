// ABOUTME: Screen to handle email verification via polling or token
// ABOUTME: Supports polling mode (after registration) and token mode (from deep link)
// ABOUTME: Supports auto-login on cold start via persisted verification data

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/email_verification/email_verification_cubit.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/screens/explore_screen.dart';
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
  bool _isTokenMode = false;
  String? _tokenModeError;

  /// Get the app-level cubit provided in main.dart
  EmailVerificationCubit get _cubit => context.read<EmailVerificationCubit>();

  @override
  void initState() {
    super.initState();

    // Use post-frame callback to access context safely
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeVerification();
    });
  }

  void _initializeVerification() {
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
      _isTokenMode = true;
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

      // Verify the email first via OAuth client, then start polling to complete login
      final oauth = ref.read(oauthClientProvider);
      try {
        await oauth.verifyEmail(token: widget.token!);
      } catch (e) {
        Log.error(
          'Email verification error: $e',
          name: 'EmailVerificationScreen',
          category: LogCategory.auth,
        );
      }

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
      _verifyWithToken(widget.token!);
    }
  }

  /// Verify email with token (standalone token mode without polling)
  Future<void> _verifyWithToken(String token) async {
    Log.info(
      'Verifying email with token',
      name: 'EmailVerificationScreen',
      category: LogCategory.auth,
    );

    final oauth = ref.read(oauthClientProvider);
    try {
      final result = await oauth.verifyEmail(token: token);
      if (result.success) {
        Log.info(
          'Email verification successful (token mode)',
          name: 'EmailVerificationScreen',
          category: LogCategory.auth,
        );
        // In token mode without polling, redirect to login
        _handleTokenModeSuccess();
      } else {
        Log.warning(
          'Email verification failed: ${result.error}',
          name: 'EmailVerificationScreen',
          category: LogCategory.auth,
        );
        if (mounted) {
          setState(() {
            _tokenModeError =
                result.error ?? result.message ?? 'Verification failed';
          });
        }
      }
    } catch (e) {
      Log.error(
        'Email verification error: $e',
        name: 'EmailVerificationScreen',
        category: LogCategory.auth,
      );
      if (mounted) {
        setState(() {
          _tokenModeError = 'Verification failed. Please try again.';
        });
      }
    }
  }

  @override
  void didUpdateWidget(EmailVerificationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If we receive a token via deep link while polling, verify it
    // This marks the email as verified on the server, allowing the poll to complete
    if (widget.isTokenMode && !oldWidget.isTokenMode) {
      Log.info(
        'Token received via deep link, calling verifyEmail',
        name: 'EmailVerificationScreen',
        category: LogCategory.auth,
      );
      final oauth = ref.read(oauthClientProvider);
      oauth.verifyEmail(token: widget.token!);
    }
  }

  // Note: We don't close the cubit in dispose() because it's owned by
  // the app-level BlocProvider in main.dart and needs to survive navigation

  void _handleSuccess() {
    // Clear persisted verification data on successful login
    ref.read(pendingVerificationServiceProvider).clear();

    if (!_isTokenMode) {
      // Polling mode: navigate to explore screen (Popular tab) after verification
      Log.info(
        'Email verification succeeded, navigating to explore (Popular tab)',
        name: 'EmailVerificationScreen',
        category: LogCategory.auth,
      );
      // Set tab by NAME (not index) because indices shift when Classics/ForYou
      // tabs become available asynchronously
      ref.read(forceExploreTabNameProvider.notifier).state = 'popular';
      context.go(ExploreScreen.path);
    } else {
      // Token mode: redirect to login screen
      _handleTokenModeSuccess();
    }
  }

  void _handleTokenModeSuccess() {
    // Clear persisted verification data
    ref.read(pendingVerificationServiceProvider).clear();
    // Show feedback message before redirecting to login
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Email verified! Please log in to continue.'),
        backgroundColor: VineTheme.vineGreen,
        duration: Duration(seconds: 3),
      ),
    );
    // Redirect to login screen
    context.go(WelcomeScreen.authNativePath);
  }

  void _handleCancel() {
    _cubit.stopPolling();
    // Don't clear pending verification data - user may still verify via email
    // link later. Data will be cleared on: successful login, logout, or
    // expiration (30 minutes).
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
    return Scaffold(
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
              if (state.status == EmailVerificationStatus.success) {
                _handleSuccess();
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
    );
  }

  Widget _buildContent(EmailVerificationState state) {
    // Token-mode error takes priority when in token mode
    if (_isTokenMode && _tokenModeError != null) {
      return _buildErrorContent(_tokenModeError!);
    }

    switch (state.status) {
      case EmailVerificationStatus.initial:
        return _buildLoadingContent(null);
      case EmailVerificationStatus.polling:
        return _buildLoadingContent(state.pendingEmail);
      case EmailVerificationStatus.success:
        return _buildSuccessContent();
      case EmailVerificationStatus.failure:
        return _buildErrorContent(state.error ?? 'Verification failed');
    }
  }

  Widget _buildLoadingContent(String? email) {
    final isPollingMode = widget.isPollingMode || !_isTokenMode;

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
        const SizedBox(height: 32),
        TextButton(
          onPressed: isPollingMode ? _handleCancel : _handleGoBack,
          child: Text(
            'Cancel',
            style: TextStyle(color: VineTheme.onSurfaceVariant, fontSize: 16),
          ),
        ),
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

  Widget _buildErrorContent(String errorMessage) {
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
