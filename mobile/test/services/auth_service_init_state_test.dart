// ABOUTME: Tests that AuthService.initialize() never emits the
// ABOUTME: `authenticating` state — locks in the welcome-screen flash fix

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockUserDataCleanupService extends Mock
    implements UserDataCleanupService {}

class _MockKeycastOAuth extends Mock implements KeycastOAuth {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService init state transitions', () {
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
        ),
      ).thenAnswer((_) async => 0);

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
      'Divine OAuth init never emits the intermediate `authenticating` state',
      () async {
        // Arrange: persisted Divine OAuth source + a stored session that
        // has not expired. This drives initialize() into the
        // signInWithDivineOAuth path, which sets `authenticating` before
        // attempting RPC. The RPC will fail in this test environment (no
        // real Keycast server), and the catch block will set
        // `unauthenticated`. With the suppression in `_setAuthState`, we
        // should observe the stream emit `unauthenticated` directly,
        // never `authenticating`.
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'divineOAuth',
          'tos_accepted': true,
        });

        final validSession = KeycastSession(
          bunkerUrl: 'https://login.divine.video/api/nostr',
          accessToken: 'valid_access_token',
          expiresAt: DateTime.now().add(const Duration(hours: 24)),
        );
        secureStorage['keycast_session'] = jsonEncode(validSession.toJson());

        final authService = createAuthService();
        final emitted = <AuthState>[];
        final subscription = authService.authStateStream.listen(emitted.add);
        addTearDown(subscription.cancel);

        await runZonedGuarded(
          () async {
            await authService.initialize();
            // Drain pending broadcast-stream microtasks so the listener
            // sees every state transition before we assert below.
            await Future<void>.delayed(Duration.zero);
          },
          (error, stack) {
            // Ignore background relay/discovery errors
          },
        );

        expect(
          emitted,
          isNot(contains(AuthState.authenticating)),
          reason:
              'init must not transition through `authenticating` — '
              '_setAuthState should suppress checking->authenticating to '
              'prevent the welcome screen from flashing the login UI.',
        );
        expect(
          emitted,
          contains(AuthState.unauthenticated),
          reason:
              'RPC fails in this test env, so init should land on '
              '`unauthenticated`. This makes sure the emitted list is not '
              'trivially empty.',
        );
      },
    );

    test(
      'OAuth refresh path never emits the intermediate `authenticating` state',
      () async {
        // Arrange: expired session, refreshSession returns a fresh one. This
        // drives initialize() into _tryRefreshOAuthSession → signInWithDivineOAuth.
        // Same suppression invariant must hold.
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'divineOAuth',
          'tos_accepted': true,
        });

        final expiredSession = KeycastSession(
          bunkerUrl: 'https://login.divine.video/api/nostr',
          accessToken: 'expired_token',
          expiresAt: DateTime.now().subtract(const Duration(hours: 1)),
        );
        secureStorage['keycast_session'] = jsonEncode(expiredSession.toJson());

        final refreshedSession = KeycastSession(
          bunkerUrl: 'https://login.divine.video/api/nostr',
          accessToken: 'fresh_access_token',
          expiresAt: DateTime.now().add(const Duration(hours: 24)),
          refreshToken: 'new_refresh_token',
        );
        when(
          () => mockOAuthClient.refreshSession(),
        ).thenAnswer((_) async => refreshedSession);

        final authService = createAuthService();
        final emitted = <AuthState>[];
        final subscription = authService.authStateStream.listen(emitted.add);
        addTearDown(subscription.cancel);

        await runZonedGuarded(
          () async {
            await authService.initialize();
            await Future<void>.delayed(Duration.zero);
          },
          (error, stack) {
            // Ignore background errors
          },
        );

        expect(
          emitted,
          isNot(contains(AuthState.authenticating)),
          reason:
              'OAuth refresh during init must not transition through '
              '`authenticating` — same flash-prevention invariant.',
        );
        expect(
          emitted,
          contains(AuthState.unauthenticated),
          reason: 'Refresh + RPC fail should still land on unauthenticated.',
        );
      },
    );

    test(
      'init with no auth source goes straight to unauthenticated',
      () async {
        // Sanity check: the simplest init path (no persisted source) was
        // already correct before the fix. Verify it still emits exactly
        // [unauthenticated] and nothing else.
        SharedPreferences.setMockInitialValues({});

        final authService = createAuthService();
        final emitted = <AuthState>[];
        final subscription = authService.authStateStream.listen(emitted.add);
        addTearDown(subscription.cancel);

        await runZonedGuarded(
          () async {
            await authService.initialize();
            await Future<void>.delayed(Duration.zero);
          },
          (error, stack) {
            // Ignore background errors
          },
        );

        expect(emitted, equals([AuthState.unauthenticated]));
        expect(authService.authState, equals(AuthState.unauthenticated));
      },
    );

    test(
      'runtime signInWithDivineOAuth (post-init) still emits `authenticating`',
      () async {
        // Regression guard for the suppression rule: runtime sign-in must
        // not be affected. The suppression only fires when previous state is
        // `checking`, which is exclusively a startup-only state. Once init
        // has settled to `unauthenticated`, calling signInWithDivineOAuth
        // should produce the normal `unauthenticated → authenticating →
        // unauthenticated` (RPC fails in test env) sequence — and crucially
        // include `authenticating`, because the welcome screen relies on
        // that state to render its in-page spinner during runtime sign-in.
        SharedPreferences.setMockInitialValues({});

        final authService = createAuthService();

        await runZonedGuarded(
          () async {
            // Drive to a settled `unauthenticated` state first
            await authService.initialize();
            await Future<void>.delayed(Duration.zero);
            expect(authService.authState, equals(AuthState.unauthenticated));

            // Now subscribe and exercise the runtime path
            final emitted = <AuthState>[];
            final subscription = authService.authStateStream.listen(
              emitted.add,
            );
            addTearDown(subscription.cancel);

            final session = KeycastSession(
              bunkerUrl: 'https://login.divine.video/api/nostr',
              accessToken: 'runtime_access_token',
              expiresAt: DateTime.now().add(const Duration(hours: 24)),
            );

            await authService.signInWithDivineOAuth(session);
            await Future<void>.delayed(Duration.zero);

            expect(
              emitted,
              contains(AuthState.authenticating),
              reason:
                  'Runtime sign-in must still emit `authenticating` so the '
                  'welcome-screen spinner can render. The suppression rule '
                  'in _setAuthState must only fire when previous state is '
                  '`checking`, not `unauthenticated`.',
            );
          },
          (error, stack) {
            // Ignore background errors
          },
        );
      },
    );
  });
}
