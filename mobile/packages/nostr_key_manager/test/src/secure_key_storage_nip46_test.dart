// ABOUTME: Tests for NIP-46 bunker key handling in SecureKeyStorage
// ABOUTME: Ensures bunker operations don't crash when feature is pending

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';

import '../test_setup.dart';

void main() {
  group('SecureKeyStorage - NIP-46 Bunker Error Handling', () {
    late SecureKeyStorage service;

    setUp(() {
      setupTestEnvironment();
      service = SecureKeyStorage(securityConfig: SecurityConfig.desktop);
    });

    tearDown(() {
      service.dispose();
    });

    test('authenticateWithBunker returns false on non-web platforms', () async {
      // Arrange
      const username = 'test@example.com';
      const password = 'testpassword123';
      const bunkerEndpoint = 'wss://bunker.example.com';

      // Act
      final result = await service.authenticateWithBunker(
        username: username,
        password: password,
        bunkerEndpoint: bunkerEndpoint,
      );

      // Assert - should return false on non-web platforms
      expect(result, isFalse);
    });

    test('isUsingBunker returns false when bunker not configured', () {
      // Act
      final isUsingBunker = service.isUsingBunker;

      // Assert
      expect(isUsingBunker, isFalse);
    });

    test(
      'signEventWithBunker returns null when bunker not available',
      () async {
        // Arrange
        final event = {
          'kind': 1,
          'content': 'test',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        };

        // Act
        final signedEvent = await service.signEventWithBunker(event);

        // Assert - should return null instead of crashing
        expect(signedEvent, isNull);
      },
    );

    test('disconnectBunker does not crash when bunker not configured', () {
      // Act & Assert - should not throw
      expect(() => service.disconnectBunker(), returnsNormally);
    });
  });
}
