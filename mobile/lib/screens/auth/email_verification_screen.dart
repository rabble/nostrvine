// ABOUTME: Screen to handle email verification via polling or token
// ABOUTME: Supports polling mode (after registration) and token mode (from deep link)
// ABOUTME: Supports auto-login on cold start via persisted verification data

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/email_verification/email_verification_cubit.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/divine_primary_button.dart';
import 'package:url_launcher/url_launcher.dart';

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
  StreamSubscription<AuthState>? _authSubscription;
  late final EmailVerificationCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<EmailVerificationCubit>();

    // Use post-frame callback to access context safely
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeVerification();
      _listenForAuthState();
    });
  }

  /// Listen for auth state changes and navigate away when authenticated.
  ///
  /// GoRouter's `refreshListenable` redirect is unreliable for navigating
  /// away from this screen after sign-in completes. This listener provides
  /// an explicit, reliable navigation path.
  void _listenForAuthState() {
    final authService = ref.read(authServiceProvider);
    _authSubscription = authService.authStateStream.listen((authState) {
      if (authState == AuthState.authenticated && mounted) {
        Log.info(
          'Auth state became authenticated, navigating to explore '
          '(cubit=${_cubit.hashCode})',
          name: 'EmailVerificationScreen',
          category: LogCategory.auth,
        );
        _cubit.stopPolling();
        ref.read(pendingVerificationServiceProvider).clear();
        ref.read(forceExploreTabNameProvider.notifier).state = 'popular';
        context.go(ExploreScreen.path);
      }
    });
  }

  void _initializeVerification() {
    // Start the appropriate verification mode
    if (widget.isPollingMode) {
      Log.info(
        'Starting polling mode verification (cubit=${_cubit.hashCode})',
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

      // Verify the email first via OAuth client, then start polling to
      // complete login
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
        _cubit.emitFailure(
          result.error ?? 'This verification link is no longer valid.',
        );
      }
    } catch (e) {
      Log.error(
        'Email verification error: $e',
        name: 'EmailVerificationScreen',
        category: LogCategory.auth,
      );
      _cubit.emitFailure(
        'Unable to verify email. Please check your connection and try again.',
      );
    }
  }

  @override
  void didUpdateWidget(EmailVerificationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If we receive a token via deep link while polling, verify it
    // This marks the email as verified on the server, allowing the poll to
    // complete
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

  @override
  void dispose() {
    _authSubscription?.cancel();
    // Stop polling when the screen is disposed (e.g., router redirect after
    // auth). The cubit is app-level so we don't close() it, but we must stop
    // its timers to prevent zombie polling.
    _cubit.stopPolling();
    super.dispose();
  }

  void _handleSuccess() {
    // Clear persisted verification data on successful login
    ref.read(pendingVerificationServiceProvider).clear();

    if (!_isTokenMode) {
      // Polling mode: navigate to explore screen (Popular tab) after
      // verification
      Log.info(
        'Email verification succeeded, navigating to explore (Popular tab)',
        name: 'EmailVerificationScreen',
        category: LogCategory.auth,
      );
      // Set tab by NAME (not index) because indices shift when
      // Classics/ForYou tabs become available asynchronously
      ref.read(forceExploreTabNameProvider.notifier).state = 'popular';
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
    context.go(WelcomeScreen.loginOptionsPath);
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

  void _handleStartOver() {
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: BlocConsumer<EmailVerificationCubit, EmailVerificationState>(
          listener: (context, state) {
            if (state.status == EmailVerificationStatus.success) {
              _handleSuccess();
            }
          },
          builder: (context, state) {
            final showCloseButton =
                state.status != EmailVerificationStatus.success;
            return Column(
              children: [
                // Close button (hidden on success)
                if (showCloseButton)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _CloseButton(
                        onPressed:
                            state.status == EmailVerificationStatus.failure
                            ? _handleStartOver
                            : _handleCancel,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 76),

                // Main content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: switch (state.status) {
                      EmailVerificationStatus.initial => _PollingContent(
                        email: null,
                        isPollingMode: widget.isPollingMode || !_isTokenMode,
                      ),
                      EmailVerificationStatus.polling => _PollingContent(
                        email: state.pendingEmail,
                        isPollingMode: widget.isPollingMode || !_isTokenMode,
                      ),
                      EmailVerificationStatus.success =>
                        const _SuccessContent(),
                      EmailVerificationStatus.failure => _ErrorContent(
                        onStartOver: _handleStartOver,
                      ),
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Close button (X) for the verification screen.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: VineTheme.surfaceContainer,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.close,
          color: VineTheme.vineGreenLight,
          size: 20,
        ),
      ),
    );
  }
}

/// Status button with a spinner (non-interactive).
class _StatusButton extends StatelessWidget {
  const _StatusButton({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: Border.all(
          color: VineTheme.vineGreenDark.withValues(alpha: 0.5),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: VineTheme.vineGreenDark.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: VineTheme.whiteText,
            ),
          ),
        ],
      ),
    );
  }
}

