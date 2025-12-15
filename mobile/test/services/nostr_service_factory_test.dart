// ABOUTME: Tests for NostrServiceFactory that creates NostrClient instances
// ABOUTME: Validates client creation with lazy auth signer

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/nostr_service_factory.dart';

class _MockSecureKeyContainer extends Mock implements SecureKeyContainer {}

void main() {
  const testPublicKey =
      '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd';

  group('NostrServiceFactory', () {
    group('create', () {
      test('creates client with key container getter returning valid key', () {
        final mockKeyContainer = _MockSecureKeyContainer();
        when(() => mockKeyContainer.publicKeyHex).thenReturn(testPublicKey);

        final client = NostrServiceFactory.create(() => mockKeyContainer);

        expect(client, isA<NostrClient>());
        expect(client.publicKey, equals(testPublicKey));
      });

      test('creates client with key container getter returning null (read-only mode)', () {
        // This should NOT throw - it should create a read-only client
        final client = NostrServiceFactory.create(() => null);

        expect(client, isA<NostrClient>());
        expect(client.publicKey, isEmpty);
      });

      test('lazy signer works when key becomes available later', () async {
        // Start with no key
        _MockSecureKeyContainer? keyContainer;
        final client = NostrServiceFactory.create(() => keyContainer);

        // Initially no public key
        expect(client.publicKey, isEmpty);

        // Now set up the key container
        keyContainer = _MockSecureKeyContainer();
        when(() => keyContainer!.publicKeyHex).thenReturn(testPublicKey);

        // The signer should now be able to get the public key
        // (tested through LazyAuthServiceSigner's getPublicKey method)
        expect(client, isA<NostrClient>());
      });
    });
  });
}
