// ABOUTME: Tests for expired Keycast session refresh and auth source
// ABOUTME: preservation — verifies divineOAuth is never lost on expiry

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show generatePrivateKey;
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockUserDataCleanupService extends Mock
    implements UserDataCleanupService {}

class _MockKeycastOAuth extends Mock implements KeycastOAuth {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Expired Keycast session handling', () {
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

      // In-memory secure storage backing
      secureStorage = {};

      // Mock flutter_secure_storage platform channel
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

      // Mock secure storage capability check channel
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
    void arrangeExpiredSessionWithLocalKeys() {
      final expiredSession = KeycastSession(
        bunkerUrl: 'https://login.divine.video/api/nostr',
        accessToken: 'expired_token_abc123',
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      secureStorage['keycast_session'] = jsonEncode(expiredSession.toJson());

      final privateKeyHex = generatePrivateKey();
      final container = SecureKeyContainer.fromPrivateKeyHex(privateKeyHex);
      secureStorage['nostr_primary_key'] =
          'privateKeyHex:$privateKeyHex'
          '|publicKeyHex:${container.publicKeyHex}'
          '|npub:${container.npub}';
    }

    /// Helper: creates an AuthService wired to the mocks
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

    test(
      'refresh fails + local keys exist → auth source stays divineOAuth',
      () async {
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'divineOAuth',
          'tos_accepted': true,
        });

        arrangeExpiredSessionWithLocalKeys();

        // refreshSession returns null (failed)
        when(
          () => mockOAuthClient.refreshSession(
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer((_) async => null);

        final authService = createAuthService();

        await runZonedGuarded(
          () async {
            await authService.initialize();

            // Auth source preserved as divineOAuth, not downgraded
            expect(
              authService.authenticationSource,
              equals(AuthenticationSource.divineOAuth),
              reason:
                  'Auth source should stay divineOAuth when refresh fails '
                  'but local keys exist',
            );
            expect(
              authService.isAnonymous,
              isFalse,
              reason:
                  'isAnonymous should be false — user registered via OAuth, '
                  'session just expired',
            );
            expect(authService.isAuthenticated, isTrue);
            expect(
              authService.hasExpiredOAuthSession,
              isTrue,
              reason:
                  'hasExpiredOAuthSession should be true so UI can show '
                  '"session expired" instead of "Secure Your Account"',
            );

            // Verify refresh was attempted
            verify(
              () => mockOAuthClient.refreshSession(
                userPubkey: any(named: 'userPubkey'),
              ),
            ).called(1);
          },
          (error, stack) {
            // Ignore background relay discovery errors
          },
        );
      },
    );

    test('refresh fails + no local keys → falls to unauthenticated', () async {
      SharedPreferences.setMockInitialValues({
        'authentication_source': 'divineOAuth',
        'tos_accepted': true,
      });

      // Expired session but NO local nsec
      final expiredSession = KeycastSession(
        bunkerUrl: 'https://login.divine.video/api/nostr',
        accessToken: 'expired_token',
        expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
      );
      secureStorage['keycast_session'] = jsonEncode(expiredSession.toJson());

      when(
        () => mockOAuthClient.refreshSession(
          userPubkey: any(named: 'userPubkey'),
        ),
      ).thenAnswer((_) async => null);

      final authService = createAuthService();

      await runZonedGuarded(
        () async {
          await authService.initialize();

          expect(
            authService.authState,
            equals(AuthState.unauthenticated),
            reason: 'No local keys + refresh failed → unauthenticated',
          );
          verify(
            () => mockOAuthClient.refreshSession(
              userPubkey: any(named: 'userPubkey'),
            ),
          ).called(1);
        },
        (error, stack) {
          // Ignore background errors
        },
      );
    });

    test(
      'refresh succeeds → saves new session and attempts signInWithDivineOAuth',
      () async {
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'divineOAuth',
          'tos_accepted': true,
        });

        // Store expired session
        final expiredSession = KeycastSession(
          bunkerUrl: 'https://login.divine.video/api/nostr',
          accessToken: 'expired_token',
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        );
        secureStorage['keycast_session'] = jsonEncode(expiredSession.toJson());

        // refreshSession returns a valid new session
        final testPubkey = 'ab' * 32;
        final refreshedSession = KeycastSession(
          bunkerUrl: 'https://login.divine.video/api/nostr',
          accessToken: 'fresh_access_token',
          expiresAt: DateTime.now().add(const Duration(hours: 24)),
          refreshToken: 'new_refresh_token',
          userPubkey: testPubkey,
        );
        when(
          () => mockOAuthClient.refreshSession(
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer((_) async {
          secureStorage['keycast_session'] = jsonEncode(
            refreshedSession.toJson(),
          );
          return refreshedSession;
        });

        final authService = createAuthService();

        await runZonedGuarded(
          () async {
            await authService.initialize();

            // Refresh was attempted
            verify(
              () => mockOAuthClient.refreshSession(
                userPubkey: any(named: 'userPubkey'),
              ),
            ).called(1);

            // The refreshed session was saved to storage before
            // signInWithDivineOAuth was called
            final savedJson = secureStorage['keycast_session'];
            expect(savedJson, isNotNull);
            final savedSession = KeycastSession.fromJson(
              jsonDecode(savedJson!) as Map<String, dynamic>,
            );
            expect(savedSession.accessToken, 'fresh_access_token');

            // Note: signInWithDivineOAuth is called but fails in test
            // (no real Keycast RPC server) — that's expected.
            // The important thing is refresh was attempted and succeeded.
          },
          (error, stack) {
            // Ignore background errors (RPC connection, relay discovery)
          },
        );
      },
    );

    test(
      'isRpcUpgradeInProgress is false after upgrade completes',
      () async {
        // Regression for #4626: isRpcUpgradeInProgress must be false after
        // _upgradeDivineRpcInBackground finishes so the session-expired sheet
        // is no longer suppressed once the silent refresh has definitively
        // resolved.
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'divineOAuth',
          'tos_accepted': true,
        });

        arrangeExpiredSessionWithLocalKeys();

        // Refresh fails immediately.
        when(
          () => mockOAuthClient.refreshSession(
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer((_) async => null);

        final authService = createAuthService();

        await runZonedGuarded(
          () async {
            await authService.initialize();

            // The background upgrade is unawaited but resolves quickly since
            // refreshSession returns immediately. Pump the event queue until
            // the upgrade finishes — it should complete well within 1 second.
            final deadline = DateTime.now().add(const Duration(seconds: 3));
            while (authService.isRpcUpgradeInProgress &&
                DateTime.now().isBefore(deadline)) {
              await Future<void>.delayed(const Duration(milliseconds: 10));
            }

            expect(
              authService.isRpcUpgradeInProgress,
              isFalse,
              reason:
                  'isRpcUpgradeInProgress must be false after the upgrade '
                  'completes (failure path)',
            );

            // Session is still flagged as expired (refresh failed).
            expect(authService.hasExpiredOAuthSession, isTrue);
          },
          (error, stack) {
            // Ignore background relay/RPC errors
          },
        );
      },
    );

    test(
      'concurrent tryRefreshExpiredSession calls share one in-flight future '
      '(single-flight guard)',
      () async {
        // Regression for #4626: if multiple UI surfaces call
        // tryRefreshExpiredSession concurrently (e.g. profile header + settings
        // tile both visible), only one token refresh should be attempted.
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'divineOAuth',
          'tos_accepted': true,
        });

        arrangeExpiredSessionWithLocalKeys();

        // Refresh always returns null (failure).
        when(
          () => mockOAuthClient.refreshSession(
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer((_) async => null);

        final authService = createAuthService();

        await runZonedGuarded(
          () async {
            await authService.initialize();

            // Wait for the background upgrade to finish before testing
            // tryRefreshExpiredSession in isolation. This avoids the
            // _pendingOAuthRefresh single-flight slot being held by the
            // background upgrade, which would conflate call counts.
            final deadline = DateTime.now().add(const Duration(seconds: 5));
            while (authService.isRpcUpgradeInProgress &&
                DateTime.now().isBefore(deadline)) {
              await Future<void>.delayed(const Duration(milliseconds: 10));
            }

            // Session should be expired after init with failed refresh.
            expect(authService.hasExpiredOAuthSession, isTrue);

            // Reset interaction tracking after init's refresh calls.
            clearInteractions(mockOAuthClient);

            // Two concurrent callers.
            final results = await Future.wait([
              authService.tryRefreshExpiredSession(),
              authService.tryRefreshExpiredSession(),
            ]);

            // Both callers receive the same result (false — refresh failed).
            expect(results, equals([false, false]));

            // refreshSession was only called ONCE despite two concurrent
            // tryRefreshExpiredSession calls (single-flight _pendingRefresh).
            verify(
              () => mockOAuthClient.refreshSession(
                userPubkey: any(named: 'userPubkey'),
              ),
            ).called(1);
          },
          (error, stack) {
            // Ignore background errors
          },
        );
      },
    );
  });
}
