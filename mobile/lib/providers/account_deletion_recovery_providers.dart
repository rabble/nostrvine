// ABOUTME: Riverpod wiring for resumable server-side account deletion.
// ABOUTME: Fetches current attempt after authentication for launch routing.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/account_deletion_attempt.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
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

final currentAccountDeletionAttemptProvider =
    FutureProvider<AccountDeletionAttempt?>((ref) async {
      if (ref.watch(currentAuthStateProvider) != AuthState.authenticated) {
        return null;
      }
      if (!ref.watch(nostrSessionProvider).isReadyForActiveClient) {
        return null;
      }
      return ref
          .watch(accountDeletionRecoveryRepositoryProvider)
          .fetchCurrent();
    });

final pollingAccountDeletionAttemptProvider =
    StreamProvider<AccountDeletionAttempt?>((ref) {
      if (ref.watch(currentAuthStateProvider) != AuthState.authenticated) {
        return Stream.value(null);
      }
      if (!ref.watch(nostrSessionProvider).isReadyForActiveClient) {
        return Stream.value(null);
      }
      return ref
          .watch(accountDeletionRecoveryRepositoryProvider)
          .watchCurrent();
    });
