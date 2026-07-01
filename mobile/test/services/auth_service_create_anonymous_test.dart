// ABOUTME: Unit tests for AuthService anonymous-account creation —
// ABOUTME: createAnonymousAccount, ...FromKeyContainer, ...FromPrivateKeyHex.
//
// #4741 PR1 gap-fill: covers the previously-uncovered anonymous-signup paths
// (fresh identity generation + acceptTerms, invite-gated key-container import)
// using a real channel-backed SecureKeyStorage. Transitively exercises
// createNewIdentity and acceptTerms.

import 'dart:async';

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

  group('AuthService anonymous account creation', () {
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

    test('createAnonymousAccount generates an automatic identity and '
        'accepts terms', () async {
      final authService = createAuthService();
      addTearDown(authService.dispose);

      await _ignoringDiscoveryErrors(authService.createAnonymousAccount);

      expect(authService.isAuthenticated, isTrue);
      expect(
        authService.authenticationSource,
        equals(AuthenticationSource.automatic),
      );
      expect(authService.currentIdentity, isA<LocalNostrIdentity>());
      expect(authService.currentPublicKeyHex, isNotNull);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('terms_accepted_at'), isNotNull);
      expect(prefs.getBool('age_verified_16_plus'), isTrue);
    });

    test('createAnonymousAccountFromKeyContainer imports the provided key '
        'as an automatic identity', () async {
      final privateKeyHex = generatePrivateKey();
      final container = SecureKeyContainer.fromPrivateKeyHex(privateKeyHex);
      final expectedPubkey = container.publicKeyHex;
      final authService = createAuthService();
      addTearDown(authService.dispose);

      await _ignoringDiscoveryErrors(
        () => authService.createAnonymousAccountFromKeyContainer(container),
      );

      expect(authService.isAuthenticated, isTrue);
      expect(
        authService.authenticationSource,
        equals(AuthenticationSource.automatic),
      );
      expect(authService.currentPublicKeyHex, equals(expectedPubkey));
    });

    test('createAnonymousAccountFromKeyContainer throws for a '
        'public-key-only container', () async {
      final pubkey = SecureKeyContainer.fromPrivateKeyHex(
        generatePrivateKey(),
      ).publicKeyHex;
      final pubkeyOnly = SecureKeyContainer.fromPublicKey(pubkey);
      final authService = createAuthService();
      addTearDown(authService.dispose);

      await expectLater(
        authService.createAnonymousAccountFromKeyContainer(pubkeyOnly),
        throwsA(isA<Exception>()),
      );
      expect(authService.isAuthenticated, isFalse);
    });
  });
}
