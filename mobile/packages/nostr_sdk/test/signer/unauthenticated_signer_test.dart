import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/signer/unauthenticated_signer.dart';

void main() {
  group(UnauthenticatedSigner, () {
    const signer = UnauthenticatedSigner();
    const peerPubkey =
        '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd';

    group('getPublicKey', () {
      test('returns the empty string, never null', () async {
        // Load-bearing: NostrClient.hasKeys is publicKey.isNotEmpty, and
        // Nostr.ensurePublicKey throws off the back of an empty cache.
        // Returning null here would still land as '' at the Nostr boundary
        // but would misrepresent the contract.
        expect(await signer.getPublicKey(), isEmpty);
      });
    });

    group('getRelays', () {
      test(
        'returns null because a keyless signer advertises no relays',
        () async {
          expect(await signer.getRelays(), isNull);
        },
      );
    });

    group('signEvent', () {
      test('throws StateError naming the missing identity', () async {
        final event = Event(peerPubkey, 1, const <List<String>>[], 'hi');

        await expectLater(
          signer.signEvent(event),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              allOf(contains('No identity'), contains('sign an event')),
            ),
          ),
        );
      });

      test('leaves the event unsigned', () async {
        final event = Event(peerPubkey, 1, const <List<String>>[], 'hi');

        await expectLater(signer.signEvent(event), throwsStateError);

        expect(event.sig, isEmpty);
      });
    });

    group('encrypt', () {
      test('throws StateError rather than returning null', () async {
        await expectLater(
          signer.encrypt(peerPubkey, 'plaintext'),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('NIP-04 encrypt'),
            ),
          ),
        );
      });
    });

    group('decrypt', () {
      test('throws StateError rather than returning null', () async {
        await expectLater(
          signer.decrypt(peerPubkey, 'ciphertext'),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('NIP-04 decrypt'),
            ),
          ),
        );
      });
    });

    group('nip44Encrypt', () {
      test('throws StateError rather than returning null', () async {
        await expectLater(
          signer.nip44Encrypt(peerPubkey, 'plaintext'),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('NIP-44 encrypt'),
            ),
          ),
        );
      });
    });

    group('nip44Decrypt', () {
      test('throws StateError rather than returning null', () async {
        await expectLater(
          signer.nip44Decrypt(peerPubkey, 'ciphertext'),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('NIP-44 decrypt'),
            ),
          ),
        );
      });
    });

    group('close', () {
      test('is a safe no-op and leaves the signer usable', () async {
        const disposable = UnauthenticatedSigner();

        disposable.close();

        expect(await disposable.getPublicKey(), isEmpty);
      });
    });
  });
}
