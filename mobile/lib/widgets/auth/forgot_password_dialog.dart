// ABOUTME: Shared forgot password dialog for authentication screens
// ABOUTME: StatefulWidget that owns and disposes its TextEditingController

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:keycast_flutter/keycast_flutter.dart' show ForgotPasswordResult;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/validators.dart';

/// Shows a forgot password dialog that sends a reset email.
///
/// [initialEmail] pre-populates the email field.
/// [onSendResetEmail] is called with the validated email address.
void showForgotPasswordDialog({
  required BuildContext context,
  required String initialEmail,
  required Future<ForgotPasswordResult> Function(String email) onSendResetEmail,
}) {
  VineBottomSheet.show<void>(
    context: context,
    scrollable: false,
    title: Text(context.l10n.forgotPasswordTitle),
    body: _ForgotPasswordSheetContent(
      initialEmail: initialEmail,
      onSendResetEmail: onSendResetEmail,
    ),
  );
}

/// Internal sheet content widget that manages its own [TextEditingController].
class _ForgotPasswordSheetContent extends StatefulWidget {
  const _ForgotPasswordSheetContent({
    required this.initialEmail,
    required this.onSendResetEmail,
  });

  final String initialEmail;
  final Future<ForgotPasswordResult> Function(String email) onSendResetEmail;

  @override
  State<_ForgotPasswordSheetContent> createState() =>
      _ForgotPasswordSheetContentState();
}

class _ForgotPasswordSheetContentState
    extends State<_ForgotPasswordSheetContent> {
  late final TextEditingController _emailController;
  final _formKey = GlobalKey<FormState>();
  var _isSubmitting = false;
  var _sendFailed = false;

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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _sendFailed = false;
    });

    try {
      final result = await widget.onSendResetEmail(
        _emailController.text.trim(),
      );
      if (!mounted) return;

      if (result.success) {
        context.pop();
      } else {
        setState(() {
          _isSubmitting = false;
          _sendFailed = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _sendFailed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final validationMessages = AuthValidationMessages.fromL10n(context.l10n);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.forgotPasswordDescription,
              style: TextStyle(
                color: context.vineColors.secondaryText,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              style: TextStyle(color: context.vineColors.primaryText),
              decoration: InputDecoration(
                labelText: context.l10n.forgotPasswordEmailLabel,
                labelStyle: TextStyle(color: context.vineColors.mutedText),
                prefixIcon: const Icon(Icons.email_outlined),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.vineColors.outline),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: VineTheme.vineGreen,
                    width: 2,
                  ),
                ),
              ),
              validator: (value) =>
                  Validators.validateEmail(value, messages: validationMessages),
            ),
            if (_sendFailed) ...[
              const SizedBox(height: 16),
              Text(
                context.l10n.authFailedToSendResetEmail,
                style: VineTheme.bodyMediumFont(color: VineTheme.error),
              ),
            ],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSubmitting ? null : () => context.pop(),
                  child: Text(
                    context.l10n.forgotPasswordCancel,
                    style: TextStyle(color: context.vineColors.onSurfaceMuted),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VineTheme.vineGreen,
                    foregroundColor: context.vineColors.background,
                  ),
                  onPressed: _isSubmitting ? null : _submit,
                  child: Text(
                    _isSubmitting
                        ? context.l10n.authSending
                        : _sendFailed
                        ? context.l10n.authTryAgain
                        : context.l10n.forgotPasswordSendLink,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
