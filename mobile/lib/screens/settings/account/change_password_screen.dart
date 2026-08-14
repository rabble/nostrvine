// ABOUTME: Change-password flow for accounts that sign in with email/password
// ABOUTME: Page bridges the Riverpod repository into ChangePasswordCubit

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/change_password/change_password_cubit.dart';
import 'package:openvine/extensions/safe_pop_extension.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/account_credentials_providers.dart';
import 'package:openvine/screens/settings/general_settings_screen.dart';
import 'package:openvine/utils/validators.dart';

/// Page layer: reads the repository from Riverpod and hands it to the cubit.
///
/// The [ValueKey] over the repository is the account-switch guard from
/// `state_management.md` — a cubit holding the previous account's repository
/// would otherwise change the wrong account's password.
class ChangePasswordScreen extends ConsumerWidget {
  const ChangePasswordScreen({super.key});

  static const routeName = 'change-password';
  static const subpath = 'change-password';
  static const path = '/general-settings/$subpath';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(accountCredentialsRepositoryProvider);

    return BlocProvider<ChangePasswordCubit>(
      key: ValueKey(repository),
      create: (_) => ChangePasswordCubit(repository: repository),
      child: const ChangePasswordView(),
    );
  }
}

/// View layer: the form itself, driven entirely by [ChangePasswordCubit].
class ChangePasswordView extends StatefulWidget {
  @visibleForTesting
  const ChangePasswordView({super.key});

  @override
  State<ChangePasswordView> createState() => _ChangePasswordViewState();
}

class _ChangePasswordViewState extends State<ChangePasswordView> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onChanged(BuildContext context, ChangePasswordState state) {
    if (state.status != ChangePasswordStatus.success) return;

    // Captured before the pop so the snackbar lands on the screen the user
    // returns to rather than on a route that is already gone.
    final messenger = ScaffoldMessenger.of(context);
    final message = context.l10n.changePasswordSuccess;
    // Lets the platform password manager offer to update the saved entry.
    TextInput.finishAutofillContext();
    // safePop rather than pop: a cold-entered stack has nothing to pop, and
    // succeeding at the change must not end in a crash.
    context.safePop(fallback: GeneralSettingsScreen.path);
    messenger.showSnackBar(DivineSnackbarContainer.snackBar(message));
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ChangePasswordCubit>();

    return Scaffold(
      appBar: DiVineAppBar(
        title: context.l10n.accountSettingsChangePassword,
        showBackButton: true,
        onBackPressed: () =>
            context.safePop(fallback: GeneralSettingsScreen.path),
      ),
      backgroundColor: context.vineColors.background,
      body: BlocConsumer<ChangePasswordCubit, ChangePasswordState>(
        listener: _onChanged,
        builder: (context, state) {
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          spacing: 16,
                          children: [
                            const SizedBox(height: 8),
                            Text(
                              context.l10n.changePasswordSubtitle,
                              style: VineTheme.bodyMediumFont(
                                color: context.vineColors.secondaryText,
                              ),
                            ),
                            AutofillGroup(
                              child: Column(
                                spacing: 16,
                                children: [
                                  DivineAuthTextField(
                                    controller: _currentPasswordController,
                                    label:
                                        context.l10n.changePasswordCurrentLabel,
                                    obscureText: true,
                                    enabled: !state.isSubmitting,
                                    autofillHints: const [
                                      AutofillHints.password,
                                    ],
                                    errorText: state.currentPasswordMissing
                                        ? context.l10n.authPasswordRequired
                                        : null,
                                    textInputAction: TextInputAction.next,
                                    onChanged: cubit.updateCurrentPassword,
                                  ),
                                  DivineAuthTextField(
                                    controller: _newPasswordController,
                                    label: context.l10n.authNewPasswordLabel,
                                    obscureText: true,
                                    enabled: !state.isSubmitting,
                                    autofillHints: const [
                                      AutofillHints.newPassword,
                                    ],
                                    errorText: _passwordErrorText(
                                      context,
                                      state.newPasswordError,
                                    ),
                                    textInputAction: TextInputAction.next,
                                    onChanged: cubit.updateNewPassword,
                                  ),
                                  DivineAuthTextField(
                                    controller: _confirmPasswordController,
                                    label: context
                                        .l10n
                                        .authConfirmNewPasswordLabel,
                                    obscureText: true,
                                    enabled: !state.isSubmitting,
                                    autofillHints: const [
                                      AutofillHints.newPassword,
                                    ],
                                    errorText: _confirmPasswordErrorText(
                                      context,
                                      state.confirmPasswordError,
                                    ),
                                    textInputAction: TextInputAction.done,
                                    onSubmitted: (_) => cubit.submit(),
                                    onChanged: cubit.updateConfirmPassword,
                                  ),
                                ],
                              ),
                            ),
                            if (state.failureReason != null)
                              _FailureMessage(reason: state.failureReason!),
                          ],
                        ),
                      ),
                    ),
                    DivineButton(
                      expanded: true,
                      label: context.l10n.authUpdatePassword,
                      isLoading: state.isSubmitting,
                      onPressed: state.canSubmit ? cubit.submit : null,
                    ),
                    SizedBox(
                      height: 32 + MediaQuery.viewPaddingOf(context).bottom,
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String? _passwordErrorText(
    BuildContext context,
    PasswordValidationError? error,
  ) => switch (error) {
    PasswordValidationError.missing => context.l10n.authPasswordRequired,
    PasswordValidationError.tooShort => context.l10n.authPasswordTooShort,
    null => null,
  };

  String? _confirmPasswordErrorText(
    BuildContext context,
    ConfirmPasswordValidationError? error,
  ) => switch (error) {
    ConfirmPasswordValidationError.missing =>
      context.l10n.authConfirmPasswordRequired,
    ConfirmPasswordValidationError.mismatch =>
      context.l10n.authPasswordsDoNotMatch,
    null => null,
  };
}

/// Why the change was refused, in copy the user can act on.
class _FailureMessage extends StatelessWidget {
  const _FailureMessage({required this.reason});

  final ChangePasswordFailureReason reason;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final message = switch (reason) {
      ChangePasswordFailureReason.wrongCurrentPassword =>
        l10n.changePasswordWrongCurrent,
      ChangePasswordFailureReason.weakPassword => l10n.authPasswordTooShort,
      ChangePasswordFailureReason.needsSignIn =>
        l10n.accountCredentialsNeedsSignIn,
      ChangePasswordFailureReason.rateLimited =>
        l10n.accountCredentialsRateLimited,
      ChangePasswordFailureReason.network => l10n.accountCredentialsNetwork,
      ChangePasswordFailureReason.unknown => l10n.accountCredentialsUnknown,
    };

    return Text(
      message,
      style: VineTheme.bodyMediumFont(color: VineTheme.error),
    );
  }
}
