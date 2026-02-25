// ABOUTME: Shared scaffold layout for auth form screens (create account,
// ABOUTME: secure account). Owns the email/password DivineAuthTextFields
// ABOUTME: internally to guarantee consistency between forms.
// Figma: https://www.figma.com/design/rp1DsDEUuCaicW0lk6I2aZ/UI-Design?node-id=6560-62187

import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/widgets/auth_back_button.dart';

/// A shared scaffold layout for authentication form screens.
///
/// Provides the standard dark-background layout with:
/// - [AuthBackButton] at the top
/// - Title text
/// - Email and password [DivineAuthTextField] fields (built internally)
/// - Dog sticker (right-aligned, rotated)
/// - Optional error widget
/// - Primary and optional secondary button slots pushed to bottom
///
/// The email and password fields are constructed internally with shared
/// configuration (labels, keyboard type, autofill hints) to prevent
/// drift between CreateAccountScreen and SecureAccountScreen. Each screen
/// passes controllers, error strings, and onChanged callbacks for the
/// parts that differ.
class AuthFormScaffold extends StatelessWidget {
  const AuthFormScaffold({
    super.key,
    required this.title,
    required this.emailController,
    required this.passwordController,
    this.emailError,
    this.passwordError,
    this.enabled = true,
    this.onEmailChanged,
    this.onPasswordChanged,
    this.errorWidget,
    required this.primaryButton,
    this.secondaryButton,
    this.onBack,
  });

  /// The title displayed below the back button.
  final String title;

  /// Controller for the email text field.
  final TextEditingController emailController;

  /// Controller for the password text field.
  final TextEditingController passwordController;

  /// Error message for the email field (null = no error).
  final String? emailError;

  /// Error message for the password field (null = no error).
  final String? passwordError;

  /// Whether the form fields are enabled.
  final bool enabled;

  /// Called when the email field text changes.
  final ValueChanged<String>? onEmailChanged;

  /// Called when the password field text changes.
  final ValueChanged<String>? onPasswordChanged;

  /// Optional error widget displayed below the dog sticker.
  final Widget? errorWidget;

  /// The primary action button (e.g. "Create account").
  final Widget primaryButton;

  /// Optional secondary action button (e.g. "Skip for now").
  final Widget? secondaryButton;

  /// Custom back button callback. Defaults to `context.pop()`.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),

                    // Back button
                    AuthBackButton(onPressed: onBack ?? () => context.pop()),

                    const SizedBox(height: 32),

                    // Title
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: VineTheme.fontFamilyBricolage,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: VineTheme.whiteText,
                      ),
                    ),

                    const SizedBox(height: 32),

                    // AutofillGroup + Form enables password manager
                    // autofill for the email and password fields.
                    AutofillGroup(
                      child: Form(
                        child: Column(
                          children: [
                            // Email field
                            DivineAuthTextField(
                              controller: emailController,
                              label: 'Email',
                              keyboardType: TextInputType.emailAddress,
                              errorText: emailError,
                              enabled: enabled,
                              autocorrect: false,
                              autofillHints: const [AutofillHints.email],
                              onChanged: onEmailChanged,
                            ),

                            const SizedBox(height: 16),

                            // Password field
                            DivineAuthTextField(
                              controller: passwordController,
                              label: 'Password',
                              obscureText: true,
                              autofillHints: const [AutofillHints.newPassword],
                              errorText: passwordError,
                              enabled: enabled,
                              onChanged: onPasswordChanged,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Dog sticker
                    Align(
                      alignment: Alignment.centerRight,
                      child: Transform.translate(
                        offset: const Offset(20, 0),
                        child: Transform.rotate(
                          angle: 12 * pi / 180,
                          child: Image.asset(
                            'assets/stickers/samoyed_dog.png',
                            width: 174,
                            height: 174,
                          ),
                        ),
                      ),
                    ),

                    // Error display
                    if (errorWidget != null) ...[
                      const SizedBox(height: 16),
                      errorWidget!,
                    ],

                    // Push buttons to bottom
                    const Spacer(),

                    // Primary button
                    primaryButton,

                    // Secondary button (optional)
                    if (secondaryButton != null) ...[
                      const SizedBox(height: 12),
                      secondaryButton!,
                    ],

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
