// ABOUTME: Pre-auth invite gate for waitlist-only and invite-code onboarding
// ABOUTME: Uses the invite server config to block or allow new account creation

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:invite_api_client/invite_api_client.dart';
import 'package:openvine/blocs/invite_gate/invite_gate_bloc.dart';
import 'package:openvine/blocs/invite_gate/invite_gate_event.dart';
import 'package:openvine/blocs/invite_gate/invite_gate_state.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/utils/validators.dart';
import 'package:openvine/widgets/auth/auth_error_box.dart';
import 'package:openvine/widgets/auth_back_button.dart';
import 'package:openvine/widgets/rounded_icon_button.dart';
import 'package:url_launcher/url_launcher.dart';

class InviteGateScreen extends StatefulWidget {
  const InviteGateScreen({super.key, this.initialCode, this.initialError});

  static const String routeName = 'invite-gate';
  static const String path = '/invite';

  final String? initialCode;
  final String? initialError;

  @override
  State<InviteGateScreen> createState() => _InviteGateScreenState();
}

class _InviteGateScreenState extends State<InviteGateScreen> {
  late TextEditingController _inviteCodeController;
  String? _waitlistEmail;

  @override
  void initState() {
    super.initState();
    _inviteCodeController = TextEditingController(
      text: widget.initialCode == null
          ? ''
          : InviteApiClient.normalizeCode(widget.initialCode!),
    );
    final inviteGateBloc = context.read<InviteGateBloc>();
    inviteGateBloc.add(const InviteGateTransientCleared());
    inviteGateBloc.add(const InviteGateConfigRequested());
    if (widget.initialError != null && widget.initialError!.isNotEmpty) {
      inviteGateBloc.add(InviteGateGeneralErrorSet(widget.initialError));
    }
  }

  @override
  void dispose() {
    _inviteCodeController.dispose();
    super.dispose();
  }

  void _validateInviteCode() {
    final normalizedCode = InviteApiClient.normalizeCode(
      _inviteCodeController.text,
    );
    _inviteCodeController.value = TextEditingValue(
      text: normalizedCode,
      selection: TextSelection.collapsed(offset: normalizedCode.length),
    );
    context.read<InviteGateBloc>().add(InviteGateCodeSubmitted(normalizedCode));
  }

  Future<void> _showWaitlistSheet(InviteClientConfig config) async {
    final joinedEmail = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WaitlistEntrySheet(
        inviteApiClient: context.read<InviteApiClient>(),
        supportEmail: config.supportEmail,
      ),
    );

    if (joinedEmail != null && mounted) {
      setState(() {
        _waitlistEmail = joinedEmail;
      });
    }
  }

  Future<void> _contactSupport(String supportEmail) async {
    final uri = Uri(
      scheme: 'mailto',
      path: supportEmail,
      queryParameters: const {
        'subject': 'Invite access help',
      },
    );

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open $supportEmail'),
          backgroundColor: VineTheme.error,
        ),
      );
    }
  }

  void _retryConfigLoad() {
    context.read<InviteGateBloc>().add(
      const InviteGateConfigRequested(force: true),
    );
  }

  void _redirectToCreateAccount() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.go(WelcomeScreen.createAccountPath);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final waitlistEmail = _waitlistEmail;

    if (waitlistEmail != null) {
      return _InviteSheetPage(
        showBackButton: false,
        illustrationAsset: 'assets/stickers/confetti.svg',
        title: "You're in!",
        body: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              height: 1.5,
              letterSpacing: 0.15,
              color: VineTheme.lightText,
            ),
            children: [
              const TextSpan(text: "We'll share updates at "),
              TextSpan(
                text: waitlistEmail,
                style: const TextStyle(
                  fontFamily: VineTheme.fontFamilyBricolage,
                  fontWeight: FontWeight.w800,
                  color: VineTheme.whiteText,
                ),
              ),
              const TextSpan(
                text:
                    ".\nWhen more invite codes are available, we'll send them your way.",
              ),
            ],
          ),
        ),
        primaryButton: DivineButton(
          type: .secondary,
          label: 'OK',
          onPressed: () => context.go(WelcomeScreen.path),
        ),
      );
    }

    return BlocConsumer<InviteGateBloc, InviteGateState>(
      listenWhen: (previous, current) =>
          previous.accessGrant != current.accessGrant &&
          current.accessGrant != null,
      listener: (context, state) {
        context.go(WelcomeScreen.createAccountPath);
      },
      builder: (context, state) {
        if (state.configStatus == InviteGateConfigStatus.initial ||
            state.configStatus == InviteGateConfigStatus.loading) {
          return const _InviteLoadingPage();
        }

        if (state.configStatus == InviteGateConfigStatus.failure ||
            state.config == null) {
          return _InviteSheetPage(
            illustrationAsset: 'assets/stickers/alert.svg',
            title: 'Invite access is temporarily unavailable.',
            body: const Text(
              'Try again in a moment, or contact support if you need help getting in.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                height: 1.5,
                letterSpacing: 0.15,
                color: VineTheme.lightText,
              ),
              textAlign: TextAlign.center,
            ),
            primaryButton: DivineButton(
              expanded: true,
              label: 'Try again',
              onPressed: _retryConfigLoad,
            ),
            secondaryButton: DivineButton(
              expanded: true,
              type: .secondary,
              label: 'Contact support',
              onPressed: () => _contactSupport('support@divine.video'),
            ),
          );
        }

        final config = state.config!;

        switch (config.mode) {
          case OnboardingMode.open:
            _redirectToCreateAccount();
            return const _InviteLoadingPage();
          case OnboardingMode.inviteCodeRequired:
            return _InviteCodeEntryPage(
              controller: _inviteCodeController,
              state: state,
              onChanged: () => context.read<InviteGateBloc>().add(
                const InviteGateTransientCleared(),
              ),
              onBack: () => context.pop(),
              onSubmit: _validateInviteCode,
              onShowWaitlist: () => _showWaitlistSheet(config),
              onContactSupport: () => _contactSupport(config.supportEmail),
            );
        }
      },
    );
  }
}

