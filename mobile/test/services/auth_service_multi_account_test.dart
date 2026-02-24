// ABOUTME: Tests for AuthService multi-account methods
// ABOUTME: Covers getKnownAccounts, _addToKnownAccounts (via signOut flow),
// signInForAccount, _archiveSignerInfo, _restoreSignerInfo, createAnonymousAccount

import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/models/known_account.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_setup.dart';

class _MockSecureKeyStorage extends Mock implements SecureKeyStorage {}

class _MockUserDataCleanupService extends Mock
    implements UserDataCleanupService {}

class _MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

// Test nsec from a known keypair (same one used in other auth_service tests)
const _testNsec =
    'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5';

/// Runs [body] while silencing unhandled async errors from `_performDiscovery`.
///
/// `_setupUserSession` fires `unawaited(_performDiscovery())` which creates a
/// `NostrClient` that tries to open a WebSocket. In the test environment this
/// throws asynchronously ("Unsupported operation: Mocked response") and the
/// test runner flags it as a test failure. Wrapping with `runZonedGuarded`
/// prevents that unhandled error from reaching the test zone.
Future<T> _ignoringDiscoveryErrors<T>(Future<T> Function() body) async {
  final completer = Completer<T>();
  runZonedGuarded(
    () async {
      try {
        final result = await body();
        completer.complete(result);
      } catch (e, st) {
        completer.completeError(e, st);
      }
    },
    (error, stack) {
      // Silently absorb async errors from unawaited _performDiscovery
    },
  );
  return completer.future;
}

