// ABOUTME: Native email/password authentication screen for diVine
// ABOUTME: Handles both login and registration with email verification flow

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/mixins/email_verification_mixin.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/utils/validators.dart';
import 'package:openvine/widgets/auth/auth_gradient_background.dart';
import 'package:openvine/widgets/auth/auth_submit_button.dart';
import 'package:openvine/widgets/auth/auth_text_field.dart';
import 'package:openvine/widgets/error_message.dart';

/// Mode for the auth screen
enum AuthMode { login, register }

class DivineAuthScreen extends ConsumerStatefulWidget {
  /// Initial mode - can be overridden by tab selection
  final AuthMode initialMode;

  const DivineAuthScreen({super.key, this.initialMode = AuthMode.login});

  @override
  ConsumerState<DivineAuthScreen> createState() => _DivineAuthScreenState();
}

class _DivineAuthScreenState extends ConsumerState<DivineAuthScreen>
    with SingleTickerProviderStateMixin, EmailVerificationMixin {
  late TabController _tabController;
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
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialMode == AuthMode.register ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    disposeVerification();
    super.dispose();
  }

  AuthMode get _currentMode =>
      _tabController.index == 0 ? AuthMode.login : AuthMode.register;

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

      if (_currentMode == AuthMode.login) {
        await _handleLogin(oauth, email, password);
      } else {
        await _handleRegister(oauth, email, password);
      }
    } catch (e) {
      Log.error(
        'Auth error: $e',
        name: 'DivineAuthScreen',
        category: LogCategory.auth,
      );
      setErrorMessage('An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleLogin(
    dynamic oauth,
    String email,
    String password,
  ) async {
    final (result, verifier) = await oauth.headlessLogin(
      email: email,
      password: password,
      scope: 'policy:full',
    );

    if (!result.success || result.code == null) {
      setErrorMessage(
        result.errorDescription ?? result.error ?? 'Login failed',
      );
      return;
    }

    // Exchange code for tokens
    await exchangeCodeAndLogin(oauth, result.code!, verifier);
  }

  Future<void> _handleRegister(
    dynamic oauth,
    String email,
    String password,
  ) async {
    final (result, verifier) = await oauth.headlessRegister(
      email: email,
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
  }

  String? _validateConfirmPassword(String? value) {
    if (_currentMode == AuthMode.login) return null;
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

            // Tab bar
            TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white60,
              tabs: const [
                Tab(text: 'Log In'),
                Tab(text: 'Create Account'),
              ],
              onTap: (_) {
                // Clear error when switching tabs
                setState(() => _errorMessage = null);
              },
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

                      // Confirm password (register only)
                      AnimatedSize(
                        duration: const Duration(milliseconds: 200),
                        child: _tabController.index == 1
                            ? Column(
                                children: [
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
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),

                      // Error message
                      if (_errorMessage != null) ...[
                        ErrorMessage(message: _errorMessage),
                        const SizedBox(height: 16),
                      ],

                      // Submit button
                      AuthSubmitButton(
                        isLoading: _isLoading,
                        label: _tabController.index == 0
                            ? 'Log In'
                            : 'Create Account',
                        onPressed: _handleSubmit,
                      ),

                      const SizedBox(height: 24),

                      // Forgot password (login only)
                      if (_tabController.index == 0)
                        TextButton(
                          onPressed: _showForgotPasswordDialog,
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(color: Colors.white70),
                          ),
                        ),
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

  void _showForgotPasswordDialog() {
    // Pre-fill from the main email controller
    final resetEmailController = TextEditingController(
      text: _emailController.text,
    );
    final dialogFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: VineTheme.cardBackground,
        title: const Text(
          'Reset Password',
          style: TextStyle(color: Colors.white),
        ),
        content: Form(
          key: dialogFormKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Enter your email address and we\'ll send you a link to reset your password.',
                  style: TextStyle(color: Colors.grey[400], fontSize: 14),
                ),
                const SizedBox(height: 20),
                AuthTextField(
                  controller: resetEmailController,
                  label: 'Email Address',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  validator: Validators.validateEmail,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: dialogContext.pop,
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.white60),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: VineTheme.vineGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (dialogFormKey.currentState!.validate()) {
                final email = resetEmailController.text.trim();
                dialogContext.pop();
                await _performPasswordReset(email);
              }
            },
            child: const Text('Email Reset Link'),
          ),
        ],
      ),
    );
  }

  Future<void> _performPasswordReset(String email) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final oauth = ref.read(oauthClientProvider);
      final result = await oauth.sendPasswordResetEmail(email);

      if (mounted) {
        if (result.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.message ??
                    'If an account exists with that email, '
                        'a password reset link has been sent.',
              ),
              backgroundColor: VineTheme.vineGreen,
            ),
          );
        } else {
          setErrorMessage(result.error ?? 'Failed to send reset email.');
        }
      }
    } catch (e) {
      setErrorMessage('An unexpected error occurred.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
