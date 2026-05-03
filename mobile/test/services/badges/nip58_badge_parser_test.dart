import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/badges/nip58_badge_parser.dart';

void main() {
  group('Nip58BadgeParser', () {
    test('parses current profile badges a/e pairs from kind 10008', () {
      final event = _event(
        id: _eventId(1),
        pubkey: _pubkey(1),
        kind: 10008,
        tags: [
          ['a', '30009:${_pubkey(2)}:daily-diviner'],
          ['e', _eventId(2), 'wss://relay.divine.video'],
          ['a', '30009:${_pubkey(3)}:weekly-diviner'],
          ['e', _eventId(3)],
        ],
      );

      final profileBadges = Nip58BadgeParser.parseProfileBadges(event);

      expect(profileBadges, isNotNull);
      expect(profileBadges!.isLegacyProfileBadges, isFalse);
      expect(profileBadges.badges, hasLength(2));
      expect(
        profileBadges.badges.first.definitionCoordinate,
        '30009:${_pubkey(2)}:daily-diviner',
      );
      expect(profileBadges.badges.first.awardEventId, _eventId(2));
      expect(profileBadges.badges.first.awardRelay, 'wss://relay.divine.video');
      expect(
        profileBadges.badges.last.definitionCoordinate,
        '30009:${_pubkey(3)}:weekly-diviner',
      );
      expect(profileBadges.badges.last.awardEventId, _eventId(3));
      expect(profileBadges.badges.last.awardRelay, isNull);
    });

    test('parses legacy profile badges from kind 30008 profile_badges', () {
      final event = _event(
        id: _eventId(4),
        pubkey: _pubkey(1),
        kind: 30008,
        tags: [
          ['d', 'profile_badges'],
          ['a', '30009:${_pubkey(2)}:daily-diviner'],
          ['e', _eventId(5)],
        ],
      );

      final profileBadges = Nip58BadgeParser.parseProfileBadges(event);

      expect(profileBadges, isNotNull);
      expect(profileBadges!.isLegacyProfileBadges, isTrue);
      expect(
        profileBadges.badges.single.definitionCoordinate,
        '30009:${_pubkey(2)}:daily-diviner',
      );
      expect(profileBadges.badges.single.awardEventId, _eventId(5));
    });

    test('ignores orphan profile badge a and e tags', () {
      final event = _event(
        id: _eventId(6),
        pubkey: _pubkey(1),
        kind: 10008,
        tags: [
          ['a', '30009:${_pubkey(2)}:orphan-a'],
          ['t', 'not-a-badge'],
          ['e', _eventId(7)],
          ['a', '30009:${_pubkey(2)}:paired'],
          ['e', _eventId(8)],
        ],
      );

      final profileBadges = Nip58BadgeParser.parseProfileBadges(event);

      expect(profileBadges, isNotNull);
      expect(profileBadges!.badges, hasLength(1));
      expect(
        profileBadges.badges.single.definitionCoordinate,
        '30009:${_pubkey(2)}:paired',
      );
      expect(profileBadges.badges.single.awardEventId, _eventId(8));
    });

    test('parses badge award definition coordinate and recipients', () {
      final event = _event(
        id: _eventId(9),
        pubkey: _pubkey(10),
        kind: EventKind.badgeAward,
        tags: [
          ['a', '30009:${_pubkey(10)}:diviner-of-the-day'],
          ['p', _pubkey(1), 'wss://relay.divine.video'],
          ['p', _pubkey(2)],
        ],
      );

      final award = Nip58BadgeParser.parseAward(event);

      expect(award, isNotNull);
      expect(
        award!.definitionCoordinate,
        '30009:${_pubkey(10)}:diviner-of-the-day',
      );
      expect(award.recipientPubkeys, [_pubkey(1), _pubkey(2)]);
      expect(award.event, event);
    });

    test('returns null for malformed badge awards', () {
      final event = _event(
        id: _eventId(10),
        pubkey: _pubkey(10),
        kind: EventKind.badgeAward,
        tags: [
          ['p', _pubkey(1)],
        ],
      );

      expect(Nip58BadgeParser.parseAward(event), isNull);
    });

    test('parses badge definition display fields', () {
      final event = _event(
        id: _eventId(11),
        pubkey: _pubkey(10),
        kind: EventKind.badgeDefinition,
        tags: [
          ['d', 'diviner-of-the-day'],
          ['name', 'Diviner of the Day'],
          ['description', 'Awarded for the loudest daily loops.'],
          ['image', 'https://media.divine.video/badge.png', '1024x1024'],
          ['thumb', 'https://media.divine.video/badge-256.png', '256x256'],
          ['thumb', 'https://media.divine.video/badge-64.png', '64x64'],
        ],
      );

      final definition = Nip58BadgeParser.parseDefinition(event);

      expect(definition, isNotNull);
      expect(definition!.coordinate, '30009:${_pubkey(10)}:diviner-of-the-day');
      expect(definition.name, 'Diviner of the Day');
      expect(definition.description, 'Awarded for the loudest daily loops.');
      expect(definition.imageUrl, 'https://media.divine.video/badge.png');
      expect(definition.thumbnails, [
        'https://media.divine.video/badge-256.png',
        'https://media.divine.video/badge-64.png',
      ]);
    });
  });
}

Event _event({
  required String id,
  required String pubkey,
  required int kind,
  required List<List<String>> tags,
  int createdAt = 1000,
  String content = '',
}) {
  return Event.fromJson({
    'id': id,
    'pubkey': pubkey,
    'created_at': createdAt,
    'kind': kind,
    'tags': tags,
    'content': content,
    'sig': '',
  });
}

String _eventId(int seed) => seed.toRadixString(16).padLeft(64, '0');

String _pubkey(int seed) => (seed + 100).toRadixString(16).padLeft(64, '0');
