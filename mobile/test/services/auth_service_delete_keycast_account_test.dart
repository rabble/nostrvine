// ABOUTME: Tests for AuthService.deleteKeycastAccount method
// ABOUTME: Verifies Keycast account deletion during account deletion flow

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

  group('AuthService deleteKeycastAccount', () {
    late _MockSecureKeyStorage mockKeyStorage;
    late _MockUserDataCleanupService mockCleanupService;
    late _MockKeycastOAuth mockOAuthClient;
    late AuthService authService;

    setUp(() async {
      mockKeyStorage = _MockSecureKeyStorage();
      mockCleanupService = _MockUserDataCleanupService();
      mockOAuthClient = _MockKeycastOAuth();

      // Setup default mock behaviors
      when(
        () => mockCleanupService.shouldClearDataForUser(any()),
      ).thenReturn(false);
      when(
        () => mockCleanupService.clearUserSpecificData(
          reason: any(named: 'reason'),
        ),
      ).thenAnswer((_) async => 0);
    });

    test('returns success when no OAuth client is configured', () async {
      // Create AuthService WITHOUT OAuth client
      authService = AuthService(
        userDataCleanupService: mockCleanupService,
        keyStorage: mockKeyStorage,
      );

      // Act
      final (success, error) = await authService.deleteKeycastAccount();

      // Assert
      expect(success, isTrue);
      expect(error, isNull);
    });

    test('returns success when no session exists', () async {
      // Create AuthService with OAuth client
      authService = AuthService(
        userDataCleanupService: mockCleanupService,
        keyStorage: mockKeyStorage,
        oauthClient: mockOAuthClient,
      );

      // Mock: no session
      when(() => mockOAuthClient.getSession()).thenAnswer((_) async => null);

      // Act
      final (success, error) = await authService.deleteKeycastAccount();

      // Assert
      expect(success, isTrue);
      expect(error, isNull);
      verify(() => mockOAuthClient.getSession()).called(1);
      verifyNever(() => mockOAuthClient.deleteAccount(any()));
    });

    test('returns success when session has no access token', () async {
      // Create AuthService with OAuth client
      authService = AuthService(
        userDataCleanupService: mockCleanupService,
        keyStorage: mockKeyStorage,
        oauthClient: mockOAuthClient,
      );

      // Mock: session exists but has no access token
      final sessionWithoutToken = KeycastSession(
        bunkerUrl: 'https://bunker.example.com',
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      when(
        () => mockOAuthClient.getSession(),
      ).thenAnswer((_) async => sessionWithoutToken);

      // Act
      final (success, error) = await authService.deleteKeycastAccount();

      // Assert
      expect(success, isTrue);
      expect(error, isNull);
      verify(() => mockOAuthClient.getSession()).called(1);
      verifyNever(() => mockOAuthClient.deleteAccount(any()));
    });

    test('returns success when account deletion succeeds', () async {
      // Create AuthService with OAuth client
      authService = AuthService(
        userDataCleanupService: mockCleanupService,
        keyStorage: mockKeyStorage,
        oauthClient: mockOAuthClient,
      );

      // Mock: session with valid access token
      const testAccessToken = 'test_access_token_123';
      final validSession = KeycastSession(
        bunkerUrl: 'https://bunker.example.com',
        accessToken: testAccessToken,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      when(
        () => mockOAuthClient.getSession(),
      ).thenAnswer((_) async => validSession);

      // Mock: successful deletion
      when(() => mockOAuthClient.deleteAccount(testAccessToken)).thenAnswer(
        (_) async => DeleteAccountResult(
          success: true,
          message: 'Account permanently deleted',
        ),
      );

      // Act
      final (success, error) = await authService.deleteKeycastAccount();

      // Assert
      expect(success, isTrue);
      expect(error, isNull);
      verify(() => mockOAuthClient.getSession()).called(1);
      verify(() => mockOAuthClient.deleteAccount(testAccessToken)).called(1);
    });

    test('returns failure with error message when deletion fails', () async {
      // Create AuthService with OAuth client
      authService = AuthService(
        userDataCleanupService: mockCleanupService,
        keyStorage: mockKeyStorage,
        oauthClient: mockOAuthClient,
      );

      // Mock: session with valid access token
      const testAccessToken = 'test_access_token_123';
      final validSession = KeycastSession(
        bunkerUrl: 'https://bunker.example.com',
        accessToken: testAccessToken,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      when(
        () => mockOAuthClient.getSession(),
      ).thenAnswer((_) async => validSession);

      // Mock: failed deletion
      const errorMessage = 'Unauthorized: invalid or expired token';
      when(
        () => mockOAuthClient.deleteAccount(testAccessToken),
      ).thenAnswer((_) async => DeleteAccountResult.error(errorMessage));

      // Act
      final (success, error) = await authService.deleteKeycastAccount();

      // Assert
      expect(success, isFalse);
      expect(error, equals(errorMessage));
      verify(() => mockOAuthClient.getSession()).called(1);
      verify(() => mockOAuthClient.deleteAccount(testAccessToken)).called(1);
    });

    test('returns failure when exception is thrown', () async {
      // Create AuthService with OAuth client
      authService = AuthService(
        userDataCleanupService: mockCleanupService,
        keyStorage: mockKeyStorage,
        oauthClient: mockOAuthClient,
      );

      // Mock: session with valid access token
      const testAccessToken = 'test_access_token_123';
      final validSession = KeycastSession(
        bunkerUrl: 'https://bunker.example.com',
        accessToken: testAccessToken,
        expiresAt: DateTime.now().add(const Duration(hours: 1)),
      );
      when(
        () => mockOAuthClient.getSession(),
      ).thenAnswer((_) async => validSession);

      // Mock: exception during deletion
      when(
        () => mockOAuthClient.deleteAccount(testAccessToken),
      ).thenThrow(Exception('Network error'));

      // Act
      final (success, error) = await authService.deleteKeycastAccount();

      // Assert
      expect(success, isFalse);
      expect(error, contains('Failed to delete Keycast account'));
      expect(error, contains('Network error'));
    });
  });
}
