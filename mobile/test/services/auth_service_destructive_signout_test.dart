// ABOUTME: Unit test for AuthService destructive sign-out recovery —
// ABOUTME: _completeDestructiveSignOutAfterDeletedKeys when cleanup throws.
//
// #4741 PR1 gap-fill: signOut(deleteKeys: true, abortOnKeyDeletionFailure: true)
// deletes local login material BEFORE session cleanup. If a later cleanup step
// then throws, the app must NOT stay authenticated-in-memory with no keys on
// disk — signOut routes to _completeDestructiveSignOutAfterDeletedKeys, which
// tears down the session and lands unauthenticated. Failure is injected via the
// mocked UserDataCleanupService.markOwnerScopedLegacyDataForUser (called
// unwrapped in the destructive branch), with a real channel-backed
// SecureKeyStorage for the authenticated starting state.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show generatePrivateKey;
import 'package:openvine/models/known_account.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/user_data_cleanup_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/auth_service_test_harness.dart';

class _MockUserDataCleanupService extends Mock
    implements UserDataCleanupService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthService destructive sign-out recovery', () {
    late _MockUserDataCleanupService mockCleanupService;

    setUp(() {
      mockCleanupService = _MockUserDataCleanupService();
      stubUserDataCleanupSuccess(mockCleanupService);
      AuthServiceChannelMocks.install();
      SharedPreferences.setMockInitialValues({kKnownAccountsKey: '[]'});
    });

    tearDown(AuthServiceChannelMocks.remove);

    AuthService createAuthService() =>
        buildTestAuthService(cleanupService: mockCleanupService);

    test('completes destructive sign-out and lands unauthenticated when a '
        'cleanup step throws after key deletion', () async {
      final authService = createAuthService();
      addTearDown(authService.dispose);

      // Authenticated starting state.
      await ignoringDiscoveryErrors(
        () => authService.importFromHex(generatePrivateKey()),
      );
      expect(authService.isAuthenticated, isTrue);

      // Fail a cleanup step that runs AFTER the pre-flight key deletion in the
      // destructive branch, forcing the recovery path.
      when(
        () => mockCleanupService.markOwnerScopedLegacyDataForUser(any()),
      ).thenAnswer((_) async => throw Exception('cleanup boom'));

      await ignoringDiscoveryErrors(
        () => authService.signOut(
          deleteKeys: true,
          abortOnKeyDeletionFailure: true,
        ),
      );

      // The recovery path tore down the session rather than leaving an
      // authenticated-in-memory state with no keys on disk.
      expect(authService.isAuthenticated, isFalse);
      expect(authService.currentIdentity, isNull);
    });
  });
}
