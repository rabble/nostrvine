// ABOUTME: Tests for DmSharedVideoRef value object + JSON round-trip.

import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group(DmSharedVideoRef, () {
    const addressable = DmSharedVideoRef(
      coordinateOrId: '34236:abc123:my-reel',
      videoKind: DmSharedVideoKind.addressableShortVideo,
      relayHint: 'wss://relay.divine.video',
      nip19: 'naddr1xyz',
    );

    final regular = DmSharedVideoRef(
      coordinateOrId: 'a' * 64, // 64-hex event id placeholder
      videoKind: DmSharedVideoKind.shortVideo,
      relayHint: 'wss://relay.divine.video',
      authorPubkey: 'b' * 64,
      nip19: 'nevent1xyz',
    );

    test('isAddressable reflects the kind', () {
      expect(addressable.isAddressable, isTrue);
      expect(regular.isAddressable, isFalse);
    });

    test('DmSharedVideoKind.fromKind maps supported video kinds', () {
      expect(
        DmSharedVideoKind.fromKind(34236),
        equals(DmSharedVideoKind.addressableShortVideo),
      );
      expect(
        DmSharedVideoKind.fromKind(34235),
        equals(DmSharedVideoKind.addressableNormalVideo),
      );
      expect(
        DmSharedVideoKind.fromKind(22),
        equals(DmSharedVideoKind.shortVideo),
      );
      expect(
        DmSharedVideoKind.fromKind(1),
        equals(DmSharedVideoKind.shortVideo),
      );
    });

    test('round-trips through JSON (addressable)', () {
      final restored = DmSharedVideoRef.fromJson(addressable.toJson());
      expect(restored, equals(addressable));
    });

    test('round-trips through JSON (addressable normal video)', () {
      const ref = DmSharedVideoRef(
        coordinateOrId: '34235:abc123:normal-reel',
        videoKind: DmSharedVideoKind.addressableNormalVideo,
      );
      final restored = DmSharedVideoRef.fromJson(ref.toJson());
      expect(restored, equals(ref));
      expect(restored!.isAddressable, isTrue);
    });

    test('round-trips through JSON (regular, with author)', () {
      final json = regular.toJson();
      expect(json['kind'], equals(22));
      expect(json['authorPubkey'], equals('b' * 64));
      expect(DmSharedVideoRef.fromJson(json), equals(regular));
    });

    test('omits null optionals from JSON', () {
      const minimal = DmSharedVideoRef(
        coordinateOrId: '34236:abc:d',
        videoKind: DmSharedVideoKind.addressableShortVideo,
      );
      final json = minimal.toJson();
      expect(json.containsKey('relayHint'), isFalse);
      expect(json.containsKey('authorPubkey'), isFalse);
      expect(json.containsKey('nip19'), isFalse);
    });

    test('fromJson returns null for malformed maps', () {
      expect(DmSharedVideoRef.fromJson(<String, dynamic>{}), isNull);
      expect(
        DmSharedVideoRef.fromJson(<String, dynamic>{'coordinateOrId': ''}),
        isNull,
      );
      expect(
        DmSharedVideoRef.fromJson(<String, dynamic>{'coordinateOrId': 'x'}),
        isNull,
      );
    });

    group('dTag', () {
      test('extracts the <d> from an addressable coordinate', () {
        expect(addressable.dTag, equals('my-reel'));
      });

      test('works for an addressable normal video (kind 34235)', () {
        const ref = DmSharedVideoRef(
          coordinateOrId: '34235:author:normal-reel',
          videoKind: DmSharedVideoKind.addressableNormalVideo,
        );
        expect(ref.dTag, equals('normal-reel'));
      });

      test('is null for a regular ref', () {
        expect(regular.dTag, isNull);
      });

      test('is null for a malformed addressable coordinate', () {
        const ref = DmSharedVideoRef(
          coordinateOrId: '34236:onlyauthor',
          videoKind: DmSharedVideoKind.addressableShortVideo,
        );
        expect(ref.dTag, isNull);
      });

      test('rejoins a <d> identifier that contains a colon', () {
        const ref = DmSharedVideoRef(
          coordinateOrId: '34236:abc:my:reel',
          videoKind: DmSharedVideoKind.addressableShortVideo,
        );
        expect(ref.dTag, equals('my:reel'));
      });
    });

    group('eventId', () {
      test('is the coordinateOrId for a regular ref', () {
        expect(regular.eventId, equals('a' * 64));
      });

      test('is null for an addressable ref', () {
        expect(addressable.eventId, isNull);
      });
    });
  });
}
