// ABOUTME: Tests that dmRepositoryProvider drives the gift-wrap subscription
// ABOUTME: lifecycle for the entire authenticated session, not just while
// ABOUTME: InboxPage is mounted. Regression guard for #2931.

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart' as nostr_filter;
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

class _FakeFilter extends Fake implements nostr_filter.Filter {}

void main() {
  // 64-character hex pubkey for tests.
  const testPubkey =
      'a1b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012';
  // 64-character hex private key for tests.
  const testPrivateKey =
      '0000000000000000000000000000000000000000000000000000000000000001';

  setUpAll(() {
    registerFallbackValue(<nostr_filter.Filter>[_FakeFilter()]);
  });

  group('dmRepositoryProvider (#2931)', () {
    late _MockNostrClient mockNostrClient;
    late _MockAuthService mockAuthService;
    late LocalNostrSigner signer;
    late AppDatabase database;
    late SharedPreferences prefs;

    setUp(() async {
      mockNostrClient = _MockNostrClient();
      mockAuthService = _MockAuthService();
      signer = LocalNostrSigner(testPrivateKey);
      database = AppDatabase.test(NativeDatabase.memory());

      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();

      // NostrClient stubs needed by DmRepository.startListening()'s
      // diagnostic logging and subscription path.
      when(() => mockNostrClient.connectedRelayCount).thenReturn(1);
      when(() => mockNostrClient.configuredRelayCount).thenReturn(1);
      when(() => mockNostrClient.publicKey).thenReturn(testPubkey);
      when(() => mockNostrClient.signer).thenReturn(signer);
      when(
        () => mockNostrClient.subscribe(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
        ),
      ).thenAnswer((_) => const Stream<Event>.empty());
      when(() => mockNostrClient.unsubscribe(any())).thenAnswer((_) async {});

      // AuthService stubs for auth-state-driven providers.
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.currentPublicKeyHex).thenReturn(testPubkey);
      when(() => mockAuthService.currentIdentity).thenReturn(null);
      when(() => mockAuthService.userRelays).thenReturn(const []);
      when(
        () => mockAuthService.authStateStream,
      ).thenAnswer((_) => const Stream<AuthState>.empty());
    });

    tearDown(() async {
      await database.close();
    });

    ProviderContainer createContainer({required bool isReady}) {
      return ProviderContainer(
        overrides: [
          nostrServiceProvider.overrideWithValue(mockNostrClient),
          authServiceProvider.overrideWithValue(mockAuthService),
          currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
          isNostrReadyProvider.overrideWithValue(isReady),
          databaseProvider.overrideWithValue(database),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
    }

    test('opens gift-wrap subscription when isNostrReady is true', () async {
      // ARRANGE
      final container = createContainer(isReady: true);
      addTearDown(container.dispose);

      // ACT — touching the provider triggers the build
      final repository = container.read(dmRepositoryProvider);

      // The provider calls startListening() asynchronously via unawaited(),
      // so let microtasks drain before asserting.
      await Future<void>.delayed(Duration.zero);

      // ASSERT — the gift-wrap subscription was opened on the relay
      // client. This is the proof that the auth-scoped lifecycle is
      // active and DMs will be ingested even without InboxPage mounting.
      verify(
        () => mockNostrClient.subscribe(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
        ),
      ).called(1);
      expect(repository.isInitialized, isTrue);
      expect(repository.userPubkey, equals(testPubkey));
    });

    test('does NOT open subscription when isNostrReady is false', () async {
      // ARRANGE — pre-auth or initialization-pending state
      final container = createContainer(isReady: false);
      addTearDown(container.dispose);

      // ACT
      final repository = container.read(dmRepositoryProvider);
      await Future<void>.delayed(Duration.zero);

      // ASSERT — the repository exists for read-only operations but no
      // relay traffic is generated until isNostrReady flips true.
      verifyNever(
        () => mockNostrClient.subscribe(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
        ),
      );
      expect(repository.isInitialized, isFalse);
    });

    test('tears down subscription on container dispose', () async {
      // ARRANGE
      final container = createContainer(isReady: true);
      container.read(dmRepositoryProvider);
      await Future<void>.delayed(Duration.zero);

      // ACT — disposing the container fires ref.onDispose hooks, which
      // include repository.stopListening.
      container.dispose();
      await Future<void>.delayed(Duration.zero);

      // ASSERT — unsubscribe was called on the relay client.
      verify(() => mockNostrClient.unsubscribe(any())).called(1);
    });
  });
}
