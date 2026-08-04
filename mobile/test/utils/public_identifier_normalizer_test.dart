// ABOUTME: Pins that normalizeToHex canonicalizes hex casing so every
// ABOUTME: consumer agrees on identity regardless of deep-link encoding

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/public_identifier_normalizer.dart';

void main() {
  const selfHex =
      'abcdef11111111111111111111111111111111111111111111111111111111ff';

  group('normalizeToHex', () {
    // The profile body decides own-vs-other by raw hex equality
    // (profile_screen_router.dart `userIdHex == currentUserHex`), while
    // routeIdentifiesUser compares case-insensitively. Canonicalizing here is
    // what keeps the two from disagreeing on an uppercase-hex deep link.
    test('lowercases an uppercase hex identifier', () {
      expect(normalizeToHex(selfHex.toUpperCase()), selfHex);
    });

    test('returns lowercase hex unchanged', () {
      expect(normalizeToHex(selfHex), selfHex);
    });

    test('decodes an npub to the same canonical hex', () {
      expect(normalizeToHex(NostrKeyUtils.encodePubKey(selfHex)), selfHex);
    });
  });
}
