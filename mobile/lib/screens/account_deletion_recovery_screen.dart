// ABOUTME: Full-screen recovery gate for interrupted account deletion.
// ABOUTME: Lets users restore a pending username or resume server processing.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart'
    show SecureKeyStorageException;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/account_deletion_attempt.dart';
import 'package:openvine/providers/account_deletion_recovery_providers.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/repositories/account_deletion_recovery_repository.dart';
import 'package:openvine/router/route_paths.dart';

class AccountDeletionRecoveryScreen extends ConsumerStatefulWidget {
  const AccountDeletionRecoveryScreen({super.key});

  static const String path = RoutePaths.accountDeletionRecovery;
  static const String routeName = 'account-deletion-recovery';

  @override
  ConsumerState<AccountDeletionRecoveryScreen> createState() =>
      _AccountDeletionRecoveryScreenState();
}

class _AccountDeletionRecoveryScreenState
    extends ConsumerState<AccountDeletionRecoveryScreen> {
  var _isCancelling = false;
  var _isSigningOut = false;
  String? _error;

  Future<void> _finishDeletion() async {
    if (_isSigningOut) return;
    _isSigningOut = true;
    try {
      await ref
          .read(authServiceProvider)
          .signOut(deleteKeys: true, deleteLocalUserData: true);
    } on SecureKeyStorageException {
      if (!mounted) return;
      setState(() {
        _isSigningOut = false;
        _error = context.l10n.deleteAccountKeyDeletionWarning;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _isSigningOut = false;
        _error = context.l10n.deleteAccountLocalDataDeletionFailed;
      });
    }
  }

  Future<void> _signOut() async {
    if (_isSigningOut) return;
    setState(() => _isSigningOut = true);
    try {
      await ref.read(authServiceProvider).signOut();
    } on Object {
      if (!mounted) return;
      setState(() {
        _isSigningOut = false;
        _error = context.l10n.accountDeletionRecoveryStatusFailed;
      });
    }
  }

  Future<void> _restore(AccountDeletionAttempt attempt) async {
    setState(() {
      _isCancelling = true;
      _error = null;
    });
    try {
      final repository = ref.read(accountDeletionRecoveryRepositoryProvider);
      final ready =
          attempt.status == AccountDeletionAttemptStatus.preparing &&
              !attempt.isCancellationInFlight &&
              attempt.username != null
          ? await repository.resumePreparation(attempt)
          : attempt;
      final canCancelPreparingAttempt =
          ready.status == AccountDeletionAttemptStatus.preparing &&
          ready.username == null;
      if (ready.status != AccountDeletionAttemptStatus.recoverable &&
          !canCancelPreparingAttempt) {
        throw const AccountDeletionRecoveryException(
          'Username preparation did not become recoverable',
        );
      }
      final restored = await repository.cancelAndWait(attemptId: ready.id);
      if (!mounted) return;
      if (restored.status != AccountDeletionAttemptStatus.cancelled) {
        throw const AccountDeletionRecoveryException(
          'Server did not confirm username restoration',
        );
      }
      ref.invalidate(currentAccountDeletionAttemptProvider);
      ref.invalidate(pollingAccountDeletionAttemptProvider);
      context.go(RoutePaths.videoFeedForIndex(0));
    } on AccountDeletionRecoveryException catch (error) {
      if (!mounted) return;
      if (const {
        'cancellation_after_commit',
        'illegal_transition',
        'attempt_not_found',
      }.contains(error.code)) {
        ref.invalidate(currentAccountDeletionAttemptProvider);
        ref.invalidate(pollingAccountDeletionAttemptProvider);
      } else {
        setState(
          () => _error = attempt.username == null
              ? context.l10n.accountDeletionRecoveryStatusFailed
              : context.l10n.accountDeletionRecoveryFailed,
        );
      }
    } on Object {
      if (!mounted) return;
      setState(
        () => _error = attempt.username == null
            ? context.l10n.accountDeletionRecoveryStatusFailed
            : context.l10n.accountDeletionRecoveryFailed,
      );
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  void _refresh() {
    setState(() => _error = null);
    ref.invalidate(currentAccountDeletionAttemptProvider);
    ref.invalidate(pollingAccountDeletionAttemptProvider);
  }

  @override
  Widget build(BuildContext context) {
    final attempt = ref.watch(pollingAccountDeletionAttemptProvider);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(context.l10n.accountDeletionRecoveryTitle),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: attempt.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => _RecoveryContent(
              body: context.l10n.accountDeletionRecoveryStatusFailed,
              actionLabel: context.l10n.commonRetry,
              onPressed: _refresh,
            ),
            data: (value) {
              if (value == null ||
                  value.status == AccountDeletionAttemptStatus.cancelled) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) context.go(RoutePaths.videoFeedForIndex(0));
                });
                return const Center(child: CircularProgressIndicator());
              }
              final error = _error;
              if (value.status == AccountDeletionAttemptStatus.completed) {
                if (!_isSigningOut && error == null) {
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _finishDeletion(),
                  );
                }
                return error == null
                    ? const Center(child: CircularProgressIndicator())
                    : _RecoveryContent(
                        body: error,
                        actionLabel: context.l10n.commonRetry,
                        onPressed: _finishDeletion,
                      );
              }
              if (value.status ==
                  AccountDeletionAttemptStatus.terminalFailure) {
                return _RecoveryContent(
                  body: error ?? _failureBody(context, value.failureCode),
                  actionLabel: context.l10n.supportContactSupport,
                  onPressed: () => context.push(RoutePaths.supportCenter),
                  secondaryActionLabel: context.l10n.accountDeletionSignOut,
                  onSecondaryPressed: _isSigningOut ? null : _signOut,
                );
              }
              if (value.status == AccountDeletionAttemptStatus.recoverable ||
                  (value.status == AccountDeletionAttemptStatus.preparing &&
                      !value.isCancellationInFlight)) {
                final expiresAt = value.usernameExpiresAt;
                final usernameRecoveryBody = expiresAt == null
                    ? context.l10n.accountDeletionRecoveryBody
                    : context.l10n.accountDeletionRecoveryBodyWithExpiry(
                        MaterialLocalizations.of(context).formatFullDate(
                          DateTime.fromMillisecondsSinceEpoch(
                            expiresAt * Duration.millisecondsPerSecond,
                          ).toLocal(),
                        ),
                      );
                return _RecoveryContent(
                  body:
                      error ??
                      (value.username == null
                          ? context.l10n.accountDeletionCancelAttemptBody
                          : usernameRecoveryBody),
                  actionLabel: value.username == null
                      ? context.l10n.accountDeletionCancelAttempt
                      : context.l10n.accountDeletionRestoreUsername,
                  onPressed: _isCancelling ? null : () => _restore(value),
                  showProgress: _isCancelling,
                );
              }
              // A cancelling attempt and a processing one are both waiting on
              // the coordinator, but they are waiting on opposite outcomes:
              // saying deletion is still running while the server is putting
              // the account back reads as the cancel having failed.
              return _RecoveryContent(
                body:
                    error ??
                    (value.isCancellationInFlight
                        ? context.l10n.accountDeletionCancellingBody
                        : context.l10n.accountDeletionFinishingBody),
                actionLabel: context.l10n.commonRetry,
                onPressed: _refresh,
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Localized copy for a terminal-failure attempt's stable `failure_code`.
///
/// The coordinator sets one of `username_attempt_expired`,
/// `keycast_deletion_failed`, `relay_erasure_unconfirmed`, or
/// `deletion_deadline_exceeded`. Only the first two have copy that says
/// something the generic terminal message does not; the rest — and any code a
/// later coordinator adds — fall back to it rather than rendering server
/// English.
String _failureBody(
  BuildContext context,
  String? failureCode,
) => switch (failureCode) {
  'username_attempt_expired' => context.l10n.deleteAccountDeletionIncomplete,
  'keycast_deletion_failed' => context.l10n.deleteAccountServerDeletionFailed,
  _ => context.l10n.accountDeletionTerminalFailureBody,
};

class _RecoveryContent extends StatelessWidget {
  const _RecoveryContent({
    required this.body,
    required this.actionLabel,
    required this.onPressed,
    this.showProgress = false,
    this.secondaryActionLabel,
    this.onSecondaryPressed,
  });

  final String body;
  final String actionLabel;
  final VoidCallback? onPressed;
  final bool showProgress;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 24,
      children: [
        const DivineIcon(icon: DivineIconName.userCircle, size: 64),
        Text(
          body,
          textAlign: TextAlign.center,
          style: VineTheme.bodyLargeFont(color: context.vineColors.primaryText),
        ),
        DivineButton(
          label: actionLabel,
          onPressed: onPressed,
          leadingIcon: DivineIconName.arrowCounterClockwise,
          isLoading: showProgress,
        ),
        if (secondaryActionLabel != null)
          DivineButton(
            label: secondaryActionLabel!,
            type: DivineButtonType.secondary,
            onPressed: onSecondaryPressed,
          ),
      ],
    );
  }
}
