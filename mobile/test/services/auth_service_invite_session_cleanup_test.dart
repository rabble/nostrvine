// ABOUTME: Tests invite-failure cleanup for persisted Divine OAuth sessions
// ABOUTME: Verifies failed invite activation cannot leave restart-restorable auth state

import 'dart:async';
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_setup.dart';

class _MockSecureKeyStorage extends Mock implements SecureKeyStorage {}

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
    if (value == null) {
      data.remove(key);
      return;
    }
    data[key] = value;
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

Future<T> _ignoringBackgroundErrors<T>(Future<T> Function() body) async {
  final completer = Completer<T>();
  runZonedGuarded(
    () async {
      try {
        completer.complete(await body());
      } catch (e, st) {
        completer.completeError(e, st);
      }
    },
    (error, stack) {
      // Ignore async work kicked off after initialize() completes.
    },
  );
  return completer.future;
}

void main() {
  setupTestEnvironment();

  group('AuthService invite session cleanup', () {
    late _MockSecureKeyStorage mockKeyStorage;
    late _MockUserDataCleanupService mockCleanupService;
    late _MockKeycastOAuth mockOAuthClient;
    late _FakeFlutterSecureStorage fakeSecureStorage;

    setUp(() {
      mockKeyStorage = _MockSecureKeyStorage();
      mockCleanupService = _MockUserDataCleanupService();
      mockOAuthClient = _MockKeycastOAuth();
      fakeSecureStorage = _FakeFlutterSecureStorage();

      when(() => mockKeyStorage.initialize()).thenAnswer((_) async {});
      when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => false);
      when(() => mockKeyStorage.clearCache()).thenReturn(null);
      when(() => mockKeyStorage.dispose()).thenReturn(null);
      when(
        () => mockKeyStorage.getKeyContainer(),
      ).thenAnswer((_) async => null);

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
        () => mockOAuthClient.refreshSession(),
      ).thenAnswer((_) async => null);
      when(() => mockOAuthClient.close()).thenReturn(null);
    });

    AuthService createAuthService() {
      return AuthService(
        userDataCleanupService: mockCleanupService,
        keyStorage: mockKeyStorage,
        oauthClient: mockOAuthClient,
        flutterSecureStorage: fakeSecureStorage,
      );
    }

    test(
      'clearPendingDivineOAuthSession removes global OAuth artifacts',
      () async {
        fakeSecureStorage.data['keycast_session'] = jsonEncode(
          KeycastSession(
            bunkerUrl: 'wss://relay.test',
            accessToken: 'access-token',
            refreshToken: 'refresh-token',
            authorizationHandle: 'auth-handle',
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
          ).toJson(),
        );
        fakeSecureStorage.data['keycast_refresh_token'] = 'refresh-token';
        fakeSecureStorage.data['keycast_auth_handle'] = 'auth-handle';

        final authService = createAuthService();
        addTearDown(authService.dispose);

        await authService.clearPendingDivineOAuthSession();

        expect(fakeSecureStorage.data['keycast_session'], isNull);
        expect(fakeSecureStorage.data['keycast_refresh_token'], isNull);
        expect(fakeSecureStorage.data['keycast_auth_handle'], isNull);
      },
    );

    test(
      'restart after invite cleanup does not restore OAuth auth state',
      () async {
        SharedPreferences.setMockInitialValues({
          'authentication_source': 'divineOAuth',
          'tos_accepted': true,
        });

        fakeSecureStorage.data['keycast_session'] = jsonEncode(
          KeycastSession(
            bunkerUrl: 'wss://relay.test',
            accessToken: 'access-token',
            refreshToken: 'refresh-token',
            authorizationHandle: 'auth-handle',
            expiresAt: DateTime.now().add(const Duration(hours: 1)),
          ).toJson(),
        );
        fakeSecureStorage.data['keycast_refresh_token'] = 'refresh-token';
        fakeSecureStorage.data['keycast_auth_handle'] = 'auth-handle';

        final initialAuthService = createAuthService();
        await initialAuthService.clearPendingDivineOAuthSession();
        await initialAuthService.dispose();

        final restartedAuthService = createAuthService();
        addTearDown(restartedAuthService.dispose);

        await _ignoringBackgroundErrors(restartedAuthService.initialize);

        expect(restartedAuthService.isAuthenticated, isFalse);
        expect(
          restartedAuthService.authState,
          equals(AuthState.unauthenticated),
        );
        verify(() => mockOAuthClient.refreshSession()).called(1);
      },
    );
  });
}
