// ABOUTME: Change-email flow for accounts that sign in with email/password
// ABOUTME: Page bridges the Riverpod repository into ChangeEmailCubit

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/change_email/change_email_cubit.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/account_credentials_providers.dart';
import 'package:openvine/screens/settings/general_settings_screen.dart';

/// Page layer: reads the repository from Riverpod and hands it to the cubit.
///
/// The [ValueKey] over the repository is the account-switch guard from
/// `state_management.md` — a cubit holding the previous account's repository
/// would otherwise move the wrong account's email address.
class ChangeEmailScreen extends ConsumerWidget {
  const ChangeEmailScreen({super.key});

  static const routeName = 'change-email';
  static const subpath = 'change-email';
  static const path = '/general-settings/$subpath';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(accountCredentialsRepositoryProvider);

    return BlocProvider<ChangeEmailCubit>(
      key: ValueKey(repository),
      create: (_) =>
          ChangeEmailCubit(repository: repository)..loadCurrentEmail(),
      child: const ChangeEmailView(),
    );
  }
}

/// View layer: the form and its confirmation panel, driven entirely by
/// [ChangeEmailCubit].
class ChangeEmailView extends StatefulWidget {
  @visibleForTesting
  const ChangeEmailView({super.key});

  @override
  State<ChangeEmailView> createState() => _ChangeEmailViewState();
}

class _ChangeEmailViewState extends State<ChangeEmailView> {
  final _newEmailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _newEmailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.accountSettingsChangeEmail,
        showBackButton: true,
        onBackPressed: () =>
            context.safePop(fallback: GeneralSettingsScreen.path),
      ),
      backgroundColor: context.vineColors.background,
      body: BlocBuilder<ChangeEmailCubit, ChangeEmailState>(
        builder: (context, state) {
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: state.status == ChangeEmailStatus.requestSent
                    ? _RequestSent(newEmail: state.newEmail.trim())
                    : _Form(
                        state: state,
                        newEmailController: _newEmailController,
                        passwordController: _passwordController,
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Form extends StatelessWidget {
  const _Form({
    required this.state,
    required this.newEmailController,
    required this.passwordController,
  });

  final ChangeEmailState state;
  final TextEditingController newEmailController;
  final TextEditingController passwordController;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ChangeEmailCubit>();
    final currentEmail = state.currentEmail;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 16,
              children: [
                const SizedBox(height: 8),
                Text(
                  context.l10n.changeEmailSubtitle,
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.secondaryText,
                  ),
                ),
                if (currentEmail != null)
                  Text(
                    context.l10n.changeEmailCurrentAddress(currentEmail),
                    style: VineTheme.bodyMediumFont(
                      color: context.vineColors.primaryText,
                    ),
                  ),
                DivineAuthTextField(
                  controller: newEmailController,
                  label: context.l10n.changeEmailNewLabel,
                  enabled: !state.isSubmitting,
                  autocorrect: false,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  errorText: _newEmailErrorText(context, state.newEmailError),
                  textInputAction: TextInputAction.next,
                  onChanged: cubit.updateNewEmail,
                ),
                DivineAuthTextField(
                  controller: passwordController,
                  label: context.l10n.changeEmailPasswordLabel,
                  obscureText: true,
                  enabled: !state.isSubmitting,
                  autofillHints: const [AutofillHints.password],
                  errorText: state.passwordMissing
                      ? context.l10n.authPasswordRequired
                      : null,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => cubit.submit(),
                  onChanged: cubit.updatePassword,
                ),
                if (state.failureReason != null)
                  _FailureMessage(reason: state.failureReason!),
              ],
            ),
          ),
        ),
        DivineButton(
          expanded: true,
          label: context.l10n.changeEmailSubmit,
          isLoading: state.isSubmitting,
          onPressed: state.canSubmit ? cubit.submit : null,
        ),
        SizedBox(
          height: 32 + MediaQuery.viewPaddingOf(context).bottom,
        ),
      ],
    );
  }

  String? _newEmailErrorText(BuildContext context, NewEmailFieldError? error) =>
      switch (error) {
        NewEmailFieldError.missing => context.l10n.authEmailRequired,
        NewEmailFieldError.invalid => context.l10n.authEmailInvalid,
        NewEmailFieldError.sameAsCurrent =>
          context.l10n.changeEmailSameAsCurrent,
        null => null,
      };
}

/// What is true after Keycast accepts the request: two links are in flight and
/// nothing has changed yet.
class _RequestSent extends StatelessWidget {
  const _RequestSent({required this.newEmail});

  final String newEmail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 16,
              children: [
                const SizedBox(height: 8),
                Text(
                  context.l10n.changeEmailSentTitle,
                  style: VineTheme.titleMediumFont(
                    color: context.vineColors.primaryText,
                  ),
                ),
                Text(
                  context.l10n.changeEmailSentMessage(newEmail),
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.secondaryText,
                  ),
                ),
                DivineInfoCard(
                  icon: DivineIconName.envelope,
                  compact: true,
                  message: context.l10n.changeEmailSentExpiry,
                ),
              ],
            ),
          ),
        ),
        DivineButton(
          expanded: true,
          label: context.l10n.changeEmailSentDone,
          onPressed: () =>
              context.safePop(fallback: GeneralSettingsScreen.path),
        ),
        SizedBox(height: 32 + MediaQuery.viewPaddingOf(context).bottom),
      ],
    );
  }
}

/// Why the change was refused, in copy the user can act on.
class _FailureMessage extends StatelessWidget {
  const _FailureMessage({required this.reason});

  final ChangeEmailFailureReason reason;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final message = switch (reason) {
      ChangeEmailFailureReason.wrongPassword => l10n.changeEmailWrongPassword,
      ChangeEmailFailureReason.invalidEmail => l10n.authEmailInvalid,
      ChangeEmailFailureReason.needsSignIn =>
        l10n.accountCredentialsNeedsSignIn,
      ChangeEmailFailureReason.rateLimited =>
        l10n.accountCredentialsRateLimited,
      ChangeEmailFailureReason.network => l10n.accountCredentialsNetwork,
      ChangeEmailFailureReason.unknown => l10n.accountCredentialsUnknown,
    };

    return Text(
      message,
      style: VineTheme.bodyMediumFont(color: VineTheme.error),
    );
  }
}
