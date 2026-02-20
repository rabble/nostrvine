// ABOUTME: Native email/password authentication screen for diVine
// ABOUTME: Handles both login and registration with mode-switch links

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:openvine/screens/auth/email_verification_screen.dart';
import 'package:openvine/screens/auth/forgot_password/forgot_password_sheet_content.dart';
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

  /// Initial mode for the auth screen.
  final AuthMode initialMode;

  const DivineAuthScreen({super.key, this.initialMode = AuthMode.login});

  @override
  ConsumerState<DivineAuthScreen> createState() => _DivineAuthScreenState();
}

class _DivineAuthScreenState extends ConsumerState<DivineAuthScreen> {
  var _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  late AuthMode _mode;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  void _setErrorMessage(String? message) {
    if (mounted) {
      setState(() => _errorMessage = message);
    }
  }

  void _switchMode() {
    setState(() {
      _mode = _mode == AuthMode.login ? AuthMode.register : AuthMode.login;
      _errorMessage = null;
      _confirmPasswordController.clear();
      _formKey.currentState?.reset();
      _formKey = GlobalKey<FormState>();
    });
  }

  bool get _isLogin => _mode == AuthMode.login;

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

      if (_isLogin) {
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
      _setErrorMessage('An unexpected error occurred. Please try again.');
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
      _setErrorMessage(
        result.errorDescription ?? result.error ?? 'Login failed',
      );
      return;
    }

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
      _setErrorMessage(result.error ?? 'Registration failed');
      return;
    }

    if (result.verificationRequired && result.deviceCode != null) {
      final pendingService = ref.read(pendingVerificationServiceProvider);
      await pendingService.save(
        deviceCode: result.deviceCode!,
        verifier: verifier,
        email: email,
      );

      if (mounted) {
        final encodedEmail = Uri.encodeComponent(email);
        context.go(
          '${EmailVerificationScreen.path}'
          '?deviceCode=${result.deviceCode}'
          '&verifier=$verifier'
          '&email=$encodedEmail',
        );
      }
    } else {
      _setErrorMessage('Registration complete. Please check your email.');
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

      final session = KeycastSession.fromTokenResponse(tokenResponse);
      final authService = ref.read(authServiceProvider);
      await authService.signInWithDivineOAuth(session);

      TextInput.finishAutofillContext();
    } on OAuthException catch (e) {
      _setErrorMessage(e.message);
    } catch (e) {
      Log.error(
        'Error exchanging code: $e',
        name: 'DivineAuthScreen',
        category: LogCategory.auth,
      );
      _setErrorMessage('Failed to complete authentication');
    }
  }

  String? _validateConfirmPassword(String? value) {
    if (_isLogin) return null;
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.surfaceBackground,
      resizeToAvoidBottomInset: false,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          child: Stack(
            children: [
              // Scrollable form content fills entire safe area
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _AuthFormContent(
                  key: ValueKey(_mode),
                  formKey: _formKey,
                  isLogin: _isLogin,
                  isLoading: _isLoading,
                  errorMessage: _errorMessage,
                  emailController: _emailController,
                  passwordController: _passwordController,
                  confirmPasswordController: _confirmPasswordController,
                  onForgotPassword: _showForgotPasswordDialog,
                  validateConfirmPassword: _validateConfirmPassword,
                  onSubmit: _handleSubmit,
                  onSwitchMode: _switchMode,
                ),
              ),

              // Back button overlays top-left
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: DivineIconButton(
                  icon: DivineIconName.caretLeft,
                  type: DivineIconButtonType.secondary,
                  size: DivineIconButtonSize.small,
                  onPressed: () => context.pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    VineBottomSheet.show<void>(
      context: context,
      scrollable: false,
      showHeaderDivider: false,
      body: ForgotPasswordSheetContent(
        initialEmail: _emailController.text,
        onSendResetLink: (email) =>
            ref.read(oauthClientProvider).sendPasswordResetEmail(email),
      ),
    );
  }
}

/// Full form content that crossfades when switching modes.
///
/// Contains the title, fields, button, and mode-switch link.
class _AuthFormContent extends StatelessWidget {
  const _AuthFormContent({
    required this.formKey,
    required this.isLogin,
    required this.isLoading,
    required this.errorMessage,
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.onForgotPassword,
    required this.validateConfirmPassword,
    required this.onSubmit,
    required this.onSwitchMode,
    super.key,
  });

  final GlobalKey<FormState> formKey;
  final bool isLogin;
  final bool isLoading;
  final String? errorMessage;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final VoidCallback onForgotPassword;
  final FormFieldValidator<String> validateConfirmPassword;
  final VoidCallback onSubmit;
  final VoidCallback onSwitchMode;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const ClampingScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Space for back button overlay
                  const SizedBox(height: 72),

                  // Title
                  Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: Text(
                      isLogin ? 'Sign in' : 'Create account',
                      style: VineTheme.headlineLargeFont(),
                    ),
                  ),

                  // Email field
                  DivineAuthTextField(
                    label: 'Email',
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    validator: Validators.validateEmail,
                  ),
                  const SizedBox(height: 16),

                  // Password field
                  DivineAuthTextField(
                    label: 'Password',
                    controller: passwordController,
                    obscureText: true,
                    validator: Validators.validatePassword,
                  ),

                  // Forgot password (login only)
                  if (isLogin) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: DivineTextLink(
                        text: 'Forgot password?',
                        onTap: onForgotPassword,
                        style:
                            VineTheme.bodyMediumFont(
                              color: VineTheme.onSurfaceMuted,
                            ).copyWith(
                              decoration: TextDecoration.underline,
                              decorationColor: VineTheme.onSurfaceMuted,
                            ),
                      ),
                    ),
                  ],

                  // Confirm password (register)
                  if (!isLogin) ...[
                    const SizedBox(height: 16),
                    DivineAuthTextField(
                      label: 'Confirm Password',
                      controller: confirmPasswordController,
                      obscureText: true,
                      validator: validateConfirmPassword,
                    ),
                  ],

                  // Push button to bottom
                  const Spacer(),
                  const SizedBox(height: 32),

                  // Error message
                  if (errorMessage != null) ...[
                    ErrorMessage(message: errorMessage),
                    const SizedBox(height: 16),
                  ],

                  // Submit button
                  DivineButton(
                    label: isLogin ? 'Sign in' : 'Create account',
                    expanded: true,
                    isLoading: isLoading,
                    onPressed: isLoading ? null : onSubmit,
                  ),
                  const SizedBox(height: 16),

                  // Mode switch link
                  _AuthModeSwitchLink(isLogin: isLogin, onTap: onSwitchMode),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Bottom link to switch between login and register modes.
///
/// Shows "New to diVine? Create account" on login,
/// and "Already have an account? Sign in" on register.
class _AuthModeSwitchLink extends StatelessWidget {
  const _AuthModeSwitchLink({required this.isLogin, required this.onTap});

  final bool isLogin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final prefix = isLogin ? 'New to diVine? ' : 'Already have an account? ';
    final action = isLogin ? 'Create account' : 'Sign in';

    return Center(
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: prefix,
              style: VineTheme.bodyLargeFont(color: VineTheme.onSurfaceVariant),
            ),
            TextSpan(
              text: action,
              style: VineTheme.bodyLargeFont(color: VineTheme.onSurfaceVariant)
                  .copyWith(
                    decoration: TextDecoration.underline,
                    decorationColor: VineTheme.primary,
                    decorationThickness: 2,
                  ),
              recognizer: TapGestureRecognizer()..onTap = onTap,
            ),
          ],
        ),
      ),
    );
  }
}