void main() {
  setupTestEnvironment();

  late _MockSecureKeyStorage mockKeyStorage;
  late _MockUserDataCleanupService mockCleanupService;
  late _MockFlutterSecureStorage mockSecureStorage;
  late AuthService authService;
  late SecureKeyContainer testKeyContainer;

  setUpAll(() {
    registerFallbackValue(SecureKeyContainer.fromNsec(_testNsec));
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({kKnownAccountsKey: '[]'});
    mockKeyStorage = _MockSecureKeyStorage();
    mockCleanupService = _MockUserDataCleanupService();
    mockSecureStorage = _MockFlutterSecureStorage();
    testKeyContainer = SecureKeyContainer.fromNsec(_testNsec);

    // Default stubs
    when(() => mockKeyStorage.initialize()).thenAnswer((_) async {});
    when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => false);
    when(() => mockKeyStorage.clearCache()).thenReturn(null);
    when(() => mockKeyStorage.dispose()).thenReturn(null);
    when(() => mockKeyStorage.deleteKeys()).thenAnswer((_) async {});
    when(
      () => mockKeyStorage.generateAndStoreKeys(
        biometricPrompt: any(named: 'biometricPrompt'),
      ),
    ).thenAnswer((_) async => testKeyContainer);
    when(
      () => mockKeyStorage.storeIdentityKeyContainer(any(), any()),
    ).thenAnswer((_) async {});
    when(
      () => mockKeyStorage.getIdentityKeyContainer(
        any(),
        biometricPrompt: any(named: 'biometricPrompt'),
      ),
    ).thenAnswer((_) async => testKeyContainer);
    when(() => mockKeyStorage.getKeyContainer()).thenAnswer((_) async => null);

    when(
      () => mockCleanupService.shouldClearDataForUser(any()),
    ).thenReturn(false);
    when(
      () => mockCleanupService.clearUserSpecificData(
        reason: any(named: 'reason'),
        isIdentityChange: any(named: 'isIdentityChange'),
      ),
    ).thenAnswer((_) async => 0);

    // Default flutter secure storage stubs
    when(
      () => mockSecureStorage.read(key: any(named: 'key')),
    ).thenAnswer((_) async => null);
    when(
      () => mockSecureStorage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockSecureStorage.delete(key: any(named: 'key')),
    ).thenAnswer((_) async {});

    authService = AuthService(
      userDataCleanupService: mockCleanupService,
      keyStorage: mockKeyStorage,
      flutterSecureStorage: mockSecureStorage,
    );
  });

  tearDown(() async {
    await authService.dispose();
  });

  group('getKnownAccounts', () {
    test('returns empty list when key exists but is empty string', () async {
      SharedPreferences.setMockInitialValues({kKnownAccountsKey: ''});

      final accounts = await authService.getKnownAccounts();

      expect(accounts, isEmpty);
    });

    test('returns empty list when key exists with empty JSON array', () async {
      SharedPreferences.setMockInitialValues({
        kKnownAccountsKey: jsonEncode([]),
      });

      final accounts = await authService.getKnownAccounts();

      expect(accounts, isEmpty);
    });

    test('returns parsed accounts sorted by lastUsedAt descending', () async {
      final olderAccount = KnownAccount(
        pubkeyHex: 'a' * 64,
        authSource: AuthenticationSource.automatic,
        addedAt: DateTime(2024),
        lastUsedAt: DateTime(2024),
      );
      final newerAccount = KnownAccount(
        pubkeyHex: 'b' * 64,
        authSource: AuthenticationSource.divineOAuth,
        addedAt: DateTime(2025),
        lastUsedAt: DateTime(2025),
      );
      final json = jsonEncode([olderAccount.toJson(), newerAccount.toJson()]);
      SharedPreferences.setMockInitialValues({kKnownAccountsKey: json});

      final accounts = await authService.getKnownAccounts();

      expect(accounts, hasLength(2));
      // Newer account should be first (sorted by lastUsedAt descending)
      expect(accounts[0].pubkeyHex, equals('b' * 64));
      expect(accounts[1].pubkeyHex, equals('a' * 64));
    });

    test('returns empty list on malformed JSON', () async {
      SharedPreferences.setMockInitialValues({
        kKnownAccountsKey: 'not valid json',
      });

      final accounts = await authService.getKnownAccounts();

      expect(accounts, isEmpty);
    });

    test('preserves all KnownAccount fields', () async {
      final account = KnownAccount(
        pubkeyHex: 'c' * 64,
        authSource: AuthenticationSource.bunker,
        addedAt: DateTime(2024, 6, 15),
        lastUsedAt: DateTime(2025, 1, 20),
      );
      final json = jsonEncode([account.toJson()]);
      SharedPreferences.setMockInitialValues({kKnownAccountsKey: json});

      final accounts = await authService.getKnownAccounts();

      expect(accounts, hasLength(1));
      expect(accounts[0].pubkeyHex, equals('c' * 64));
      expect(accounts[0].authSource, equals(AuthenticationSource.bunker));
      expect(accounts[0].addedAt, equals(DateTime(2024, 6, 15)));
      expect(accounts[0].lastUsedAt, equals(DateTime(2025, 1, 20)));
    });
  });

  group('_migrateLegacyAccount', () {
    test('migrates automatic account from legacy auth source', () async {
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'automatic',
      });
      when(
        () => mockKeyStorage.getKeyContainer(),
      ).thenAnswer((_) async => testKeyContainer);

      final accounts = await authService.getKnownAccounts();

      expect(accounts, hasLength(1));
      expect(accounts[0].pubkeyHex, equals(testKeyContainer.publicKeyHex));
      expect(accounts[0].authSource, equals(AuthenticationSource.automatic));
    });

    test('migrates imported_keys account from legacy auth source', () async {
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'imported_keys',
      });
      when(
        () => mockKeyStorage.getKeyContainer(),
      ).thenAnswer((_) async => testKeyContainer);

      final accounts = await authService.getKnownAccounts();

      expect(accounts, hasLength(1));
      expect(accounts[0].authSource, equals(AuthenticationSource.importedKeys));
    });

    test('migrates amber account from legacy auth source', () async {
      final pubkeyHex = 'd' * 64;
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'amber',
      });
      when(
        () => mockSecureStorage.read(key: 'amber_pubkey'),
      ).thenAnswer((_) async => pubkeyHex);

      final accounts = await authService.getKnownAccounts();

      expect(accounts, hasLength(1));
      expect(accounts[0].pubkeyHex, equals(pubkeyHex));
      expect(accounts[0].authSource, equals(AuthenticationSource.amber));
    });

    test('migrates bunker account from legacy auth source', () async {
      final userPubkeyHex = 'e' * 64;
      final bunkerPubkeyHex = 'a' * 64;
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'bunker',
      });
      when(() => mockSecureStorage.read(key: 'bunker_info')).thenAnswer(
        (_) async =>
            'bunker://$bunkerPubkeyHex?relay=wss://relay.example.com'
            '&userPubkey=$userPubkeyHex',
      );

      final accounts = await authService.getKnownAccounts();

      expect(accounts, hasLength(1));
      expect(accounts[0].pubkeyHex, equals(userPubkeyHex));
      expect(accounts[0].authSource, equals(AuthenticationSource.bunker));
    });

    test('migrates divineOAuth account from legacy auth source', () async {
      final pubkeyHex = 'f' * 64;
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'divineOAuth',
      });
      final sessionJson = jsonEncode({
        'bunker_url': 'wss://keycast.example.com',
        'access_token': 'test_token',
        'scope': 'policy:full',
        'user_pubkey': pubkeyHex,
      });
      when(
        () => mockSecureStorage.read(key: 'keycast_session'),
      ).thenAnswer((_) async => sessionJson);

      final accounts = await authService.getKnownAccounts();

      expect(accounts, hasLength(1));
      expect(accounts[0].pubkeyHex, equals(pubkeyHex));
      expect(accounts[0].authSource, equals(AuthenticationSource.divineOAuth));
    });

    test(
      'returns empty list when legacy auth source is none and no keys',
      () async {
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'none',
        });

        final accounts = await authService.getKnownAccounts();

        expect(accounts, isEmpty);
      },
    );

    test('recovers automatic keys even when auth source is none', () async {
      SharedPreferences.setMockInitialValues({'authentication_source': 'none'});
      when(
        () => mockKeyStorage.getKeyContainer(),
      ).thenAnswer((_) async => testKeyContainer);

      final accounts = await authService.getKnownAccounts();

      expect(accounts, hasLength(1));
      expect(accounts[0].pubkeyHex, equals(testKeyContainer.publicKeyHex));
      expect(accounts[0].authSource, equals(AuthenticationSource.automatic));
    });

    test('returns empty list when no legacy auth source and no keys', () async {
      // No authentication_source key at all (fresh install)
      SharedPreferences.setMockInitialValues({});

      final accounts = await authService.getKnownAccounts();

      expect(accounts, isEmpty);
    });

    test('returns empty list when legacy keys cannot be loaded', () async {
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'automatic',
      });
      when(
        () => mockKeyStorage.getKeyContainer(),
      ).thenAnswer((_) async => null);

      final accounts = await authService.getKnownAccounts();

      expect(accounts, isEmpty);
    });

    test('recovers both auth-source account and automatic keys', () async {
      final oauthPubkeyHex = 'f' * 64;
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'divineOAuth',
      });
      final sessionJson = jsonEncode({
        'bunker_url': 'wss://keycast.example.com',
        'access_token': 'test_token',
        'scope': 'policy:full',
        'user_pubkey': oauthPubkeyHex,
      });
      when(
        () => mockSecureStorage.read(key: 'keycast_session'),
      ).thenAnswer((_) async => sessionJson);

      // Automatic keys from a previous anonymous session
      when(
        () => mockKeyStorage.getKeyContainer(),
      ).thenAnswer((_) async => testKeyContainer);

      final accounts = await authService.getKnownAccounts();

      expect(accounts, hasLength(2));
      expect(accounts.any((a) => a.pubkeyHex == oauthPubkeyHex), isTrue);
      expect(
        accounts.any((a) => a.pubkeyHex == testKeyContainer.publicKeyHex),
        isTrue,
      );
    });

    test(
      'does not duplicate when auth-source keys match automatic keys',
      () async {
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'automatic',
        });
        when(
          () => mockKeyStorage.getKeyContainer(),
        ).thenAnswer((_) async => testKeyContainer);

        final accounts = await authService.getKnownAccounts();

        // Same pubkey from both paths — should only appear once
        expect(accounts, hasLength(1));
      },
    );

    test('persists result so migration only runs once', () async {
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'automatic',
      });
      when(
        () => mockKeyStorage.getKeyContainer(),
      ).thenAnswer((_) async => testKeyContainer);

      // First call triggers migration
      await authService.getKnownAccounts();

      // Verify the key was persisted
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kKnownAccountsKey), isNotNull);
      expect(prefs.getString(kKnownAccountsKey), isNotEmpty);
    });

    test('does not re-migrate after all accounts are removed', () async {
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'automatic',
      });
      when(
        () => mockKeyStorage.getKeyContainer(),
      ).thenAnswer((_) async => testKeyContainer);

      // Migration runs and creates one account
      final migrated = await authService.getKnownAccounts();
      expect(migrated, hasLength(1));

      // Simulate removing the account (sets key to "[]")
      await authService.removeKnownAccount(testKeyContainer.publicKeyHex);

      // Subsequent call should NOT re-migrate
      final afterRemoval = await authService.getKnownAccounts();
      expect(afterRemoval, isEmpty);
    });

    test('handles error during key loading gracefully', () async {
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'automatic',
      });
      when(
        () => mockKeyStorage.getKeyContainer(),
      ).thenThrow(Exception('storage corrupted'));

      final accounts = await authService.getKnownAccounts();

      // Should return empty list, not throw
      expect(accounts, isEmpty);

      // Should still persist the result to seal the migration
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(kKnownAccountsKey), isNotNull);
    });
  });

  group('_addToKnownAccounts (via _setupUserSession)', () {
    test('adds account to known accounts after createNewIdentity', () async {
      await _ignoringDiscoveryErrors(authService.createNewIdentity);

      final accounts = await authService.getKnownAccounts();
      expect(accounts, hasLength(1));
      expect(accounts[0].pubkeyHex, equals(testKeyContainer.publicKeyHex));
      expect(accounts[0].authSource, equals(AuthenticationSource.automatic));
    });

    test('updates existing account instead of duplicating', () async {
      // Create identity twice with the same keys
      await _ignoringDiscoveryErrors(authService.createNewIdentity);
      await _ignoringDiscoveryErrors(authService.createNewIdentity);

      final accounts = await authService.getKnownAccounts();
      // Should have 1 account, not 2
      expect(accounts, hasLength(1));
      expect(accounts[0].pubkeyHex, equals(testKeyContainer.publicKeyHex));
    });

    test('updates lastUsedAt when re-adding existing account', () async {
      await _ignoringDiscoveryErrors(authService.createNewIdentity);
      final firstAccounts = await authService.getKnownAccounts();
      final firstUsedAt = firstAccounts[0].lastUsedAt;

      // Small delay to ensure timestamp changes
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await _ignoringDiscoveryErrors(authService.createNewIdentity);

      final secondAccounts = await authService.getKnownAccounts();
      expect(secondAccounts, hasLength(1));
      expect(
        secondAccounts[0].lastUsedAt.millisecondsSinceEpoch,
        greaterThanOrEqualTo(firstUsedAt.millisecondsSinceEpoch),
      );
    });
  });

  group('createAnonymousAccount', () {
    test('deletes existing keys before creating new identity', () async {
      await _ignoringDiscoveryErrors(authService.createAnonymousAccount);

      verify(() => mockKeyStorage.deleteKeys()).called(1);
      verify(
        () => mockKeyStorage.generateAndStoreKeys(
          biometricPrompt: any(named: 'biometricPrompt'),
        ),
      ).called(1);
    });

    test('accepts terms after creating identity', () async {
      await _ignoringDiscoveryErrors(authService.createAnonymousAccount);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('age_verified_16_plus'), isTrue);
      expect(prefs.getString('terms_accepted_at'), isNotNull);
    });

    test('sets auth state to authenticated', () async {
      await _ignoringDiscoveryErrors(authService.createAnonymousAccount);

      expect(authService.authState, equals(AuthState.authenticated));
    });

    test('throws when identity creation fails', () async {
      when(
        () => mockKeyStorage.generateAndStoreKeys(
          biometricPrompt: any(named: 'biometricPrompt'),
        ),
      ).thenThrow(Exception('key generation failed'));

      await expectLater(
        _ignoringDiscoveryErrors(authService.createAnonymousAccount),
        throwsA(isA<Exception>()),
      );
    });

    test('registers account in known accounts', () async {
      await _ignoringDiscoveryErrors(authService.createAnonymousAccount);

      final accounts = await authService.getKnownAccounts();
      expect(accounts, hasLength(1));
      expect(accounts[0].authSource, equals(AuthenticationSource.automatic));
    });
  });

  group('_archiveSignerInfo (via signOut)', () {
    setUp(() async {
      // Create an authenticated session first
      await _ignoringDiscoveryErrors(authService.createNewIdentity);
    });

    test('archives Amber info when present', () async {
      final pubkeyHex = testKeyContainer.publicKeyHex;

      // Set up Amber info to be found
      when(
        () => mockSecureStorage.read(key: 'amber_pubkey'),
      ).thenAnswer((_) async => pubkeyHex);
      when(
        () => mockSecureStorage.read(key: 'amber_package'),
      ).thenAnswer((_) async => 'com.example.amber');

      // Non-destructive sign-out triggers _archiveSignerInfo
      await authService.signOut();

      verify(
        () => mockSecureStorage.write(
          key: 'amber_pubkey_$pubkeyHex',
          value: pubkeyHex,
        ),
      ).called(1);
      verify(
        () => mockSecureStorage.write(
          key: 'amber_package_$pubkeyHex',
          value: 'com.example.amber',
        ),
      ).called(1);
    });

    test('archives bunker URL when present', () async {
      final pubkeyHex = testKeyContainer.publicKeyHex;

      when(
        () => mockSecureStorage.read(key: 'bunker_info'),
      ).thenAnswer((_) async => 'bunker://relay.example.com');

      await authService.signOut();

      verify(
        () => mockSecureStorage.write(
          key: 'bunker_info_$pubkeyHex',
          value: 'bunker://relay.example.com',
        ),
      ).called(1);
    });

    test('archives OAuth session when present', () async {
      final pubkeyHex = testKeyContainer.publicKeyHex;

      final sessionJson = jsonEncode({
        'bunker_url': 'wss://keycast.example.com',
        'access_token': 'test_token',
        'scope': 'policy:full',
      });
      when(
        () => mockSecureStorage.read(key: 'keycast_session'),
      ).thenAnswer((_) async => sessionJson);

      await authService.signOut();

      verify(
        () => mockSecureStorage.write(
          key: 'keycast_session_$pubkeyHex',
          value: any(named: 'value'),
        ),
      ).called(1);
    });

    test('skips archiving when no signer info present', () async {
      // All reads return null by default — no signer info to archive
      await authService.signOut();

      // Should not write any per-account archive keys
      verifyNever(
        () => mockSecureStorage.write(
          key: any(named: 'key', that: contains('amber_pubkey_')),
          value: any(named: 'value'),
        ),
      );
      verifyNever(
        () => mockSecureStorage.write(
          key: any(named: 'key', that: contains('bunker_info_')),
          value: any(named: 'value'),
        ),
      );
    });

    test('handles archiving errors gracefully', () async {
      when(
        () => mockSecureStorage.read(key: 'amber_pubkey'),
      ).thenThrow(Exception('storage failure'));

      // Should not throw
      await expectLater(authService.signOut(), completes);
    });
  });

  group('_restoreSignerInfo (via signInForAccount)', () {
    test('restores Amber info for amber auth source', () async {
      final pubkeyHex = testKeyContainer.publicKeyHex;

      // Set up archived Amber info
      when(
        () => mockSecureStorage.read(key: 'amber_pubkey_$pubkeyHex'),
      ).thenAnswer((_) async => pubkeyHex);
      when(
        () => mockSecureStorage.read(key: 'amber_package_$pubkeyHex'),
      ).thenAnswer((_) async => 'com.example.amber');

      // Set up the active Amber info read for _loadAmberInfo in
      // signInForAccount
      when(
        () => mockSecureStorage.read(key: 'amber_pubkey'),
      ).thenAnswer((_) async => pubkeyHex);
      when(
        () => mockSecureStorage.read(key: 'amber_package'),
      ).thenAnswer((_) async => 'com.example.amber');

      // signInForAccount for amber will call _reconnectAmber which requires
      // Android platform — it will throw on test platform, but we can verify
      // the restore happened
      try {
        await _ignoringDiscoveryErrors(
          () => authService.signInForAccount(
            pubkeyHex,
            AuthenticationSource.amber,
          ),
        );
      } catch (_) {
        // Expected: _reconnectAmber requires Android platform
      }

      // Verify restore wrote to active keys
      verify(
        () => mockSecureStorage.write(key: 'amber_pubkey', value: pubkeyHex),
      ).called(1);
      verify(
        () => mockSecureStorage.write(
          key: 'amber_package',
          value: 'com.example.amber',
        ),
      ).called(1);
    });

    test('restores bunker URL for bunker auth source', () async {
      final pubkeyHex = testKeyContainer.publicKeyHex;

      when(
        () => mockSecureStorage.read(key: 'bunker_info_$pubkeyHex'),
      ).thenAnswer((_) async => 'bunker://relay.example.com');

      try {
        await _ignoringDiscoveryErrors(
          () => authService.signInForAccount(
            pubkeyHex,
            AuthenticationSource.bunker,
          ),
        );
      } catch (_) {
        // Expected: _reconnectBunker requires network
      }

      verify(
        () => mockSecureStorage.write(
          key: 'bunker_info',
          value: 'bunker://relay.example.com',
        ),
      ).called(1);
    });

    test('restores OAuth session for divineOAuth auth source', () async {
      final pubkeyHex = testKeyContainer.publicKeyHex;

      final sessionJson = jsonEncode({
        'bunker_url': 'wss://keycast.example.com',
        'access_token': 'test_token',
        'scope': 'policy:full',
      });
      when(
        () => mockSecureStorage.read(key: 'keycast_session_$pubkeyHex'),
      ).thenAnswer((_) async => sessionJson);

      // After restore, signInForAccount loads the session via
      // KeycastSession.load — set it up
      when(
        () => mockSecureStorage.read(key: 'keycast_session'),
      ).thenAnswer((_) async => sessionJson);

      try {
        await _ignoringDiscoveryErrors(
          () => authService.signInForAccount(
            pubkeyHex,
            AuthenticationSource.divineOAuth,
          ),
        );
      } catch (_) {
        // Expected: signInWithDivineOAuth needs oauthClient
      }

      // Verify session was written to active session key
      verify(
        () => mockSecureStorage.write(
          key: 'keycast_session',
          value: any(named: 'value'),
        ),
      ).called(1);
    });

    test('sets auth source in SharedPreferences', () async {
      final pubkeyHex = testKeyContainer.publicKeyHex;

      // Use automatic source so signInForAccount follows the simple
      // importedKeys/automatic path
      await _ignoringDiscoveryErrors(
        () => authService.signInForAccount(
          pubkeyHex,
          AuthenticationSource.automatic,
        ),
      );

      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('authentication_source'),
        equals(AuthenticationSource.automatic.code),
      );
    });

    test('does no restore for automatic/importedKeys/none sources', () async {
      final pubkeyHex = testKeyContainer.publicKeyHex;

      await _ignoringDiscoveryErrors(
        () => authService.signInForAccount(
          pubkeyHex,
          AuthenticationSource.automatic,
        ),
      );

      // Should not read any per-account archive keys
      verifyNever(() => mockSecureStorage.read(key: 'amber_pubkey_$pubkeyHex'));
      verifyNever(() => mockSecureStorage.read(key: 'bunker_info_$pubkeyHex'));
      verifyNever(
        () => mockSecureStorage.read(key: 'keycast_session_$pubkeyHex'),
      );
    });
  });

  group('signInForAccount', () {
    test('signs in with automatic source using stored identity keys', () async {
      final pubkeyHex = testKeyContainer.publicKeyHex;

      await _ignoringDiscoveryErrors(
        () => authService.signInForAccount(
          pubkeyHex,
          AuthenticationSource.automatic,
        ),
      );

      expect(authService.authState, equals(AuthState.authenticated));
      expect(
        authService.currentPublicKeyHex,
        equals(testKeyContainer.publicKeyHex),
      );
    });

    test(
      'signs in with importedKeys source using stored identity keys',
      () async {
        final pubkeyHex = testKeyContainer.publicKeyHex;

        await _ignoringDiscoveryErrors(
          () => authService.signInForAccount(
            pubkeyHex,
            AuthenticationSource.importedKeys,
          ),
        );

        expect(authService.authState, equals(AuthState.authenticated));
      },
    );

    test(
      'falls back to _checkExistingAuth when identity keys not found',
      () async {
        final pubkeyHex = testKeyContainer.publicKeyHex;

        // Return null for identity key lookup
        when(
          () => mockKeyStorage.getIdentityKeyContainer(
            any(),
            biometricPrompt: any(named: 'biometricPrompt'),
          ),
        ).thenAnswer((_) async => null);

        await _ignoringDiscoveryErrors(
          () => authService.signInForAccount(
            pubkeyHex,
            AuthenticationSource.automatic,
          ),
        );

        // _checkExistingAuth with no keys calls createNewIdentity
        verify(() => mockKeyStorage.hasKeys()).called(1);
      },
    );

    test('throws for AuthenticationSource.none', () async {
      await expectLater(
        _ignoringDiscoveryErrors(
          () =>
              authService.signInForAccount('a' * 64, AuthenticationSource.none),
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Cannot sign in with auth source "none"'),
          ),
        ),
      );
    });

    test('throws when amber info not found for amber source', () async {
      final pubkeyHex = testKeyContainer.publicKeyHex;

      // No Amber info archived or active
      when(
        () => mockSecureStorage.read(key: 'amber_pubkey'),
      ).thenAnswer((_) async => null);

      await expectLater(
        _ignoringDiscoveryErrors(
          () => authService.signInForAccount(
            pubkeyHex,
            AuthenticationSource.amber,
          ),
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('No archived Amber info found'),
          ),
        ),
      );
    });

    test('throws when bunker info not found for bunker source', () async {
      final pubkeyHex = testKeyContainer.publicKeyHex;

      // No bunker info archived or active
      when(
        () => mockSecureStorage.read(key: 'bunker_info'),
      ).thenAnswer((_) async => null);

      await expectLater(
        _ignoringDiscoveryErrors(
          () => authService.signInForAccount(
            pubkeyHex,
            AuthenticationSource.bunker,
          ),
        ),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('No archived Bunker info found'),
          ),
        ),
      );
    });

    test(
      'throws when OAuth session not found for divineOAuth source',
      () async {
        final pubkeyHex = testKeyContainer.publicKeyHex;

        await expectLater(
          _ignoringDiscoveryErrors(
            () => authService.signInForAccount(
              pubkeyHex,
              AuthenticationSource.divineOAuth,
            ),
          ),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('No archived OAuth session found'),
            ),
          ),
        );
      },
    );

    test('adds account to known accounts after successful sign-in', () async {
      final pubkeyHex = testKeyContainer.publicKeyHex;

      await _ignoringDiscoveryErrors(
        () => authService.signInForAccount(
          pubkeyHex,
          AuthenticationSource.automatic,
        ),
      );

      final accounts = await authService.getKnownAccounts();
      expect(accounts, hasLength(1));
      expect(accounts[0].pubkeyHex, equals(pubkeyHex));
    });
  });

  group('round-trip: archive then restore', () {
    test('Amber info survives archive-then-restore cycle', () async {
      final pubkeyHex = testKeyContainer.publicKeyHex;

      // Use in-memory storage to track writes
      final storage = <String, String>{};

      when(() => mockSecureStorage.read(key: any(named: 'key'))).thenAnswer((
        invocation,
      ) async {
        final key = invocation.namedArguments[#key] as String;
        return storage[key];
      });
      when(
        () => mockSecureStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((invocation) async {
        final key = invocation.namedArguments[#key] as String;
        final value = invocation.namedArguments[#value] as String;
        storage[key] = value;
      });
      when(() => mockSecureStorage.delete(key: any(named: 'key'))).thenAnswer((
        invocation,
      ) async {
        final key = invocation.namedArguments[#key] as String;
        storage.remove(key);
      });

      // Set up active Amber info
      storage['amber_pubkey'] = pubkeyHex;
      storage['amber_package'] = 'com.example.amber';

      // Create an authenticated session
      await _ignoringDiscoveryErrors(authService.createNewIdentity);

      // Sign out (non-destructive) — archives signer info
      await authService.signOut();

      // Verify per-account archive keys exist
      expect(storage['amber_pubkey_$pubkeyHex'], equals(pubkeyHex));
      expect(storage['amber_package_$pubkeyHex'], equals('com.example.amber'));

      // Now clear the active keys (simulating fresh state)
      storage.remove('amber_pubkey');
      storage.remove('amber_package');

      // Restore signer info via signInForAccount
      try {
        await _ignoringDiscoveryErrors(
          () => authService.signInForAccount(
            pubkeyHex,
            AuthenticationSource.amber,
          ),
        );
      } catch (_) {
        // Expected: _reconnectAmber requires Android platform
      }

      // Active keys should be restored
      expect(storage['amber_pubkey'], equals(pubkeyHex));
      expect(storage['amber_package'], equals('com.example.amber'));
    });

    test('OAuth session survives archive-then-restore cycle', () async {
      final pubkeyHex = testKeyContainer.publicKeyHex;

      final storage = <String, String>{};

      when(() => mockSecureStorage.read(key: any(named: 'key'))).thenAnswer((
        invocation,
      ) async {
        final key = invocation.namedArguments[#key] as String;
        return storage[key];
      });
      when(
        () => mockSecureStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((invocation) async {
        final key = invocation.namedArguments[#key] as String;
        final value = invocation.namedArguments[#value] as String;
        storage[key] = value;
      });

      // Set up active OAuth session
      final sessionData = {
        'bunker_url': 'wss://keycast.example.com',
        'access_token': 'my_token',
        'scope': 'policy:full',
      };
      storage['keycast_session'] = jsonEncode(sessionData);

      // Create an authenticated session
      await _ignoringDiscoveryErrors(authService.createNewIdentity);

      // Sign out (non-destructive) — archives OAuth session
      await authService.signOut();

      // Verify per-account archive key exists
      expect(storage['keycast_session_$pubkeyHex'], isNotNull);

      // Clear the active session
      storage.remove('keycast_session');

      // Restore signer info
      try {
        await _ignoringDiscoveryErrors(
          () => authService.signInForAccount(
            pubkeyHex,
            AuthenticationSource.divineOAuth,
          ),
        );
      } catch (_) {
        // Expected: signInWithDivineOAuth needs oauthClient
      }

      // Active session should be restored
      expect(storage['keycast_session'], isNotNull);
      final restored =
          jsonDecode(storage['keycast_session']!) as Map<String, dynamic>;
      expect(restored['bunker_url'], equals('wss://keycast.example.com'));
      expect(restored['access_token'], equals('my_token'));
    });
  });
}
