// ABOUTME: Tests local-signing resolution inside signInWithDivineOAuth.
// ABOUTME: Pins that locally-stored nsec bypasses Keycast RPC for signing.

import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nostr_identity.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_setup.dart';

class _MockSecureKeyStorage extends Mock implements SecureKeyStorage {}

class _MockNostrKeyManager extends Mock implements NostrKeyManager {}

class _MockUserDataCleanupService extends Mock
    implements UserDataCleanupService {}

class _MockKeycastOAuth extends Mock implements KeycastOAuth {}

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

// Two distinct nsecs so we can exercise the pubkey-mismatch guard.
const _matchingNsec =
    'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5';
const _otherNsec =
    'nsec1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqsmhltgl';

Future<T> _ignoringDiscoveryErrors<T>(Future<T> Function() body) async {
  final completer = Completer<T>();
  runZonedGuarded(
    () async {
      try {
        completer.complete(await body());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    },
    (_, _) {
      // Absorb unawaited _performDiscovery errors.
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

  late SecureKeyContainer matchingContainer;
  late SecureKeyContainer otherContainer;
  late KeycastSession session;

  setUpAll(() {
    registerFallbackValue(SecureKeyContainer.fromNsec(_matchingNsec));
  });

  setUp(() {
    mockKeyStorage = _MockSecureKeyStorage();
    mockNostrKeyManager = _MockNostrKeyManager();
    mockCleanupService = _MockUserDataCleanupService();
    mockOAuthClient = _MockKeycastOAuth();
    fakeSecureStorage = _FakeFlutterSecureStorage();

    matchingContainer = SecureKeyContainer.fromNsec(_matchingNsec);
    otherContainer = SecureKeyContainer.fromNsec(_otherNsec);

    // A non-expired session whose userPubkey matches matchingContainer so
    // signInWithDivineOAuth never has to round-trip to Keycast for the pubkey.
    session = KeycastSession(
      bunkerUrl: 'https://keycast.example.com',
      accessToken: 'access_token',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      refreshToken: 'refresh_token',
      userPubkey: matchingContainer.publicKeyHex,
    );

    when(() => mockKeyStorage.initialize()).thenAnswer((_) async {});
    when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => false);
    when(() => mockKeyStorage.clearCache()).thenReturn(null);
    when(() => mockKeyStorage.dispose()).thenReturn(null);
    when(
      () => mockKeyStorage.getIdentityKeyContainer(
        any(),
        biometricPrompt: any(named: 'biometricPrompt'),
      ),
    ).thenAnswer((_) async => null);
    when(() => mockKeyStorage.getKeyContainer()).thenAnswer((_) async => null);
    when(
      () => mockKeyStorage.storeIdentityKeyContainer(any(), any()),
    ).thenAnswer((_) async {});

    when(() => mockNostrKeyManager.publicKey).thenReturn(null);
    when(() => mockNostrKeyManager.privateKey).thenReturn(null);

    when(
      () => mockCleanupService.shouldClearDataForUser(any()),
    ).thenReturn(false);
    when(
      () => mockCleanupService.clearUserSpecificData(
        reason: any(named: 'reason'),
        isIdentityChange: any(named: 'isIdentityChange'),
        userPubkey: any(named: 'userPubkey'),
        deleteUserData: any(named: 'deleteUserData'),
      ),
    ).thenAnswer((_) async => 0);
    when(
      () => mockCleanupService.claimLegacyRows(any()),
    ).thenAnswer((_) async {});

    when(() => mockOAuthClient.close()).thenReturn(null);

    SharedPreferences.setMockInitialValues({});
  });

  AuthService createAuthService() {
    return AuthService(
      userDataCleanupService: mockCleanupService,
      keyStorage: mockKeyStorage,
      nostrKeyManager: mockNostrKeyManager,
      flutterSecureStorage: fakeSecureStorage,
      oauthClient: mockOAuthClient,
      oauthConfig: const OAuthConfig(
        serverUrl: 'https://example.com',
        clientId: 'test',
        redirectUri: 'https://example.com/cb',
      ),
    );
  }

  tearDown(() async {
    await authService.dispose();
  });

  group('signInWithDivineOAuth local signing (issue #3066)', () {
    test(
      'uses locally-stored nsec when per-identity container matches session pubkey',
      () async {
        when(
          () => mockKeyStorage.getIdentityKeyContainer(
            matchingContainer.npub,
            biometricPrompt: any(named: 'biometricPrompt'),
          ),
        ).thenAnswer((_) async => matchingContainer);

        authService = createAuthService();

        await _ignoringDiscoveryErrors(
          () => authService.signInWithDivineOAuth(session),
        );

        final identity = authService.currentIdentity;
        expect(
          identity,
          isA<KeycastNostrIdentity>(),
          reason:
              'signInWithDivineOAuth must build a KeycastNostrIdentity when '
              'a Keycast signer is present.',
        );
        expect(
          identity!.pubkey,
          equals(matchingContainer.publicKeyHex),
          reason: 'Identity must carry the session pubkey.',
        );
        final keycast = identity as KeycastNostrIdentity;
        expect(
          keycast.canDecryptInIsolate,
          isTrue,
          reason:
              'When the local nsec is available, the KeycastNostrIdentity '
              'must attach a LocalKeySigner so signing stays local instead '
              'of routing through 200-500ms Keycast RPC calls.',
        );
      },
    );

    test(
      'falls back to primary key container when per-identity slot is empty',
      () async {
        when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => true);
        when(
          () => mockKeyStorage.getKeyContainer(),
        ).thenAnswer((_) async => matchingContainer);

        authService = createAuthService();

        await _ignoringDiscoveryErrors(
          () => authService.signInWithDivineOAuth(session),
        );

        final identity = authService.currentIdentity;
        expect(identity, isA<KeycastNostrIdentity>());
        expect(
          (identity! as KeycastNostrIdentity).canDecryptInIsolate,
          isTrue,
          reason: 'Primary container fallback must also enable local signing.',
        );
      },
    );

    test(
      'ignores local nsec when stored pubkey does not match session pubkey',
      () async {
        when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => true);
        when(
          () => mockKeyStorage.getKeyContainer(),
        ).thenAnswer((_) async => otherContainer);

        authService = createAuthService();

        await _ignoringDiscoveryErrors(
          () => authService.signInWithDivineOAuth(session),
        );

        final identity = authService.currentIdentity;
        expect(identity, isA<KeycastNostrIdentity>());
        expect(
          identity!.pubkey,
          equals(matchingContainer.publicKeyHex),
          reason: 'Pubkey must come from the session, not the stale local key.',
        );
        expect(
          (identity as KeycastNostrIdentity).canDecryptInIsolate,
          isFalse,
          reason:
              "Using another account's nsec would sign for the wrong "
              'identity; the lookup must reject pubkey mismatches and '
              'keep RPC-only signing.',
        );
      },
    );

    test(
      'prefers per-identity container over primary when both exist',
      () async {
        // Per-identity slot: matching nsec for this account.
        // Primary slot: a different account's nsec (e.g. last-used was another).
        when(
          () => mockKeyStorage.getIdentityKeyContainer(
            matchingContainer.npub,
            biometricPrompt: any(named: 'biometricPrompt'),
          ),
        ).thenAnswer((_) async => matchingContainer);
        when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => true);
        when(
          () => mockKeyStorage.getKeyContainer(),
        ).thenAnswer((_) async => otherContainer);

        authService = createAuthService();

        await _ignoringDiscoveryErrors(
          () => authService.signInWithDivineOAuth(session),
        );

        final identity = authService.currentIdentity;
        expect(identity, isA<KeycastNostrIdentity>());
        expect(
          (identity! as KeycastNostrIdentity).canDecryptInIsolate,
          isTrue,
          reason:
              'The per-identity slot is authoritative when present, even if '
              'the primary slot holds a different account.',
        );

        verify(
          () => mockKeyStorage.getIdentityKeyContainer(
            matchingContainer.npub,
            biometricPrompt: any(named: 'biometricPrompt'),
          ),
        ).called(1);
      },
    );

    test(
      'falls back to RPC-only signing when no local nsec is available',
      () async {
        // Defaults already return null for both getters.
        authService = createAuthService();

        await _ignoringDiscoveryErrors(
          () => authService.signInWithDivineOAuth(session),
        );

        final identity = authService.currentIdentity;
        expect(identity, isA<KeycastNostrIdentity>());
        expect(
          (identity! as KeycastNostrIdentity).canDecryptInIsolate,
          isFalse,
          reason:
              'Without a local nsec there is no private key for isolate-based '
              'decryption; KeycastNostrIdentity must go RPC-only.',
        );
      },
    );

    test(
      'key-storage lookup failures do not break sign-in — falls back to RPC',
      () async {
        when(
          () => mockKeyStorage.getIdentityKeyContainer(
            any(),
            biometricPrompt: any(named: 'biometricPrompt'),
          ),
        ).thenThrow(StateError('simulated keystore failure'));

        authService = createAuthService();

        // Must not throw.
        await _ignoringDiscoveryErrors(
          () => authService.signInWithDivineOAuth(session),
        );

        final identity = authService.currentIdentity;
        expect(identity, isA<KeycastNostrIdentity>());
        expect(
          (identity! as KeycastNostrIdentity).canDecryptInIsolate,
          isFalse,
        );
      },
    );
  });
}
