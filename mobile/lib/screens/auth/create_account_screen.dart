// ABOUTME: Create account screen with email/password registration form
// ABOUTME: Provides DivineAuthCubit in sign-up mode
// DESIGN: https://www.figma.com/design/rp1DsDEUuCaicW0lk6I2aZ/UI-Design?node-id=7391-55983

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/divine_auth/divine_auth_cubit.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/auth/email_verification_screen.dart';
import 'package:openvine/widgets/auth/auth_error_box.dart';
import 'package:openvine/widgets/auth/auth_form_scaffold.dart';
import 'package:openvine/widgets/divine_primary_button.dart';

/// Create account screen — Page that provides [DivineAuthCubit] in sign-up
/// mode.
class CreateAccountScreen extends ConsumerWidget {
  /// Route name for this screen.
  static const String routeName = 'create-account';

  /// Route path for this screen (relative, under /welcome).
  static const String path = '/create-account';

  const CreateAccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final oauthClient = ref.watch(oauthClientProvider);
    final authService = ref.watch(authServiceProvider);
    final pendingVerificationService = ref.watch(
      pendingVerificationServiceProvider,
    );

    return BlocProvider(
      create: (_) => DivineAuthCubit(
        oauthClient: oauthClient,
        authService: authService,
        pendingVerificationService: pendingVerificationService,
      )..initialize(),
      child: const _CreateAccountView(),
    );
  }
}

/// Create account screen — View that consumes [DivineAuthCubit] state.
class _CreateAccountView extends StatelessWidget {
  const _CreateAccountView();

  @override
  Widget build(BuildContext context) {
    return BlocListener<DivineAuthCubit, DivineAuthState>(
      listenWhen: (prev, next) =>
          next is DivineAuthEmailVerification || next is DivineAuthSuccess,
      listener: (context, state) {
        if (state is DivineAuthEmailVerification) {
          final encodedEmail = Uri.encodeComponent(state.email);
          context.go(
            '${EmailVerificationScreen.path}'
            '?deviceCode=${state.deviceCode}'
            '&verifier=${state.verifier}'
            '&email=$encodedEmail',
          );
        }
      },
      child: BlocBuilder<DivineAuthCubit, DivineAuthState>(
        builder: (context, state) {
          if (state is DivineAuthFormState) {
            return _CreateAccountBody(state: state);
          }
          return const Scaffold(
            backgroundColor: VineTheme.backgroundColor,
            body: Center(
              child: CircularProgressIndicator(color: VineTheme.vineGreen),
            ),
          );
        },
      ),
    );
  }
}

/// Body of the create account form with email and password.
class _CreateAccountBody extends StatefulWidget {
  const _CreateAccountBody({required this.state});

  final DivineAuthFormState state;

  @override
  State<_CreateAccountBody> createState() => _CreateAccountBodyState();
}

class _CreateAccountBodyState extends State<_CreateAccountBody> {
  late TextEditingController _emailController;
  late TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.state.email);
    _passwordController = TextEditingController(text: widget.state.password);
  }

  @override
  void didUpdateWidget(covariant _CreateAccountBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_emailController.text != widget.state.email) {
      _emailController.text = widget.state.email;
    }
    if (_passwordController.text != widget.state.password) {
      _passwordController.text = widget.state.password;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    context.read<DivineAuthCubit>().submit();
  }

  Future<void> _skip() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: VineTheme.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _SkipConfirmationSheet(),
    );

    if (confirmed != true || !mounted) return;

    context.read<DivineAuthCubit>().skipWithAnonymousAccount();
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = widget.state.isSubmitting;
    final isSkipping = widget.state.isSkipping;
    final isDisabled = isSubmitting || isSkipping;

    return AuthFormScaffold(
      title: 'Create account',
      onBack: isDisabled ? null : () => context.pop(),
      emailController: _emailController,
      passwordController: _passwordController,
      emailError: widget.state.emailError,
      passwordError: widget.state.passwordError,
      enabled: !isDisabled,
      onEmailChanged: (value) =>
          context.read<DivineAuthCubit>().updateEmail(value),
      onPasswordChanged: (value) =>
          context.read<DivineAuthCubit>().updatePassword(value),
      errorWidget: widget.state.generalError != null
          ? AuthErrorBox(message: widget.state.generalError!)
          : null,
      primaryButton: DivinePrimaryButton(
        label: 'Create account',
        isLoading: isSubmitting,
        onPressed: isDisabled ? null : _submit,
      ),
      secondaryButton: _SkipButton(
        isSkipping: isSkipping,
        isDisabled: isDisabled,
        onPressed: _skip,
      ),
    );
  }
}

/// Skip button for users who want anonymous keys.
class _SkipButton extends StatelessWidget {
  const _SkipButton({
    required this.isSkipping,
    required this.isDisabled,
    required this.onPressed,
  });

  final bool isSkipping;
  final bool isDisabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: TextButton(
        onPressed: isDisabled ? null : onPressed,
        style: TextButton.styleFrom(
          foregroundColor: VineTheme.secondaryText,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: isSkipping
            ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(
                  color: VineTheme.secondaryText,
                  strokeWidth: 2,
                ),
              )
            : const Text(
                'Use Divine with no backup',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
      ),
    );
  }
}

/// Bottom sheet asking the user to confirm skipping email/password setup.
// DESIGN: https://www.figma.com/design/rp1DsDEUuCaicW0lk6I2aZ/UI-Design?node-id=6872-22358
class _SkipConfirmationSheet extends StatelessWidget {
  const _SkipConfirmationSheet();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: VineTheme.outlineMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 32),

          Image.asset(
            'assets/stickers/pointing_finger.png',
            width: 132,
            height: 132,
            fit: BoxFit.contain,
          ),
          const SizedBox(height: 24),

          // Title
          const Text(
            'One last thing...',
            style: TextStyle(
              fontFamily: VineTheme.fontFamilyBricolage,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: VineTheme.whiteText,
            ),
          ),
          const SizedBox(height: 16),

          // Description
          const Text(
            "You're in! We'll create a secure key that powers "
            'your Divine account.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: VineTheme.secondaryText,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Without an email, your key is the only way '
            'Divine knows this account is yours.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: VineTheme.secondaryText,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'You can access your key in the app, but, if '
            "you're not technical we recommend adding an "
            'email and password now. It makes it easier to '
            'sign in and restore your account if you lose or '
            'reset this device.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: VineTheme.secondaryText,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),

          // Add email & password button
          DivinePrimaryButton(
            label: 'Add email & password',
            onPressed: () => Navigator.pop(context, false),
          ),
          const SizedBox(height: 12),

          // Use this device only button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: VineTheme.secondaryText,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'Use this device only',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
