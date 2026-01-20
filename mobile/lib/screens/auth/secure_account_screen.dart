// ABOUTME: Native email/password registration screen for diVine
// ABOUTME: Handles registration with nsec and email verification flow

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/mixins/email_verification_mixin.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/utils/validators.dart';
import 'package:openvine/widgets/auth/auth_gradient_background.dart';
import 'package:openvine/widgets/auth/auth_submit_button.dart';
import 'package:openvine/widgets/auth/auth_text_field.dart';
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

class _SecureAccountScreenState extends ConsumerState<SecureAccountScreen>
    with EmailVerificationMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  @override
  void setErrorMessage(String? message) {
    if (mounted) {
      setState(() => _errorMessage = message);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    disposeVerification();
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
      final keyManager = ref.watch(nostrKeyManagerProvider);
      final nsec = keyManager.exportAsNsec();

      final (result, verifier) = await oauth.headlessRegister(
        email: email,
        nsec: nsec,
        password: password,
        scope: 'policy:full',
      );

      if (!result.success) {
        setErrorMessage(result.error ?? 'Registration failed');
        return;
      }

      if (result.verificationRequired && result.deviceCode != null) {
        // Store for polling and show verification UI
        setPendingVerification(
          deviceCode: result.deviceCode!,
          verifier: verifier,
          email: email,
        );

        startVerificationPolling(oauth);

        if (mounted) {
          showVerificationDialog();
        }
      } else {
        setErrorMessage('Registration complete. Please check your email.');
      }
    } catch (e) {
      Log.error(
        'Auth error: $e',
        name: 'SecureAccountScreen',
        category: LogCategory.auth,
      );
      setErrorMessage('An unexpected error occurred. Please try again.');
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

  @override
  Widget build(BuildContext context) => Scaffold(
    body: AuthGradientBackground(
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
                      AuthTextField(
                        controller: _emailController,
                        label: 'Email',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        validator: Validators.validateEmail,
                      ),
                      const SizedBox(height: 16),

                      // Password field
                      AuthTextField(
                        controller: _passwordController,
                        label: 'Password',
                        icon: Icons.lock_outlined,
                        obscureText: _obscurePassword,
                        onToggleObscure: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        validator: Validators.validatePassword,
                      ),
                      const SizedBox(height: 16),

                      // Confirm password
                      AuthTextField(
                        controller: _confirmPasswordController,
                        label: 'Confirm Password',
                        icon: Icons.lock_outlined,
                        obscureText: _obscureConfirmPassword,
                        onToggleObscure: () => setState(
                          () => _obscureConfirmPassword =
                              !_obscureConfirmPassword,
                        ),
                        validator: _validateConfirmPassword,
                      ),
                      const SizedBox(height: 16),

                      // Error message
                      if (_errorMessage != null) ...[
                        ErrorMessage(message: _errorMessage),
                        const SizedBox(height: 16),
                      ],

                      // Submit button
                      AuthSubmitButton(
                        isLoading: _isLoading,
                        label: 'Create Account',
                        onPressed: _handleSubmit,
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
