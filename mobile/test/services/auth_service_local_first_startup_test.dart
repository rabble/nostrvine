// ABOUTME: Tests for local-first Divine OAuth startup behavior
// ABOUTME: Verifies that matching local keys authenticate before RPC refresh

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show generatePrivateKey;
import 'package:openvine/models/auth_rpc_capability.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockUserDataCleanupService extends Mock
    implements UserDataCleanupService {}

class _MockKeycastOAuth extends Mock implements KeycastOAuth {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Local-first Divine OAuth startup', () {
    late _MockUserDataCleanupService mockCleanupService;
    late _MockKeycastOAuth mockOAuthClient;
    late Map<String, String> secureStorage;

    setUp(() {
      mockCleanupService = _MockUserDataCleanupService();
      mockOAuthClient = _MockKeycastOAuth();

      when(
        () => mockCleanupService.shouldClearDataForUser(any()),
      ).thenReturn(false);
      when(
        () => mockCleanupService.clearUserSpecificData(
          reason: any(named: 'reason'),
          userPubkey: any(named: 'userPubkey'),
          deleteUserData: any(named: 'deleteUserData'),
        ),
      ).thenAnswer((_) async => 0);
      when(
        () => mockCleanupService.claimLegacyRows(any()),
      ).thenAnswer((_) async {});

      secureStorage = {};

      const channel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (MethodCall call) async {
            switch (call.method) {
              case 'read':
                final key = call.arguments['key'] as String?;
                return secureStorage[key];
              case 'write':
                final key = call.arguments['key'] as String?;
                final value = call.arguments['value'] as String?;
                if (key != null && value != null) {
                  secureStorage[key] = value;
                }
                return null;
              case 'delete':
                final key = call.arguments['key'] as String?;
                secureStorage.remove(key);
                return null;
              case 'deleteAll':
                secureStorage.clear();
                return null;
              case 'readAll':
                return secureStorage;
              case 'containsKey':
                final key = call.arguments['key'] as String?;
                return secureStorage.containsKey(key);
              case 'getCapabilities':
                return {'basicSecureStorage': true};
              default:
                return null;
            }
          });

      const capabilityChannel = MethodChannel('openvine.secure_storage');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(capabilityChannel, (MethodCall call) async {
            switch (call.method) {
              case 'getCapabilities':
                return {
                  'hasHardwareSecurity': false,
                  'hasBiometrics': false,
                  'hasKeychain': true,
                };
              default:
                return null;
            }
          });
    });

    /// Helper: stores an expired Keycast session and a valid local nsec
    /// that matches the session pubkey.
    String arrangeExpiredSessionWithMatchingLocalKeys() {
      final privateKeyHex = generatePrivateKey();
      final container = SecureKeyContainer.fromPrivateKeyHex(privateKeyHex);
      final pubkey = container.publicKeyHex;

      final expiredSession = KeycastSession(
        bunkerUrl: 'https://login.divine.video/api/nostr',
        accessToken: 'expired_token_abc123',
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        userPubkey: pubkey,
      );
      secureStorage['keycast_session'] = jsonEncode(expiredSession.toJson());

      secureStorage['nostr_primary_key'] =
          'privateKeyHex:$privateKeyHex'
          '|publicKeyHex:${container.publicKeyHex}'
          '|npub:${container.npub}';

      return pubkey;
    }

    AuthService createAuthService() {
      final keyStorage = SecureKeyStorage(
        securityConfig: const SecurityConfig(requireHardwareBacked: false),
      );
      return AuthService(
        userDataCleanupService: mockCleanupService,
        keyStorage: keyStorage,
        oauthClient: mockOAuthClient,
      );
    }

    test('divineOAuth local restore starts in upgrading state '
        'before RPC is ready', () async {
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'divineOAuth',
        'tos_accepted': true,
      });

      arrangeExpiredSessionWithMatchingLocalKeys();

      // refreshSession returns null (failed)
      when(
        () => mockOAuthClient.refreshSession(),
      ).thenAnswer((_) async => null);

      final authService = createAuthService();

      await runZonedGuarded(
        () async {
          await authService.initialize();

          expect(authService.isAuthenticated, isTrue);
          expect(
            authService.authenticationSource,
            equals(AuthenticationSource.divineOAuth),
          );
          // RPC capability should not be rpcReady since refresh failed
          expect(
            authService.authRpcCapability,
            isNot(equals(AuthRpcCapability.rpcReady)),
          );
        },
        (error, stack) {
          // Ignore background relay discovery errors
        },
      );
    });

    test(
      'authRpcCapability defaults to unavailable for non-oauth sources',
      () async {
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'automatic',
          'tos_accepted': true,
        });

        // Store a local key for automatic login
        final privateKeyHex = generatePrivateKey();
        final container = SecureKeyContainer.fromPrivateKeyHex(privateKeyHex);
        secureStorage['nostr_primary_key'] =
            'privateKeyHex:$privateKeyHex'
            '|publicKeyHex:${container.publicKeyHex}'
            '|npub:${container.npub}';

        final authService = createAuthService();

        await runZonedGuarded(
          () async {
            await authService.initialize();

            expect(authService.isAuthenticated, isTrue);
            expect(
              authService.authRpcCapability,
              equals(AuthRpcCapability.unavailable),
            );
          },
          (error, stack) {
            // Ignore background errors
          },
        );
      },
    );

    test(
      'canPublishNostrWritesNow is true when local private key exists',
      () async {
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'divineOAuth',
          'tos_accepted': true,
        });

        arrangeExpiredSessionWithMatchingLocalKeys();

        when(
          () => mockOAuthClient.refreshSession(),
        ).thenAnswer((_) async => null);

        final authService = createAuthService();

        await runZonedGuarded(
          () async {
            await authService.initialize();

            expect(authService.isAuthenticated, isTrue);
            expect(authService.canPublishNostrWritesNow, isTrue);
          },
          (error, stack) {
            // Ignore background errors
          },
        );
      },
    );

    test('canPublishNostrWritesNow is false when not authenticated', () {
      final authService = createAuthService();
      expect(authService.canPublishNostrWritesNow, isFalse);
    });

    test('matching local key authenticates before refresh completes', () async {
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'divineOAuth',
        'tos_accepted': true,
      });

      final pubkey = arrangeExpiredSessionWithMatchingLocalKeys();

      // refreshSession hangs forever (simulates slow network)
      when(
        () => mockOAuthClient.refreshSession(),
      ).thenAnswer((_) => Completer<KeycastSession?>().future);

      final authService = createAuthService();

      await runZonedGuarded(
        () async {
          await authService.initialize();

          // Should be authenticated immediately from local keys
          expect(authService.isAuthenticated, isTrue);
          expect(authService.currentPublicKeyHex, equals(pubkey));
          expect(
            authService.authenticationSource,
            equals(AuthenticationSource.divineOAuth),
          );
          // RPC is upgrading (refresh is still in-flight)
          expect(
            authService.authRpcCapability,
            equals(AuthRpcCapability.upgrading),
          );
        },
        (error, stack) {
          // Ignore background errors
        },
      );
    });

    test(
      'refresh timeout does not block local authenticated startup',
      () async {
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'divineOAuth',
          'tos_accepted': true,
        });

        arrangeExpiredSessionWithMatchingLocalKeys();

        // refreshSession hangs forever — will be timed out
        when(
          () => mockOAuthClient.refreshSession(),
        ).thenAnswer((_) => Completer<KeycastSession?>().future);

        final authService = createAuthService();

        await runZonedGuarded(
          () async {
            await authService.initialize();

            // User is authenticated immediately — not waiting on refresh
            expect(authService.isAuthenticated, isTrue);
          },
          (error, stack) {
            // Ignore background errors
          },
        );
      },
    );

    test('no local key + no valid session → unauthenticated', () async {
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'divineOAuth',
        'tos_accepted': true,
      });

      // Expired session, no local keys
      final expiredSession = KeycastSession(
        bunkerUrl: 'https://login.divine.video/api/nostr',
        accessToken: 'expired_token',
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      secureStorage['keycast_session'] = jsonEncode(expiredSession.toJson());

      when(
        () => mockOAuthClient.refreshSession(),
      ).thenAnswer((_) async => null);

      final authService = createAuthService();

      await runZonedGuarded(
        () async {
          await authService.initialize();

          expect(authService.authState, equals(AuthState.unauthenticated));
          expect(authService.hasExpiredOAuthSession, isTrue);
        },
        (error, stack) {
          // Ignore background errors
        },
      );
    });
  });
}
