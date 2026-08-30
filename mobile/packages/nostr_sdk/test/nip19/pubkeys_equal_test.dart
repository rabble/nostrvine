// ABOUTME: Tests the shared case-insensitive Nostr pubkey comparison.
// ABOUTME: Pins equal and unequal hexadecimal-key behavior.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nip19/pubkeys_equal.dart';

void main() {
  group('pubkeysEqual', () {
    test('matches hexadecimal pubkeys case-insensitively', () {
      expect(pubkeysEqual('a1b2', 'A1B2'), isTrue);
    });

    test('rejects different pubkeys', () {
      expect(pubkeysEqual('a1b2', 'a1b3'), isFalse);
    });
  });
}
