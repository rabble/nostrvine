// ABOUTME: Tests the shared inspired-by p-tag builder and creator resolution
// ABOUTME: used by the direct-upload and edit-video publish paths.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/inspired_by_tags.dart';
import 'package:openvine/utils/nostr_key_utils.dart';

void main() {
  const creatorPubkey =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
  const otherPubkey =
      'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
  const selfPubkey =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  group('buildInspiredByPTag', () {
    test('builds the inspired-by-marked p tag with the default relay', () {
      expect(
        buildInspiredByPTag(creatorPubkey),
        equals([
          'p',
          creatorPubkey,
          inspiredByPTagRelayHint,
          inspiredByPTagMarker,
        ]),
      );
    });

    test('uses the provided relay hint when non-empty', () {
      expect(
        buildInspiredByPTag(creatorPubkey, relayHint: 'wss://other.relay'),
        equals(['p', creatorPubkey, 'wss://other.relay', 'inspired-by']),
      );
    });

    test('falls back to the default relay when the hint is empty', () {
      expect(
        buildInspiredByPTag(creatorPubkey, relayHint: ''),
        equals([
          'p',
          creatorPubkey,
          inspiredByPTagRelayHint,
          inspiredByPTagMarker,
        ]),
      );
    });
  });

  group('resolveInspiredByCreatorHexes', () {
    test('resolves the creator from a well-formed addressable id', () {
      expect(
        resolveInspiredByCreatorHexes(
          addressableId: '34236:$creatorPubkey:some-d-tag',
        ),
        equals({creatorPubkey}),
      );
    });

    test('skips a malformed addressable id', () {
      expect(resolveInspiredByCreatorHexes(addressableId: '34236:'), isEmpty);
      expect(
        resolveInspiredByCreatorHexes(addressableId: 'not-a-coordinate'),
        isEmpty,
      );
      expect(
        resolveInspiredByCreatorHexes(addressableId: '34236:short-hex:d'),
        isEmpty,
      );
    });

    test('resolves the creator from a valid npub', () {
      final npub = NostrKeyUtils.encodePubKey(creatorPubkey);
      expect(
        resolveInspiredByCreatorHexes(npub: npub),
        equals({creatorPubkey}),
      );
    });

    test('skips an undecodable npub', () {
      expect(
        resolveInspiredByCreatorHexes(npub: 'npub1notavalidbech32string'),
        isEmpty,
      );
      expect(resolveInspiredByCreatorHexes(npub: ''), isEmpty);
      expect(resolveInspiredByCreatorHexes(), isEmpty);
    });

    test('resolves two distinct creators when both sources are present', () {
      final npub = NostrKeyUtils.encodePubKey(otherPubkey);
      expect(
        resolveInspiredByCreatorHexes(
          addressableId: '34236:$creatorPubkey:some-d-tag',
          npub: npub,
        ),
        equals({creatorPubkey, otherPubkey}),
      );
    });

    test('dedupes when both sources reference the same creator', () {
      final npub = NostrKeyUtils.encodePubKey(creatorPubkey);
      expect(
        resolveInspiredByCreatorHexes(
          addressableId: '34236:$creatorPubkey:some-d-tag',
          npub: npub,
        ),
        equals({creatorPubkey}),
      );
    });
  });

  group('buildInspiredByPTags', () {
    test('emits an inspired-by p tag for the resolved creator', () {
      expect(
        buildInspiredByPTags(
          existingTags: const [],
          addressableId: '34236:$creatorPubkey:some-d-tag',
          selfPubkey: selfPubkey,
        ),
        equals([buildInspiredByPTag(creatorPubkey)]),
      );
    });

    test("skips the publisher's own pubkey", () {
      expect(
        buildInspiredByPTags(
          existingTags: const [],
          addressableId: '34236:$selfPubkey:some-d-tag',
          selfPubkey: selfPubkey,
        ),
        isEmpty,
      );
    });

    test('skips a creator already carried by any existing p tag', () {
      expect(
        buildInspiredByPTags(
          existingTags: const [
            ['p', creatorPubkey, 'wss://relay.divine.video', 'collaborator'],
          ],
          addressableId: '34236:$creatorPubkey:some-d-tag',
          selfPubkey: selfPubkey,
        ),
        isEmpty,
      );
    });

    test('emits both creators on co-occurring video and person sources', () {
      final npub = NostrKeyUtils.encodePubKey(otherPubkey);
      final tags = buildInspiredByPTags(
        existingTags: const [],
        addressableId: '34236:$creatorPubkey:some-d-tag',
        npub: npub,
        selfPubkey: selfPubkey,
      );
      expect(tags, hasLength(2));
      expect(tags, anyElement(equals(buildInspiredByPTag(creatorPubkey))));
      expect(tags, anyElement(equals(buildInspiredByPTag(otherPubkey))));
    });
  });
}
