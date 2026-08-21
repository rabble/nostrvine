// ABOUTME: Full-screen recovery gate for interrupted account deletion.
// ABOUTME: Lets users restore a pending username or resume server processing.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
    // Captured before the await so the catch can localize without reading
    // BuildContext across an async gap.
    final keyDeletionWarning = context.l10n.deleteAccountKeyDeletionWarning;
    try {
      await ref
          .read(authServiceProvider)
          .signOut(deleteKeys: true, deleteLocalUserData: true);
    } on Object {
      // Whichever half of the local cleanup failed, the account is already
      // gone server-side and credentials may still be on the device. Naming
      // the keys is the conservative read and the one with a remedy the user
      // can act on. Telling them apart would mean importing the service layer
      // into a screen, which the UI boundary does not allow.
      _reportCleanupFailure(keyDeletionWarning);
    }
  }

  /// The server already reported `completed`, so nothing here may suggest the
  /// account survived or that a username is being restored. Only the local
  /// cleanup failed, and that is what the message names.
  void _reportCleanupFailure(String message) {
    if (!mounted) return;
    setState(() {
      _isSigningOut = false;
      _error = message;
    });
  }

  Future<void> _restore(AccountDeletionAttempt attempt) async {
    setState(() {
      _isCancelling = true;
      _error = null;
    });
    try {
      final repository = ref.read(accountDeletionRecoveryRepositoryProvider);
      final ready = attempt.status == AccountDeletionAttemptStatus.preparing
          ? await repository.prepare(username: attempt.username)
          : attempt;
      if (ready.status != AccountDeletionAttemptStatus.recoverable) {
        throw const AccountDeletionRecoveryException(
          'Username preparation did not become recoverable',
        );
      }
      final restored = await repository.cancel(attemptId: ready.id);
      if (!mounted) return;
      if (restored.status != AccountDeletionAttemptStatus.cancelled) {
        throw const AccountDeletionRecoveryException(
          'Server did not confirm username restoration',
        );
      }
      ref.invalidate(currentAccountDeletionAttemptProvider);
      context.go(RoutePaths.videoFeedForIndex(0));
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
  }

  @override
  Widget build(BuildContext context) {
    final attempt = ref.watch(currentAccountDeletionAttemptProvider);
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
              if (value.status == AccountDeletionAttemptStatus.completed) {
                if (!_isSigningOut) {
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _finishDeletion(),
                  );
                }
                final error = _error;
                return error == null
                    ? const Center(child: CircularProgressIndicator())
                    : _RecoveryContent(
                        body: error,
                        actionLabel: context.l10n.commonRetry,
                        onPressed: _finishDeletion,
                      );
              }
              final error = _error;
              if (value.status == AccountDeletionAttemptStatus.recoverable ||
                  value.status == AccountDeletionAttemptStatus.preparing) {
                return _RecoveryContent(
                  body:
                      error ??
                      (value.username == null
                          ? context.l10n.accountDeletionFinishingBody
                          : context.l10n.accountDeletionRecoveryBody),
                  actionLabel: value.username == null
                      ? context.l10n.commonCancel
                      : context.l10n.accountDeletionRestoreUsername,
                  onPressed: _isCancelling ? null : () => _restore(value),
                  showProgress: _isCancelling,
                );
              }
              return _RecoveryContent(
                body: error ?? context.l10n.accountDeletionFinishingBody,
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

class _RecoveryContent extends StatelessWidget {
  const _RecoveryContent({
    required this.body,
    required this.actionLabel,
    required this.onPressed,
    this.showProgress = false,
  });

  final String body;
  final String actionLabel;
  final VoidCallback? onPressed;
  final bool showProgress;

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
          style: VineTheme.bodyLargeFont(
            color: context.vineColors.primaryText,
          ),
        ),
        DivineButton(
          label: actionLabel,
          onPressed: onPressed,
          leadingIcon: DivineIconName.arrowCounterClockwise,
          isLoading: showProgress,
        ),
      ],
    );
  }
}
