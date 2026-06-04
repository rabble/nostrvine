// ABOUTME: Bottom sheet content for the forgot password flow
// ABOUTME: Transitions between form view (enter email) and confirmation view (email sent)

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:keycast_flutter/keycast_flutter.dart' show ForgotPasswordResult;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/validators.dart';
import 'package:url_launcher/url_launcher.dart';

/// The current mode of the forgot password bottom sheet.
enum ForgotPasswordMode { form, confirmation }

/// Bottom sheet content for the forgot password flow.
///
/// Transitions between a form view (enter email) and a confirmation view
/// (email sent) using an animated crossfade.
class ForgotPasswordSheetContent extends StatefulWidget {
  const ForgotPasswordSheetContent({
    required this.initialEmail,
    required this.onSendResetLink,
    super.key,
  });

  /// Pre-filled email from the login form.
  final String initialEmail;

  /// Callback to send the password reset email.
  final Future<ForgotPasswordResult> Function(String email) onSendResetLink;

  @override
  State<ForgotPasswordSheetContent> createState() =>
      _ForgotPasswordSheetContentState();
}

class _ForgotPasswordSheetContentState extends State<ForgotPasswordSheetContent>
    with SingleTickerProviderStateMixin {
  late final TextEditingController _emailController;
  final _formKey = GlobalKey<FormState>();

  ForgotPasswordMode _mode = ForgotPasswordMode.form;
  ForgotPasswordMode _displayedMode = ForgotPasswordMode.form;
  var _isSubmitting = false;
  String? _errorMessage;

  late final AnimationController _controller;
  late final Animation<double> _fadeOutAnimation;
  late final Animation<double> _fadeInAnimation;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeOutAnimation = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.333, curve: Curves.easeOut),
      ),
    );
    _fadeInAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.667, 1, curve: Curves.easeIn),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _transitionTo(ForgotPasswordMode mode) {
    setState(() => _mode = mode);
    _controller.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() => _displayedMode = mode);
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.onSendResetLink(email);
      if (!mounted) return;

      if (result.success) {
        FocusScope.of(context).unfocus();
        _transitionTo(ForgotPasswordMode.confirmation);
      } else {
        setState(() {
          _errorMessage =
              result.error ?? context.l10n.authFailedToSendResetEmail;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _errorMessage = context.l10n.authUnexpectedErrorShort,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTransitioning = _mode != ForgotPasswordMode.form;

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final opacity = isTransitioning
              ? (_displayedMode != ForgotPasswordMode.form
                    ? _fadeInAnimation.value
                    : 0.0)
              : _fadeOutAnimation.value;

          return Opacity(
            opacity: isTransitioning ? opacity : _fadeOutAnimation.value,
            child: switch (_displayedMode) {
              ForgotPasswordMode.form => _ForgotPasswordForm(
                formKey: _formKey,
                emailController: _emailController,
                errorMessage: _errorMessage,
                isSubmitting: _isSubmitting,
                onSubmit: _submit,
              ),
              ForgotPasswordMode.confirmation => _ForgotPasswordConfirmation(
                email: _emailController.text.trim(),
              ),
            },
          );
        },
      ),
    );
  }
}

/// Form view for the forgot password sheet — enter email and submit.
class _ForgotPasswordForm extends StatelessWidget {
  const _ForgotPasswordForm({
    required this.formKey,
    required this.emailController,
    required this.errorMessage,
    required this.isSubmitting,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final String? errorMessage;
  final bool isSubmitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final validationMessages = AuthValidationMessages.fromL10n(context.l10n);
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(16, 32, 16, 16 + bottomInset),
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const DivineSticker(sticker: DivineStickerName.forgotPasswordAlt),
              const SizedBox(height: 16),
              Text(
                context.l10n.authResetPassword,
                style: VineTheme.headlineSmallFont(),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.authResetPasswordDescription,
                style: VineTheme.bodyLargeFont(
                  color: VineTheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              DivineAuthTextField(
                label: context.l10n.authEmailLabel,
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                validator: (value) => Validators.validateEmail(
                  value,
                  messages: validationMessages,
                ),
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  errorMessage!,
                  style: VineTheme.bodyMediumFont(color: VineTheme.error),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 32),
              DivineButton(
                label: isSubmitting
                    ? context.l10n.authSending
                    : context.l10n.authSendResetLink,
                expanded: true,
                onPressed: isSubmitting ? null : onSubmit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Confirmation view shown after the reset email is sent.
class _ForgotPasswordConfirmation extends StatelessWidget {
  const _ForgotPasswordConfirmation({required this.email});

  final String email;

  Future<void> _openEmailApp() async {
    // On iOS, 'message://' opens the Mail app inbox directly.
    // On Android, fall back to 'mailto:' which shows an app chooser
    // for email apps (compose mode is unavoidable on Android).
    final uri = defaultTargetPlatform == TargetPlatform.iOS
        ? Uri.parse('message://')
        : Uri.parse('mailto:');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const DivineSticker(sticker: DivineStickerName.email),
          const SizedBox(height: 16),
          Text(
            context.l10n.authEmailSent,
            style: VineTheme.headlineSmallFont(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Builder(
            builder: (context) {
              final baseStyle = VineTheme.bodyLargeFont(
                color: VineTheme.onSurfaceVariant,
              );
              final message = context.l10n.authResetLinkSentTo(email);
              final emailStart = message.indexOf(email);
              if (emailStart < 0) {
                return Text(
                  message,
                  style: baseStyle,
                  textAlign: TextAlign.center,
                );
              }
              return Text.rich(
                TextSpan(
                  style: baseStyle,
                  children: [
                    TextSpan(text: message.substring(0, emailStart)),
                    TextSpan(
                      text: email,
                      style: baseStyle.copyWith(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(
                      text: message.substring(emailStart + email.length),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              );
            },
          ),
          const SizedBox(height: 32),
          DivineButton(
            label: context.l10n.authOpenEmailApp,
            expanded: true,
            onPressed: () {
              _openEmailApp();
              context.pop();
            },
          ),
        ],
      ),
    );
  }
}
