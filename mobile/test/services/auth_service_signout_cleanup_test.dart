// ABOUTME: Tests for AuthService signOut clearing user-specific data
// ABOUTME: Verifies that explicit logout clears pubkey tracking and user data

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test_setup.dart';

class _MockSecureKeyStorage extends Mock implements SecureKeyStorage {}

class _MockUserDataCleanupService extends Mock
    implements UserDataCleanupService {}

void main() {
  setupTestEnvironment();

  group('AuthService signOut cleanup', () {
    late _MockSecureKeyStorage mockKeyStorage;
    late _MockUserDataCleanupService mockCleanupService;
    late AuthService authService;
    late SharedPreferences prefs;

    // Test nsec from a known keypair
    const testNsec =
        'nsec1vl029mgpspedva04g90vltkh6fvh240zqtv9k0t9af8935ke9laqsnlfe5';

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'current_user_pubkey_hex': 'existing_pubkey_hex_123',
        'age_verified_16_plus': true,
        'terms_accepted_at': '2024-01-01T00:00:00Z',
      });
      prefs = await SharedPreferences.getInstance();
      mockKeyStorage = _MockSecureKeyStorage();
      mockCleanupService = _MockUserDataCleanupService();

      // Create AuthService with mock dependencies
      authService = AuthService(
        userDataCleanupService: mockCleanupService,
        keyStorage: mockKeyStorage,
      );

      // Setup mock behaviors
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
    });

    test('signOut should clear current_user_pubkey_hex', () async {
      // Arrange: Verify pubkey is initially stored
      expect(prefs.getString('current_user_pubkey_hex'), isNotNull);

      // Setup mock to not delete keys (just clearing cache)
      when(() => mockKeyStorage.clearCache()).thenReturn(null);

      // Act: Sign out without deleting keys
      await authService.signOut();

      // Assert: Pubkey should be cleared
      expect(prefs.getString('current_user_pubkey_hex'), isNull);
    });

    test('signOut should clear TOS acceptance flags', () async {
      // Arrange: Verify TOS flags are initially set
      expect(prefs.getBool('age_verified_16_plus'), isTrue);
      expect(prefs.getString('terms_accepted_at'), isNotNull);

      // Setup mock
      when(() => mockKeyStorage.clearCache()).thenReturn(null);

      // Act: Sign out
      await authService.signOut();

      // Assert: TOS flags should be cleared
      expect(prefs.getBool('age_verified_16_plus'), isNull);
      expect(prefs.getString('terms_accepted_at'), isNull);
    });

    test('non-destructive signOut passes deleteUserData: false', () async {
      // Setup mock
      when(() => mockKeyStorage.clearCache()).thenReturn(null);

      // Act: Sign out without deleting keys (account switch)
      await authService.signOut();

      // Assert: Cleanup called with deleteUserData=false (preserves
      // per-user DAO data since it's scoped by ownerPubkey)
      verify(
        () => mockCleanupService.clearUserSpecificData(
          reason: 'explicit_logout',
          userPubkey: any(named: 'userPubkey'),
          // ignore: avoid_redundant_argument_values
          deleteUserData: false,
        ),
      ).called(1);
    });

    test('destructive signOut passes deleteUserData: true', () async {
      // Arrange
      when(() => mockKeyStorage.deleteKeys()).thenAnswer((_) async => {});
      when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => false);
      when(() => mockKeyStorage.initialize()).thenAnswer((_) async => {});

      // Auto-create new identity after deletion
      final newKeyContainer = SecureKeyContainer.fromNsec(testNsec);
      when(
        () => mockKeyStorage.generateAndStoreKeys(
          biometricPrompt: any(named: 'biometricPrompt'),
        ),
      ).thenAnswer((_) async => newKeyContainer);

      // Act: Sign out with key deletion
      await authService.signOut(deleteKeys: true);

      // Assert: Keys should be deleted
      verify(() => mockKeyStorage.deleteKeys()).called(1);

      // Assert: Cleanup called with deleteUserData=true (destructive)
      verify(
        () => mockCleanupService.clearUserSpecificData(
          reason: 'explicit_logout',
          userPubkey: any(named: 'userPubkey'),
          deleteUserData: true,
        ),
      ).called(1);

      // Note: After deleteKeys=true, a new identity is auto-created,
      // which sets a new pubkey. So we verify cleanup was called,
      // not that pubkey is null (since new identity sets it).
    });

    test('signOut should set auth state to unauthenticated', () async {
      // Setup mock
      when(() => mockKeyStorage.clearCache()).thenReturn(null);

      // Act: Sign out
      await authService.signOut();

      // Assert: Auth state should be unauthenticated
      expect(authService.authState, equals(AuthState.unauthenticated));
    });

    group('key deletion error propagation', () {
      test('signOut with deleteKeys rethrows SecureKeyStorageException '
          'after completing cleanup', () async {
        // Arrange: deleteKeys() throws
        when(() => mockKeyStorage.deleteKeys()).thenThrow(
          const SecureKeyStorageException(
            'Platform key deletion failed',
            code: 'platform_deletion_failed',
          ),
        );
        when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => false);

        // Act & Assert: signOut completes cleanup then rethrows
        await expectLater(
          authService.signOut(deleteKeys: true),
          throwsA(isA<SecureKeyStorageException>()),
        );

        // Auth state should still be unauthenticated — cleanup completed
        expect(authService.authState, equals(AuthState.unauthenticated));
      });

      test('signOut with deleteKeys succeeds normally when keys delete '
          'successfully', () async {
        // Arrange: deleteKeys() succeeds
        when(() => mockKeyStorage.deleteKeys()).thenAnswer((_) async => {});
        when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => false);

        // Act: should not throw
        await authService.signOut(deleteKeys: true);

        // Assert: completed normally
        expect(authService.authState, equals(AuthState.unauthenticated));
        verify(() => mockKeyStorage.deleteKeys()).called(1);
      });

      test('signOut with abortOnKeyDeletionFailure throws before cleanup '
          'when key deletion fails', () async {
        // Arrange: deleteKeys() throws
        when(() => mockKeyStorage.deleteKeys()).thenThrow(
          const SecureKeyStorageException(
            'Platform key deletion failed',
            code: 'platform_deletion_failed',
          ),
        );

        // Act & Assert: signOut throws immediately
        await expectLater(
          authService.signOut(
            deleteKeys: true,
            abortOnKeyDeletionFailure: true,
          ),
          throwsA(isA<SecureKeyStorageException>()),
        );

        // Auth state should still be initial — no cleanup happened
        expect(authService.authState, isNot(equals(AuthState.unauthenticated)));

        // Cleanup service should NOT have been called
        verifyNever(
          () => mockCleanupService.clearUserSpecificData(
            reason: any(named: 'reason'),
            userPubkey: any(named: 'userPubkey'),
            deleteUserData: any(named: 'deleteUserData'),
          ),
        );
      });

      test('signOut with abortOnKeyDeletionFailure completes normally '
          'when key deletion succeeds', () async {
        // Arrange: deleteKeys() succeeds
        when(() => mockKeyStorage.deleteKeys()).thenAnswer((_) async => {});
        when(() => mockKeyStorage.hasKeys()).thenAnswer((_) async => false);

        // Act: should not throw
        await authService.signOut(
          deleteKeys: true,
          abortOnKeyDeletionFailure: true,
        );

        // Assert: completed normally, auth state unauthenticated
        expect(authService.authState, equals(AuthState.unauthenticated));

        // deleteKeys() called only once (pre-flight), not twice
        verify(() => mockKeyStorage.deleteKeys()).called(1);
      });
    });
  });
}
