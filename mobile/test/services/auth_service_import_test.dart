// ABOUTME: Unit tests for AuthService key-import flows — importFromNsec,
// ABOUTME: importFromHex, and importFromNcryptsec (NIP-49). No emulator needed.
//
// #4741 PR1 gap-fill: covers the previously-uncovered validation/error branches
// (invalid nsec, invalid hex, wrong ncryptsec password) plus the happy path into
// a LocalNostrIdentity, using a real channel-backed SecureKeyStorage.

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show Nip19, Nip49, generatePrivateKey;
import 'package:openvine/models/known_account.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nostr_identity.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockUserDataCleanupService extends Mock
    implements UserDataCleanupService {}

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

  group('AuthService key import', () {
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

    AuthService createAuthService() {
      return AuthService(
        userDataCleanupService: mockCleanupService,
        keyStorage: SecureKeyStorage(
          securityConfig: const SecurityConfig(requireHardwareBacked: false),
        ),
        flutterSecureStorage: const FlutterSecureStorage(),
      );
    }

    group('importFromNsec', () {
      test('imports a valid nsec into a LocalNostrIdentity', () async {
        final privateKeyHex = generatePrivateKey();
        final expectedPubkey = SecureKeyContainer.fromPrivateKeyHex(
          privateKeyHex,
        ).publicKeyHex;
        final nsec = Nip19.encodePrivateKey(privateKeyHex);
        final authService = createAuthService();
        addTearDown(authService.dispose);

        final result = await _ignoringDiscoveryErrors(
          () => authService.importFromNsec(nsec),
        );

        expect(result.success, isTrue);
        expect(
          authService.authenticationSource,
          equals(AuthenticationSource.importedKeys),
        );
        expect(authService.currentIdentity, isA<LocalNostrIdentity>());
        expect(authService.currentPublicKeyHex, equals(expectedPubkey));
      });

      test('rejects an invalid nsec', () async {
        final authService = createAuthService();
        addTearDown(authService.dispose);

        final result = await authService.importFromNsec('not-a-valid-nsec');

        expect(result.success, isFalse);
        expect(result.errorMessage, contains('Invalid nsec format'));
        expect(authService.isAuthenticated, isFalse);
      });
    });

    group('importFromHex', () {
      test('imports a valid hex key into a LocalNostrIdentity', () async {
        final privateKeyHex = generatePrivateKey();
        final authService = createAuthService();
        addTearDown(authService.dispose);

        final result = await _ignoringDiscoveryErrors(
          () => authService.importFromHex(privateKeyHex),
        );

        expect(result.success, isTrue);
        expect(authService.currentIdentity, isA<LocalNostrIdentity>());
      });

      test('rejects an invalid hex key', () async {
        final authService = createAuthService();
        addTearDown(authService.dispose);

        final result = await authService.importFromHex('not-hex');

        expect(result.success, isFalse);
        expect(result.errorMessage, contains('Invalid private key format'));
        expect(authService.isAuthenticated, isFalse);
      });
    });

    group('importFromNcryptsec', () {
      test('decrypts and imports with the correct password', () async {
        final privateKeyHex = generatePrivateKey();
        // logN kept low so scrypt stays fast in tests.
        final ncryptsec = await Nip49.encode(
          privateKeyHex,
          'correct horse',
          logN: 4,
        );
        final authService = createAuthService();
        addTearDown(authService.dispose);

        final result = await _ignoringDiscoveryErrors(
          () => authService.importFromNcryptsec(ncryptsec, 'correct horse'),
        );

        expect(result.success, isTrue);
        expect(authService.currentIdentity, isA<LocalNostrIdentity>());
      });

      test('fails with Incorrect password on a wrong password', () async {
        final ncryptsec = await Nip49.encode(
          generatePrivateKey(),
          'correct horse',
          logN: 4,
        );
        final authService = createAuthService();
        addTearDown(authService.dispose);

        final result = await authService.importFromNcryptsec(
          ncryptsec,
          'wrong password',
        );

        expect(result.success, isFalse);
        expect(result.errorMessage, equals('Incorrect password'));
        expect(authService.isAuthenticated, isFalse);
      });
    });
  });
}
