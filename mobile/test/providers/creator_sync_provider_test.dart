// ABOUTME: Tests the soundSyncRepositoryProvider nullable-gate branches.
// ABOUTME: Covers signed-out, not-ready, vault-key-unavailable, and ready.

import 'dart:convert';
import 'dart:typed_data';

import 'package:creator_sync/creator_sync.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/creator_sync_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/saved_sounds_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/saved_sounds_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockNostrSigner extends Mock implements NostrSigner {}

class _MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

class _TestNostrSession extends NostrSession {
  _TestNostrSession(this._readiness);

  final NostrSessionReadiness _readiness;

  @override
  NostrSessionReadiness build() => _readiness;
}

void main() {
  // 64-character hex pubkey for tests.
  const testPubkey =
      'a1b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012';

  group('soundSyncRepositoryProvider', () {
    late SharedPreferences prefs;
    late SavedSoundsService savedSoundsService;

    setUp(() async {
      SavedSoundsService.resetLegacyMigrationClaimForTesting();
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      savedSoundsService = SavedSoundsService(prefs, pubkeyHex: testPubkey);
    });

    ProviderContainer createContainer({
      required NostrSessionReadiness readiness,
      FlutterSecureStorage? secureStorage,
    }) {
      return ProviderContainer(
        overrides: [
          nostrSessionProvider.overrideWith(
            () => _TestNostrSession(readiness),
          ),
          flutterSecureStorageProvider.overrideWithValue(
            secureStorage ?? _MockFlutterSecureStorage(),
          ),
          sharedPreferencesProvider.overrideWithValue(prefs),
          savedSoundsServiceProvider.overrideWithValue(savedSoundsService),
        ],
      );
    }

    test('resolves to null when signed out', () async {
      final container = createContainer(
        readiness: const NostrSessionReadiness.signedOut(),
      );
      addTearDown(container.dispose);

      final repository = await container.read(
        soundSyncRepositoryProvider.future,
      );

      expect(repository, isNull);
    });

    test(
      'resolves to null when identity is known but the client is not ready',
      () async {
        final container = createContainer(
          readiness: const NostrSessionReadiness.identityKnown(
            pubkey: testPubkey,
          ),
        );
        addTearDown(container.dispose);

        final repository = await container.read(
          soundSyncRepositoryProvider.future,
        );

        expect(repository, isNull);
      },
    );

    test('resolves to null when the vault key cannot be obtained', () async {
      final mockClient = _MockNostrClient();
      final mockSigner = _MockNostrSigner();
      when(() => mockClient.signer).thenReturn(mockSigner);
      when(() => mockClient.hasKeys).thenReturn(true);
      when(() => mockClient.publicKey).thenReturn(testPubkey);
      // No signed-in account from the signer's perspective — VaultKeyService
      // throws VaultKeyUnavailableException before ever touching the client.
      when(mockSigner.getPublicKey).thenAnswer((_) async => null);

      final container = createContainer(
        readiness: NostrSessionReadiness.nostrReady(
          pubkey: testPubkey,
          client: mockClient,
        ),
      );
      addTearDown(container.dispose);

      final repository = await container.read(
        soundSyncRepositoryProvider.future,
      );

      expect(repository, isNull);
    });

    test(
      'returns a repository once the client is ready and the vault key '
      'resolves from cache',
      () async {
        final mockClient = _MockNostrClient();
        final mockSigner = _MockNostrSigner();
        when(() => mockClient.signer).thenReturn(mockSigner);
        when(() => mockClient.hasKeys).thenReturn(true);
        when(() => mockClient.publicKey).thenReturn(testPubkey);
        when(mockSigner.getPublicKey).thenAnswer((_) async => testPubkey);

        // A cached vault key lets VaultKeyService.obtain() resolve without
        // any relay round trip — proves this test exercises the "ready"
        // path via the real, app-wired flutterSecureStorageProvider-backed
        // SecureVaultKeyCache rather than a hand-rolled fake.
        final secureStorage = _MockFlutterSecureStorage();
        final vaultKey = base64Encode(Uint8List(32));
        when(
          () => secureStorage.read(key: any(named: 'key')),
        ).thenAnswer((_) async => vaultKey);

        final container = createContainer(
          readiness: NostrSessionReadiness.nostrReady(
            pubkey: testPubkey,
            client: mockClient,
          ),
          secureStorage: secureStorage,
        );
        addTearDown(container.dispose);

        final repository = await container.read(
          soundSyncRepositoryProvider.future,
        );

        expect(repository, isA<SoundSyncRepository>());
      },
    );
  });
}
