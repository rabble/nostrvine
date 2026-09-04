// ABOUTME: Riverpod wiring for resumable server-side account deletion.
// ABOUTME: Fetches current attempt after authentication for launch routing.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/account_deletion_attempt.dart';
import 'package:openvine/models/signer_readiness.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/service_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
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

/// Durable receipt for a deletion this installation submitted.
final class SubmittedAccountDeletionAttempt {
  const SubmittedAccountDeletionAttempt({
    required this.pubkeyHex,
    required this.attempt,
    required this.vanishEventId,
  });

  factory SubmittedAccountDeletionAttempt.fromJson(Map<String, dynamic> json) =>
      SubmittedAccountDeletionAttempt(
        pubkeyHex: json['pubkey_hex'] as String,
        vanishEventId: json['vanish_event_id'] as String,
        attempt: AccountDeletionAttempt.fromJson(
          json['attempt'] as Map<String, dynamic>,
        ),
      );

  final String pubkeyHex;
  final AccountDeletionAttempt attempt;
  final String vanishEventId;

  Map<String, dynamic> toJson() => {
    'pubkey_hex': pubkeyHex,
    'vanish_event_id': vanishEventId,
    'attempt': attempt.toJson(),
  };

  SubmittedAccountDeletionAttempt copyWith({AccountDeletionAttempt? attempt}) =>
      SubmittedAccountDeletionAttempt(
        pubkeyHex: pubkeyHex,
        attempt: attempt ?? this.attempt,
        vanishEventId: vanishEventId,
      );
}

/// The attempt this installation submitted for irreversible processing.
///
/// Persisted before `submit`, because a lost response is ambiguous and the
/// coordinator may already have deleted the Keycast signer. It deliberately
/// survives sign-out and app restart so ordinary login cannot race a pending
/// deletion (#8583).
final submittedAccountDeletionAttemptProvider =
    NotifierProvider<
      SubmittedAccountDeletionAttemptNotifier,
      SubmittedAccountDeletionAttempt?
    >(SubmittedAccountDeletionAttemptNotifier.new);

class SubmittedAccountDeletionAttemptNotifier
    extends Notifier<SubmittedAccountDeletionAttempt?> {
  static const _storageKey = 'account_deletion_receipt_v1';

  @override
  SubmittedAccountDeletionAttempt? build() {
    final encoded = ref.watch(sharedPreferencesProvider).getString(_storageKey);
    if (encoded == null) return null;
    try {
      return SubmittedAccountDeletionAttempt.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );
    } on Object {
      unawaited(ref.read(sharedPreferencesProvider).remove(_storageKey));
      return null;
    }
  }

  Future<void> record({
    required String pubkeyHex,
    required AccountDeletionAttempt attempt,
    required String vanishEventId,
  }) async {
    final receipt = SubmittedAccountDeletionAttempt(
      pubkeyHex: pubkeyHex,
      attempt: attempt,
      vanishEventId: vanishEventId,
    );
    final saved = await ref
        .read(sharedPreferencesProvider)
        .setString(_storageKey, jsonEncode(receipt.toJson()));
    if (!saved) throw StateError('Could not persist account deletion receipt');
    state = receipt;
  }

  Future<void> updateAttempt(AccountDeletionAttempt attempt) async {
    final receipt = state;
    if (receipt == null || receipt.attempt.id != attempt.id) return;
    await record(
      pubkeyHex: receipt.pubkeyHex,
      attempt: attempt,
      vanishEventId: receipt.vanishEventId,
    );
  }

  Future<void> clear() async {
    final removed = await ref
        .read(sharedPreferencesProvider)
        .remove(_storageKey);
    if (!removed) throw StateError('Could not clear account deletion receipt');
    state = null;
  }
}

final currentAccountDeletionAttemptProvider =
    FutureProvider<AccountDeletionAttempt?>(
      (ref) async {
        final submitted = ref.watch(submittedAccountDeletionAttemptProvider);
        if (submitted != null) {
          return submitted.attempt;
        }
        if (ref.watch(currentAuthStateProvider) != AuthState.authenticated) {
          return null;
        }
        final authService = ref.watch(authServiceProvider);
        ref.watch(currentAuthRpcCapabilityProvider);
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
