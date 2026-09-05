// ABOUTME: Pins that normalizeToHex canonicalizes hex casing so every
// ABOUTME: consumer agrees on identity regardless of deep-link encoding, and
// ABOUTME: that withoutPublicIdentifier excludes by resolved hex, not by text

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

  group('withoutPublicIdentifier', () {
    const otherHex =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

    // A draft written before the collaborator picker excluded the viewer can
    // hold the creator in any encoding it was saved with, so exclusion has to
    // resolve both sides rather than compare the stored text.
    test('removes an entry stored in a different encoding', () {
      expect(
        withoutPublicIdentifier({
          selfHex,
          selfHex.toUpperCase(),
          NostrKeyUtils.encodePubKey(selfHex),
          otherHex,
        }, selfHex),
        {otherHex},
      );
    });

    test('resolves an npub passed as the excluded identifier', () {
      expect(
        withoutPublicIdentifier({
          selfHex,
          otherHex,
        }, NostrKeyUtils.encodePubKey(selfHex)),
        {otherHex},
      );
    });

    test('leaves surviving entries in their original representation', () {
      final npub = NostrKeyUtils.encodePubKey(otherHex);
      expect(withoutPublicIdentifier({npub}, selfHex), {npub});
    });

    // restoreFromDraft passes `currentPublicKeyHex ?? ''`, so a draft restored
    // while signed out must keep every collaborator rather than drop them all.
    test('keeps every entry when the excluded identifier is empty', () {
      expect(withoutPublicIdentifier({selfHex, otherHex}, ''), {
        selfHex,
        otherHex,
      });
    });

    test('keeps every entry when the excluded identifier is unresolvable', () {
      expect(withoutPublicIdentifier({selfHex, otherHex}, 'not-a-pubkey'), {
        selfHex,
        otherHex,
      });
    });

    // Boundary validation belongs to the caller, so an unresolvable entry
    // survives instead of being silently dropped here.
    test('preserves an entry that does not resolve to a pubkey', () {
      expect(withoutPublicIdentifier({'not-a-pubkey', selfHex}, selfHex), {
        'not-a-pubkey',
      });
    });

    test('returns an empty set when every entry is the excluded identity', () {
      expect(
        withoutPublicIdentifier({
          selfHex,
          NostrKeyUtils.encodePubKey(selfHex),
        }, selfHex),
        isEmpty,
      );
    });
  });
}
