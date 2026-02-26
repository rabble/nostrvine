// ABOUTME: Secure account screen for existing anonymous users
// ABOUTME: Allows adding email/password to an existing anonymous account

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:openvine/blocs/email_verification/email_verification_cubit.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/utils/validators.dart';
import 'package:openvine/widgets/auth/auth_error_box.dart';
import 'package:openvine/widgets/auth/auth_form_scaffold.dart';
import 'package:openvine/widgets/divine_primary_button.dart';

class SecureAccountScreen extends ConsumerStatefulWidget {
  /// Route name for this screen.
  static const routeName = 'secure-account';

  /// Path for this route.
  static const path = '/secure-account';

  const SecureAccountScreen({super.key});

  @override
  ConsumerState<SecureAccountScreen> createState() =>
      _SecureAccountScreenState();
}

class _SecureAccountScreenState extends ConsumerState<SecureAccountScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _emailError;
  String? _passwordError;
  String? _generalError;

  void _setGeneralError(String? message) {
    if (mounted) {
      setState(() => _generalError = message);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final emailError = Validators.validateEmail(_emailController.text.trim());
    final passwordError = Validators.validatePassword(_passwordController.text);

    if (emailError != null || passwordError != null) {
      setState(() {
        _emailError = emailError;
        _passwordError = passwordError;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _emailError = null;
      _passwordError = null;
      _generalError = null;
    });

    try {
      final oauth = ref.read(oauthClientProvider);
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      // Use authService.exportNsec() which accesses keys from secure storage
      // This works for both auto-generated and imported keys
      final authService = ref.read(authServiceProvider);
      final nsec = await authService.exportNsec();

      if (nsec == null) {
        _setGeneralError('Unable to access your keys. Please try again.');
        return;
      }

      await _handleRegister(
        oauth: oauth,
        email: email,
        password: password,
        nsec: nsec,
      );
    } catch (e) {
      Log.error(
        'Auth error: $e',
        name: 'SecureAccountScreen',
        category: LogCategory.auth,
      );
      _setGeneralError('An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleRegister({
    required KeycastOAuth oauth,
    required String email,
    required String password,
    required String nsec,
  }) async {
    final (result, verifier) = await oauth.headlessRegister(
      email: email,
      nsec: nsec,
      password: password,
      scope: 'policy:full',
    );

    if (!result.success) {
      _setGeneralError(result.errorDescription ?? 'Registration failed');
      return;
    }

    if (result.verificationRequired && result.deviceCode != null) {
      // Start polling
      if (mounted) {
        context.read<EmailVerificationCubit>().startPolling(
          deviceCode: result.deviceCode!,
          verifier: verifier,
          email: email,
        );

        // Show verification dialog but let user continue
        _showVerificationDialog(email);
      }
    } else {
      _setGeneralError('Registration complete. Please check your email.');
    }
  }

  void _showVerificationDialog(String email) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _VerificationDialog(
        email: email,
        onContinue: () {
          Navigator.of(dialogContext).pop();
          _continueToApp();
        },
        onSuccess: () {
          // Navigate to explore screen after successful verification
          if (mounted) {
            context.go(ExploreScreen.path);
          }
        },
      ),
    );
  }

  void _continueToApp() {
    if (mounted) {
      context.go(ExploreScreen.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthFormScaffold(
      title: 'Secure account',
      emailController: _emailController,
      passwordController: _passwordController,
      emailError: _emailError,
      passwordError: _passwordError,
      enabled: !_isLoading,
      onEmailChanged: (_) {
        if (_emailError != null) setState(() => _emailError = null);
      },
      onPasswordChanged: (_) {
        if (_passwordError != null) setState(() => _passwordError = null);
      },
      errorWidget: _generalError != null
          ? AuthErrorBox(message: _generalError!)
          : null,
      primaryButton: DivinePrimaryButton(
        label: 'Secure account',
        isLoading: _isLoading,
        onPressed: _handleSubmit,
      ),
    );
  }
}

/// Reactive dialog that watches verification state and auto-closes on success
class _VerificationDialog extends ConsumerWidget {
  const _VerificationDialog({
    required this.email,
    required this.onContinue,
    required this.onSuccess,
  });

  final String email;
  final VoidCallback onContinue;
  final VoidCallback onSuccess;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);

    return BlocBuilder<EmailVerificationCubit, EmailVerificationState>(
      builder: (context, verificationState) {
        // Auto-close when verification completes (user is no longer anonymous)
        if (!verificationState.isPolling &&
            verificationState.error == null &&
            !authService.isAnonymous) {
          // Use post-frame callback to avoid calling Navigator during build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            onSuccess();
          });
        }

        // Show error state if verification failed
        if (verificationState.error != null) {
          return AlertDialog(
            backgroundColor: VineTheme.cardBackground,
            title: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red),
                SizedBox(width: 12),
                Text(
                  'Verification Failed',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
            content: Text(
              verificationState.error!,
              style: TextStyle(color: Colors.grey[400]),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Close',
                  style: TextStyle(color: VineTheme.vineGreen),
                ),
              ),
            ],
          );
        }

        // Show success state briefly before auto-closing
        if (!authService.isAnonymous) {
          return const AlertDialog(
            backgroundColor: VineTheme.cardBackground,
            title: Row(
              children: [
                Icon(Icons.check_circle, color: VineTheme.vineGreen),
                SizedBox(width: 12),
                Text('Account Secured!', style: TextStyle(color: Colors.white)),
              ],
            ),
            content: Text(
              'Your account is now linked to your email.',
              style: TextStyle(color: Colors.white70),
            ),
          );
        }

        // Show waiting state
        return AlertDialog(
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
                email,
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
              onPressed: onContinue,
              child: const Text(
                'Continue to App',
                style: TextStyle(color: VineTheme.vineGreen),
              ),
            ),
          ],
        );
      },
    );
  }
}
