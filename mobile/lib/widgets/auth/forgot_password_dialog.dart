// ABOUTME: Shared forgot password dialog for authentication screens
// ABOUTME: StatefulWidget that owns and disposes its TextEditingController

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/utils/validators.dart';

/// Shows a forgot password dialog that sends a reset email.
///
/// [initialEmail] pre-populates the email field.
/// [onSendResetEmail] is called with the validated email address.
void showForgotPasswordDialog({
  required BuildContext context,
  required String initialEmail,
  required Future<void> Function(String email) onSendResetEmail,
}) {
  showDialog<void>(
    context: context,
    builder: (_) => _ForgotPasswordDialog(
      initialEmail: initialEmail,
      onSendResetEmail: onSendResetEmail,
    ),
  );
}

/// Internal dialog widget that manages its own [TextEditingController].
class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({
    required this.initialEmail,
    required this.onSendResetEmail,
  });

  final String initialEmail;
  final Future<void> Function(String email) onSendResetEmail;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late final TextEditingController _emailController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: VineTheme.cardBackground,
      title: const Text(
        'Reset Password',
        style: TextStyle(color: VineTheme.primaryText),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Enter your email address and we'll send you a link to "
                'reset your password.',
                style: TextStyle(color: VineTheme.secondaryText, fontSize: 14),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                style: const TextStyle(color: VineTheme.primaryText),
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  labelStyle: const TextStyle(color: VineTheme.lightText),
                  prefixIcon: const Icon(Icons.email_outlined),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: VineTheme.outlineVariant,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: VineTheme.vineGreen,
                      width: 2,
                    ),
                  ),
                ),
                validator: Validators.validateEmail,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(),
          child: const Text(
            'Cancel',
            style: TextStyle(color: VineTheme.onSurfaceMuted),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: VineTheme.vineGreen,
            foregroundColor: VineTheme.backgroundColor,
          ),
          onPressed: () async {
            if (_formKey.currentState!.validate()) {
              final email = _emailController.text.trim();
              context.pop();
              await widget.onSendResetEmail(email);
            }
          },
          child: const Text('Email Reset Link'),
        ),
      ],
    );
  }
}