class _InviteLoadingPage extends StatelessWidget {
  const _InviteLoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      body: Center(
        child: CircularProgressIndicator(color: VineTheme.vineGreen),
      ),
    );
  }
}

class _InviteCodeEntryPage extends StatelessWidget {
  const _InviteCodeEntryPage({
    required this.controller,
    required this.state,
    required this.onChanged,
    required this.onBack,
    required this.onSubmit,
    required this.onShowWaitlist,
    required this.onContactSupport,
  });

  final TextEditingController controller;
  final InviteGateState state;
  final VoidCallback onChanged;
  final VoidCallback onBack;
  final VoidCallback onSubmit;
  final VoidCallback onShowWaitlist;
  final VoidCallback onContactSupport;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Positioned(
                  top: constraints.maxHeight / 2 - 80,
                  left: -36,
                  child: Transform.rotate(
                    angle: 12 * 3.14159 / 180,
                    child: const DivineSticker(sticker: .confetti, size: 174),
                  ),
                ),

                Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.viewInsetsOf(context).bottom,
                  ),
                  child: CustomScrollView(
                    slivers: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const SizedBox(height: 16),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: RoundedIconButton(
                                  onPressed: onBack,
                                  icon: const Icon(
                                    Icons.chevron_left,
                                    color: VineTheme.vineGreenLight,
                                    size: 28,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              const Text(
                                'Add your invite code',
                                style: TextStyle(
                                  fontFamily: VineTheme.fontFamilyBricolage,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w700,
                                  color: VineTheme.whiteText,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 32),
                              _InviteCodeInput(
                                controller: controller,
                                enabled: !state.isValidatingCode,
                                errorText: state.inviteCodeError,
                                onChanged: onChanged,
                                onSubmitted: onSubmit,
                              ),
                              if (state.generalError != null) ...[
                                const SizedBox(height: 16),
                                AuthErrorBox(message: state.generalError!),
                              ],

                              const Spacer(),

                              const SizedBox(height: 24),
                              DivineButton(
                                expanded: true,
                                label: 'Next',
                                isLoading: state.isValidatingCode,
                                onPressed: state.isValidatingCode
                                    ? null
                                    : onSubmit,
                              ),
                              const SizedBox(height: 12),
                              DivineButton(
                                expanded: true,
                                type: DivineButtonType.secondary,
                                label: 'Join waitlist',
                                onPressed: state.isValidatingCode
                                    ? null
                                    : onShowWaitlist,
                              ),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: state.isValidatingCode
                                    ? null
                                    : onContactSupport,
                                child: const Text(
                                  'Contact support',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 15,
                                    color: VineTheme.lightText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _InviteCodeInput extends StatelessWidget {
  const _InviteCodeInput({
    required this.controller,
    required this.enabled,
    required this.onChanged,
    required this.onSubmitted,
    this.errorText,
  });

  final TextEditingController controller;
  final bool enabled;
  final String? errorText;
  final VoidCallback onChanged;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          enabled: enabled,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9-]')),
            _InviteCodeTextInputFormatter(),
          ],
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: VineTheme.whiteText,
            letterSpacing: 0.15,
          ),
          decoration: InputDecoration(
            labelText: 'Invite code',
            labelStyle: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: hasError ? VineTheme.error : VineTheme.vineGreen,
            ),
            floatingLabelBehavior: FloatingLabelBehavior.always,
            hintText: 'Enter your code',
            hintStyle: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              color: VineTheme.whiteText.withValues(alpha: 0.25),
              letterSpacing: 0.15,
            ),
            filled: true,
            fillColor: VineTheme.surfaceContainer,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: hasError
                  ? const BorderSide(color: VineTheme.error)
                  : BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(
                color: hasError ? VineTheme.error : VineTheme.vineGreen,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
          ),
          onChanged: (_) => onChanged(),
          onSubmitted: (_) => onSubmitted(),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 20),
            child: Text(
              errorText!,
              style: const TextStyle(color: VineTheme.error, fontSize: 12),
            ),
          ),
        ],
      ],
    );
  }
}

