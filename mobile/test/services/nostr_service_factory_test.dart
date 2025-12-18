// ABOUTME: Tests for NostrServiceFactory that creates NostrClient instances
// ABOUTME: Validates client creation with direct key container

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
      test('creates client with valid key container', () {
        final mockKeyContainer = _MockSecureKeyContainer();
        when(() => mockKeyContainer.publicKeyHex).thenReturn(testPublicKey);

        final client = NostrServiceFactory.create(
          keyContainer: mockKeyContainer,
        );

        expect(client, isA<NostrClient>());
        expect(client.publicKey, equals(testPublicKey));
      });

      test('creates client with null key container (read-only mode)', () {
        // This should NOT throw - it should create a read-only client
        final client = NostrServiceFactory.create();

        expect(client, isA<NostrClient>());
        expect(client.publicKey, isEmpty);
      });

      test(
        'creates client with empty public key when keyContainer is null',
        () {
          final client = NostrServiceFactory.create(keyContainer: null);

          expect(client, isA<NostrClient>());
          expect(client.publicKey, isEmpty);
        },
      );
    });
  });
}
