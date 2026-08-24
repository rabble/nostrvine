// ABOUTME: Tests the externally visible format of NIP-46 request ids.

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
    });
  });
}
