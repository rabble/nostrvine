// ABOUTME: Reset password screen for setting a new password via token
// ABOUTME: Dark-themed screen with password field, samoyed sticker, and submit
// DESIGN: https://www.figma.com/design/rp1DsDEUuCaicW0lk6I2aZ/UI-Design?node-id=7447-109578

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/widgets/auth_back_button.dart';
import 'package:unified_logger/unified_logger.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  /// Route name for navigation
  static const String routeName = 'reset-password';

  /// Path for navigation
  static const String path = '/reset-password';

  const ResetPasswordScreen({required this.token, this.email, super.key});

  final String token;

  /// Account email (optional) — when present, rendered as a read-only field
  /// inside the form's [AutofillGroup] with [AutofillHints.username] so
  /// password managers update the existing credential instead of creating a
  /// new one. See issue #3156.
  final String? email;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  TextEditingController? _emailController;

  bool _isLoading = false;
  String? _errorMessage;

  bool get _hasEmail => widget.email != null && widget.email!.isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (_hasEmail) {
      _emailController = TextEditingController(text: widget.email);
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _emailController?.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final password = _passwordController.text;
    if (password.length < 8) {
      setState(() {
        _errorMessage = context.l10n.authPasswordTooShort;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final oauth = ref.read(oauthClientProvider);

      final result = await oauth.resetPassword(
        token: widget.token,
        newPassword: password,
      );

      if (!mounted) return;

      if (result.success) {
        TextInput.finishAutofillContext();
        if (!mounted) return;
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.authPasswordResetSuccess)),
        );
      } else {
        setState(() {
          _errorMessage =
              result.message ?? context.l10n.authPasswordResetFailed;
        });
      }
    } catch (e) {
      Log.error(
        'Reset Password error: $e',
        name: 'ResetPasswordScreen',
        category: LogCategory.auth,
      );
      if (mounted) {
        setState(() {
          _errorMessage = context.l10n.authUnexpectedError;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),

                      // Back button
                      AuthBackButton(enabled: !_isLoading),

                      const SizedBox(height: 32),

                      // Title
                      Text(
                        context.l10n.authResetPasswordTitle,
                        style: const TextStyle(
                          fontFamily: VineTheme.fontFamilyBricolage,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: VineTheme.whiteText,
                        ),
                      ),

                      const SizedBox(height: 12),

                      // Subtitle
                      Text(
                        context.l10n.authResetPasswordSubtitle,
                        style: const TextStyle(
                          fontSize: 16,
                          color: VineTheme.secondaryText,
                          height: 1.4,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // AutofillGroup + Form enables password manager save
                      // prompts. When the account email is known (passed via
                      // the reset link), render it as a read-only field with
                      // AutofillHints.username so iOS Keychain / Google
                      // Password Manager update the existing credential
                      // rather than creating a duplicate. See #3156.
                      AutofillGroup(
                        child: Form(
                          child: Column(
                            children: [
                              if (_hasEmail) ...[
                                DivineAuthTextField(
                                  controller: _emailController,
                                  label: context.l10n.authEmailLabel,
                                  readOnly: true,
                                  autofillHints: const [
                                    AutofillHints.username,
                                  ],
                                ),
                                const SizedBox(height: 16),
                              ],
                              DivineAuthTextField(
                                controller: _passwordController,
                                label: context.l10n.authNewPasswordLabel,
                                obscureText: true,
                                autofillHints: const [
                                  AutofillHints.newPassword,
                                ],
                                errorText: _errorMessage,
                                enabled: !_isLoading,
                                onChanged: (_) {
                                  if (_errorMessage != null) {
                                    setState(() => _errorMessage = null);
                                  }
                                },
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) => _handleSubmit(),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Samoyed sticker
                      const Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: DivineSticker(
                          sticker: DivineStickerName.samoyedDog,
                          size: 160,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Update password button — pinned below the scrollable content.
              DivineButton(
                expanded: true,
                label: context.l10n.authUpdatePassword,
                isLoading: _isLoading,
                onPressed: _handleSubmit,
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
