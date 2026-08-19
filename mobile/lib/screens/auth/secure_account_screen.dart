// ABOUTME: Secure account screen for existing anonymous users
// ABOUTME: Allows adding email/password to an existing anonymous account

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/router/routes/router_guards.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/utils/validators.dart';
import 'package:openvine/widgets/auth/auth_error_box.dart';
import 'package:openvine/widgets/auth/auth_form_scaffold.dart';
import 'package:unified_logger/unified_logger.dart';

class SecureAccountScreen extends ConsumerStatefulWidget {
  /// Route name for this screen.
  static const routeName = 'secure-account';

  /// Path for this route.
  static const String path = RoutePaths.secureAccount;

  const SecureAccountScreen({super.key});

  @override
  ConsumerState<SecureAccountScreen> createState() =>
      _SecureAccountScreenState();
}

class _SecureAccountScreenState extends ConsumerState<SecureAccountScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  String? _emailError;
  String? _passwordError;
  String? _confirmPasswordError;
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
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final messages = AuthValidationMessages.fromL10n(context.l10n);
    final emailError = Validators.validateEmail(
      _emailController.text.trim(),
      messages: messages,
    );
    final passwordError = Validators.validatePassword(
      _passwordController.text,
      messages: messages,
    );
    final confirmPasswordError = Validators.validateConfirmPassword(
      _confirmPasswordController.text,
      password: _passwordController.text,
      messages: messages,
    );

    if (emailError != null ||
        passwordError != null ||
        confirmPasswordError != null) {
      setState(() {
        _emailError = emailError;
        _passwordError = passwordError;
        _confirmPasswordError = confirmPasswordError;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _emailError = null;
      _passwordError = null;
      _confirmPasswordError = null;
      _generalError = null;
    });

    final l10n = context.l10n;
    try {
      final oauth = ref.read(oauthClientProvider);
      final email = _emailController.text.trim();
      final password = _passwordController.text;

      // Use authService.exportNsec() which accesses keys from secure storage
      // This works for both auto-generated and imported keys
      final authService = ref.read(authServiceProvider);
      final nsec = await authService.exportNsec();

      if (nsec == null) {
        _setGeneralError(l10n.authUnableToAccessKeys);
        return;
      }

      await _handleRegister(
        oauth: oauth,
        email: email,
        password: password,
        nsec: nsec,
        ownerPublicKeyHex: authService.currentPublicKeyHex,
      );
    } catch (e) {
      Log.error(
        'Auth error: $e',
        name: 'SecureAccountScreen',
        category: LogCategory.auth,
      );
      _setGeneralError(l10n.authUnexpectedError);
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
    required String? ownerPublicKeyHex,
  }) async {
    final (result, verifier) = await oauth.headlessRegister(
      email: email,
      nsec: nsec,
      password: password,
      scope: 'policy:full',
    );

    if (!result.success) {
      // CONFLICT means the key or the entered email already has an account
      // (the common case is a registered key the app forgot after falling back
      // to anonymous). Route to the recovery hub instead of dead-ending on the
      // raw server text.
      if (result.errorCode == 'CONFLICT') {
        if (!mounted) return;
        context.go(
          WelcomeScreen.loginOptionsPathWithRecovery(
            email: email,
            error: context.l10n.authSecureAccountAlreadyRegistered,
          ),
        );
        return;
      }
      _setGeneralError(
        result.errorDescription ?? context.l10n.authRegistrationFailed,
      );
      return;
    }

    final deviceCode = result.deviceCode;
    if (result.verificationRequired && deviceCode != null) {
      await ref
          .read(pendingVerificationServiceProvider)
          .save(
            deviceCode: deviceCode,
            verifier: verifier,
            email: email,
            ownerPublicKeyHex: ownerPublicKeyHex,
          );
      if (!mounted) return;

      TextInput.finishAutofillContext();
      context.go(pendingEmailVerificationLocation(email: email));
    } else {
      _setGeneralError(context.l10n.authRegistrationComplete);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthFormScaffold(
      title: context.l10n.authSecureAccountTitle,
      emailController: _emailController,
      passwordController: _passwordController,
      confirmPasswordController: _confirmPasswordController,
      emailLabel: context.l10n.authEmailLabel,
      passwordLabel: context.l10n.authPasswordLabel,
      confirmPasswordLabel: context.l10n.authConfirmPasswordLabel,
      emailError: _emailError,
      passwordError: _passwordError,
      confirmPasswordError: _confirmPasswordError,
      enabled: !_isLoading,
      onEmailChanged: (_) {
        if (_emailError != null) setState(() => _emailError = null);
      },
      onPasswordChanged: (_) {
        if (_passwordError != null || _confirmPasswordError != null) {
          setState(() {
            _passwordError = null;
            _confirmPasswordError = null;
          });
        }
      },
      onConfirmPasswordChanged: (_) {
        if (_confirmPasswordError != null) {
          setState(() => _confirmPasswordError = null);
        }
      },
      errorWidget: _generalError != null
          ? AuthErrorBox(message: _generalError!)
          : null,
      primaryButton: DivineButton(
        expanded: true,
        label: context.l10n.authSecureAccountTitle,
        isLoading: _isLoading,
        onPressed: _handleSubmit,
      ),
    );
  }
}
