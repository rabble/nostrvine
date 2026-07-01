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

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show generatePrivateKey;
import 'package:openvine/models/known_account.dart';
import 'package:openvine/services/auth_service.dart';
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

  group('AuthService destructive sign-out recovery', () {
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

    test('completes destructive sign-out and lands unauthenticated when a '
        'cleanup step throws after key deletion', () async {
      final authService = createAuthService();
      addTearDown(authService.dispose);

      // Authenticated starting state.
      await _ignoringDiscoveryErrors(
        () => authService.importFromHex(generatePrivateKey()),
      );
      expect(authService.isAuthenticated, isTrue);

      // Fail a cleanup step that runs AFTER the pre-flight key deletion in the
      // destructive branch, forcing the recovery path.
      when(
        () => mockCleanupService.markOwnerScopedLegacyDataForUser(any()),
      ).thenAnswer((_) async => throw Exception('cleanup boom'));

      await _ignoringDiscoveryErrors(
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
