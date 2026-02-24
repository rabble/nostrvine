// ABOUTME: Native email/password authentication screen for diVine
// ABOUTME: Handles both login and registration with email verification flow

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
import 'package:openvine/widgets/error_message.dart';

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
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
  }

  void _setErrorMessage(String? message) {
    if (mounted) {
      setState(() => _errorMessage = message);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    // Note: Polling is managed by emailVerificationNotifierProvider
    // which survives navigation, so we don't cancel it here
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
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
        setState(() {
          _errorMessage = 'Unable to access your keys. Please try again.';
        });
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
      _setErrorMessage('An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String? _validateConfirmPassword(String? value) {
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
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
      _setErrorMessage(result.errorDescription ?? 'Registration failed');
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
      _setErrorMessage('Registration complete. Please check your email.');
    }
  }

  void _showVerificationDialog(String email) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
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
    // User can use the app while waiting for verification
    // The polling continues in the background
    // Navigate to explore screen
    if (mounted) {
      context.go(ExploreScreen.path);
    }
  }

  InputDecoration _buildInputDecoration({
    required String label,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
    );
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
          child: Column(
            children: [
              // Header with back button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => context.pop(),
                    ),
                    const Spacer(),
                  ],
                ),
              ),

              // Form
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 32),

                        // Email field
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          decoration: _buildInputDecoration(
                            label: 'Email',
                            icon: Icons.email_outlined,
                          ),
                          validator: Validators.validateEmail,
                        ),
                        const SizedBox(height: 16),

                        // Password field
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: _buildInputDecoration(
                            label: 'Password',
                            icon: Icons.lock_outlined,
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                                color: Colors.white60,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                          validator: Validators.validatePassword,
                        ),
                        const SizedBox(height: 16),

                        // Confirm password
                        AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _confirmPasswordController,
                                obscureText: _obscureConfirmPassword,
                                decoration: _buildInputDecoration(
                                  label: 'Confirm Password',
                                  icon: Icons.lock_outlined,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _obscureConfirmPassword
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                      color: Colors.white60,
                                    ),
                                    onPressed: () => setState(
                                      () => _obscureConfirmPassword =
                                          !_obscureConfirmPassword,
                                    ),
                                  ),
                                ),
                                validator: _validateConfirmPassword,
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),

                        // Error message
                        if (_errorMessage != null) ...[
                          ErrorMessage(message: _errorMessage),
                          const SizedBox(height: 16),
                        ],

                        // Submit button
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _handleSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: VineTheme.vineGreen,
                              disabledBackgroundColor: Colors.white60,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: VineTheme.vineGreen,
                                    ),
                                  )
                                : const Text(
                                    'Create Account',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
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
          return AlertDialog(
            backgroundColor: VineTheme.cardBackground,
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: VineTheme.vineGreen),
                SizedBox(width: 12),
                Text('Account Secured!', style: TextStyle(color: Colors.white)),
              ],
            ),
            content: const Text(
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
