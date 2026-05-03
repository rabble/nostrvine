// ABOUTME: Sign-in screen with email/password form and alternative Nostr methods
// ABOUTME: Options: Email sign-in, Import Nostr Key, Signer App, or Amber
// DESIGN: https://www.figma.com/design/rp1DsDEUuCaicW0lk6I2aZ/UI-Design?node-id=5061-65986

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show AndroidPlugin;
import 'package:openvine/blocs/divine_auth/divine_auth_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/auth/email_verification_screen.dart';
import 'package:openvine/screens/auth/nostr_connect_screen.dart';
import 'package:openvine/screens/key_import_screen.dart';
import 'package:openvine/utils/validators.dart';
import 'package:openvine/widgets/auth/auth_error_box.dart';
import 'package:openvine/widgets/auth/forgot_password_dialog.dart';
import 'package:openvine/widgets/auth_back_button.dart';
import 'package:openvine/widgets/rounded_icon_button.dart';

/// Sign-in screen — Page that provides [DivineAuthCubit].
class LoginOptionsScreen extends ConsumerWidget {
  /// Route name for this screen.
  static const String routeName = 'login-options';

  /// Route path for this screen.
  static const String path = '/login-options';

  const LoginOptionsScreen({this.initialEmail, this.initialError, super.key});

  /// Optional email to prefill from create-account recovery.
  final String? initialEmail;

  /// Optional error to display when arriving from create-account recovery.
  final String? initialError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final oauthClient = ref.watch(oauthClientProvider);
    final authService = ref.watch(authServiceProvider);
    final pendingVerificationService = ref.watch(
      pendingVerificationServiceProvider,
    );

    return BlocProvider(
      create: (_) =>
          DivineAuthCubit(
            oauthClient: oauthClient,
            authService: authService,
            pendingVerificationService: pendingVerificationService,
            validationMessages: AuthValidationMessages.fromL10n(l10n),
          )..initialize(
            isSignIn: true,
            initialEmail: initialEmail,
            initialGeneralError: initialError,
          ),
      child: const _LoginOptionsView(),
    );
  }
}

/// Sign-in screen — View that consumes [DivineAuthCubit] state.
class _LoginOptionsView extends StatelessWidget {
  const _LoginOptionsView();

