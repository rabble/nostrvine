// ABOUTME: Tests the account-deletion recovery providers used by routing.
// ABOUTME: Verifies lookup readiness remains fail-closed until signing works.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/account_deletion_attempt.dart';
import 'package:openvine/models/auth_rpc_capability.dart';
import 'package:openvine/models/signer_readiness.dart';
import 'package:openvine/providers/account_deletion_recovery_providers.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/repositories/account_deletion_recovery_repository.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockDeletionRepository extends Mock
    implements AccountDeletionRecoveryRepository {}

class _MockAuthService extends Mock implements AuthService {}

class _AuthStateProbe extends Notifier<AuthState> {
  @override
  AuthState build() => AuthState.authenticated;

  void set(AuthState next) => state = next;
}

final _authStateProbe = NotifierProvider<_AuthStateProbe, AuthState>(
  _AuthStateProbe.new,
);

class _TestNostrSession extends NostrSession {
  @override
  NostrSessionReadiness build() =>
      const NostrSessionReadiness.identityKnown(pubkey: 'user-pubkey');
}

void main() {
  late SharedPreferences preferences;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    preferences = await SharedPreferences.getInstance();
  });

  group('currentAccountDeletionAttemptProvider', () {
    test(
      'lookup starts when signing is ready without waiting for relays',
      () async {
        final repository = _MockDeletionRepository();
        final authService = _MockAuthService();
        when(repository.fetchCurrent).thenAnswer((_) async => null);
        when(
          () => authService.signerReadiness,
        ).thenReturn(SignerReadiness.ready);
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
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

    test('lookup stays fail-closed while signing warms up', () async {
      final repository = _MockDeletionRepository();
      final authService = _MockAuthService();
      when(
        () => authService.signerReadiness,
      ).thenReturn(SignerReadiness.pending);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
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

    test('permanent signer failure settles as a typed error', () async {
      final repository = _MockDeletionRepository();
      final authService = _MockAuthService();
      when(
        () => authService.signerReadiness,
      ).thenReturn(SignerReadiness.unavailable);
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          authServiceProvider.overrideWithValue(authService),
          currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          currentAuthRpcCapabilityProvider.overrideWithValue(
            AuthRpcCapability.unavailable,
          ),
          accountDeletionRecoveryRepositoryProvider.overrideWithValue(
            repository,
          ),
        ],
      );
      addTearDown(container.dispose);

      final settled = Completer<AsyncValue<AccountDeletionAttempt?>>();
      final subscription = container.listen(
        currentAccountDeletionAttemptProvider,
        (_, next) {
          if (next.hasError && !next.isLoading && !settled.isCompleted) {
            settled.complete(next);
          }
        },
        fireImmediately: true,
      );
      addTearDown(subscription.close);

      final result = await settled.future;
      expect(result.isLoading, isFalse);
      expect(result.error, isA<AccountDeletionStatusUnavailable>());
      verifyNever(repository.fetchCurrent);
    });
  });

  group('submittedAccountDeletionAttemptProvider', () {
    const pubkey = 'user-pubkey';
    const processing = AccountDeletionAttempt(
      id: 'attempt-id',
      status: AccountDeletionAttemptStatus.processing,
    );

    late _MockDeletionRepository repository;
    late _MockAuthService authService;
    late ProviderContainer container;

    setUp(() {
      repository = _MockDeletionRepository();
      authService = _MockAuthService();
      when(repository.fetchCurrent).thenAnswer((_) async => null);
      when(() => authService.signerReadiness).thenReturn(SignerReadiness.ready);
      when(() => authService.currentPublicKeyHex).thenReturn(pubkey);
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          authServiceProvider.overrideWithValue(authService),
          currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          currentAuthRpcCapabilityProvider.overrideWithValue(
            AuthRpcCapability.rpcReady,
          ),
          accountDeletionRecoveryRepositoryProvider.overrideWithValue(
            repository,
          ),
        ],
      );
      addTearDown(container.dispose);
    });

    // Listened after the record is written, the way the router listens
    // from app start: the lookup must never have been needed.
    void keepAlive() {
      final subscription = container.listen(
        currentAccountDeletionAttemptProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
    }

    test(
      'a recorded attempt is the current attempt without a lookup',
      () async {
        // The signer the deletion just killed: every lookup fails, exactly
        // as it does once the coordinator has deleted the Keycast user
        // (#8583).
        when(repository.fetchCurrent).thenThrow(
          const AccountDeletionRecoveryException(
            'Could not authorize deletion attempt request',
          ),
        );
        await container
            .read(submittedAccountDeletionAttemptProvider.notifier)
            .record(
              pubkeyHex: pubkey,
              attempt: processing,
              vanishEventId: 'vanish-event-id',
            );
        keepAlive();

        expect(
          await container.read(currentAccountDeletionAttemptProvider.future),
          same(processing),
        );
        verifyNever(repository.fetchCurrent);
      },
    );

    test('a recorded attempt survives a new provider container', () async {
      await container
          .read(submittedAccountDeletionAttemptProvider.notifier)
          .record(
            pubkeyHex: pubkey,
            attempt: processing,
            vanishEventId: 'vanish-event-id',
          );
      final restarted = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          authServiceProvider.overrideWithValue(authService),
          currentAuthStateProvider.overrideWithValue(AuthState.unauthenticated),
          currentAuthRpcCapabilityProvider.overrideWithValue(
            AuthRpcCapability.unavailable,
          ),
          accountDeletionRecoveryRepositoryProvider.overrideWithValue(
            repository,
          ),
        ],
      );
      addTearDown(restarted.dispose);

      final receipt = restarted.read(submittedAccountDeletionAttemptProvider);
      expect(receipt?.pubkeyHex, pubkey);
      expect(receipt?.attempt.id, processing.id);
      expect(receipt?.attempt.status, processing.status);
      expect(receipt?.vanishEventId, 'vanish-event-id');
      expect(
        await restarted.read(currentAccountDeletionAttemptProvider.future),
        isNotNull,
      );
      verifyNever(repository.fetchCurrent);
    });

    test('a durable record gates before authentication is restored', () async {
      final preAuth = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          authServiceProvider.overrideWithValue(authService),
          currentAuthStateProvider.overrideWithValue(AuthState.unauthenticated),
          currentAuthRpcCapabilityProvider.overrideWithValue(
            AuthRpcCapability.unavailable,
          ),
          accountDeletionRecoveryRepositoryProvider.overrideWithValue(
            repository,
          ),
        ],
      );
      addTearDown(preAuth.dispose);
      await preAuth
          .read(submittedAccountDeletionAttemptProvider.notifier)
          .record(
            pubkeyHex: 'someone-else',
            attempt: processing,
            vanishEventId: 'vanish-event-id',
          );

      expect(
        await preAuth.read(currentAccountDeletionAttemptProvider.future),
        same(processing),
      );
      verifyNever(repository.fetchCurrent);
    });

    test('a different authenticated account ignores the receipt', () async {
      when(
        () => authService.currentPublicKeyHex,
      ).thenReturn('different-account-pubkey');
      await container
          .read(submittedAccountDeletionAttemptProvider.notifier)
          .record(
            pubkeyHex: pubkey,
            attempt: processing,
            vanishEventId: 'vanish-event-id',
          );
      keepAlive();

      expect(
        await container.read(currentAccountDeletionAttemptProvider.future),
        isNull,
      );
      expect(
        container.read(currentSubmittedAccountDeletionAttemptProvider),
        isNull,
      );
      verify(repository.fetchCurrent).called(1);
    });

    test(
      'a different account is not gated by a retained receipt after lookup '
      'failure',
      () async {
        final probe = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(preferences),
            authServiceProvider.overrideWithValue(authService),
            currentAuthStateProvider.overrideWith(
              (ref) => ref.watch(_authStateProbe),
            ),
            currentAuthRpcCapabilityProvider.overrideWithValue(
              AuthRpcCapability.rpcReady,
            ),
            accountDeletionRecoveryRepositoryProvider.overrideWithValue(
              repository,
            ),
          ],
        );
        addTearDown(probe.dispose);
        probe.read(_authStateProbe.notifier).set(AuthState.unauthenticated);
        await probe
            .read(submittedAccountDeletionAttemptProvider.notifier)
            .record(
              pubkeyHex: pubkey,
              attempt: processing,
              vanishEventId: 'vanish-event-id',
            );
        final subscription = probe.listen(
          currentAccountDeletionAttemptProvider,
          (_, _) {},
          fireImmediately: true,
        );
        addTearDown(subscription.close);
        expect(
          await probe.read(currentAccountDeletionAttemptProvider.future),
          same(processing),
        );

        when(
          () => authService.currentPublicKeyHex,
        ).thenReturn('different-account-pubkey');
        when(repository.fetchCurrent).thenThrow(
          const AccountDeletionStatusUnavailable(),
        );
        probe.read(_authStateProbe.notifier).set(AuthState.authenticated);
        await expectLater(
          probe.read(currentAccountDeletionAttemptProvider.future),
          throwsA(isA<AccountDeletionStatusUnavailable>()),
        );

        final retained = probe.read(currentAccountDeletionAttemptProvider);
        expect(retained.hasError, isTrue);
        expect(retained.value, same(processing));
        expect(
          probe.read(currentSubmittedAccountDeletionAttemptProvider),
          isNull,
        );
        expect(
          accountDeletionRecoveryGateActive(
            retained,
            submittedAttempt: probe.read(
              submittedAccountDeletionAttemptProvider,
            ),
            authState: AuthState.authenticated,
            currentPubkeyHex: 'different-account-pubkey',
          ),
          isFalse,
        );
      },
    );

    test('a second account cannot overwrite the pending receipt', () async {
      final notifier = container.read(
        submittedAccountDeletionAttemptProvider.notifier,
      );
      await notifier.record(
        pubkeyHex: pubkey,
        attempt: processing,
        vanishEventId: 'vanish-event-id',
      );

      await expectLater(
        notifier.record(
          pubkeyHex: 'different-account-pubkey',
          attempt: processing,
          vanishEventId: 'other-vanish-event-id',
        ),
        throwsStateError,
      );
      expect(notifier.state?.pubkeyHex, pubkey);
    });

    test('signing out preserves the record', () async {
      final probe = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          authServiceProvider.overrideWithValue(authService),
          currentAuthStateProvider.overrideWith(
            (ref) => ref.watch(_authStateProbe),
          ),
          currentAuthRpcCapabilityProvider.overrideWithValue(
            AuthRpcCapability.rpcReady,
          ),
          accountDeletionRecoveryRepositoryProvider.overrideWithValue(
            repository,
          ),
        ],
      );
      addTearDown(probe.dispose);
      final subscription = probe.listen(
        submittedAccountDeletionAttemptProvider,
        (_, _) {},
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      await probe
          .read(submittedAccountDeletionAttemptProvider.notifier)
          .record(
            pubkeyHex: pubkey,
            attempt: processing,
            vanishEventId: 'vanish-event-id',
          );

      probe.read(_authStateProbe.notifier).set(AuthState.unauthenticated);
      await Future<void>.delayed(Duration.zero);

      expect(
        probe.read(submittedAccountDeletionAttemptProvider)?.attempt,
        same(processing),
      );
    });

    test('clearing the record hands the lookup back to the signer', () async {
      final notifier = container.read(
        submittedAccountDeletionAttemptProvider.notifier,
      );
      await notifier.record(
        pubkeyHex: pubkey,
        attempt: processing,
        vanishEventId: 'vanish-event-id',
      );
      keepAlive();
      await container.read(currentAccountDeletionAttemptProvider.future);

      await notifier.clear();

      expect(
        await container.read(currentAccountDeletionAttemptProvider.future),
        isNull,
      );
      verify(repository.fetchCurrent).called(1);
    });
  });
}
