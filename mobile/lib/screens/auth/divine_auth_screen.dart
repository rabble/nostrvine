// ABOUTME: Native email/password authentication screen for diVine
// ABOUTME: Handles both login and registration with email verification flow

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/home_screen_router.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/utils/validators.dart';
import 'package:openvine/widgets/error_message.dart';

/// Mode for the auth screen
enum AuthMode { login, register }

class DivineAuthScreen extends ConsumerStatefulWidget {
  /// Route name for the auth screen
  static const String routeName = 'auth-native';

  /// Path for the auth screen
  static const String path = '/auth-native';

  /// Initial mode - can be overridden by tab selection
  final AuthMode initialMode;

  const DivineAuthScreen({super.key, this.initialMode = AuthMode.login});

  @override
  ConsumerState<DivineAuthScreen> createState() => _DivineAuthScreenState();
}

class _DivineAuthScreenState extends ConsumerState<DivineAuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  // For email verification polling
  String? _pendingDeviceCode;
  String? _pendingVerifier;
  String? _pendingEmail;
  Timer? _pollTimer;

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
    _pollTimer?.cancel();
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
      setState(() {
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleLogin(
    KeycastOAuth oauth,
    String email,
    String password,
  ) async {
    final (result, verifier) = await oauth.headlessLogin(
      email: email,
      password: password,
      scope: 'policy:full',
    );

    if (!result.success || result.code == null) {
      setState(() {
        _errorMessage =
            result.errorDescription ?? result.error ?? 'Login failed';
      });
      return;
    }

    // Exchange code for tokens
    await _exchangeCodeAndLogin(oauth, result.code!, verifier);
  }

  Future<void> _handleRegister(
    KeycastOAuth oauth,
    String email,
    String password,
  ) async {
    final (result, verifier) = await oauth.headlessRegister(
      email: email,
      password: password,
      scope: 'policy:full',
    );

    if (!result.success) {
      setState(() {
        _errorMessage = result.error ?? 'Registration failed';
      });
      return;
    }

    if (result.verificationRequired && result.deviceCode != null) {
      // Store for polling and show verification UI
      setState(() {
        _pendingDeviceCode = result.deviceCode;
        _pendingVerifier = verifier;
        _pendingEmail = email;
      });

      // Start background polling
      _startPolling(oauth);

      // Show verification dialog but let user continue
      if (mounted) {
        _showVerificationDialog();
      }
    } else {
      // No verification needed (unlikely but handle it)
      // This shouldn't happen with the current backend
      setState(() {
        _errorMessage = 'Registration complete. Please check your email.';
      });
    }
  }

  void _startPolling(KeycastOAuth oauth) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      if (_pendingDeviceCode == null || !mounted) {
        timer.cancel();
        return;
      }

      final result = await oauth.pollForCode(_pendingDeviceCode!);

      switch (result.status) {
        case PollStatus.complete:
          timer.cancel();
          if (result.code != null && _pendingVerifier != null) {
            await _exchangeCodeAndLogin(oauth, result.code!, _pendingVerifier!);
          }
          break;
        case PollStatus.pending:
          // Keep polling
          break;
        case PollStatus.error:
          timer.cancel();
          if (mounted) {
            setState(() {
              _errorMessage = result.error ?? 'Verification failed';
            });
          }
          break;
      }
    });
  }

  void _showVerificationDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
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
              _pendingEmail ?? '',
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
            onPressed: () {
              Navigator.of(context).pop();
              // Let user continue to the app
              _continueToApp();
            },
            child: const Text(
              'Continue to App',
              style: TextStyle(color: VineTheme.vineGreen),
            ),
          ),
        ],
      ),
    );
  }

  void _continueToApp() {
    // User can use the app while waiting for verification
    // The polling continues in the background
    // Navigate to home
    if (mounted) {
      context.go(HomeScreenRouter.pathForIndex(0));
    }
  }

  Future<void> _exchangeCodeAndLogin(
    KeycastOAuth oauth,
    String code,
    String verifier,
  ) async {
    try {
      final tokenResponse = await oauth.exchangeCode(
        code: code,
        verifier: verifier,
      );

      // Get the session and sign in
      final session = KeycastSession.fromTokenResponse(tokenResponse);
      final authService = ref.read(authServiceProvider);
      await authService.signInWithDivineOAuth(session);

      // Clear pending state
      setState(() {
        _pendingDeviceCode = null;
        _pendingVerifier = null;
        _pendingEmail = null;
      });

      // Navigation will be handled by auth state listener
    } on OAuthException catch (e) {
      setState(() {
        _errorMessage = e.message;
      });
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

                        // Confirm password (register only)
                        AnimatedSize(
                          duration: const Duration(milliseconds: 200),
                          child: _tabController.index == 1
                              ? Column(
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
                                )
                              : const SizedBox.shrink(),
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
                                : Text(
                                    _tabController.index == 0
                                        ? 'Log In'
                                        : 'Create Account',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
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
  }

  void _showForgotPasswordDialog() {
    // Pre-fill from the main email controller
    final resetEmailController = TextEditingController(
      text: _emailController.text,
    );
    final dialogFormKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
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
                TextFormField(
                  controller: resetEmailController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: _buildInputDecoration(
                    label: 'Email Address',
                    icon: Icons.email_outlined,
                  ),
                  validator: Validators.validateEmail,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
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
                Navigator.pop(context); // Close dialog
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
          setState(() {
            _errorMessage = result.error ?? 'Failed to send reset email.';
          });
        }
      }
    } catch (e) {
      setState(() => _errorMessage = 'An unexpected error occurred.');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
}
