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
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:openvine/widgets/delete_account_confirmation.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:unified_logger/unified_logger.dart';

/// Show warning dialog for removing keys from device only
Future<void> showRemoveKeysWarningDialog({
  required BuildContext context,
  required FutureOr<void> Function() onConfirm,
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
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            context.l10n.commonCancel,
            style: const TextStyle(color: VineTheme.lightText, fontSize: 16),
          ),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            unawaited(Future<void>.sync(onConfirm));
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
/// DELETE).
///
/// This dialog ensures they understand the dangerous/irreversible nature of
/// account deletion. The dialog opens immediately; [ownedUsernameFuture] is
/// resolved in the background and the opt-in "burn my username" toggle is
/// revealed only once it completes with a non-null handle — so a slow
/// name-server lookup never blocks the tap or lets a second tap stack a
/// duplicate dialog. [onConfirm] receives the handle the dialog actually
/// displayed, so a burn only ever targets the name the user consented to.
Future<void> showDeleteAllContentWarningDialog({
  required BuildContext context,
  required DeleteAccountConfirmation confirmation,
  required void Function({
    required bool burnUsername,
    ({String name, String canonical})? ownedUsername,
  })
  onConfirm,
  required Future<({String name, String canonical})?> ownedUsernameFuture,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _DeleteAllContentDialog(
      confirmation: confirmation,
      ownedUsernameFuture: ownedUsernameFuture,
      onConfirm: onConfirm,
    ),
  );
}

class _DeleteAllContentDialog extends StatefulWidget {
  const _DeleteAllContentDialog({
    required this.confirmation,
    required this.ownedUsernameFuture,
    required this.onConfirm,
  });

  final DeleteAccountConfirmation confirmation;
  final Future<({String name, String canonical})?> ownedUsernameFuture;
  final void Function({
    required bool burnUsername,
    ({String name, String canonical})? ownedUsername,
  })
  onConfirm;

  @override
  State<_DeleteAllContentDialog> createState() =>
      _DeleteAllContentDialogState();
}

class _DeleteAllContentDialogState extends State<_DeleteAllContentDialog> {
  final _confirmationController = TextEditingController();
  var _burnUsername = false;
  ({String name, String canonical})? _ownedUsername;

  @override
  void initState() {
    super.initState();
    unawaited(
      widget.ownedUsernameFuture
          .then<void>((owned) {
            if (!mounted || owned == null) return;
            setState(() => _ownedUsername = owned);
          })
          .catchError((Object _) {
            // Lookup failed: treat as "no handle" and leave the toggle hidden,
            // matching getUsernameByPubkey's unknown-means-no-name contract.
          }),
    );
  }

  @override
  void dispose() {
    _confirmationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final owned = _ownedUsername;
    final c = widget.confirmation;
    final canConfirm = c.matches(_confirmationController.text);
    return AlertDialog(
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
          _DeleteIdentityHeader(confirmation: c),
          const SizedBox(height: 16),
          Text(
            context.l10n.deleteAccountWarningBody,
            style: const TextStyle(
              color: VineTheme.whiteText,
              fontSize: 16,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            c.isUsernameConfirmation
                ? context.l10n.deleteAccountConfirmUsernamePrompt
                : context.l10n.deleteAccountConfirmDeletePrompt,
            style: const TextStyle(color: VineTheme.whiteText, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            c.requiredToken,
            style: const TextStyle(
              color: VineTheme.error,
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _confirmationController,
            style: const TextStyle(color: VineTheme.whiteText),
            autocorrect: false,
            textCapitalization: c.isUsernameConfirmation
                ? TextCapitalization.none
                : TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: c.isUsernameConfirmation
                  ? context.l10n.deleteAccountConfirmationHintUsername
                  : context.l10n.deleteAccountConfirmationHint,
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
          if (owned != null) ...[
            const SizedBox(height: 16),
            CheckboxListTile(
              value: _burnUsername,
              onChanged: (value) =>
                  setState(() => _burnUsername = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: VineTheme.error,
              checkColor: VineTheme.whiteText,
              title: Text(
                context.l10n.deleteAccountBurnUsernameToggle(
                  '@${owned.name}.divine.video',
                ),
                style: VineTheme.bodyMediumFont(),
              ),
            ),
          ],
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
          onPressed: canConfirm
              ? () {
                  context.pop();
                  widget.onConfirm(
                    burnUsername: _burnUsername,
                    ownedUsername: _ownedUsername,
                  );
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
    );
  }
}

/// Identity block (avatar + name + handle/npub) for the delete dialog.
class _DeleteIdentityHeader extends StatelessWidget {
  const _DeleteIdentityHeader({required this.confirmation});

  final DeleteAccountConfirmation confirmation;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        UserAvatar(
          imageUrl: confirmation.avatarUrl,
          name: confirmation.displayName,
          placeholderSeed: confirmation.pubkeyHex,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                confirmation.displayName,
                style: VineTheme.titleMediumFont(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                confirmation.identifierLine,
                style: VineTheme.bodyMediumFont(color: VineTheme.secondaryText),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
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
/// 2. If [burnUsername], release the @divine.video handle first (needs a
///    working signer); on failure, abort with nothing deleted (hard-block)
/// 3. Send NIP-62 deletion request (requires working signer)
/// 4. Delete Keycast account if exists (invalidates signer)
/// 5. Sign out and delete local keys
/// 6. Show success snackbar (router auto-redirects to /welcome)
///
/// If the burn commits but a later step fails, the error discloses that the
/// username was permanently released (the burn is never rolled back).
///
/// [context] - BuildContext for showing dialogs
/// [deletionService] - Service to execute NIP-62 deletion
/// [authService] - Service for Keycast deletion and sign out
/// [profileRepository] - Burns the username / re-checks ownership when
///   [burnUsername] is set
/// [burnUsername] - Whether the user opted in to permanently burn their handle
/// [ownedUsername] - The active handle (display name + canonical) to burn
/// [screenName] - Name of the calling screen for logging
Future<void> executeAccountDeletion({
  required BuildContext context,
  required AccountDeletionService deletionService,
  required AuthService authService,
  ProfileRepository? profileRepository,
  bool burnUsername = false,
  ({String name, String canonical})? ownedUsername,
  String? confirmedPubkey,
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
  final localDataDeletionFailedText =
      context.l10n.deleteAccountLocalDataDeletionFailed;
  final accountChangedText = context.l10n.deleteAccountAccountChanged;
  final burnUsernameFailedText = context.l10n.deleteAccountBurnUsernameFailed;
  final deletionIncompleteText = context.l10n.deleteAccountDeletionIncomplete;
  final handleLabel = ownedUsername != null
      ? '@${ownedUsername.name}.divine.video'
      : null;
  // Disclosure message for when the burn committed but the account could not
  // be fully deleted — states the permanent release (never rolled back).
  final burnReleasedText = handleLabel != null
      ? context.l10n.deleteAccountBurnUsernameReleased(handleLabel)
      : null;

  // Whether the @divine.video handle was permanently released this run.
  var burnCommitted = false;

  try {
    // Bind to the confirmed account: if the signed-in account changed since the
    // user confirmed, abort before burning or deleting anything.
    if (confirmedPubkey != null &&
        authService.currentPublicKeyHex != confirmedPubkey) {
      Log.warning(
        'Deletion aborted: signed-in account changed since confirmation',
        name: screenName,
        category: LogCategory.auth,
      );
      dismissDialog();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(accountChangedText, error: true),
        );
      }
      return;
    }

    // Burn-first hard-block: release the username before any destructive step,
    // so a failed burn leaves everything intact. Needs a working signer, which
    // exists before deleteKeycastAccount() below.
    if (burnUsername) {
      // Opted in to burn. A missing handle or repository means we cannot honor
      // it, so we must NOT proceed — treated the same as a failed release
      // (hard-block, symmetric in both directions).
      final releaseResult = (ownedUsername == null)
          ? null
          : await profileRepository?.releaseUsername(
              name: ownedUsername.canonical,
            );
      if (releaseResult is UsernameReleaseSuccess) {
        burnCommitted = true;
        Log.info(
          'Released $handleLabel before account deletion',
          name: screenName,
          category: LogCategory.auth,
        );
      } else {
        // Nothing was destroyed. Pick an honest message:
        //  - definite failure (not-owner / signer / null repo) -> nothing
        //    happened, safe to retry.
        //  - ambiguous network failure -> re-check ownership: if the name is
        //    still present the burn definitely did not happen; if we cannot
        //    tell, stay neutral and make no claim about the handle.
        var message = burnUsernameFailedText;
        if (releaseResult is UsernameReleaseNetworkError) {
          final pubkey = authService.currentPublicKeyHex;
          final stillOwned = (profileRepository != null && pubkey != null)
              ? await profileRepository.getUsernameByPubkey(pubkeyHex: pubkey)
              : null;
          if (stillOwned == null) {
            message = deletionIncompleteText;
          }
        }
        final abortReason = switch (releaseResult) {
          null when ownedUsername == null => 'no active handle to burn',
          null => 'profile repository unavailable',
          _ => 'release returned ${releaseResult.runtimeType}',
        };
        Log.warning(
          'Username burn could not be honored ($abortReason); aborting '
          'account deletion',
          name: screenName,
          category: LogCategory.auth,
        );
        dismissDialog();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            DivineSnackbarContainer.snackBar(message, error: true),
          );
        }
        return;
      }
    }

    // Publish the NIP-62 deletion request (requires working signer).
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
          'Keycast account deletion failed for registered user: $keycastError'
          '${burnCommitted ? ' (username $handleLabel already released)' : ''}',
          name: screenName,
          category: LogCategory.auth,
        );
        dismissDialog();
        if (context.mounted) {
          final text = (burnCommitted && burnReleasedText != null)
              ? burnReleasedText
              : context.l10n.deleteAccountServerDeletionFailed;
          ScaffoldMessenger.of(context).showSnackBar(
            DivineSnackbarContainer.snackBar(text, error: true),
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

      // Step 3: Sign out, delete local keys, and clear local account data
      // Router will automatically redirect to /welcome when auth state
      // becomes unauthenticated.
      // signOut may throw SecureKeyStorageException if platform key
      // deletion failed — the user IS signed out but keys may remain.
      String? keyDeletionWarning;
      String? localDataDeletionFailure;
      try {
        await authService.signOut(deleteKeys: true, deleteLocalUserData: true);
      } on SecureKeyStorageException catch (e) {
        Log.warning(
          'Key deletion failed during account deletion: $e',
          name: screenName,
          category: LogCategory.auth,
        );
        keyDeletionWarning = keyDeletionWarningText;
      } on UserDataCleanupException catch (e) {
        Log.warning(
          'Local user data cleanup failed during account deletion: $e',
          name: screenName,
          category: LogCategory.auth,
        );
        localDataDeletionFailure = localDataDeletionFailedText;
      }

      // Close loading indicator and show result snackbar
      // Router will automatically redirect to /welcome after sign out
      dismissDialog();
      if (context.mounted) {
        final snackbarText =
            keyDeletionWarning ??
            localDataDeletionFailure ??
            context.l10n.deleteAccountSuccess;
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            snackbarText,
            error:
                keyDeletionWarning != null || localDataDeletionFailure != null,
          ),
        );
      }
    } else {
      // Content deletion (NIP-62) failed.
      if (burnCommitted) {
        Log.error(
          'Content deletion failed after releasing $handleLabel',
          name: screenName,
          category: LogCategory.auth,
        );
      }
      dismissDialog();
      if (context.mounted) {
        final text = (burnCommitted && burnReleasedText != null)
            ? burnReleasedText
            : (result.error ?? context.l10n.deleteAccountContentDeletionFailed);
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(text, error: true),
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
