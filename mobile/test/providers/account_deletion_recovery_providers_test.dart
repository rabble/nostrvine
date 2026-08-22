// ABOUTME: Tests the account-deletion recovery providers used by routing.
// ABOUTME: Verifies lookup readiness remains fail-closed until signing works.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/providers/account_deletion_recovery_providers.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/repositories/account_deletion_recovery_repository.dart';
import 'package:openvine/services/auth_service.dart';

class _MockDeletionRepository extends Mock
    implements AccountDeletionRecoveryRepository {}

class _MockNostrClient extends Mock implements NostrClient {}

class _TestNostrSession extends NostrSession {
  @override
  NostrSessionReadiness build() =>
      const NostrSessionReadiness.identityKnown(pubkey: 'user-pubkey');

  void markReady() {
    final client = _MockNostrClient();
    when(() => client.hasKeys).thenReturn(true);
    when(() => client.publicKey).thenReturn('user-pubkey');
    state = NostrSessionReadiness.nostrReady(
      pubkey: 'user-pubkey',
      client: client,
    );
  }
}

void main() {
  test('lookup stays loading until the active client is ready', () async {
    final repository = _MockDeletionRepository();
    when(repository.fetchCurrent).thenAnswer((_) async => null);
    final container = ProviderContainer(
      overrides: [
        currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
        nostrSessionProvider.overrideWith(_TestNostrSession.new),
        accountDeletionRecoveryRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(
      currentAccountDeletionAttemptProvider,
      (_, _) {},
      fireImmediately: true,
    );
    addTearDown(subscription.close);

    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(currentAccountDeletionAttemptProvider).isLoading,
      true,
    );
    verifyNever(repository.fetchCurrent);

    (container.read(nostrSessionProvider.notifier) as _TestNostrSession)
        .markReady();
    await container.read(currentAccountDeletionAttemptProvider.future);

    expect(container.read(currentAccountDeletionAttemptProvider).value, isNull);
    verify(repository.fetchCurrent).called(1);
  });
}
