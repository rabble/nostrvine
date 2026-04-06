// ABOUTME: Tests for SecureKeyStorage.deleteKeys() error propagation
// ABOUTME: Verifies that failed platform deletion throws instead of silently
// succeeding, and that in-memory cache is cleared regardless

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';

import '../test_setup.dart';

void main() {
  group('SecureKeyStorage deleteKeys error propagation', () {
    late SecureKeyStorage storage;

    setUp(() async {
      setupTestEnvironment();
      storage = SecureKeyStorage();
      await storage.initialize();

      // Store a key so there's something to delete
      await storage.generateAndStoreKeys();
      expect(await storage.hasKeys(), isTrue);
    });

    test(
      'deleteKeys throws SecureKeyStorageException when platform '
      'deletion fails',
      () async {
        // Arrange: Make the fallback storage throw on delete so
        // PlatformSecureStorage.deleteKey() returns false.
        const secureStorageChannel = MethodChannel(
          'plugins.it_nomads.com/flutter_secure_storage',
        );
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(secureStorageChannel, (call) async {
              if (call.method == 'delete') {
                throw PlatformException(
                  code: 'ERROR',
                  message: 'Simulated platform deletion failure',
                );
              }
              // Delegate other calls to default behavior
              switch (call.method) {
                case 'read':
                  return null;
                case 'containsKey':
                  return false;
                default:
                  return null;
              }
            });

        // Act & Assert
        await expectLater(
          storage.deleteKeys(),
          throwsA(
            isA<SecureKeyStorageException>().having(
              (e) => e.code,
              'code',
              'platform_deletion_failed',
            ),
          ),
        );
      },
    );

    test(
      'deleteKeys clears in-memory cache even when platform deletion '
      'fails',
      () async {
        // Verify key is accessible before deletion attempt
        final container = await storage.getKeyContainer();
        expect(container, isNotNull);

        // Arrange: Make platform deletion fail
        const secureStorageChannel = MethodChannel(
          'plugins.it_nomads.com/flutter_secure_storage',
        );
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(secureStorageChannel, (call) async {
              if (call.method == 'delete') {
                throw PlatformException(
                  code: 'ERROR',
                  message: 'Simulated platform deletion failure',
                );
              }
              switch (call.method) {
                case 'read':
                  return null;
                case 'containsKey':
                  return false;
                default:
                  return null;
              }
            });

        // Act: deleteKeys throws, but cache should be cleared
        try {
          await storage.deleteKeys();
        } on SecureKeyStorageException {
          // Expected
        }

        // Assert: In-memory cache was cleared despite platform failure.
        // getKeyContainer() checks the cache first, so null means cleared.
        final containerAfter = await storage.getKeyContainer();
        expect(containerAfter, isNull);
      },
    );
  });

  group('SecureKeyStorage deleteBackupKey error propagation', () {
    late SecureKeyStorage storage;

    setUp(() async {
      setupTestEnvironment();
      storage = SecureKeyStorage();
      await storage.initialize();
    });

    test(
      'deleteBackupKey throws SecureKeyStorageException when platform '
      'deletion fails',
      () async {
        // Arrange: Make the fallback storage throw on delete
        const secureStorageChannel = MethodChannel(
          'plugins.it_nomads.com/flutter_secure_storage',
        );
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(secureStorageChannel, (call) async {
              if (call.method == 'delete') {
                throw PlatformException(
                  code: 'ERROR',
                  message: 'Simulated platform deletion failure',
                );
              }
              switch (call.method) {
                case 'read':
                  return null;
                case 'containsKey':
                  return false;
                default:
                  return null;
              }
            });

        // Act & Assert
        await expectLater(
          storage.deleteBackupKey(),
          throwsA(
            isA<SecureKeyStorageException>().having(
              (e) => e.code,
              'code',
              'platform_deletion_failed',
            ),
          ),
        );
      },
    );
  });
}
