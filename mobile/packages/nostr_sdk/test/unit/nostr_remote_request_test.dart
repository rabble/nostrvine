// ABOUTME: Tests that NIP-46 request ids are unguessable (#7344).

import 'package:nostr_sdk/nip46/nostr_remote_request.dart';
import 'package:test/test.dart';

void main() {
  group('NostrRemoteRequest', () {
    group('id', () {
      test('is a 12-char string from the name alphabet', () {
        final request = NostrRemoteRequest('get_public_key', []);
        expect(request.id, hasLength(12));
        expect(RegExp(r'^[0-9a-z]{12}$').hasMatch(request.id), isTrue);
      });

      test('is unique across many mints (secure RNG, not a fixed stream)', () {
        final ids = {
          for (var i = 0; i < 1000; i++)
            NostrRemoteRequest('sign_event', const []).id,
        };
        // A fresh unseeded Random per call could collide within a run; a CSPRNG
        // makes 1000 distinct 62-bit-entropy ids effectively certain.
        expect(ids.length, 1000);
      });
    });
  });
}
