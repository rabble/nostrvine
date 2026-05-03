import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/badges/badge_repository.dart';
import 'package:openvine/services/badges/nip58_badge_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

void main() {
  group('BadgeRepository', () {
    late _MockNostrClient nostrClient;
    late SharedPreferences preferences;
    late Event? Function() lastSignedEvent;
    late BadgeRepository repository;
    late Event? signedEvent;

    setUpAll(() {
      registerFallbackValue(<Filter>[]);
      registerFallbackValue(_event(id: _eventId(999), pubkey: _pubkey(999)));
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      preferences = await SharedPreferences.getInstance();
      nostrClient = _MockNostrClient();
      signedEvent = null;
      lastSignedEvent = () => signedEvent;

      when(() => nostrClient.queryEvents(any())).thenAnswer((_) async => []);
      when(() => nostrClient.publishEvent(any())).thenAnswer(
        (invocation) async => invocation.positionalArguments.single as Event,
      );

      repository = BadgeRepository(
        nostrClient: nostrClient,
        sharedPreferences: preferences,
        currentPubkey: () => _pubkey(1),
        signEvent:
            ({
              required int kind,
              required String content,
              required List<List<String>> tags,
            }) async {
              signedEvent = _event(
                id: _eventId(900 + kind),
                pubkey: _pubkey(1),
                kind: kind,
                tags: tags,
                content: content,
              );
              return signedEvent;
            },
      );
    });

    test('loadAwardedBadges marks awards accepted by profile badges', () async {
      final award = _awardEvent(
        id: _eventId(1),
        issuerPubkey: _pubkey(2),
        definitionCoordinate: '30009:${_pubkey(2)}:daily-diviner',
        recipients: [_pubkey(1)],
      );
      final profileBadges = _profileBadgesEvent(
        id: _eventId(2),
        pubkey: _pubkey(1),
        tags: [
          ['a', '30009:${_pubkey(2)}:daily-diviner'],
          ['e', _eventId(1)],
        ],
      );
      final definition = _definitionEvent(
        pubkey: _pubkey(2),
        dTag: 'daily-diviner',
        name: 'Diviner of the Day',
      );
      _stubQueries(nostrClient, {
        'awarded': [award],
        'profileCurrent:${_pubkey(1)}': [profileBadges],
        'definition:30009:${_pubkey(2)}:daily-diviner': [definition],
      });

      final awards = await repository.loadAwardedBadges();

      expect(awards, hasLength(1));
      expect(awards.single.award.event.id, _eventId(1));
      expect(awards.single.isAccepted, isTrue);
      expect(awards.single.definition?.name, 'Diviner of the Day');
      expect(awards.single.isHidden, isFalse);
    });

    test(
      'loadAwardedBadges reads legacy profile badges compatibility',
      () async {
        final award = _awardEvent(
          id: _eventId(3),
          issuerPubkey: _pubkey(2),
          definitionCoordinate: '30009:${_pubkey(2)}:legacy-diviner',
          recipients: [_pubkey(1)],
        );
        final legacyProfileBadges = _event(
          id: _eventId(4),
          pubkey: _pubkey(1),
          kind: EventKind.badgeSet,
          tags: [
            ['d', 'profile_badges'],
            ['a', '30009:${_pubkey(2)}:legacy-diviner'],
            ['e', _eventId(3)],
          ],
        );
        _stubQueries(nostrClient, {
          'awarded': [award],
          'profileLegacy:${_pubkey(1)}': [legacyProfileBadges],
        });

        final awards = await repository.loadAwardedBadges();

        expect(awards.single.isAccepted, isTrue);
      },
    );

    test('acceptAward publishes a kind 10008 profile badges event', () async {
      final award = _awardEvent(
        id: _eventId(5),
        issuerPubkey: _pubkey(2),
        definitionCoordinate: '30009:${_pubkey(2)}:daily-diviner',
        recipients: [_pubkey(1)],
      );
      final existingProfileBadges = _profileBadgesEvent(
        id: _eventId(6),
        pubkey: _pubkey(1),
        tags: [
          ['a', '30009:${_pubkey(3)}:weekly-diviner'],
          ['e', _eventId(7)],
        ],
      );
      _stubQueries(nostrClient, {
        'profileCurrent:${_pubkey(1)}': [existingProfileBadges],
      });

      await repository.acceptAward(
        BadgeAwardViewData(award: Nip58BadgeParser.parseAward(award)!),
      );

      final event = lastSignedEvent();
      expect(event, isNotNull);
      expect(event!.kind, EventKind.profileBadges);
      expect(event.tags, [
        ['a', '30009:${_pubkey(3)}:weekly-diviner'],
        ['e', _eventId(7)],
        ['a', '30009:${_pubkey(2)}:daily-diviner'],
        ['e', _eventId(5)],
      ]);
      verify(() => nostrClient.publishEvent(event)).called(1);
    });

    test('removeAward publishes kind 10008 without the removed pair', () async {
      final award = _awardEvent(
        id: _eventId(8),
        issuerPubkey: _pubkey(2),
        definitionCoordinate: '30009:${_pubkey(2)}:daily-diviner',
        recipients: [_pubkey(1)],
      );
      final existingProfileBadges = _profileBadgesEvent(
        id: _eventId(9),
        pubkey: _pubkey(1),
        tags: [
          ['a', '30009:${_pubkey(2)}:daily-diviner'],
          ['e', _eventId(8)],
          ['a', '30009:${_pubkey(3)}:weekly-diviner'],
          ['e', _eventId(10)],
        ],
      );
      _stubQueries(nostrClient, {
        'profileCurrent:${_pubkey(1)}': [existingProfileBadges],
      });

      await repository.removeAward(
        BadgeAwardViewData(award: Nip58BadgeParser.parseAward(award)!),
      );

      final event = lastSignedEvent();
      expect(event, isNotNull);
      expect(event!.kind, EventKind.profileBadges);
      expect(event.tags, [
        ['a', '30009:${_pubkey(3)}:weekly-diviner'],
        ['e', _eventId(10)],
      ]);
      verify(() => nostrClient.publishEvent(event)).called(1);
    });

    test('hideAward stores a local per-user dismissal', () async {
      final award = _awardEvent(
        id: _eventId(11),
        issuerPubkey: _pubkey(2),
        definitionCoordinate: '30009:${_pubkey(2)}:daily-diviner',
        recipients: [_pubkey(1)],
      );
      _stubQueries(nostrClient, {
        'awarded': [award],
      });

      await repository.hideAward(_eventId(11));

      final awards = await repository.loadAwardedBadges();
      expect(awards, isEmpty);
      expect(
        preferences.getStringList('dismissed_badge_awards_${_pubkey(1)}'),
        [_eventId(11)],
      );
    });

    test(
      'loadIssuedBadges marks recipients accepted when they publish award',
      () async {
        final issuedAward = _awardEvent(
          id: _eventId(12),
          issuerPubkey: _pubkey(1),
          definitionCoordinate: '30009:${_pubkey(1)}:creator-badge',
          recipients: [_pubkey(2)],
        );
        final recipientProfileBadges = _profileBadgesEvent(
          id: _eventId(13),
          pubkey: _pubkey(2),
          tags: [
            ['a', '30009:${_pubkey(1)}:creator-badge'],
            ['e', _eventId(12)],
          ],
        );
        _stubQueries(nostrClient, {
          'issued': [issuedAward],
          'profileCurrent:${_pubkey(2)}': [recipientProfileBadges],
        });

        final issued = await repository.loadIssuedBadges();

        expect(issued, hasLength(1));
        expect(issued.single.award.event.id, _eventId(12));
        expect(issued.single.recipients.single.pubkey, _pubkey(2));
        expect(issued.single.recipients.single.isAccepted, isTrue);
      },
    );
  });
}

