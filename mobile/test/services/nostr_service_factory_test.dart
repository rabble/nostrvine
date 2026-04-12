import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/nostr_identity.dart';
import 'package:openvine/services/nostr_service_factory.dart';

class _MockSecureKeyContainer extends Mock implements SecureKeyContainer {}

class _MockNostrSigner extends Mock implements NostrSigner {}

void main() {
  const testPublicKey =
      '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd';

  group('NostrServiceFactory', () {
    group('create', () {
      test('creates client with LocalNostrIdentity signer', () {
        final mockKeyContainer = _MockSecureKeyContainer();
        when(() => mockKeyContainer.publicKeyHex).thenReturn(testPublicKey);
        when(() => mockKeyContainer.isDisposed).thenReturn(false);

        final signer = LocalNostrIdentity(keyContainer: mockKeyContainer);
        final client = NostrServiceFactory.create(signer: signer);

        expect(client, isA<NostrClient>());
        // Public key is empty before initialize() - signer is source of truth
        expect(client.publicKey, isEmpty);
      });

      test('creates client with mock signer', () {
        final mockSigner = _MockNostrSigner();
        when(mockSigner.getPublicKey).thenAnswer((_) async => testPublicKey);

        final client = NostrServiceFactory.create(signer: mockSigner);

        expect(client, isA<NostrClient>());
        expect(client.publicKey, isEmpty);
      });
    });
  });
}
