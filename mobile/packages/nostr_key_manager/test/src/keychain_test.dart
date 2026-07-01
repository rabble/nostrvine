// ABOUTME: Unit tests for the Keychain key-pair wrapper.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';

void main() {
  group('Keychain', () {
    test('should generate valid key pair', () {
      final keychain = Keychain.generate();

      expect(keychain.private, isNotEmpty);
      expect(keychain.public, isNotEmpty);
      expect(keychain.private.length, equals(64)); // Hex format
      expect(keychain.public.length, equals(64));

      // Should be different
      expect(keychain.private, isNot(equals(keychain.public)));
    });

    test('should derive public key from private key', () {
      const privateKey =
          '5dab4a6cf3b8c9b8d3c5e6f7a8b9c0d1e2f3a4b5c6d7e8f9a0b1c2d3e4f5a6b7';

      final keychain = Keychain(privateKey);

      expect(keychain.private, equals(privateKey));
      expect(keychain.public, isNotEmpty);
      expect(keychain.public.length, equals(64));
    });
  });
}