void _stubQueries(
  _MockNostrClient nostrClient,
  Map<String, List<Event>> eventsByQueryKey,
) {
  when(() => nostrClient.queryEvents(any())).thenAnswer((invocation) async {
    final filters = invocation.positionalArguments.single as List<Filter>;
    final filter = filters.single;
    final key = _queryKey(filter);
    return eventsByQueryKey[key] ?? const <Event>[];
  });
}

String _queryKey(Filter filter) {
  if (filter.kinds?.contains(EventKind.badgeAward) == true &&
      filter.p?.contains(_pubkey(1)) == true) {
    return 'awarded';
  }
  if (filter.kinds?.contains(EventKind.badgeAward) == true &&
      filter.authors?.contains(_pubkey(1)) == true) {
    return 'issued';
  }
  if (filter.kinds?.contains(EventKind.profileBadges) == true &&
      filter.authors?.isNotEmpty == true) {
    return 'profileCurrent:${filter.authors!.single}';
  }
  if (filter.kinds?.contains(EventKind.badgeSet) == true &&
      filter.authors?.isNotEmpty == true &&
      filter.d?.contains('profile_badges') == true) {
    return 'profileLegacy:${filter.authors!.single}';
  }
  if (filter.kinds?.contains(EventKind.badgeDefinition) == true &&
      filter.authors?.isNotEmpty == true &&
      filter.d?.isNotEmpty == true) {
    return 'definition:${EventKind.badgeDefinition}:${filter.authors!.single}:${filter.d!.single}';
  }
  return 'unknown';
}

Event _awardEvent({
  required String id,
  required String issuerPubkey,
  required String definitionCoordinate,
  required List<String> recipients,
}) {
  return _event(
    id: id,
    pubkey: issuerPubkey,
    kind: EventKind.badgeAward,
    tags: [
      ['a', definitionCoordinate],
      for (final recipient in recipients) ['p', recipient],
    ],
  );
}

Event _profileBadgesEvent({
  required String id,
  required String pubkey,
  required List<List<String>> tags,
}) {
  return _event(
    id: id,
    pubkey: pubkey,
    kind: EventKind.profileBadges,
    tags: tags,
  );
}

Event _definitionEvent({
  required String pubkey,
  required String dTag,
  required String name,
}) {
  return _event(
    id: _eventId(100),
    pubkey: pubkey,
    kind: EventKind.badgeDefinition,
    tags: [
      ['d', dTag],
      ['name', name],
    ],
  );
}

Event _event({
  required String id,
  required String pubkey,
  int kind = 1,
  List<List<String>> tags = const [],
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
