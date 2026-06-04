// ABOUTME: Dialog widgets for account deletion flow
// ABOUTME: Warning dialogs for key removal and content deletion with confirmation

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart'
    show SecureKeyStorageException;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/services/account_deletion_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// Show warning dialog for removing keys from device only
Future<void> showRemoveKeysWarningDialog({
  required BuildContext context,
  required VoidCallback onConfirm,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => AlertDialog(
      backgroundColor: VineTheme.cardBackground,
      title: Text(
        context.l10n.deleteAccountRemoveKeysTitle,
        style: const TextStyle(
          color: VineTheme.whiteText,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Text(
        context.l10n.deleteAccountRemoveKeysBody,
        style: const TextStyle(
          color: VineTheme.whiteText,
          fontSize: 16,
          height: 1.5,
        ),
      ),
      actions: [
        TextButton(
          onPressed: context.pop,
          child: Text(
            context.l10n.commonCancel,
            style: const TextStyle(color: VineTheme.lightText, fontSize: 16),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            context.pop();
            onConfirm();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: VineTheme.warning,
            foregroundColor: VineTheme.whiteText,
          ),
          child: Text(
            context.l10n.deleteAccountRemoveKeysConfirm,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );
}

/// Show confirmation dialog before deleting all content (requires typing
/// DELETE)
///
/// This dialog ensures they understand the dangerous/irreversible nature of
/// account deletion.
Future<void> showDeleteAllContentWarningDialog({
  required BuildContext context,
  required VoidCallback onConfirm,
}) {
  final confirmationController = TextEditingController();
  const requiredText = 'DELETE';

  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        backgroundColor: VineTheme.cardBackground,
        scrollable: true,
        title: Text(
          context.l10n.deleteAccountFinalConfirmationTitle,
          style: const TextStyle(
            color: VineTheme.error,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.deleteAccountFinalConfirmationBody,
              style: const TextStyle(
                color: VineTheme.whiteText,
                fontSize: 16,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              requiredText,
              style: TextStyle(
                color: VineTheme.error,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmationController,
              style: const TextStyle(color: VineTheme.whiteText),
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: context.l10n.deleteAccountConfirmationHint,
                hintStyle: const TextStyle(color: VineTheme.lightText),
                enabledBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: VineTheme.cardBackground),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: VineTheme.error),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
            onPressed: context.pop,
            child: Text(
              context.l10n.commonCancel,
              style: const TextStyle(color: VineTheme.lightText, fontSize: 16),
            ),
          ),
          ElevatedButton(
            onPressed:
                confirmationController.text.trim().toUpperCase() == requiredText
                ? () {
                    context.pop();
                    onConfirm();
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: VineTheme.error,
              foregroundColor: VineTheme.whiteText,
              disabledBackgroundColor: VineTheme.cardBackground,
              disabledForegroundColor: VineTheme.lightText,
            ),
            child: Text(
              context.l10n.deleteAccountDeleteAllContentButton,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Progress dialog that shows deletion progress using BLoC pattern.
class _DeletionProgressDialog extends StatelessWidget {
  const _DeletionProgressDialog();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        color: VineTheme.cardBackground,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child:
              BlocBuilder<
                AccountDeletionProgressCubit,
                AccountDeletionProgressState
              >(
                builder: (context, state) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: switch (state) {
                      AccountDeletionProgressUpdating(
                        :final current,
                        :final total,
                      ) =>
                        [
                          CircularProgressIndicator(
                            value: current / total,
                            color: VineTheme.vineGreen,
                            backgroundColor: VineTheme.cardBackground,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            context.l10n.videoGridDeletingContent,
                            style: const TextStyle(
                              color: VineTheme.whiteText,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            context.l10n.deleteAccountProgressEvents(
                              current,
                              total,
                            ),
                            style: const TextStyle(
                              color: VineTheme.secondaryText,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      AccountDeletionProgressPreparing() => [
                        const CircularProgressIndicator(
                          color: VineTheme.vineGreen,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.l10n.deleteAccountPreparingDeletion,
                          style: const TextStyle(
                            color: VineTheme.whiteText,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    },
                  );
                },
              ),
        ),
      ),
    );
  }
}

/// Execute the full account deletion flow:
/// 1. Show loading indicator with progress
/// 2. Send NIP-62 deletion request (requires working signer)
/// 3. Delete Keycast account if exists (invalidates signer)
/// 4. Sign out and delete local keys
/// 5. Show success snackbar (router auto-redirects to /welcome)
///
/// [context] - BuildContext for showing dialogs
/// [deletionService] - Service to execute NIP-62 deletion
/// [authService] - Service for Keycast deletion and sign out
/// [screenName] - Name of the calling screen for logging
Future<void> executeAccountDeletion({
  required BuildContext context,
  required AccountDeletionService deletionService,
  required AuthService authService,
  String screenName = 'AccountDeletion',
}) async {
  // Create cubit for tracking progress
  final cubit = AccountDeletionProgressCubit();

  // Show progress dialog with BlocProvider
  if (!context.mounted) return;
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => BlocProvider.value(
        value: cubit,
        child: const _DeletionProgressDialog(),
      ),
    ),
  );

  // Track if dialog was dismissed to avoid double-popping
  var dialogDismissed = false;

  void dismissDialog() {
    if (!dialogDismissed && context.mounted) {
      dialogDismissed = true;
      context.pop();
    }
  }

  // Captured before the first await so the post-sign-out catch can localize
  // without reading BuildContext across an async gap.
  final keyDeletionWarningText = context.l10n.deleteAccountKeyDeletionWarning;

  // Step 1: Execute NIP-62 deletion request (requires working signer)
  try {
    final result = await deletionService.deleteAccount(
      onProgress: cubit.updateProgress,
    );

    if (result.success) {
      // Step 2: Delete Keycast account if one exists (invalidates signer)
      final (keycastSuccess, keycastError) = await authService
          .deleteKeycastAccount();
      if (!keycastSuccess && authService.isRegistered) {
        // divineOAuth users MUST have their Keycast account deleted to
        // prevent re-login. Show error and do NOT sign out.
        Log.error(
          'Keycast account deletion failed for registered user: '
          '$keycastError',
          name: screenName,
          category: LogCategory.auth,
        );
        dismissDialog();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            DivineSnackbarContainer.snackBar(
              context.l10n.deleteAccountServerDeletionFailed,
              error: true,
            ),
          );
        }
        return;
      }
      if (!keycastSuccess) {
        // Non-OAuth users: log and continue (no server account to delete)
        Log.warning(
          'Keycast account deletion failed (continuing anyway): '
          '$keycastError',
          name: screenName,
          category: LogCategory.auth,
        );
      }

      // Step 3: Sign out and delete local keys
      // Router will automatically redirect to /welcome when auth state
      // becomes unauthenticated.
      // signOut may throw SecureKeyStorageException if platform key
      // deletion failed — the user IS signed out but keys may remain.
      String? keyDeletionWarning;
      try {
        await authService.signOut(deleteKeys: true);
      } on SecureKeyStorageException catch (e) {
        Log.warning(
          'Key deletion failed during account deletion: $e',
          name: screenName,
          category: LogCategory.auth,
        );
        keyDeletionWarning = keyDeletionWarningText;
      }

      // Close loading indicator and show result snackbar
      // Router will automatically redirect to /welcome after sign out
      dismissDialog();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            keyDeletionWarning ?? context.l10n.deleteAccountSuccess,
            error: keyDeletionWarning != null,
          ),
        );
      }
    } else {
      // Close loading indicator and show error
      dismissDialog();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            result.error ?? context.l10n.deleteAccountContentDeletionFailed,
            error: true,
          ),
        );
      }
    }
  } finally {
    await cubit.close();

    // Ensure dialog is dismissed even if an exception occurred
    dismissDialog();
  }
}

/// Cubit for managing account deletion progress state.
///
/// Used by the deletion progress dialog to display real-time
/// progress updates during the NIP-62 account deletion flow.
class AccountDeletionProgressCubit extends Cubit<AccountDeletionProgressState> {
  AccountDeletionProgressCubit()
    : super(const AccountDeletionProgressPreparing());

  /// Update the deletion progress.
  ///
  /// [current] - Number of events processed so far
  /// [total] - Total number of events to process
  void updateProgress(int current, int total) {
    emit(AccountDeletionProgressUpdating(current: current, total: total));
  }
}

/// State for the account deletion progress cubit.
sealed class AccountDeletionProgressState extends Equatable {
  const AccountDeletionProgressState();

  @override
  List<Object?> get props => [];
}

/// Initial state while preparing for deletion (fetching events).
class AccountDeletionProgressPreparing extends AccountDeletionProgressState {
  const AccountDeletionProgressPreparing();
}

/// State with active deletion progress.
class AccountDeletionProgressUpdating extends AccountDeletionProgressState {
  const AccountDeletionProgressUpdating({
    required this.current,
    required this.total,
  });

  /// Number of events processed so far.
  final int current;

  /// Total number of events to process.
  final int total;

  @override
  List<Object?> get props => [current, total];
}
