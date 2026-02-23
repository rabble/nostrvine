// ABOUTME: Welcome screen for new users showing TOS acceptance and age verification
// ABOUTME: App auto-creates nsec on first launch - this screen only handles TOS and shows error if auto-creation fails

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
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
  bool _hasSavedKeys = false;
  String? _savedNpub;

  @override
  void initState() {
    super.initState();
    _checkForSavedKeys();
  }

  Future<void> _checkForSavedKeys() async {
    final authService = ref.read(authServiceProvider);
    final hasSavedKeys = await authService.hasSavedKeys();
    final savedNpub = hasSavedKeys ? await authService.getSavedNpub() : null;

    if (mounted) {
      setState(() {
        _hasSavedKeys = hasSavedKeys;
        _savedNpub = savedNpub;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch auth state for reactive updates when state changes
    final authState = ref.watch(currentAuthStateProvider);
    final authService = ref.watch(authServiceProvider);

    return Scaffold(
      backgroundColor: VineTheme.surfaceBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: 600,
                        minHeight: constraints.maxHeight - 76,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Top section with branding
                          Column(
                            children: [
                              // Logo
                              SvgPicture.asset(
                                'assets/icon/logo.svg',
                                height: 50,
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Create and share short videos\non the decentralized web',
                                style: VineTheme.titleMediumFont(),
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
                                hasSavedKeys: _hasSavedKeys,
                                savedNpub: _savedNpub,
                                onContinue: () => _handleContinue(context),
                              ),

                              const SizedBox(height: 24),

                              // Login option for existing users
                              Text.rich(
                                TextSpan(
                                  style: VineTheme.bodyLargeFont(
                                    color: _canProceed
                                        ? VineTheme.onSurfaceVariant
                                        : VineTheme.onSurfaceDisabled,
                                  ),
                                  children: [
                                    const TextSpan(text: 'Have an account? '),
                                    DivineTextLink.span(
                                      text: 'Sign in',
                                      onTap: _canProceed
                                          ? () {
                                              authService.acceptTerms();
                                              context.push(
                                                WelcomeScreen.loginOptionsPath,
                                              );
                                            }
                                          : null,
                                    ),
                                  ],
                                ),
                              ),

                              // Start fresh option - only show when saved keys exist
                              if (_hasSavedKeys) ...[
                                const SizedBox(height: 8),
                                DivineButton(
                                  label: 'Start with a new identity',
                                  type: DivineButtonType.link,
                                  size: DivineButtonSize.small,
                                  onPressed: _canProceed
                                      ? () => _handleStartFresh(context)
                                      : null,
                                ),
                              ],
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
    );
  }

  bool get _canProceed => _isOver16 && _agreedToTerms;

  Future<void> _handleContinue(BuildContext context) async {
    setState(() => _isAccepting = true);

    try {
      final authService = ref.read(authServiceProvider);
      authService.clearError();
      // Accept TOS - this transitions auth state from awaitingTosAcceptance to authenticated
      // Router will automatically redirect to /explore when state changes
      await authService.signInAutomatically();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to continue: $e'),
            backgroundColor: VineTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAccepting = false);
      }
    }
  }

  Future<void> _handleStartFresh(BuildContext context) async {
    // Show warning dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VineTheme.cardBackground,
        title: Text(
          'Start with New Identity?',
          style: VineTheme.headlineSmallFont(),
        ),
        content: Text(
          'This will:\n\n'
          '• Delete your current keys from this device\n'
          '• Generate a completely new Nostr identity\n'
          '• You will NOT be able to access your previous '
          'account unless you have a backup of your nsec'
          '\n\nAre you sure you want to start fresh?',
          style: VineTheme.bodyMediumFont(
            color: VineTheme.onSurfaceVariant,
          ).copyWith(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: Text(
              'Cancel',
              style: VineTheme.bodyMediumFont(color: VineTheme.onSurfaceMuted),
            ),
          ),
          TextButton(
            onPressed: () => context.pop(true),
            child: Text(
              'Start Fresh',
              style: VineTheme.bodyMediumFont(color: VineTheme.error),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isAccepting = true);

    try {
      final authService = ref.read(authServiceProvider);

      // Delete existing keys and generate new identity
      await authService.signOut(deleteKeys: true);

      // Clear local state so UI updates
      setState(() {
        _hasSavedKeys = false;
        _savedNpub = null;
      });

      // Now sign in with the new auto-generated identity
      await authService.signInAutomatically();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start fresh: $e'),
            backgroundColor: VineTheme.error,
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
    required this.hasSavedKeys,
    required this.savedNpub,
    required this.onContinue,
  });

  final AuthState authState;
  final String? lastError;
  final bool canProceed;
  final bool isAccepting;
  final bool hasSavedKeys;
  final String? savedNpub;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    if (authState == AuthState.checking ||
        authState == AuthState.authenticating) {
      return const _LoadingIndicator();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (lastError != null) ...[
          ErrorMessage(message: lastError!),
          const SizedBox(height: 16),
        ],
        _ActionButton(
          enabled: canProceed && !isAccepting,
          isLoading: isAccepting,
          hasSavedKeys: hasSavedKeys,
          savedNpub: savedNpub,
          onPressed: onContinue,
        ),
      ],
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
    required this.hasSavedKeys,
    required this.savedNpub,
    required this.onPressed,
  });
  final bool enabled;
  final bool isLoading;
  final bool hasSavedKeys;
  final String? savedNpub;
  final VoidCallback onPressed;

  String _getButtonText() {
    if (enabled) return 'Continue';
    return 'Accept terms & continue';
  }

  @override
  Widget build(BuildContext context) {
    final maskedNpub = savedNpub != null
        ? NostrKeyUtils.maskKey(savedNpub!)
        : null;

    return Column(
      children: [
        if (isLoading)
          const SizedBox(
            height: 48,
            width: 48,
            child: CircularProgressIndicator(
              color: VineTheme.primary,
              strokeWidth: 2,
            ),
          )
        else
          DivineButton(
            label: _getButtonText(),
            expanded: true,
            onPressed: enabled ? onPressed : null,
          ),
        if (hasSavedKeys && maskedNpub != null && enabled) ...[
          const SizedBox(height: 8),
          Text(
            'Resume as $maskedNpub',
            style: VineTheme.bodySmallFont(color: VineTheme.onSurfaceVariant),
          ),
        ],
      ],
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Age verification checkbox
        DivineRowCheckbox(
          state: isOver16
              ? DivineCheckboxState.selected
              : DivineCheckboxState.unselected,
          onChanged: (value) => onOver16Changed(value),
          label: Text(
            'I am 16 years or older',
            style: VineTheme.bodyLargeFont(),
          ),
        ),
        const SizedBox(height: 16),

        // TOS acceptance checkbox with links
        DivineRowCheckbox(
          state: agreedToTerms
              ? DivineCheckboxState.selected
              : DivineCheckboxState.unselected,
          onChanged: (value) => onAgreedToTermsChanged(value),
          crossAxisAlignment: CrossAxisAlignment.start,
          label: RichText(
            text: TextSpan(
              style: VineTheme.bodyLargeFont(),
              children: [
                const TextSpan(text: 'I agree to the '),
                TextSpan(
                  text: 'Terms of Service',
                  style: VineTheme.bodyLargeFont().copyWith(
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => _openUrl('https://divine.video/terms'),
                ),
                const TextSpan(text: ', '),
                TextSpan(
                  text: 'Privacy Policy',
                  style: VineTheme.bodyLargeFont().copyWith(
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => _openUrl('https://divine.video/privacy'),
                ),
                const TextSpan(text: ', and '),
                TextSpan(
                  text: 'Safety Standards',
                  style: VineTheme.bodyLargeFont().copyWith(
                    decoration: TextDecoration.underline,
                  ),
                  recognizer: TapGestureRecognizer()
                    ..onTap = () => _openUrl('https://divine.video/safety'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
