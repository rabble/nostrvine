// ABOUTME: Dialog widgets for account deletion flow
// ABOUTME: Warning dialogs for key removal and content deletion with confirmation

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/services/account_deletion_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/utils/unified_logger.dart';

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
      title: const Text(
        '⚠️ Remove Keys from Device?',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: const Text(
        'This will:\n'
        '• Remove your Nostr private key (nsec) from this device\n'
        '• Sign you out immediately\n'
        '• Your content will REMAIN on Nostr relays\n\n'
        'Make sure you have your nsec backed up elsewhere or you will lose access to your account!\n\n'
        'Continue?',
        style: TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
      ),
      actions: [
        TextButton(
          onPressed: context.pop,
          child: const Text(
            'Cancel',
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            context.pop();
            onConfirm();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange,
            foregroundColor: Colors.white,
          ),
          child: const Text(
            'Remove Keys',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
        title: const Text(
          '⚠️ Final Confirmation',
          style: TextStyle(
            color: Colors.red,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'To confirm permanent deletion of ALL your content from Nostr relays, type:',
              style: TextStyle(color: Colors.white, fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 12),
            Text(
              requiredText,
              style: TextStyle(
                color: Colors.red.shade300,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmationController,
              style: const TextStyle(color: Colors.white),
              autocorrect: false,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                hintText: 'Type DELETE',
                hintStyle: const TextStyle(color: Colors.grey),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.grey.shade700),
                ),
                focusedBorder: const OutlineInputBorder(
                  borderSide: BorderSide(color: Colors.red),
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
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ),
          ElevatedButton(
            onPressed: confirmationController.text == requiredText
                ? () {
                    context.pop();
                    onConfirm();
                  }
                : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey.shade800,
              disabledForegroundColor: Colors.grey,
            ),
            child: const Text(
              'Delete All Content',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
                            backgroundColor: Colors.grey.shade800,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Deleting content...',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$current / $total events',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      AccountDeletionProgressPreparing() => [
                        const CircularProgressIndicator(
                          color: VineTheme.vineGreen,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Preparing deletion...',
                          style: TextStyle(
                            color: Colors.white,
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

  // Step 1: Execute NIP-62 deletion request (requires working signer)
  try {
    final result = await deletionService.deleteAccount(
      onProgress: cubit.updateProgress,
    );

    if (result.success) {
      // Step 2: Delete Keycast account if one exists (invalidates signer)
      // We log but don't block on failure since NIP-62 already succeeded
      final (keycastSuccess, keycastError) = await authService
          .deleteKeycastAccount();
      if (!keycastSuccess) {
        Log.warning(
          'Keycast account deletion failed (continuing anyway): $keycastError',
          name: screenName,
          category: LogCategory.auth,
        );
      }

      // Step 3: Sign out and delete local keys
      // Router will automatically redirect to /welcome when auth state
      // becomes unauthenticated
      await authService.signOut(deleteKeys: true);

      // Close loading indicator and show success snackbar
      // Router will automatically redirect to /welcome after sign out
      dismissDialog();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Your account has been deleted',
              style: TextStyle(color: Colors.white),
            ),
            backgroundColor: VineTheme.vineGreen,
          ),
        );
      }
    } else {
      // Close loading indicator and show error
      dismissDialog();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.error ?? 'Failed to delete content from relays',
              style: const TextStyle(color: Colors.white),
            ),
            backgroundColor: Colors.red,
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
