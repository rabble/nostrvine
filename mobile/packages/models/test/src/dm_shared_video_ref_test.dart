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
  });
}
