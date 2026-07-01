// ABOUTME: Unit tests for AuthService NIP-55 Amber (Android signer) sign-in and
// ABOUTME: session-restore flows. Runs on CI without an emulator via channel mocks.
//
// Covers the previously-uncovered Amber concern (#4741 PR1 gap-fill): the
// connectWithAmber platform/availability guards and the _reconnectAmber restore
// path reached through initialize(). The Amber signer talks to the native
// `nostrmoPlugin` MethodChannel, which is stubbed here; AndroidNostrSigner is
// constructed with a known pubkey on the restore path, so no intent round-trip
// is needed.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show generatePrivateKey;
import 'package:openvine/models/known_account.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nostr_identity.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockUserDataCleanupService extends Mock
    implements UserDataCleanupService {}

/// Runs [body] while silencing unhandled async errors from the fire-and-forget
/// _performDiscovery() that initialize()/reconnect kicks off (it attempts real
/// relay WebSocket connections which fail fast in the test environment).
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

  group('AuthService NIP-55 Amber', () {
    late _MockUserDataCleanupService mockCleanupService;
    late Map<String, String> secureStorage;
    late bool androidSignerInstalled;

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
      androidSignerInstalled = true;

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

      // Native NIP-55 signer probe. existAndroidNostrSigner reflects the
      // per-test [androidSignerInstalled] flag.
      const androidPluginChannel = MethodChannel('nostrmoPlugin');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(androidPluginChannel, (call) async {
            if (call.method == 'existAndroidNostrSigner') {
              return androidSignerInstalled;
            }
            return null;
          });
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        ..setMockMethodCallHandler(
          const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
          null,
        )
        ..setMockMethodCallHandler(
          const MethodChannel('openvine.secure_storage'),
          null,
        )
        ..setMockMethodCallHandler(const MethodChannel('nostrmoPlugin'), null);
    });

    AuthService createAuthService() {
      final keyStorage = SecureKeyStorage(
        securityConfig: const SecurityConfig(requireHardwareBacked: false),
      );
      return AuthService(
        userDataCleanupService: mockCleanupService,
        keyStorage: keyStorage,
        flutterSecureStorage: const FlutterSecureStorage(),
      );
    }

    String freshPubkey() =>
        SecureKeyContainer.fromPrivateKeyHex(generatePrivateKey()).publicKeyHex;

    group('connectWithAmber', () {
      test('returns failure on non-Android platforms', () async {
        SharedPreferences.setMockInitialValues({kKnownAccountsKey: '[]'});
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        final authService = createAuthService();
        addTearDown(authService.dispose);

        final result = await authService.connectWithAmber();

        expect(result.success, isFalse);
        expect(
          result.errorMessage,
          contains('Android signer only supported on Android'),
        );
        expect(authService.isAuthenticated, isFalse);
        expect(authService.currentIdentity, isNull);
      });

      test('returns failure when no signer app is installed', () async {
        SharedPreferences.setMockInitialValues({kKnownAccountsKey: '[]'});
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        androidSignerInstalled = false;
        final authService = createAuthService();
        addTearDown(authService.dispose);

        final result = await authService.connectWithAmber();

        expect(result.success, isFalse);
        expect(result.errorMessage, contains('No Android signer app'));
        expect(authService.isAuthenticated, isFalse);
      });
    });

    group('restore via initialize()', () {
      test(
        'reconnects an Amber account into an AmberNostrIdentity',
        () async {
          final pubkey = freshPubkey();
          secureStorage['amber_pubkey'] = pubkey;
          secureStorage['amber_package'] = 'com.greenart7c3.nostrsigner';
          SharedPreferences.setMockInitialValues({
            'authentication_source': 'amber',
            kKnownAccountsKey: '[]',
          });
          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          androidSignerInstalled = true;
          final authService = createAuthService();
          addTearDown(authService.dispose);

          await _ignoringDiscoveryErrors(authService.initialize);

          expect(authService.isAuthenticated, isTrue);
          expect(
            authService.authenticationSource,
            equals(AuthenticationSource.amber),
          );
          expect(authService.currentIdentity, isA<AmberNostrIdentity>());
          expect(authService.currentPublicKeyHex, equals(pubkey));
        },
      );

      test(
        'stays unauthenticated when the signer app is gone on restore',
        () async {
          secureStorage['amber_pubkey'] = freshPubkey();
          SharedPreferences.setMockInitialValues({
            'authentication_source': 'amber',
            kKnownAccountsKey: '[]',
          });
          debugDefaultTargetPlatformOverride = TargetPlatform.android;
          androidSignerInstalled = false;
          final authService = createAuthService();
          addTearDown(authService.dispose);

          await _ignoringDiscoveryErrors(authService.initialize);

          expect(authService.isAuthenticated, isFalse);
          expect(authService.currentIdentity, isNull);
        },
      );
    });
  });
}
