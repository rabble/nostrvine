// ABOUTME: Riverpod wiring for resumable server-side account deletion.
// ABOUTME: Fetches current attempt after authentication for launch routing.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/account_deletion_attempt.dart';
import 'package:openvine/models/signer_readiness.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/repositories/account_deletion_recovery_repository.dart';
import 'package:openvine/services/auth_service.dart';

final accountDeletionRecoveryRepositoryProvider =
    Provider<AccountDeletionRecoveryRepository>((ref) {
      final client = ref.watch(instrumentedHttpClientFactoryProvider)();
      ref.onDispose(client.close);
      return AccountDeletionRecoveryRepository(
        baseUrl: ref.watch(currentEnvironmentProvider).apiBaseUrl,
        nameServerBaseUrl: ref
            .watch(currentEnvironmentProvider)
            .nameServerBaseUrl,
        httpClient: client,
        nip98AuthService: ref.watch(nip98AuthServiceProvider),
        currentPubkey: () => ref.read(authServiceProvider).currentPublicKeyHex,
      );
    });

/// A deletion attempt this process committed, bound to the account it belongs
/// to.
typedef SubmittedAccountDeletionAttempt = ({
  String pubkeyHex,
  AccountDeletionAttempt attempt,
});

/// The attempt the coordinator accepted for processing on this device.
///
/// Once `submit` answers `processing`, the coordinator deletes the Keycast
/// user within seconds, so a status lookup can no longer be signed. The
/// recovery gate must therefore read the attempt from here rather than from a
/// refetch (#8583). Cleared when the recovery screen resolves the attempt.
final submittedAccountDeletionAttemptProvider =
    NotifierProvider<
      SubmittedAccountDeletionAttemptNotifier,
      SubmittedAccountDeletionAttempt?
    >(SubmittedAccountDeletionAttemptNotifier.new);

class SubmittedAccountDeletionAttemptNotifier
    extends Notifier<SubmittedAccountDeletionAttempt?> {
  @override
  SubmittedAccountDeletionAttempt? build() => null;

  void record({
    required String pubkeyHex,
    required AccountDeletionAttempt attempt,
  }) => state = (pubkeyHex: pubkeyHex, attempt: attempt);

  void clear() => state = null;
}

final currentAccountDeletionAttemptProvider =
    FutureProvider<AccountDeletionAttempt?>(
      (ref) async {
        if (ref.watch(currentAuthStateProvider) != AuthState.authenticated) {
          return null;
        }
        final authService = ref.watch(authServiceProvider);
        ref.watch(currentAuthRpcCapabilityProvider);
        // Consulted before the signer: the attempt this process committed is
        // known without a lookup, and the lookup is exactly what a committed
        // deletion makes impossible.
        final submitted = ref.watch(submittedAccountDeletionAttemptProvider);
        if (submitted != null &&
            submitted.pubkeyHex == authService.currentPublicKeyHex) {
          return submitted.attempt;
        }
        switch (authService.signerReadiness) {
          case SignerReadiness.pending:
            final waitingForReadiness = Completer<AccountDeletionAttempt?>();
            ref.onDispose(
              () => waitingForReadiness.completeError(
                const _SignerReadinessWaitCancelled(),
              ),
            );
            return waitingForReadiness.future;
          case SignerReadiness.unavailable:
            throw const AccountDeletionStatusUnavailable();
          case SignerReadiness.ready:
            return ref
                .watch(accountDeletionRecoveryRepositoryProvider)
                .fetchCurrent();
        }
      },
      retry: (retryCount, error) => error is AccountDeletionStatusUnavailable
          ? null
          : ProviderContainer.defaultRetry(retryCount, error),
    );

class AccountDeletionStatusUnavailable implements Exception {
  const AccountDeletionStatusUnavailable();

  @override
  String toString() => 'AccountDeletionStatusUnavailable';
}

class _SignerReadinessWaitCancelled implements Exception {
  const _SignerReadinessWaitCancelled();

  @override
  String toString() => '_SignerReadinessWaitCancelled';
}
