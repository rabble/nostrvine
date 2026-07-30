// ABOUTME: Tests for AuthService.exportKeycastNsec method
// ABOUTME: Verifies the bearer-token handoff and refusal passthrough for the
// ABOUTME: nsec Keycast holds for a Divine Login account

import 'package:flutter_test/flutter_test.dart';
import 'package:keycast_flutter/keycast_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';

import '../test_setup.dart';

class _MockSecureKeyStorage extends Mock implements SecureKeyStorage {}

class _MockUserDataCleanupService extends Mock
    implements UserDataCleanupService {}

class _MockKeycastOAuth extends Mock implements KeycastOAuth {}

void main() {
  setupTestEnvironment();

  group('AuthService exportKeycastNsec', () {
    const testAccessToken = 'test-access-token';
    const testPassword = 'hunter2';
    const testNsec =
        'nsec1testkeymaterialthatisnotarealkey00000000000000000000000000';

    late _MockSecureKeyStorage mockKeyStorage;
    late _MockUserDataCleanupService mockCleanupService;
    late _MockKeycastOAuth mockOAuthClient;

    setUp(() {
      mockKeyStorage = _MockSecureKeyStorage();
      mockCleanupService = _MockUserDataCleanupService();
      mockOAuthClient = _MockKeycastOAuth();

      when(
        () => mockCleanupService.shouldClearDataForUser(any()),
      ).thenReturn(false);
    });

    AuthService buildAuthService({bool withOAuthClient = true}) {
      return AuthService(
        userDataCleanupService: mockCleanupService,
        keyStorage: mockKeyStorage,
        oauthClient: withOAuthClient ? mockOAuthClient : null,
      );
    }

    KeycastSession sessionWithToken(String? token) {
      return KeycastSession(
        bunkerUrl: 'https://bunker.example.com',
        accessToken: token,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
    }

    test('needs sign-in when no OAuth client is configured', () async {
      final authService = buildAuthService(withOAuthClient: false);

      final result = await authService.exportKeycastNsec(testPassword);

      expect(result.success, isFalse);
      expect(result.key, isNull);
      expect(result.failure, ExportKeyFailure.needsSignIn);
    });

    test('needs sign-in when there is no session after a refresh', () async {
      when(
        () => mockOAuthClient.getSessionOrRefresh(),
      ).thenAnswer((_) async => null);

      final result = await buildAuthService().exportKeycastNsec(testPassword);

      expect(result.failure, ExportKeyFailure.needsSignIn);
      verify(() => mockOAuthClient.getSessionOrRefresh()).called(1);
      // No password is sent anywhere without a credential to send it with.
      verifyNever(() => mockOAuthClient.exportKey(any(), any()));
    });

    test('needs sign-in when the session carries no access token', () async {
      when(
        () => mockOAuthClient.getSessionOrRefresh(),
      ).thenAnswer((_) async => sessionWithToken(null));

      final result = await buildAuthService().exportKeycastNsec(testPassword);

      expect(result.failure, ExportKeyFailure.needsSignIn);
      verifyNever(() => mockOAuthClient.exportKey(any(), any()));
    });

    test('returns the key using the refreshed session token', () async {
      when(
        () => mockOAuthClient.getSessionOrRefresh(),
      ).thenAnswer((_) async => sessionWithToken(testAccessToken));
      when(
        () => mockOAuthClient.exportKey(testAccessToken, testPassword),
      ).thenAnswer((_) async => ExportKeyResult.success(testNsec));

      final result = await buildAuthService().exportKeycastNsec(testPassword);

      expect(result.success, isTrue);
      expect(result.key, testNsec);
      // Refresh runs first, so an expired-but-refreshable session does not
      // surface to the user as a sign-in prompt.
      verify(() => mockOAuthClient.getSessionOrRefresh()).called(1);
      verify(
        () => mockOAuthClient.exportKey(testAccessToken, testPassword),
      ).called(1);
    });

    test(
      'passes a refusal through unchanged rather than reshaping it',
      () async {
        when(
          () => mockOAuthClient.getSessionOrRefresh(),
        ).thenAnswer((_) async => sessionWithToken(testAccessToken));
        when(
          () => mockOAuthClient.exportKey(testAccessToken, testPassword),
        ).thenAnswer(
          (_) async => ExportKeyResult.failure(
            ExportKeyFailure.denied,
            message: 'Operation denied by policy',
          ),
        );

        final result = await buildAuthService().exportKeycastNsec(testPassword);

        expect(result.success, isFalse);
        expect(result.key, isNull);
        // A verified_minor refusal must reach the UI as denied, not as a
        // generic error the user could read as "try again".
        expect(result.failure, ExportKeyFailure.denied);
        expect(result.error, 'Operation denied by policy');
      },
    );

    test('reports a thrown client error as a network failure', () async {
      when(
        () => mockOAuthClient.getSessionOrRefresh(),
      ).thenAnswer((_) async => sessionWithToken(testAccessToken));
      when(
        () => mockOAuthClient.exportKey(testAccessToken, testPassword),
      ).thenThrow(Exception('socket closed'));

      final result = await buildAuthService().exportKeycastNsec(testPassword);

      expect(result.success, isFalse);
      expect(result.failure, ExportKeyFailure.network);
    });
  });
}
