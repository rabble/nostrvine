// ABOUTME: Welcome screen for new users showing TOS acceptance and age verification
// ABOUTME: App auto-creates nsec on first launch - this screen only handles TOS and shows error if auto-creation fails

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/error_message.dart';
import 'package:url_launcher/url_launcher.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  /// Route name for this screen.
  static const routeName = 'welcome';

  /// Path for this route.
  static const path = '/welcome';

  /// Path for login options route.
  static const loginOptionsPath = '/welcome/login-options';

  /// Path for auth native route.
  static const authNativePath = '/welcome/login-options/auth-native';

  /// Path for reset password route.
  static const resetPasswordPath =
      '/welcome/login-options/auth-native/reset-password';

  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  bool _isOver16 = false;
  bool _agreedToTerms = false;
  bool _isAccepting = false;

  @override
  Widget build(BuildContext context) {
    // Watch auth state for reactive updates when state changes
    final authState = ref.watch(currentAuthStateProvider);
    final authService = ref.watch(authServiceProvider);

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF00AB82), Color(0xFF009870)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isSmallScreen = constraints.maxHeight < 700;
              final iconSize = isSmallScreen ? 160.0 : 224.0;
              final wordmarkWidth = isSmallScreen ? 100.0 : 130.0;

              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 600),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Top section with branding
                            Column(
                              children: [
                                // No top margin on phones, keep margin on tablets
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.width < 600
                                      ? 0
                                      : 40,
                                ),
                                // App branding - Divine icon (responsive sizing)
                                Image.asset(
                                  'assets/icon/divine_icon_transparent.png',
                                  height: iconSize,
                                  fit: BoxFit.contain,
                                ),
                                // Wordmark logo - positioned close to icon above
                                Image.asset(
                                  'assets/icon/divine_wordmark.png',
                                  width: wordmarkWidth,
                                  fit: BoxFit.contain,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'Create and share short videos\non the decentralized web',
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: Color(0xFFF5F6EA),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),

                            // Bottom section with TOS and buttons
                            Column(
                              children: [
                                // Age verification and TOS acceptance
                                _TermsCheckboxSection(
                                  isOver16: _isOver16,
                                  agreedToTerms: _agreedToTerms,
                                  onOver16Changed: (value) =>
                                      setState(() => _isOver16 = value),
                                  onAgreedToTermsChanged: (value) =>
                                      setState(() => _agreedToTerms = value),
                                ),

                                const SizedBox(height: 32),

                                // Main action buttons - show based on auth state
                                _WelcomeActionSection(
                                  authState: authState,
                                  lastError: authService.lastError,
                                  canProceed: _canProceed,
                                  isAccepting: _isAccepting,
                                  onContinue: () => _handleContinue(context),
                                ),

                                const SizedBox(height: 24),

                                // Login option for existing users
                                TextButton(
                                  onPressed: _canProceed
                                      ? () {
                                          authService.acceptTerms();
                                          context.push(
                                            WelcomeScreen.loginOptionsPath,
                                          );
                                        }
                                      : null,
                                  child: Text(
                                    'Have an account? Log In',
                                    style: TextStyle(
                                      color: _canProceed
                                          ? Colors.white
                                          : Colors.white.withValues(alpha: 0.5),
                                      fontSize: 16,
                                      decoration: TextDecoration.underline,
                                      decorationColor: _canProceed
                                          ? Colors.white
                                          : Colors.white.withValues(alpha: 0.5),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  bool get _canProceed => _isOver16 && _agreedToTerms;

  Future<void> _handleContinue(BuildContext context) async {
    setState(() => _isAccepting = true);

    try {
      final authService = ref.read(authServiceProvider);
      // Accept TOS - this transitions auth state from awaitingTosAcceptance to authenticated
      // Router will automatically redirect to /explore when state changes
      await authService.signInAutomatically();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to continue: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAccepting = false);
      }
    }
  }
}

class _WelcomeActionSection extends StatelessWidget {
  const _WelcomeActionSection({
    required this.authState,
    required this.lastError,
    required this.canProceed,
    required this.isAccepting,
    required this.onContinue,
  });

  final AuthState authState;
  final String? lastError;
  final bool canProceed;
  final bool isAccepting;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    if (authState == AuthState.checking ||
        authState == AuthState.authenticating) {
      return const _LoadingIndicator();
    }

    if (lastError != null) {
      return ErrorMessage(message: lastError!);
    }

    return _ActionButton(
      enabled: canProceed && !isAccepting,
      isLoading: isAccepting,
      onPressed: onContinue,
    );
  }
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Center(child: BrandedLoadingIndicator(size: 120));
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.enabled,
    required this.isLoading,
    required this.onPressed,
  });
  final bool enabled;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: VineTheme.vineGreen,
          disabledBackgroundColor: Colors.white.withValues(alpha: 0.7),
          disabledForegroundColor: VineTheme.vineGreen.withValues(alpha: 0.7),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  color: VineTheme.vineGreen,
                  strokeWidth: 2,
                ),
              )
            : Text(
                enabled ? 'Continue' : 'Accept Terms to Continue',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

class _TermsCheckboxSection extends StatelessWidget {
  const _TermsCheckboxSection({
    required this.isOver16,
    required this.agreedToTerms,
    required this.onOver16Changed,
    required this.onAgreedToTermsChanged,
  });

  final bool isOver16;
  final bool agreedToTerms;
  final ValueChanged<bool> onOver16Changed;
  final ValueChanged<bool> onAgreedToTermsChanged;

  Future<void> _openUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Age verification checkbox
          InkWell(
            onTap: () => onOver16Changed(!isOver16),
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: isOver16,
                    onChanged: (value) => onOver16Changed(value ?? false),
                    fillColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return Colors.white;
                      }
                      return Colors.transparent;
                    }),
                    checkColor: VineTheme.vineGreen,
                    side: const BorderSide(color: Colors.white, width: 2),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'I am 16 years or older',
                    style: TextStyle(color: VineTheme.whiteText, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // TOS acceptance checkbox with links
          InkWell(
            onTap: () => onAgreedToTermsChanged(!agreedToTerms),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: agreedToTerms,
                    onChanged: (value) =>
                        onAgreedToTermsChanged(value ?? false),
                    fillColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return Colors.white;
                      }
                      return Colors.transparent;
                    }),
                    checkColor: VineTheme.vineGreen,
                    side: const BorderSide(color: Colors.white, width: 2),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: VineTheme.whiteText,
                        fontSize: 14,
                      ),
                      children: [
                        const TextSpan(text: 'I agree to the '),
                        TextSpan(
                          text: 'Terms of Service',
                          style: const TextStyle(
                            color: Colors.white,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () =>
                                _openUrl('https://divine.video/terms'),
                        ),
                        const TextSpan(text: ', '),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: const TextStyle(
                            color: Colors.white,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () =>
                                _openUrl('https://divine.video/privacy'),
                        ),
                        const TextSpan(text: ', and '),
                        TextSpan(
                          text: 'Safety Standards',
                          style: const TextStyle(
                            color: Colors.white,
                            decoration: TextDecoration.underline,
                          ),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () =>
                                _openUrl('https://divine.video/safety'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