  @override
  Widget build(BuildContext context) {
    return BlocListener<DivineAuthCubit, DivineAuthState>(
      listenWhen: (prev, next) =>
          next is DivineAuthEmailVerification || next is DivineAuthSuccess,
      listener: (context, state) {
        if (state is DivineAuthSuccess) {
          // Signal password managers to save credentials.
          TextInput.finishAutofillContext();
        }
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
      child: Scaffold(
        backgroundColor: VineTheme.backgroundColor,
        body: SafeArea(
          child: BlocBuilder<DivineAuthCubit, DivineAuthState>(
            builder: (context, state) {
              if (state is DivineAuthFormState) {
                return _SignInContent(state: state);
              }
              return const Center(
                child: CircularProgressIndicator(color: VineTheme.vineGreen),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Main content with email/password form and alternative login methods.
class _SignInContent extends ConsumerStatefulWidget {
  const _SignInContent({required this.state});

  final DivineAuthFormState state;

  @override
  ConsumerState<_SignInContent> createState() => _SignInContentState();
}

class _SignInContentState extends ConsumerState<_SignInContent> {
  late TextEditingController _emailController;
  late TextEditingController _passwordController;
  late FocusNode _emailFocusNode;
  late FocusNode _passwordFocusNode;
  bool _isConnectingAmber = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.state.email);
    _passwordController = TextEditingController(text: widget.state.password);
    _emailFocusNode = FocusNode();
    _passwordFocusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _SignInContent oldWidget) {
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
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _connectWithAmber() async {
    final isInstalled = await AndroidPlugin.existAndroidNostrSigner() ?? false;
    if (!isInstalled) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.authAmberNotInstalled),
          backgroundColor: VineTheme.error,
        ),
      );
      return;
    }

    setState(() => _isConnectingAmber = true);

    try {
      final authService = ref.read(authServiceProvider);
      final result = await authService.connectWithAmber();

      if (!mounted) return;

      if (result.success) {
        context.go('/');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.errorMessage ?? context.l10n.authAmberConnectionFailed,
            ),
            backgroundColor: VineTheme.error,
          ),
        );
        // Clear the error so it doesn't show again on the welcome screen
        authService.clearError();
      }
    } finally {
      if (mounted) {
        setState(() => _isConnectingAmber = false);
      }
    }
  }

  void _showForgotPasswordDialog() {
    showForgotPasswordDialog(
      context: context,
      initialEmail: _emailController.text,
      onSendResetEmail: (email) async {
        await context.read<DivineAuthCubit>().sendPasswordResetEmail(email);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              padding: EdgeInsets.zero,
              backgroundColor: VineTheme.transparent,
              elevation: 0,
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
              content: DivineSnackbarContainer(
                label: context.l10n.authPasswordResetSent,
              ),
            ),
          );
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = widget.state.isSubmitting;
    final isDisabled = isSubmitting || _isConnectingAmber;

    return CustomScrollView(
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // Top bar: back + info
                Row(
                  children: [
                    AuthBackButton(enabled: !isDisabled),
                    const Spacer(),
                    RoundedIconButton(
                      onPressed: isDisabled
                          ? null
                          : () => _showInfoSheet(context),
                      icon: const Icon(
                        Icons.info_outline,
                        color: VineTheme.vineGreenLight,
                        size: 24,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // Title
                Text(
                  context.l10n.authSignInTitle,
                  style: const TextStyle(
                    fontFamily: VineTheme.fontFamilyBricolage,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: VineTheme.whiteText,
                  ),
                ),

                const SizedBox(height: 40),

                // Email + Password wrapped for password manager autofill.
                AutofillGroup(
                  child: Form(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 16,
                      children: [
                        // Email field
                        DivineAuthTextField(
                          controller: _emailController,
                          focusNode: _emailFocusNode,
                          label: context.l10n.authEmailLabel,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: .next,
                          errorText: widget.state.emailError,
                          enabled: !isDisabled,
                          autocorrect: false,
                          onChanged: (value) => context
                              .read<DivineAuthCubit>()
                              .updateEmail(value),
                          onSubmitted: (_) => _passwordFocusNode.requestFocus(),
                        ),

                        // Password field
                        DivineAuthTextField(
                          controller: _passwordController,
                          focusNode: _passwordFocusNode,
                          label: context.l10n.authPasswordLabel,
                          obscureText: true,
                          autofillHints: const [AutofillHints.password],
                          textInputAction: .done,
                          errorText: widget.state.passwordError,
                          enabled: !isDisabled,
                          onChanged: (value) => context
                              .read<DivineAuthCubit>()
                              .updatePassword(value),
                          onSubmitted: isDisabled
                              ? null
                              : (_) => context.read<DivineAuthCubit>().submit(),
                        ),
                      ],
                    ),
                  ),
                ),

                // General error
                if (widget.state.generalError != null) ...[
                  const SizedBox(height: 16),
                  AuthErrorBox(message: widget.state.generalError!),
                ],

                const SizedBox(height: 24),

                // Sign in button
                DivineButton(
                  expanded: true,
                  label: context.l10n.authSignInButton,
                  isLoading: isSubmitting,
                  onPressed: isDisabled
                      ? null
                      : () => context.read<DivineAuthCubit>().submit(),
                ),

                const SizedBox(height: 16),

                // Forgot password
                Center(
                  child: GestureDetector(
                    onTap: isDisabled ? null : _showForgotPasswordDialog,
                    child: Text(
                      context.l10n.authForgotPassword,
                      style: const TextStyle(
                        color: VineTheme.whiteText,
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                        decorationColor: VineTheme.whiteText,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Push alternative methods to bottom
                const Spacer(),

                // Alternative login methods
                DivineButton(
                  type: .secondary,
                  expanded: true,
                  label: context.l10n.authImportNostrKey,
                  onPressed: isDisabled
                      ? null
                      : () => context.push(KeyImportScreen.path),
                ),

                const SizedBox(height: 12),

                DivineButton(
                  type: .secondary,
                  expanded: true,
                  label: context.l10n.authConnectSignerApp,
                  onPressed: isDisabled
                      ? null
                      : () => context.push(NostrConnectScreen.path),
                ),

                if (!kIsWeb &&
                    defaultTargetPlatform == TargetPlatform.android) ...[
                  const SizedBox(height: 12),
                  DivineButton(
                    type: .secondary,
                    expanded: true,
                    label: context.l10n.authSignInWithAmber,
                    isLoading: _isConnectingAmber,
                    onPressed: isDisabled ? null : _connectWithAmber,
                  ),
                ],

                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

void _showInfoSheet(BuildContext context) {
  VineBottomSheet.show<void>(
    context: context,
    title: Text(context.l10n.authSignInOptionsTitle),
    buildScrollBody: (scrollController) => Builder(
      builder: (sheetContext) => ListView(
        controller: scrollController,
        padding: EdgeInsets.fromLTRB(
          24,
          16,
          24,
          32 + MediaQuery.viewPaddingOf(sheetContext).bottom,
        ),
        children: [
          _InfoItem(
            title: sheetContext.l10n.authInfoEmailPasswordTitle,
            description: sheetContext.l10n.authInfoEmailPasswordDescription,
          ),
          const SizedBox(height: 16),
          _InfoItem(
            title: sheetContext.l10n.authImportNostrKey,
            description: sheetContext.l10n.authInfoImportNostrKeyDescription,
          ),
          const SizedBox(height: 16),
          _InfoItem(
            title: sheetContext.l10n.authInfoSignerAppTitle,
            description: sheetContext.l10n.authInfoSignerAppDescription,
          ),
          if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) ...[
            const SizedBox(height: 16),
            _InfoItem(
              title: sheetContext.l10n.authInfoAmberTitle,
              description: sheetContext.l10n.authInfoAmberDescription,
            ),
          ],
        ],
      ),
    ),
  );
}

/// Single info item in the info sheet.
class _InfoItem extends StatelessWidget {
  const _InfoItem({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: VineTheme.whiteText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: const TextStyle(
            fontSize: 14,
            color: VineTheme.secondaryText,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