class _InviteSheetPage extends StatelessWidget {
  const _InviteSheetPage({
    required this.illustrationAsset,
    required this.title,
    required this.body,
    required this.primaryButton,
    this.secondaryButton,
    this.showBackButton = true,
  });

  final String illustrationAsset;
  final String title;
  final Widget body;
  final Widget primaryButton;
  final Widget? secondaryButton;
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: VineTheme.backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
              child: Row(
                children: [
                  if (showBackButton)
                    AuthBackButton(onPressed: () => context.pop())
                  else
                    const SizedBox(width: 48, height: 48),
                ],
              ),
            ),
            const Spacer(),
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: VineTheme.surfaceBackground,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    height: 32,
                    width: double.infinity,
                    alignment: const Alignment(0, -0.2),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: VineTheme.outlineDisabled,
                        ),
                      ),
                    ),
                    child: Container(
                      width: 64,
                      height: 4,
                      decoration: BoxDecoration(
                        color: VineTheme.whiteText.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      32,
                      16,
                      16 + safeBottom,
                    ),
                    child: Column(
                      children: [
                        SvgPicture.asset(
                          illustrationAsset,
                          width: 132,
                          height: 132,
                        ),
                        const SizedBox(height: 32),
                        Text(
                          title,
                          style: const TextStyle(
                            fontFamily: VineTheme.fontFamilyBricolage,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: VineTheme.whiteText,
                            height: 1.333,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        body,
                        const SizedBox(height: 32),
                        primaryButton,
                        if (secondaryButton != null) ...[
                          const SizedBox(height: 16),
                          secondaryButton!,
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaitlistEntrySheet extends StatefulWidget {
  const _WaitlistEntrySheet({
    required this.inviteApiClient,
    required this.supportEmail,
  });

  final InviteApiClient inviteApiClient;
  final String supportEmail;

  @override
  State<_WaitlistEntrySheet> createState() => _WaitlistEntrySheetState();
}

class _WaitlistEntrySheetState extends State<_WaitlistEntrySheet> {
  final TextEditingController _emailController = TextEditingController();
  String? _emailError;
  String? _generalError;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final emailError = Validators.validateEmail(email);

    if (emailError != null) {
      setState(() {
        _emailError = emailError;
        _generalError = null;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _emailError = null;
      _generalError = null;
    });

    try {
      await widget.inviteApiClient.joinWaitlist(contact: email);
      if (!mounted) return;
      Navigator.of(context).pop(email);
    } on InviteApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _generalError = error.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Future<void> _contactSupport() async {
    final launched = await launchUrl(
      Uri(
        scheme: 'mailto',
        path: widget.supportEmail,
        queryParameters: const {'subject': 'Invite access help'},
      ),
      mode: LaunchMode.externalApplication,
    );

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open ${widget.supportEmail}'),
          backgroundColor: VineTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 16,
      ),
      child: Material(
        color: VineTheme.surfaceBackground,
        borderRadius: BorderRadius.circular(32),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 4,
                decoration: BoxDecoration(
                  color: VineTheme.whiteText.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Join the waitlist',
                style: TextStyle(
                  fontFamily: VineTheme.fontFamilyBricolage,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: VineTheme.whiteText,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                "Share your email and we'll send updates as access opens up.",
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 16,
                  height: 1.5,
                  letterSpacing: 0.15,
                  color: VineTheme.lightText,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              DivineAuthTextField(
                label: 'Email',
                controller: _emailController,
                enabled: !_isSubmitting,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                errorText: _emailError,
                onChanged: (_) {
                  if (_emailError != null || _generalError != null) {
                    setState(() {
                      _emailError = null;
                      _generalError = null;
                    });
                  }
                },
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              if (_generalError != null) ...[
                AuthErrorBox(message: _generalError!),
                const SizedBox(height: 16),
              ],
              DivineButton(
                type: .secondary,
                label: 'Join waitlist',
                isLoading: _isSubmitting,
                onPressed: _isSubmitting ? null : _submit,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _isSubmitting ? null : _contactSupport,
                child: const Text(
                  'Contact support',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    color: VineTheme.lightText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InviteCodeTextInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final normalized = InviteApiClient.normalizeCode(newValue.text);
    return TextEditingValue(
      text: normalized,
      selection: TextSelection.collapsed(offset: normalized.length),
    );
  }
}
