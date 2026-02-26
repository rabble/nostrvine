// ABOUTME: Reset password screen for setting a new password via token
// ABOUTME: Dark-themed screen with password field, samoyed sticker, and submit
// DESIGN: https://www.figma.com/design/rp1DsDEUuCaicW0lk6I2aZ/UI-Design?node-id=7447-109578

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/auth_back_button.dart';
import 'package:openvine/widgets/divine_primary_button.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  /// Route name for navigation
  static const String routeName = 'reset-password';

  /// Path for navigation
  static const String path = '/reset-password';

  const ResetPasswordScreen({required this.token, super.key});

  final String token;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final password = _passwordController.text;
    if (password.length < 8) {
      setState(() {
        _errorMessage = 'Password must be at least 8 characters';
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
        context.pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset successful. Please log in.'),
          ),
        );
      } else {
        setState(() {
          _errorMessage = result.message ?? 'Password reset failed';
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
          _errorMessage = 'An unexpected error occurred. Please try again.';
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
              const SizedBox(height: 8),

              // Back button
              AuthBackButton(
                onPressed: _isLoading ? null : () => context.pop(),
              ),

              const SizedBox(height: 32),

              // Title
              const Text(
                'Reset Password',
                style: TextStyle(
                  fontFamily: VineTheme.fontFamilyBricolage,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: VineTheme.whiteText,
                ),
              ),

              const SizedBox(height: 12),

              // Subtitle
              const Text(
                'Please enter your new password. It must be at '
                'least 8 characters in length.',
                style: TextStyle(
                  fontSize: 16,
                  color: VineTheme.secondaryText,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 32),

              // Password field
              DivineAuthTextField(
                controller: _passwordController,
                label: 'New Password',
                obscureText: true,
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

              const SizedBox(height: 32),

              // Samoyed sticker
              const Align(
                alignment: Alignment.centerRight,
                child: DivineSticker(
                  sticker: DivineStickerName.samoyedDog,
                  size: 160,
                ),
              ),

              const Spacer(),

              // Update password button
              DivinePrimaryButton(
                label: 'Update password',
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
