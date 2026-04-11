// ABOUTME: Tests OAuth account recovery after destructive sign-out
// ABOUTME: Verifies keycast session, refresh token, and auth handle restoration

import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/models/known_account.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_setup.dart';

class _MockSecureKeyStorage extends Mock implements SecureKeyStorage {}

class _MockNostrKeyManager extends Mock implements NostrKeyManager {}

class _MockUserDataCleanupService extends Mock
    implements UserDataCleanupService {}

class _MockKeycastOAuth extends Mock implements KeycastOAuth {}

/// In-memory [FlutterSecureStorage] implementation so that writes persist
/// and reads return previously written values — matching production
/// behaviour without platform channels.
class _FakeFlutterSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> data = {};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => data[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) {
      data[key] = value;
    } else {
      data.remove(key);
    }
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    data.remove(key);
  }
}

// Test nsec from a known keypair (same one used in other auth_service tests)
const _testNsec =
    'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5';

/// Runs [body] while silencing unhandled async errors from `_performDiscovery`.
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
  late _MockNostrKeyManager mockNostrKeyManager;
  late _MockUserDataCleanupService mockCleanupService;
  late _MockKeycastOAuth mockOAuthClient;
  late _FakeFlutterSecureStorage fakeSecureStorage;
  late AuthService authService;
  late SecureKeyContainer testKeyContainer;

  // Account A (the one that should survive deletion of B)
  late SecureKeyContainer accountA;
  late KeycastSession sessionA;

  setUpAll(() {
    registerFallbackValue(SecureKeyContainer.fromNsec(_testNsec));
  });

  setUp(() {
    mockKeyStorage = _MockSecureKeyStorage();
    mockNostrKeyManager = _MockNostrKeyManager();
    mockCleanupService = _MockUserDataCleanupService();
    mockOAuthClient = _MockKeycastOAuth();
    fakeSecureStorage = _FakeFlutterSecureStorage();
    testKeyContainer = SecureKeyContainer.fromNsec(_testNsec);

    accountA = SecureKeyContainer.fromNsec(
      'nsec1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqsmhltgl',
    );
    sessionA = KeycastSession(
      bunkerUrl: 'https://keycast.example.com',
      accessToken: 'access_token_A',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      refreshToken: 'refresh_token_A',
      authorizationHandle: 'auth_handle_A',
      userPubkey: accountA.publicKeyHex,
    );

    // Default key storage stubs
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
    ).thenAnswer((_) async => null);
    when(() => mockKeyStorage.getKeyContainer()).thenAnswer((_) async => null);
    when(
      () => mockKeyStorage.switchToIdentity(
        any(),
        biometricPrompt: any(named: 'biometricPrompt'),
      ),
    ).thenAnswer((_) async => true);
    when(() => mockNostrKeyManager.publicKey).thenReturn(null);
    when(() => mockNostrKeyManager.privateKey).thenReturn(null);

    when(
      () => mockCleanupService.shouldClearDataForUser(any()),
    ).thenReturn(false);
    when(
      () => mockCleanupService.clearUserSpecificData(
        reason: any(named: 'reason'),
        isIdentityChange: any(named: 'isIdentityChange'),
      ),
    ).thenAnswer((_) async => 0);

    // Mock OAuth client: logout clears the same keys that the real
    // KeycastOAuth.logout() would clear via SecureKeycastStorage.
    when(() => mockOAuthClient.logout()).thenAnswer((_) async {
      fakeSecureStorage.data.remove('keycast_session');
      fakeSecureStorage.data.remove('keycast_refresh_token');
      fakeSecureStorage.data.remove('keycast_auth_handle');
    });
    when(() => mockOAuthClient.close()).thenReturn(null);
  });

  AuthService createAuthService() {
    return AuthService(
      userDataCleanupService: mockCleanupService,
      keyStorage: mockKeyStorage,
      nostrKeyManager: mockNostrKeyManager,
      flutterSecureStorage: fakeSecureStorage,
      oauthClient: mockOAuthClient,
    );
  }

  tearDown(() async {
    await authService.dispose();
  });

  group('OAuth account recovery after destructive sign-out', () {
    setUp(() {
      // Archive A's OAuth session in fake secure storage
      fakeSecureStorage.data['keycast_session_${accountA.publicKeyHex}'] =
          jsonEncode(sessionA.toJson());

      // Known accounts: A (divineOAuth) + B (automatic, most recent)
      final knownAccounts = jsonEncode([
        KnownAccount(
          pubkeyHex: accountA.publicKeyHex,
          authSource: AuthenticationSource.divineOAuth,
          addedAt: DateTime.now().subtract(const Duration(hours: 2)),
          lastUsedAt: DateTime.now().subtract(const Duration(hours: 1)),
        ).toJson(),
        KnownAccount(
          pubkeyHex: testKeyContainer.publicKeyHex,
          authSource: AuthenticationSource.automatic,
          addedAt: DateTime.now().subtract(const Duration(hours: 1)),
          lastUsedAt: DateTime.now(),
        ).toJson(),
      ]);

      SharedPreferences.setMockInitialValues({
        'authentication_source': 'automatic',
        'last_used_npub': testKeyContainer.npub,
        kKnownAccountsKey: knownAccounts,
      });

      authService = createAuthService();
    });

    test('restores session, refresh token, and auth handle for remaining '
        'OAuth account', () async {
      // Sign in as B (local keys)
      await _ignoringDiscoveryErrors(authService.createNewIdentity);
      expect(authService.isAuthenticated, isTrue);

      // Delete B (destructive sign-out)
      await authService.signOut(deleteKeys: true);

      // Verify recovery prefs point to A
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('last_used_npub'), equals(accountA.npub));
      expect(
        prefs.getString('authentication_source'),
        equals('divineOAuth'),
      );

      // Verify A's OAuth session was restored to the active slot
      final restoredSessionJson = fakeSecureStorage.data['keycast_session'];
      expect(restoredSessionJson, isNotNull);
      final restoredSession = KeycastSession.fromJson(
        jsonDecode(restoredSessionJson!) as Map<String, dynamic>,
      );
      expect(restoredSession.userPubkey, equals(accountA.publicKeyHex));
      expect(restoredSession.accessToken, equals('access_token_A'));

      // Verify standalone refresh token was restored (the key fix)
      expect(
        fakeSecureStorage.data['keycast_refresh_token'],
        equals('refresh_token_A'),
      );

      // Verify standalone auth handle was restored
      expect(
        fakeSecureStorage.data['keycast_auth_handle'],
        equals('auth_handle_A'),
      );
    });

    test(
      'initialize with expired restored session attempts OAuth refresh',
      () async {
        // Sign in as B
        await _ignoringDiscoveryErrors(authService.createNewIdentity);
        expect(authService.isAuthenticated, isTrue);

        // Delete B
        await authService.signOut(deleteKeys: true);
        await authService.dispose();

        // Tamper the restored session to be expired — simulates the 15s
        // TTL in the local Docker stack where sessions always expire
        // between archive and restore.
        final sessionJson = fakeSecureStorage.data['keycast_session'];
        expect(sessionJson, isNotNull);
        final sessionMap = jsonDecode(sessionJson!) as Map<String, dynamic>;
        sessionMap['expires_at'] = DateTime.now()
            .subtract(const Duration(seconds: 1))
            .toIso8601String();
        fakeSecureStorage.data['keycast_session'] = jsonEncode(sessionMap);

        // Mock refresh: return a valid session with A's pubkey
        final refreshedSession = KeycastSession(
          bunkerUrl: 'https://keycast.example.com',
          accessToken: 'refreshed_access_token_A',
          expiresAt: DateTime.now().add(const Duration(hours: 1)),
          refreshToken: 'new_refresh_token_A',
          userPubkey: accountA.publicKeyHex,
        );
        when(() => mockOAuthClient.refreshSession()).thenAnswer(
          (_) async => refreshedSession,
        );

        // Create fresh AuthService (simulates app restart)
        authService = createAuthService();
        await _ignoringDiscoveryErrors(authService.initialize);

        // The refresh was attempted — signInWithDivineOAuth is called
        // with the refreshed session. It fails due to HTTP (no server
        // in unit tests), but we can verify refresh was called.
        verify(() => mockOAuthClient.refreshSession()).called(1);
      },
    );

    test(
      'initialize with valid restored session reaches signInWithDivineOAuth',
      () async {
        // Sign in as B
        await _ignoringDiscoveryErrors(authService.createNewIdentity);
        expect(authService.isAuthenticated, isTrue);

        // Delete B
        await authService.signOut(deleteKeys: true);
        await authService.dispose();

        // Verify the restored session has RPC access (not expired)
        final sessionJson = fakeSecureStorage.data['keycast_session'];
        expect(sessionJson, isNotNull);
        final restored = KeycastSession.fromJson(
          jsonDecode(sessionJson!) as Map<String, dynamic>,
        );
        expect(restored.hasRpcAccess, isTrue);

        // Collect auth state transitions during initialize
        authService = createAuthService();
        final states = <AuthState>[];
        final sub = authService.authStateStream.listen(states.add);

        await _ignoringDiscoveryErrors(authService.initialize);
        await sub.cancel();

        // Should have reached 'authenticating' (signInWithDivineOAuth sets
        // it) even though it ultimately fails due to HTTP in unit tests.
        expect(states, contains(AuthState.authenticating));
      },
    );
  });
}
