// ABOUTME: Tests the account-deletion recovery providers used by routing.
// ABOUTME: Verifies lookup readiness remains fail-closed until signing works.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/auth_rpc_capability.dart';
import 'package:openvine/providers/account_deletion_recovery_providers.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/repositories/account_deletion_recovery_repository.dart';
import 'package:openvine/services/auth_service.dart';

class _MockDeletionRepository extends Mock
    implements AccountDeletionRecoveryRepository {}

class _MockAuthService extends Mock implements AuthService {}

class _TestNostrSession extends NostrSession {
  @override
  NostrSessionReadiness build() =>
      const NostrSessionReadiness.identityKnown(pubkey: 'user-pubkey');
}

void main() {
  group('currentAccountDeletionAttemptProvider', () {
    test(
      'lookup starts when signing is ready without waiting for relays',
      () async {
        final repository = _MockDeletionRepository();
        final authService = _MockAuthService();
        when(repository.fetchCurrent).thenAnswer((_) async => null);
        when(() => authService.canPublishNostrWritesNow).thenReturn(true);
        final container = ProviderContainer(
          overrides: [
            authServiceProvider.overrideWithValue(authService),
            currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
            currentAuthRpcCapabilityProvider.overrideWithValue(
              AuthRpcCapability.unavailable,
            ),
            nostrSessionProvider.overrideWith(_TestNostrSession.new),
            accountDeletionRecoveryRepositoryProvider.overrideWithValue(
              repository,
            ),
          ],
        );
        addTearDown(container.dispose);
        final subscription = container.listen(
          currentAccountDeletionAttemptProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        await container.read(currentAccountDeletionAttemptProvider.future);

        expect(
          container.read(currentAccountDeletionAttemptProvider).value,
          isNull,
        );
        verify(repository.fetchCurrent).called(1);
      },
    );

    test('lookup stays fail-closed while signing is unavailable', () async {
      final repository = _MockDeletionRepository();
      final authService = _MockAuthService();
      when(() => authService.canPublishNostrWritesNow).thenReturn(false);
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          currentAuthRpcCapabilityProvider.overrideWithValue(
            AuthRpcCapability.upgrading,
          ),
          accountDeletionRecoveryRepositoryProvider.overrideWithValue(
            repository,
          ),
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
    });
  });
}
