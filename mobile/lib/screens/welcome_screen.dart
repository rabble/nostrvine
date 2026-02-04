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
                              const SizedBox(height: 16),
                              Text(
                                'Authentic moments.\nHuman creativity.',
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

                              // Start fresh option - only show when saved keys exist
                              if (_hasSavedKeys) ...[
                                const SizedBox(height: 8),
                                TextButton(
                                  onPressed: _canProceed
                                      ? () => _handleStartFresh(context)
                                      : null,
                                  child: Text(
                                    'Start with a new identity',
                                    style: TextStyle(
                                      color: _canProceed
                                          ? Colors.white.withValues(alpha: 0.7)
                                          : Colors.white.withValues(alpha: 0.4),
                                      fontSize: 14,
                                      decoration: TextDecoration.underline,
                                      decorationColor: _canProceed
                                          ? Colors.white.withValues(alpha: 0.7)
                                          : Colors.white.withValues(alpha: 0.4),
                                    ),
                                  ),
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

  Future<void> _handleStartFresh(BuildContext context) async {
    // Show warning dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: VineTheme.cardBackground,
        title: const Text(
          'Start with New Identity?',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'This will:\n\n'
          '• Delete your current keys from this device\n'
          '• Generate a completely new Nostr identity\n'
          '• You will NOT be able to access your previous account unless you have a backup of your nsec\n\n'
          'Are you sure you want to start fresh?',
          style: TextStyle(color: Colors.grey, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => context.pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => context.pop(true),
            child: const Text(
              'Start Fresh',
              style: TextStyle(color: Colors.orange),
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

    if (lastError != null) {
      return ErrorMessage(message: lastError!);
    }

    return _ActionButton(
      enabled: canProceed && !isAccepting,
      isLoading: isAccepting,
      hasSavedKeys: hasSavedKeys,
      savedNpub: savedNpub,
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
    if (!enabled) return 'Accept Terms to Continue';
    if (hasSavedKeys) return 'Continue with Saved Keys';
    return 'Get Started';
  }

  @override
  Widget build(BuildContext context) {
    final maskedNpub = savedNpub != null
        ? NostrKeyUtils.maskKey(savedNpub!)
        : null;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: enabled ? onPressed : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: VineTheme.vineGreen,
              disabledBackgroundColor: Colors.white.withValues(alpha: 0.7),
              disabledForegroundColor: VineTheme.vineGreen.withValues(
                alpha: 0.7,
              ),
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
                    _getButtonText(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
        if (hasSavedKeys && maskedNpub != null && enabled) ...[
          const SizedBox(height: 8),
          Text(
            'Resume as $maskedNpub',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.7),
            ),
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
        _buildCheckboxRow(
          value: isOver16,
          onChanged: onOver16Changed,
          label: Text(
            'I am 16 years or older',
            style: VineTheme.bodyLargeFont(),
          ),
        ),
        const SizedBox(height: 16),

        // TOS acceptance checkbox with links
        _buildCheckboxRow(
          value: agreedToTerms,
          onChanged: onAgreedToTermsChanged,
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

  Widget _buildCheckboxRow({
    required bool value,
    required ValueChanged<bool> onChanged,
    required Widget label,
    CrossAxisAlignment crossAxisAlignment = CrossAxisAlignment.center,
  }) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: value ? VineTheme.primary : VineTheme.outlineMuted,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: crossAxisAlignment,
          children: [
            GestureDetector(
              onTap: () => onChanged(!value),
              child: _SpriteCheckbox(
                state: value
                    ? _CheckboxState.selected
                    : _CheckboxState.unselected,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: label),
          ],
        ),
      ),
    );
  }
}

enum _CheckboxState {
  unselected,
  selected,
  intermediate,
  disabled,
}

class _SpriteCheckbox extends StatelessWidget {
  const _SpriteCheckbox({required this.state});

  final _CheckboxState state;

  @override
  Widget build(BuildContext context) {
    // Sprite is 24x72 with three 24x24 sections stacked vertically
    // Top (0-24): unselected, Middle (24-48): selected, Bottom (48-72): intermediate
    final yOffset = switch (state) {
      _CheckboxState.unselected || _CheckboxState.disabled => 0.0,
      _CheckboxState.selected => -24.0,
      _CheckboxState.intermediate => -48.0,
    };

    final opacity = state == _CheckboxState.disabled ? 0.5 : 1.0;

    return Opacity(
      opacity: opacity,
      child: SizedBox(
        width: 24,
        height: 24,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              top: yOffset,
              left: 0,
              child: SvgPicture.asset(
                'assets/icon/checkbox-sprite.svg',
                width: 24,
                height: 72,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
