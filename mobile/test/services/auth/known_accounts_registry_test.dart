// ABOUTME: Tests for KnownAccountsRegistry — known-accounts CRUD, the one-time
// ABOUTME: legacy migration, persist, and the restorable-account filter.

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart'
    show SecureKeyContainer, SecureKeyStorage;
import 'package:nostr_sdk/nostr_sdk.dart' show NostrRemoteSignerInfo;
import 'package:openvine/models/authentication_source.dart';
import 'package:openvine/models/known_account.dart';
import 'package:openvine/services/auth/known_accounts_registry.dart';
import 'package:openvine/services/auth/signer_secure_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockSecureKeyStorage extends Mock implements SecureKeyStorage {}

class _MockSignerSecureStore extends Mock implements SignerSecureStore {}

class _MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

// Test nsec from a known keypair (same one used in other auth_service tests).
const _testNsec =
    'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5';

String _accountsJson(List<KnownAccount> accounts) =>
    jsonEncode(accounts.map((a) => a.toJson()).toList());

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(KnownAccountsRegistry, () {
    late _MockSecureKeyStorage keyStorage;
    late _MockSignerSecureStore signerStore;
    late _MockFlutterSecureStorage secureStorage;
    late SecureKeyContainer testKeyContainer;

    setUpAll(() {
      registerFallbackValue(AuthenticationSource.automatic);
    });

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      keyStorage = _MockSecureKeyStorage();
      signerStore = _MockSignerSecureStore();
      secureStorage = _MockFlutterSecureStorage();
      testKeyContainer = SecureKeyContainer.fromNsec(_testNsec);

      when(() => keyStorage.hasKeys()).thenAnswer((_) async => false);
      when(() => keyStorage.getKeyContainer()).thenAnswer((_) async => null);
      when(
        () => keyStorage.getIdentityKeyContainer(any()),
      ).thenAnswer((_) async => null);
      when(() => signerStore.loadAmber()).thenAnswer((_) async => null);
      when(() => signerStore.loadBunker()).thenAnswer((_) async => null);
      when(
        () => signerStore.hasArchive(any(), any()),
      ).thenAnswer((_) async => false);
      when(
        () => secureStorage.read(key: any(named: 'key')),
      ).thenAnswer((_) async => null);
    });

    KnownAccountsRegistry build() => KnownAccountsRegistry(
      keyStorage: keyStorage,
      signerStore: signerStore,
      flutterSecureStorage: secureStorage,
    );

    KnownAccount account(
      String pubkeyHex,
      AuthenticationSource source, {
      DateTime? addedAt,
      DateTime? lastUsedAt,
    }) {
      final now = addedAt ?? DateTime(2024);
      return KnownAccount(
        pubkeyHex: pubkeyHex,
        authSource: source,
        addedAt: now,
        lastUsedAt: lastUsedAt ?? now,
      );
    }

    group('getKnownAccounts', () {
      test(
        'returns empty list for a sealed-empty key (no migration)',
        () async {
          SharedPreferences.setMockInitialValues({kKnownAccountsKey: ''});

          final accounts = await build().getKnownAccounts();

          expect(accounts, isEmpty);
          // The empty (not null) key must NOT re-trigger legacy migration.
          verifyNever(() => keyStorage.getKeyContainer());
        },
      );

      test('returns stored accounts sorted by lastUsedAt descending', () async {
        final older = account(
          'a' * 64,
          AuthenticationSource.automatic,
          lastUsedAt: DateTime(2024),
        );
        final newer = account(
          'b' * 64,
          AuthenticationSource.bunker,
          lastUsedAt: DateTime(2024, 6),
        );
        SharedPreferences.setMockInitialValues({
          kKnownAccountsKey: _accountsJson([older, newer]),
        });

        final accounts = await build().getKnownAccounts();

        expect(accounts.map((a) => a.pubkeyHex), ['b' * 64, 'a' * 64]);
      });

      test('returns empty list on malformed JSON', () async {
        SharedPreferences.setMockInitialValues({
          kKnownAccountsKey: 'not-valid-json',
        });

        final accounts = await build().getKnownAccounts();

        expect(accounts, isEmpty);
      });
    });

    group('legacy migration (via null key)', () {
      test(
        'source=none with no keys returns empty and seals the key',
        () async {
          SharedPreferences.setMockInitialValues({
            'authentication_source': 'none',
          });

          final accounts = await build().getKnownAccounts();

          expect(accounts, isEmpty);
          final prefs = await SharedPreferences.getInstance();
          expect(prefs.getString(kKnownAccountsKey), '[]');
        },
      );

      test('recovers automatic keys even when source=none', () async {
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'none',
        });
        when(
          () => keyStorage.getKeyContainer(),
        ).thenAnswer((_) async => testKeyContainer);

        final accounts = await build().getKnownAccounts();

        expect(accounts, hasLength(1));
        expect(accounts[0].pubkeyHex, testKeyContainer.publicKeyHex);
        expect(accounts[0].authSource, AuthenticationSource.automatic);
      });

      test('migrates an automatic account from the legacy source', () async {
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'automatic',
        });
        when(
          () => keyStorage.getKeyContainer(),
        ).thenAnswer((_) async => testKeyContainer);

        final accounts = await build().getKnownAccounts();

        expect(accounts, hasLength(1));
        expect(accounts[0].authSource, AuthenticationSource.automatic);
      });

      test('migrates an amber account from the legacy source', () async {
        final amberPubkey = 'd' * 64;
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'amber',
        });
        when(
          () => signerStore.loadAmber(),
        ).thenAnswer((_) async => (pubkey: amberPubkey, package: null));

        final accounts = await build().getKnownAccounts();

        expect(accounts, hasLength(1));
        expect(accounts[0].pubkeyHex, amberPubkey);
        expect(accounts[0].authSource, AuthenticationSource.amber);
      });

      test('migrates a bunker account from the legacy source', () async {
        final userPubkey = 'e' * 64;
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'bunker',
        });
        when(() => signerStore.loadBunker()).thenAnswer(
          (_) async => NostrRemoteSignerInfo(
            remoteSignerPubkey: 'a' * 64,
            relays: const ['wss://relay.example.com'],
            userPubkey: userPubkey,
          ),
        );

        final accounts = await build().getKnownAccounts();

        expect(accounts, hasLength(1));
        expect(accounts[0].pubkeyHex, userPubkey);
        expect(accounts[0].authSource, AuthenticationSource.bunker);
      });

      test('migrates a divineOAuth account from the legacy source', () async {
        final oauthPubkey = 'f' * 64;
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'divineOAuth',
        });
        when(() => secureStorage.read(key: 'keycast_session')).thenAnswer(
          (_) async => jsonEncode({
            'bunker_url': 'wss://keycast.example.com',
            'access_token': 'test_token',
            'scope': 'policy:full',
            'user_pubkey': oauthPubkey,
          }),
        );

        final accounts = await build().getKnownAccounts();

        expect(accounts, hasLength(1));
        expect(accounts[0].pubkeyHex, oauthPubkey);
        expect(accounts[0].authSource, AuthenticationSource.divineOAuth);
      });

      test('recovers both the source account and automatic keys', () async {
        final oauthPubkey = 'f' * 64;
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'divineOAuth',
        });
        when(() => secureStorage.read(key: 'keycast_session')).thenAnswer(
          (_) async => jsonEncode({
            'bunker_url': 'wss://keycast.example.com',
            'access_token': 'test_token',
            'scope': 'policy:full',
            'user_pubkey': oauthPubkey,
          }),
        );
        when(
          () => keyStorage.getKeyContainer(),
        ).thenAnswer((_) async => testKeyContainer);

        final accounts = await build().getKnownAccounts();

        expect(accounts, hasLength(2));
        expect(accounts.any((a) => a.pubkeyHex == oauthPubkey), isTrue);
        expect(
          accounts.any((a) => a.pubkeyHex == testKeyContainer.publicKeyHex),
          isTrue,
        );
      });

      test(
        'does not duplicate when source keys match automatic keys',
        () async {
          SharedPreferences.setMockInitialValues({
            'authentication_source': 'automatic',
          });
          when(
            () => keyStorage.getKeyContainer(),
          ).thenAnswer((_) async => testKeyContainer);

          final accounts = await build().getKnownAccounts();

          expect(accounts, hasLength(1));
        },
      );

      test('persists the result so migration only runs once', () async {
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'automatic',
        });
        when(
          () => keyStorage.getKeyContainer(),
        ).thenAnswer((_) async => testKeyContainer);
        final registry = build();

        await registry.getKnownAccounts();
        await registry.getKnownAccounts();

        // getKeyContainer is only reached inside the migration; the sealed key
        // means the second read never re-migrates.
        verify(() => keyStorage.getKeyContainer()).called(1);
      });

      test('swallows key-loading errors and still seals the key', () async {
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'automatic',
        });
        when(
          () => keyStorage.getKeyContainer(),
        ).thenThrow(Exception('storage corrupted'));

        final accounts = await build().getKnownAccounts();

        expect(accounts, isEmpty);
        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(kKnownAccountsKey), isNotNull);
      });
    });

    group('upsert', () {
      test('inserts a new account', () async {
        SharedPreferences.setMockInitialValues({kKnownAccountsKey: '[]'});
        final registry = build();

        await registry.upsert('a' * 64, AuthenticationSource.bunker);

        final accounts = await registry.getKnownAccounts();
        expect(accounts, hasLength(1));
        expect(accounts[0].pubkeyHex, 'a' * 64);
        expect(accounts[0].authSource, AuthenticationSource.bunker);
      });

      test('updates an existing account, preserving addedAt', () async {
        final existing = account(
          'a' * 64,
          AuthenticationSource.automatic,
          addedAt: DateTime(2023),
          lastUsedAt: DateTime(2023),
        );
        SharedPreferences.setMockInitialValues({
          kKnownAccountsKey: _accountsJson([existing]),
        });
        final registry = build();

        await registry.upsert('a' * 64, AuthenticationSource.bunker);

        final accounts = await registry.getKnownAccounts();
        expect(accounts, hasLength(1));
        expect(accounts[0].addedAt, DateTime(2023));
        expect(accounts[0].authSource, AuthenticationSource.bunker);
        expect(accounts[0].lastUsedAt.isAfter(DateTime(2023)), isTrue);
      });
    });

    group('remove', () {
      test('removes the matching account', () async {
        final keep = account('a' * 64, AuthenticationSource.automatic);
        final drop = account('b' * 64, AuthenticationSource.bunker);
        SharedPreferences.setMockInitialValues({
          kKnownAccountsKey: _accountsJson([keep, drop]),
        });
        final registry = build();

        await registry.remove('b' * 64);

        final accounts = await registry.getKnownAccounts();
        expect(accounts.map((a) => a.pubkeyHex), ['a' * 64]);
      });

      test('is a no-op for an unknown pubkey', () async {
        final keep = account('a' * 64, AuthenticationSource.automatic);
        SharedPreferences.setMockInitialValues({
          kKnownAccountsKey: _accountsJson([keep]),
        });
        final registry = build();

        await registry.remove('c' * 64);

        final accounts = await registry.getKnownAccounts();
        expect(accounts.map((a) => a.pubkeyHex), ['a' * 64]);
      });
    });

    group('persist', () {
      test('overwrites the stored registry with the given list', () async {
        final a = account('a' * 64, AuthenticationSource.automatic);
        final b = account('b' * 64, AuthenticationSource.bunker);
        SharedPreferences.setMockInitialValues({
          kKnownAccountsKey: _accountsJson([a, b]),
        });
        final registry = build();

        await registry.persist([a]);

        final accounts = await registry.getKnownAccounts();
        expect(accounts.map((a) => a.pubkeyHex), ['a' * 64]);
      });

      test('persisting an empty list writes "[]"', () async {
        final a = account('a' * 64, AuthenticationSource.automatic);
        SharedPreferences.setMockInitialValues({
          kKnownAccountsKey: _accountsJson([a]),
        });

        await build().persist(const <KnownAccount>[]);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString(kKnownAccountsKey), '[]');
      });
    });

    group('restorableAccounts', () {
      test('keeps an automatic account with a matching identity key', () async {
        final acc = account(
          testKeyContainer.publicKeyHex,
          AuthenticationSource.automatic,
        );
        when(
          () => keyStorage.getIdentityKeyContainer(any()),
        ).thenAnswer((_) async => testKeyContainer);

        final restorable = await build().restorableAccounts([acc]);

        expect(restorable, [acc]);
      });

      test('keeps an automatic account with a matching primary key', () async {
        final acc = account(
          testKeyContainer.publicKeyHex,
          AuthenticationSource.importedKeys,
        );
        when(() => keyStorage.hasKeys()).thenAnswer((_) async => true);
        when(
          () => keyStorage.getKeyContainer(),
        ).thenAnswer((_) async => testKeyContainer);

        final restorable = await build().restorableAccounts([acc]);

        expect(restorable, [acc]);
      });

      test('drops an automatic account with no local key material', () async {
        final acc = account('a' * 64, AuthenticationSource.automatic);

        final restorable = await build().restorableAccounts([acc]);

        expect(restorable, isEmpty);
      });

      test('keeps a remote-signer account when an archive exists', () async {
        final acc = account('a' * 64, AuthenticationSource.bunker);
        when(
          () => signerStore.hasArchive('a' * 64, AuthenticationSource.bunker),
        ).thenAnswer((_) async => true);

        final restorable = await build().restorableAccounts([acc]);

        expect(restorable, [acc]);
      });

      test('drops a remote-signer account with no archive', () async {
        final acc = account('a' * 64, AuthenticationSource.divineOAuth);

        final restorable = await build().restorableAccounts([acc]);

        expect(restorable, isEmpty);
      });

      test('always drops none and nip07 accounts', () async {
        final none = account('a' * 64, AuthenticationSource.none);
        final nip07 = account('b' * 64, AuthenticationSource.nip07);

        final restorable = await build().restorableAccounts([none, nip07]);

        expect(restorable, isEmpty);
      });

      test('treats a local-key verification error as not restorable', () async {
        final acc = account('a' * 64, AuthenticationSource.automatic);
        when(
          () => keyStorage.getIdentityKeyContainer(any()),
        ).thenThrow(Exception('keychain unavailable'));

        final restorable = await build().restorableAccounts([acc]);

        expect(restorable, isEmpty);
      });
    });
  });
}