/// Polling/loading content shown while waiting for email verification.
class _PollingContent extends StatelessWidget {
  const _PollingContent({required this.email, required this.isPollingMode});

  final String? email;
  final bool isPollingMode;

  Future<void> _openEmailApp() async {
    Log.info(
      'Opening email app (platform=${Platform.operatingSystem})',
      name: 'EmailVerification',
      category: LogCategory.auth,
    );

    try {
      if (Platform.isAndroid) {
        // Use AndroidIntent to fire ACTION_MAIN + APP_EMAIL which opens
        // the default email app's inbox (not compose).
        const intent = AndroidIntent(
          action: 'android.intent.action.MAIN',
          category: 'android.intent.category.APP_EMAIL',
          flags: <int>[Flag.FLAG_ACTIVITY_NEW_TASK],
        );
        await intent.launch();
        Log.info(
          'Android email intent launched successfully',
          name: 'EmailVerification',
          category: LogCategory.auth,
        );
      } else {
        // iOS: 'message://' opens the Mail inbox directly
        final launched = await launchUrl(
          Uri.parse('message://'),
          mode: LaunchMode.externalApplication,
        );
        Log.info(
          'iOS message:// launch result: $launched',
          name: 'EmailVerification',
          category: LogCategory.auth,
        );
      }
    } catch (e) {
      Log.warning(
        'Primary email launch failed: $e',
        name: 'EmailVerification',
        category: LogCategory.auth,
      );
      // Fallback: mailto: opens the email app (compose view)
      try {
        await launchUrl(
          Uri(scheme: 'mailto'),
          mode: LaunchMode.externalApplication,
        );
        Log.info(
          'Fallback mailto: launched',
          name: 'EmailVerification',
          category: LogCategory.auth,
        );
      } catch (fallbackError) {
        Log.warning(
          'Fallback mailto: also failed: $fallbackError',
          name: 'EmailVerification',
          category: LogCategory.auth,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Spacer(),

        // Email sticker
        Transform.rotate(
          angle: -8 * pi / 180,
          child: const DivineSticker(
            sticker: DivineStickerName.email,
            size: 120,
          ),
        ),
        const SizedBox(height: 32),

        // Title
        Text(
          isPollingMode ? 'Complete your registration' : 'Verifying...',
          style: const TextStyle(
            fontFamily: VineTheme.fontFamilyBricolage,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: VineTheme.whiteText,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),

        if (isPollingMode && email != null && email!.isNotEmpty) ...[
          Text(
            'We sent a verification link to:',
            style: TextStyle(
              fontSize: 16,
              color: VineTheme.secondaryText,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            email!,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: VineTheme.whiteText,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Please click the link in your email to\ncomplete your '
            'registration.',
            style: TextStyle(
              fontSize: 14,
              color: VineTheme.secondaryText,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ] else ...[
          Text(
            'Please wait while we verify your email...',
            style: TextStyle(
              fontSize: 16,
              color: VineTheme.secondaryText,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],

        const Spacer(),

        // Status + action buttons at bottom
        Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: Column(
            children: [
              const _StatusButton(label: 'Waiting for verification'),
              if (isPollingMode) ...[
                const SizedBox(height: 20),
                DivinePrimaryButton(
                  label: 'Open email app',
                  onPressed: _openEmailApp,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Success content shown briefly when email is verified.
class _SuccessContent extends StatelessWidget {
  const _SuccessContent();

  @override
  Widget build(BuildContext context) {
    // Navigation happens automatically via BlocConsumer listener
    // This UI is shown briefly during the transition
    return Column(
      children: [
        const Spacer(),

        // Shaka sticker (celebration)
        const DivineSticker(sticker: DivineStickerName.hangLoose, size: 120),
        const SizedBox(height: 32),

        const Text(
          'Welcome to Divine!',
          style: TextStyle(
            fontFamily: VineTheme.fontFamilyBricolage,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: VineTheme.whiteText,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Your email has been verified.',
          style: TextStyle(
            fontSize: 16,
            color: VineTheme.secondaryText,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),

        const Spacer(),

        // Signing you in status button
        const Padding(
          padding: EdgeInsets.only(bottom: 32),
          child: _StatusButton(label: 'Signing you in'),
        ),
      ],
    );
  }
}

/// Error content shown when verification fails.
class _ErrorContent extends StatelessWidget {
  const _ErrorContent({required this.onStartOver});

  final VoidCallback onStartOver;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Spacer(),

        // Siren sticker
        const DivineSticker(sticker: DivineStickerName.policeSiren, size: 120),
        const SizedBox(height: 32),

        const Text(
          'Uh oh.',
          style: TextStyle(
            fontFamily: VineTheme.fontFamilyBricolage,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            color: VineTheme.whiteText,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'We failed to verify your email.\nPlease try again.',
          style: TextStyle(
            fontSize: 16,
            color: VineTheme.secondaryText,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),

        const Spacer(),

        // Start over button
        Padding(
          padding: const EdgeInsets.only(bottom: 32),
          child: DivinePrimaryButton(
            label: 'Start over',
            onPressed: onStartOver,
          ),
        ),
      ],
    );
  }
}
