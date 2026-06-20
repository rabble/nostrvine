// ABOUTME: Tests for DmSharedVideoCitation build (q tag + nostr URI) + parse.

import 'package:dm_repository/src/dm_shared_video_citation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/nip19/nip19_tlv.dart';

void main() {
  // Deterministic 64-hex fixtures.
  final author = 'a' * 64;
  final eventId = 'b' * 64;
  const dTag = 'my-reel-123';
  const relay = 'wss://relay.example';

  group('DmSharedVideoCitation.build', () {
    test('addressable (34236) → coordinate q tag + naddr, no 4th element', () {
      final citation = DmSharedVideoCitation.build(
        videoKind: 34236,
        authorPubkey: author,
        relayHint: relay,
        dTag: dTag,
      )!;

      expect(citation.qTag, equals(['q', '34236:$author:$dTag', relay]));
      expect(citation.qTag.length, equals(3)); // no 4th pubkey element
      expect(citation.nostrUri, startsWith('nostr:naddr1'));

      final decoded = NIP19Tlv.decodeNaddr(
        citation.nostrUri.substring('nostr:'.length),
      )!;
      expect(decoded.id, equals(dTag));
      expect(decoded.author, equals(author));
      expect(decoded.kind, equals(34236));
      expect(decoded.relays, contains(relay));
    });

    test('regular (22) → id q tag with 4th author element + nevent', () {
      final citation = DmSharedVideoCitation.build(
        videoKind: 22,
        authorPubkey: author,
        relayHint: relay,
        eventId: eventId,
      )!;

      expect(citation.qTag, equals(['q', eventId, relay, author]));
      expect(citation.qTag.length, equals(4)); // 4th element present
      expect(citation.nostrUri, startsWith('nostr:nevent1'));

      final decoded = NIP19Tlv.decodeNevent(
        citation.nostrUri.substring('nostr:'.length),
      )!;
      expect(decoded.id, equals(eventId));
      expect(decoded.author, equals(author));
      expect(decoded.relays, contains(relay));
    });

    test('empty relay hint falls back to the Divine default', () {
      final citation = DmSharedVideoCitation.build(
        videoKind: 34236,
        authorPubkey: author,
        relayHint: '',
        dTag: dTag,
      )!;
      expect(citation.qTag[2], equals(DmShareConstants.defaultRelayHint));
    });

    test('returns null when addressable d-tag is missing', () {
      expect(
        DmSharedVideoCitation.build(
          videoKind: 34236,
          authorPubkey: author,
          relayHint: relay,
        ),
        isNull,
      );
    });

    test('returns null when regular event id is missing/invalid', () {
      expect(
        DmSharedVideoCitation.build(
          videoKind: 22,
          authorPubkey: author,
          relayHint: relay,
          eventId: 'not-hex',
        ),
        isNull,
      );
    });

    test('returns null when author pubkey is not 64-hex', () {
      expect(
        DmSharedVideoCitation.build(
          videoKind: 34236,
          authorPubkey: 'short',
          relayHint: relay,
          dTag: dTag,
        ),
        isNull,
      );
    });
  });

  group('DmSharedVideoCitation.parse', () {
    test('parses an addressable coordinate q tag', () {
      final ref = DmSharedVideoCitation.parse([
        ['p', author],
        ['q', '34236:$author:$dTag', relay],
      ]);
      expect(ref, isNotNull);
      expect(ref!.videoKind, equals(DmSharedVideoKind.addressableShortVideo));
      expect(ref.coordinateOrId, equals('34236:$author:$dTag'));
      expect(ref.relayHint, equals(relay));
      expect(ref.authorPubkey, equals(author));
      expect(ref.isAddressable, isTrue);
    });

    test('parses an addressable normal-video coordinate q tag', () {
      final ref = DmSharedVideoCitation.parse([
        ['q', '34235:$author:$dTag', relay],
      ]);
      expect(ref, isNotNull);
      expect(ref!.videoKind, equals(DmSharedVideoKind.addressableNormalVideo));
      expect(ref.coordinateOrId, equals('34235:$author:$dTag'));
      expect(ref.authorPubkey, equals(author));
      expect(ref.isAddressable, isTrue);
    });

    test('parses a regular event-id q tag with 4th author element', () {
      final ref = DmSharedVideoCitation.parse([
        ['q', eventId, relay, author],
      ]);
      expect(ref, isNotNull);
      expect(ref!.videoKind, equals(DmSharedVideoKind.shortVideo));
      expect(ref.coordinateOrId, equals(eventId));
      expect(ref.relayHint, equals(relay));
      expect(ref.authorPubkey, equals(author));
      expect(ref.isAddressable, isFalse);
    });

    test('returns null when there is no q tag', () {
      expect(
        DmSharedVideoCitation.parse([
          ['p', author],
          ['e', eventId],
        ]),
        isNull,
      );
    });

    test('returns null for a malformed q value', () {
      expect(
        DmSharedVideoCitation.parse([
          ['q', 'not-a-coordinate-or-id'],
        ]),
        isNull,
      );
      expect(
        DmSharedVideoCitation.parse([
          ['q', '1:$author:$dTag'],
        ]),
        isNull,
      );
      expect(DmSharedVideoCitation.parse([]), isNull);
    });

    test('round-trips build → parse for addressable', () {
      final citation = DmSharedVideoCitation.build(
        videoKind: 34236,
        authorPubkey: author,
        relayHint: relay,
        dTag: dTag,
      )!;
      final ref = DmSharedVideoCitation.parse([citation.qTag])!;
      expect(ref.coordinateOrId, equals('34236:$author:$dTag'));
      expect(ref.authorPubkey, equals(author));
      expect(ref.isAddressable, isTrue);
    });

    test('round-trips build → parse for addressable normal video', () {
      final citation = DmSharedVideoCitation.build(
        videoKind: 34235,
        authorPubkey: author,
        relayHint: relay,
        dTag: dTag,
      )!;
      final ref = DmSharedVideoCitation.parse([citation.qTag])!;
      expect(ref.coordinateOrId, equals('34235:$author:$dTag'));
      expect(ref.videoKind, equals(DmSharedVideoKind.addressableNormalVideo));
      expect(ref.authorPubkey, equals(author));
      expect(ref.isAddressable, isTrue);
    });
  });
}
