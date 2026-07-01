// ABOUTME: Unit tests for AuthService NIP-46 bunker:// connect flow and the
// ABOUTME: client-initiated nostrconnect:// session guards. No network needed.
//
// #4741 PR1 gap-fill: connectWithBunker (heavily uncovered) is driven through
// the injectable remoteSignerFactory with a mock NostrRemoteSigner, so no real
// relay round-trip happens. The nostrconnect:// happy path (initiateNostrConnect
// -> waitForNostrConnectResponse) connects to public relays via
// NostrConnectSession.start() and has no injection seam, so only its no-session
// guards are covered here — adding a session seam is a follow-up for the
// extraction.

// mocktail's `when(() => mock.method())` capture idiom must be a closure (it
// records the invocation inside the stubbing zone) and cannot be a tearoff.
// ignore_for_file: unnecessary_lambdas

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart'
    show NostrRemoteSigner, NostrRemoteSignerInfo, generatePrivateKey;
import 'package:openvine/models/known_account.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nostr_identity.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockUserDataCleanupService extends Mock
    implements UserDataCleanupService {}

class _MockNostrRemoteSigner extends Mock implements NostrRemoteSigner {}

/// Silences unhandled async errors from the fire-and-forget _performDiscovery().
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
    (_, _) {},
  );
  return completer.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService NIP-46 bunker connect', () {
    late _MockUserDataCleanupService mockCleanupService;
    late Map<String, String> secureStorage;

    setUp(() {
      mockCleanupService = _MockUserDataCleanupService();
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
      when(
        () => mockCleanupService.markOwnerScopedLegacyDataForUser(any()),
      ).thenAnswer((_) async {});

      secureStorage = {};
      const secureStorageChannel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(secureStorageChannel, (call) async {
            switch (call.method) {
              case 'read':
                return secureStorage[call.arguments['key'] as String?];
              case 'write':
                final key = call.arguments['key'] as String?;
                final value = call.arguments['value'] as String?;
                if (key != null && value != null) secureStorage[key] = value;
                return null;
              case 'delete':
                secureStorage.remove(call.arguments['key'] as String?);
                return null;
              case 'deleteAll':
                secureStorage.clear();
                return null;
              case 'readAll':
                return secureStorage;
              case 'containsKey':
                return secureStorage.containsKey(
                  call.arguments['key'] as String?,
                );
              case 'getCapabilities':
                return {'basicSecureStorage': true};
              default:
                return null;
            }
          });

      const capabilityChannel = MethodChannel('openvine.secure_storage');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(capabilityChannel, (call) async {
            if (call.method == 'getCapabilities') {
              return {
                'hasHardwareSecurity': false,
                'hasBiometrics': false,
                'hasKeychain': true,
              };
            }
            return null;
          });

      SharedPreferences.setMockInitialValues({kKnownAccountsKey: '[]'});
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        ..setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        )
        ..setMockMethodCallHandler(
          const MethodChannel('openvine.secure_storage'),
          null,
        );
    });

    String freshPubkey() =>
        SecureKeyContainer.fromPrivateKeyHex(generatePrivateKey()).publicKeyHex;

    AuthService createAuthService(RemoteSignerFactory factory) {
      return AuthService(
        userDataCleanupService: mockCleanupService,
        keyStorage: SecureKeyStorage(
          securityConfig: const SecurityConfig(requireHardwareBacked: false),
        ),
        flutterSecureStorage: const FlutterSecureStorage(),
        remoteSignerFactory: factory,
      );
    }

    String bunkerUrlFor(String remoteSignerPubkey) =>
        'bunker://$remoteSignerPubkey'
        '?relay=wss%3A%2F%2Frelay.example.com&secret=testsecret';

    group('connectWithBunker', () {
      test('connects and sets a BunkerNostrIdentity on success', () async {
        final remoteSignerPubkey = freshPubkey();
        final userPubkey = freshPubkey();
        final url = bunkerUrlFor(remoteSignerPubkey);

        final signer = _MockNostrRemoteSigner();
        when(
          () => signer.info,
        ).thenReturn(NostrRemoteSignerInfo.parseBunkerUrl(url));
        when(() => signer.connect()).thenAnswer((_) async => 'ack');
        when(() => signer.pullPubkey()).thenAnswer((_) async => userPubkey);

        final authService = createAuthService((_, _) => signer);
        addTearDown(authService.dispose);

        final result = await _ignoringDiscoveryErrors(
          () => authService.connectWithBunker(url),
        );

        expect(result.success, isTrue);
        expect(
          authService.authenticationSource,
          equals(AuthenticationSource.bunker),
        );
        expect(authService.currentIdentity, isA<BunkerNostrIdentity>());
        expect(authService.currentPublicKeyHex, equals(userPubkey));
      });

      test('fails when the bunker returns no public key', () async {
        final url = bunkerUrlFor(freshPubkey());

        final signer = _MockNostrRemoteSigner();
        when(
          () => signer.info,
        ).thenReturn(NostrRemoteSignerInfo.parseBunkerUrl(url));
        when(() => signer.connect()).thenAnswer((_) async => 'ack');
        when(() => signer.pullPubkey()).thenAnswer((_) async => null);

        final authService = createAuthService((_, _) => signer);
        addTearDown(authService.dispose);

        final result = await authService.connectWithBunker(url);

        expect(result.success, isFalse);
        expect(result.errorMessage, contains('Failed to get public key'));
        expect(authService.isAuthenticated, isFalse);
      });

      test('fails on an invalid bunker URL', () async {
        var factoryCalled = false;
        final authService = createAuthService((_, _) {
          factoryCalled = true;
          return _MockNostrRemoteSigner();
        });
        addTearDown(authService.dispose);

        final result = await authService.connectWithBunker('not-a-bunker-url');

        expect(result.success, isFalse);
        expect(authService.isAuthenticated, isFalse);
        expect(factoryCalled, isFalse);
      });
    });

    group('nostrconnect:// guards', () {
      test(
        'waitForNostrConnectResponse fails with no active session',
        () async {
          final authService = createAuthService(
            (_, _) => _MockNostrRemoteSigner(),
          );
          addTearDown(authService.dispose);

          final result = await authService.waitForNostrConnectResponse();

          expect(result.success, isFalse);
          expect(
            result.errorMessage,
            contains('No active nostrconnect session'),
          );
        },
      );

      test('exposes null nostrconnect state before any session', () {
        final authService = createAuthService(
          (_, _) => _MockNostrRemoteSigner(),
        );
        addTearDown(authService.dispose);

        expect(authService.nostrConnectUrl, isNull);
        expect(authService.nostrConnectState, isNull);
        // Cancelling with no active session is a safe no-op.
        expect(authService.cancelNostrConnect, returnsNormally);
      });
    });
  });
}
