import 'package:badge_repository/badge_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
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
      when(() => nostrClient.publishEventAwaitOk(any())).thenAnswer((
        invocation,
      ) async {
        final event = invocation.positionalArguments.single as Event;
        return _acceptedPublishOutcome(event);
      });

      repository = BadgeRepository(
        nostrClient: nostrClient,
        sharedPreferences: preferences,
        currentPubkey: () => _pubkey(1),
        signEvent: ({required kind, required content, required tags}) async {
          return signedEvent = _event(
            id: _eventId(900 + kind),
            pubkey: _pubkey(1),
            kind: kind,
            tags: tags,
            content: content,
          );
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

    test(
      'loadAcceptedBadgesForProfile returns badge definitions for profile',
      () async {
        final award = _awardEvent(
          id: _eventId(15),
          issuerPubkey: _pubkey(3),
          definitionCoordinate: '30009:${_pubkey(3)}:daily-diviner',
          recipients: [_pubkey(2), _pubkey(4)],
        );
        final profileBadges = _profileBadgesEvent(
          id: _eventId(14),
          pubkey: _pubkey(2),
          tags: [
            ['a', '30009:${_pubkey(3)}:daily-diviner'],
            ['e', _eventId(15)],
          ],
        );
        final definition = _definitionEvent(
          pubkey: _pubkey(3),
          dTag: 'daily-diviner',
          name: 'Diviner of the Day',
          description: 'A daily badge for people who keep the network weird.',
          thumbnails: ['https://example.com/daily-diviner-thumb.png'],
        );
        _stubQueries(nostrClient, {
          'profileCurrent:${_pubkey(2)}': [profileBadges],
          'definition:30009:${_pubkey(3)}:daily-diviner': [definition],
          'ids:${_eventId(15)}': [award],
        });

        final badges = await repository.loadAcceptedBadgesForProfile(
          _pubkey(2),
        );

        expect(badges, hasLength(1));
        expect(
          badges.single.definitionCoordinate,
          '30009:${_pubkey(3)}:daily-diviner',
        );
        expect(badges.single.awardEventId, _eventId(15));
        expect(badges.single.displayName, 'Diviner of the Day');
        expect(
          badges.single.description,
          'A daily badge for people who keep the network weird.',
        );
        expect(
          badges.single.imageUrl,
          'https://example.com/daily-diviner-thumb.png',
        );
        expect(badges.single.award?.event.id, _eventId(15));
        expect(badges.single.issuerPubkey, _pubkey(3));
        expect(badges.single.recipientPubkeys, [_pubkey(2), _pubkey(4)]);
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
      verify(() => nostrClient.publishEventAwaitOk(event)).called(1);
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
      verify(() => nostrClient.publishEventAwaitOk(event)).called(1);
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

      // Still returned, flagged rather than dropped, so it can be restored.
      final awards = await repository.loadAwardedBadges();
      expect(awards.single.isHidden, isTrue);
      expect(
        preferences.getStringList('dismissed_badge_awards_${_pubkey(1)}'),
        [_eventId(11)],
      );
    });

    test('loadAwardedBadges loads each unique definition once', () async {
      final coordinate = '30009:${_pubkey(2)}:daily-diviner';
      final awardA = _awardEvent(
        id: _eventId(20),
        issuerPubkey: _pubkey(2),
        definitionCoordinate: coordinate,
        recipients: [_pubkey(1)],
      );
      final awardB = _awardEvent(
        id: _eventId(21),
        issuerPubkey: _pubkey(2),
        definitionCoordinate: coordinate,
        recipients: [_pubkey(1)],
      );
      final definition = _definitionEvent(
        pubkey: _pubkey(2),
        dTag: 'daily-diviner',
        name: 'Diviner of the Day',
      );
      final callCounts = _stubQueries(nostrClient, {
        'awarded': [awardA, awardB],
        'definition:$coordinate': [definition],
      });

      final awards = await repository.loadAwardedBadges();

      expect(awards, hasLength(2));
      expect(
        awards.map((award) => award.definition?.name),
        everyElement('Diviner of the Day'),
      );
      expect(callCounts['definition:$coordinate'], 1);
    });

    test(
      'loadIssuedBadges checks each unique recipient once across awards',
      () async {
        final coordinate = '30009:${_pubkey(1)}:creator-badge';
        final awardA = _awardEvent(
          id: _eventId(32),
          issuerPubkey: _pubkey(1),
          definitionCoordinate: coordinate,
          recipients: [_pubkey(2)],
        );
        final awardB = _awardEvent(
          id: _eventId(33),
          issuerPubkey: _pubkey(1),
          definitionCoordinate: coordinate,
          recipients: [_pubkey(2)],
        );
        final callCounts = _stubQueries(nostrClient, {
          'issued': [awardA, awardB],
        });

        final issued = await repository.loadIssuedBadges();

        // One badge, one recipient — the second award supersedes the first
        // instead of adding a row that can never resolve.
        expect(issued, hasLength(1));
        expect(issued.single.recipients, hasLength(1));
        expect(callCounts['profileCurrent:${_pubkey(2)}'], 1);
        expect(callCounts['profileLegacy:${_pubkey(2)}'], 1);
        expect(callCounts['definition:$coordinate'], 1);
      },
    );

    test(
      'loadDashboard shares the own profile badges lookup between halves',
      () async {
        final awardedAward = _awardEvent(
          id: _eventId(22),
          issuerPubkey: _pubkey(2),
          definitionCoordinate: '30009:${_pubkey(2)}:daily-diviner',
          recipients: [_pubkey(1)],
        );
        final selfIssuedAward = _awardEvent(
          id: _eventId(23),
          issuerPubkey: _pubkey(1),
          definitionCoordinate: '30009:${_pubkey(1)}:creator-badge',
          recipients: [_pubkey(1)],
        );
        final callCounts = _stubQueries(nostrClient, {
          'awarded': [awardedAward],
          'issued': [selfIssuedAward],
        });

        final dashboard = await repository.loadDashboard();

        expect(dashboard.awarded, hasLength(1));
        expect(dashboard.issued, hasLength(1));
        expect(callCounts['profileCurrent:${_pubkey(1)}'], 1);
        expect(callCounts['profileLegacy:${_pubkey(1)}'], 1);
      },
    );

    test('loadAwardedBadges rethrows when a definition query fails', () async {
      final coordinate = '30009:${_pubkey(2)}:daily-diviner';
      final award = _awardEvent(
        id: _eventId(24),
        issuerPubkey: _pubkey(2),
        definitionCoordinate: coordinate,
        recipients: [_pubkey(1)],
      );
      _stubQueries(
        nostrClient,
        {
          'awarded': [award],
        },
        errorsByQueryKey: {
          'definition:$coordinate': Exception('relay unavailable'),
        },
      );

      await expectLater(repository.loadAwardedBadges(), throwsException);
    });

    test(
      'loadIssuedBadges preserves recipient order under concurrency',
      () async {
        final coordinate = '30009:${_pubkey(1)}:creator-badge';
        final award = _awardEvent(
          id: _eventId(25),
          issuerPubkey: _pubkey(1),
          definitionCoordinate: coordinate,
          recipients: [_pubkey(2), _pubkey(3)],
        );
        final acceptance = _profileBadgesEvent(
          id: _eventId(26),
          pubkey: _pubkey(3),
          tags: [
            ['a', coordinate],
            ['e', _eventId(25)],
          ],
        );
        _stubQueries(
          nostrClient,
          {
            'issued': [award],
            'profileCurrent:${_pubkey(3)}': [acceptance],
          },
          delaysByQueryKey: {
            'profileCurrent:${_pubkey(2)}': const Duration(milliseconds: 40),
            'profileCurrent:${_pubkey(3)}': const Duration(milliseconds: 1),
          },
        );

        final issued = await repository.loadIssuedBadges();

        final recipients = issued.single.recipients;
        expect(
          [for (final recipient in recipients) recipient.pubkey],
          [_pubkey(2), _pubkey(3)],
        );
        expect(recipients[0].isAccepted, isFalse);
        expect(recipients[1].isAccepted, isTrue);
      },
    );

    test(
      'loadAwardedBadges uses newer legacy profile badges over older current',
      () async {
        final coordinate = '30009:${_pubkey(2)}:daily-diviner';
        final award = _awardEvent(
          id: _eventId(27),
          issuerPubkey: _pubkey(2),
          definitionCoordinate: coordinate,
          recipients: [_pubkey(1)],
        );
        final olderCurrentProfileBadges = _profileBadgesEvent(
          id: _eventId(28),
          pubkey: _pubkey(1),
          tags: [
            ['a', coordinate],
            ['e', _eventId(27)],
          ],
        );
        final newerLegacyWithoutAward = _event(
          id: _eventId(29),
          pubkey: _pubkey(1),
          kind: EventKind.badgeSet,
          createdAt: 2000,
          tags: [
            ['d', 'profile_badges'],
            ['a', '30009:${_pubkey(3)}:weekly-diviner'],
            ['e', _eventId(30)],
          ],
        );
        _stubQueries(nostrClient, {
          'awarded': [award],
          'profileCurrent:${_pubkey(1)}': [olderCurrentProfileBadges],
          'profileLegacy:${_pubkey(1)}': [newerLegacyWithoutAward],
        });

        final awards = await repository.loadAwardedBadges();

        expect(awards.single.isAccepted, isFalse);
      },
    );

    test(
      'loadAwardedBadges uses newer current profile badges over older legacy',
      () async {
        final coordinate = '30009:${_pubkey(2)}:daily-diviner';
        final award = _awardEvent(
          id: _eventId(34),
          issuerPubkey: _pubkey(2),
          definitionCoordinate: coordinate,
          recipients: [_pubkey(1)],
        );
        final newerCurrentProfileBadges = _profileBadgesEvent(
          id: _eventId(35),
          pubkey: _pubkey(1),
          createdAt: 3000,
          tags: [
            ['a', coordinate],
            ['e', _eventId(34)],
          ],
        );
        final olderLegacyWithoutAward = _event(
          id: _eventId(36),
          pubkey: _pubkey(1),
          kind: EventKind.badgeSet,
          createdAt: 2000,
          tags: [
            ['d', 'profile_badges'],
            ['a', '30009:${_pubkey(3)}:weekly-diviner'],
            ['e', _eventId(37)],
          ],
        );
        _stubQueries(nostrClient, {
          'awarded': [award],
          'profileCurrent:${_pubkey(1)}': [newerCurrentProfileBadges],
          'profileLegacy:${_pubkey(1)}': [olderLegacyWithoutAward],
        });

        final awards = await repository.loadAwardedBadges();

        expect(awards.single.isAccepted, isTrue);
      },
    );

    test(
      'loadAwardedBadges treats newer empty profile badges as authoritative',
      () async {
        final coordinate = '30009:${_pubkey(2)}:daily-diviner';
        final award = _awardEvent(
          id: _eventId(38),
          issuerPubkey: _pubkey(2),
          definitionCoordinate: coordinate,
          recipients: [_pubkey(1)],
        );
        final newerEmptyProfileBadges = _profileBadgesEvent(
          id: _eventId(39),
          pubkey: _pubkey(1),
          createdAt: 3000,
          tags: const [],
        );
        final olderLegacyWithAward = _event(
          id: _eventId(40),
          pubkey: _pubkey(1),
          kind: EventKind.badgeSet,
          createdAt: 2000,
          tags: [
            ['d', 'profile_badges'],
            ['a', coordinate],
            ['e', _eventId(38)],
          ],
        );
        _stubQueries(nostrClient, {
          'awarded': [award],
          'profileCurrent:${_pubkey(1)}': [newerEmptyProfileBadges],
          'profileLegacy:${_pubkey(1)}': [olderLegacyWithAward],
        });

        final awards = await repository.loadAwardedBadges();

        expect(awards.single.isAccepted, isFalse);
      },
    );

    test(
      'loadAwardedBadges prefers current profile badges when timestamps tie',
      () async {
        final coordinate = '30009:${_pubkey(2)}:daily-diviner';
        final award = _awardEvent(
          id: _eventId(41),
          issuerPubkey: _pubkey(2),
          definitionCoordinate: coordinate,
          recipients: [_pubkey(1)],
        );
        final currentProfileBadges = _profileBadgesEvent(
          id: _eventId(43),
          pubkey: _pubkey(1),
          createdAt: 3000,
          tags: [
            ['a', coordinate],
            ['e', _eventId(41)],
          ],
        );
        final legacyWithoutAward = _event(
          id: _eventId(42),
          pubkey: _pubkey(1),
          kind: EventKind.badgeSet,
          createdAt: 3000,
          tags: [
            ['d', 'profile_badges'],
            ['a', '30009:${_pubkey(3)}:weekly-diviner'],
            ['e', _eventId(44)],
          ],
        );
        _stubQueries(nostrClient, {
          'awarded': [award],
          'profileCurrent:${_pubkey(1)}': [currentProfileBadges],
          'profileLegacy:${_pubkey(1)}': [legacyWithoutAward],
        });

        final awards = await repository.loadAwardedBadges();

        expect(awards.single.isAccepted, isTrue);
      },
    );

    test(
      'loadAwardedBadges uses lowest event id when same-kind timestamps tie',
      () async {
        final coordinate = '30009:${_pubkey(2)}:daily-diviner';
        final award = _awardEvent(
          id: _eventId(46),
          issuerPubkey: _pubkey(2),
          definitionCoordinate: coordinate,
          recipients: [_pubkey(1)],
        );
        final higherIdWithAward = _profileBadgesEvent(
          id: _eventId(48),
          pubkey: _pubkey(1),
          createdAt: 3000,
          tags: [
            ['a', coordinate],
            ['e', _eventId(46)],
          ],
        );
        final lowerIdWithoutAward = _profileBadgesEvent(
          id: _eventId(47),
          pubkey: _pubkey(1),
          createdAt: 3000,
          tags: [
            ['a', '30009:${_pubkey(3)}:weekly-diviner'],
            ['e', _eventId(49)],
          ],
        );
        _stubQueries(nostrClient, {
          'awarded': [award],
          'profileCurrent:${_pubkey(1)}': [
            higherIdWithAward,
            lowerIdWithoutAward,
          ],
        });

        final awards = await repository.loadAwardedBadges();

        expect(awards.single.isAccepted, isFalse);
      },
    );

    test(
      'loadIssuedBadges caps recipient checks at recipientCheckLimit',
      () async {
        final award = _awardEvent(
          id: _eventId(31),
          issuerPubkey: _pubkey(1),
          definitionCoordinate: '30009:${_pubkey(1)}:creator-badge',
          recipients: [_pubkey(2), _pubkey(3), _pubkey(4)],
        );
        final callCounts = _stubQueries(nostrClient, {
          'issued': [award],
        });

        final issued = await repository.loadIssuedBadges(
          recipientCheckLimit: 2,
        );

        expect(
          [
            for (final recipient in issued.single.recipients) recipient.pubkey,
          ],
          [_pubkey(2), _pubkey(3)],
        );
        expect(callCounts['profileCurrent:${_pubkey(4)}'], isNull);
      },
    );

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
        expect(issued.single.coordinate, '30009:${_pubkey(1)}:creator-badge');
        expect(issued.single.recipients.single.pubkey, _pubkey(2));
        expect(issued.single.recipients.single.isAccepted, isTrue);
      },
    );

    test(
      'acceptAward keeps an already-accepted award and preserves relay hints',
      () async {
        final coordinate = '30009:${_pubkey(2)}:daily-diviner';
        final award = _awardEvent(
          id: _eventId(42),
          issuerPubkey: _pubkey(2),
          definitionCoordinate: coordinate,
          recipients: [_pubkey(1)],
        );
        final existingProfileBadges = _profileBadgesEvent(
          id: _eventId(43),
          pubkey: _pubkey(1),
          tags: [
            ['a', coordinate],
            ['e', _eventId(42), 'wss://relay.divine.video'],
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
        expect(event!.tags, [
          ['a', coordinate],
          ['e', _eventId(42), 'wss://relay.divine.video'],
        ]);
      },
    );

    test('acceptAward throws a StateError when signing fails', () async {
      final failingRepository = BadgeRepository(
        nostrClient: nostrClient,
        sharedPreferences: preferences,
        currentPubkey: () => _pubkey(1),
        signEvent: ({required kind, required content, required tags}) async =>
            null,
      );
      final award = _awardEvent(
        id: _eventId(44),
        issuerPubkey: _pubkey(2),
        definitionCoordinate: '30009:${_pubkey(2)}:daily-diviner',
        recipients: [_pubkey(1)],
      );

      await expectLater(
        failingRepository.acceptAward(
          BadgeAwardViewData(award: Nip58BadgeParser.parseAward(award)!),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'acceptAward throws a BadgePublishException when no relay accepts',
      () async {
        when(() => nostrClient.publishEventAwaitOk(any())).thenAnswer((
          invocation,
        ) async {
          final event = invocation.positionalArguments.single as Event;
          return _rejectedPublishOutcome(event);
        });
        final award = _awardEvent(
          id: _eventId(45),
          issuerPubkey: _pubkey(2),
          definitionCoordinate: '30009:${_pubkey(2)}:daily-diviner',
          recipients: [_pubkey(1)],
        );

        await expectLater(
          repository.acceptAward(
            BadgeAwardViewData(award: Nip58BadgeParser.parseAward(award)!),
          ),
          throwsA(
            isA<BadgePublishException>()
                .having(
                  (error) => error.outcome.acceptedBy,
                  'acceptedBy',
                  isEmpty,
                )
                .having(
                  (error) => error.toString(),
                  'toString',
                  contains('Could not publish profile badges event'),
                ),
          ),
        );
        verifyNever(() => nostrClient.publishEvent(any()));
      },
    );

    test('acceptAward throws a StateError without a current pubkey', () async {
      // A WORKING signer is injected so the only possible StateError source is
      // the missing-pubkey guard. If that guard were removed the signer would
      // succeed and this test would fail — so it can fail for the right reason
      // rather than being satisfied by an unrelated null-signer StateError.
      final anonymousRepository = BadgeRepository(
        nostrClient: nostrClient,
        sharedPreferences: preferences,
        currentPubkey: () => null,
        signEvent: ({required kind, required content, required tags}) async =>
            _event(
              id: _eventId(946),
              pubkey: _pubkey(1),
              kind: kind,
              tags: tags,
              content: content,
            ),
      );
      final award = _awardEvent(
        id: _eventId(46),
        issuerPubkey: _pubkey(2),
        definitionCoordinate: '30009:${_pubkey(2)}:daily-diviner',
        recipients: [_pubkey(1)],
      );

      await expectLater(
        anonymousRepository.acceptAward(
          BadgeAwardViewData(award: Nip58BadgeParser.parseAward(award)!),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'Cannot load badges without a current pubkey',
          ),
        ),
      );
    });

    test(
      'acceptAward bases new profile badges on the newest of multiple events',
      () async {
        final award = _awardEvent(
          id: _eventId(47),
          issuerPubkey: _pubkey(2),
          definitionCoordinate: '30009:${_pubkey(2)}:daily-diviner',
          recipients: [_pubkey(1)],
        );
        final olderProfileBadges = _event(
          id: _eventId(48),
          pubkey: _pubkey(1),
          kind: EventKind.profileBadges,
          createdAt: 500,
          tags: [
            ['a', '30009:${_pubkey(3)}:older-badge'],
            ['e', _eventId(49)],
          ],
        );
        final newerProfileBadges = _event(
          id: _eventId(50),
          pubkey: _pubkey(1),
          kind: EventKind.profileBadges,
          createdAt: 2000,
          tags: [
            ['a', '30009:${_pubkey(3)}:newer-badge'],
            ['e', _eventId(51)],
          ],
        );
        _stubQueries(nostrClient, {
          'profileCurrent:${_pubkey(1)}': [
            olderProfileBadges,
            newerProfileBadges,
          ],
        });

        await repository.acceptAward(
          BadgeAwardViewData(award: Nip58BadgeParser.parseAward(award)!),
        );

        final event = lastSignedEvent();
        expect(event, isNotNull);
        expect(event!.tags, [
          ['a', '30009:${_pubkey(3)}:newer-badge'],
          ['e', _eventId(51)],
          ['a', '30009:${_pubkey(2)}:daily-diviner'],
          ['e', _eventId(47)],
        ]);
      },
    );

    group('loadCreatedBadges', () {
      test(
        'keeps the newest definition per identifier, newest first',
        () async {
          _stubQueries(nostrClient, {
            'created:${_pubkey(1)}': [
              _definitionEvent(
                id: _eventId(60),
                pubkey: _pubkey(1),
                dTag: 'scene-stealer',
                name: 'Scene Stealer',
              ),
              _definitionEvent(
                id: _eventId(61),
                pubkey: _pubkey(1),
                dTag: 'scene-stealer',
                name: 'Scene Stealer v2',
                createdAt: 3000,
              ),
              _definitionEvent(
                id: _eventId(62),
                pubkey: _pubkey(1),
                dTag: 'loop-of-the-week',
                name: 'Loop of the Week',
                createdAt: 2000,
              ),
              // Missing the `d` tag, so it is not a definition at all.
              _event(
                id: _eventId(63),
                pubkey: _pubkey(1),
                kind: EventKind.badgeDefinition,
                tags: const [
                  ['name', 'Nameless'],
                ],
              ),
            ],
          });

          final created = await repository.loadCreatedBadges();

          expect(created.map((badge) => badge.displayName), [
            'Scene Stealer v2',
            'Loop of the Week',
          ]);
          expect(created.first.coordinate, '30009:${_pubkey(1)}:scene-stealer');
        },
      );

      test('counts awards and distinct recipients per definition', () async {
        const coordinate = 'scene-stealer';
        _stubQueries(nostrClient, {
          'created:${_pubkey(1)}': [
            _definitionEvent(
              id: _eventId(64),
              pubkey: _pubkey(1),
              dTag: coordinate,
              name: 'Scene Stealer',
            ),
          ],
          'issued': [
            _awardEvent(
              id: _eventId(65),
              issuerPubkey: _pubkey(1),
              definitionCoordinate: '30009:${_pubkey(1)}:$coordinate',
              recipients: [_pubkey(2), _pubkey(3)],
            ),
            _awardEvent(
              id: _eventId(66),
              issuerPubkey: _pubkey(1),
              definitionCoordinate: '30009:${_pubkey(1)}:$coordinate',
              recipients: [_pubkey(3)],
            ),
            // Award for a badge the user never defined.
            _awardEvent(
              id: _eventId(67),
              issuerPubkey: _pubkey(1),
              definitionCoordinate: '30009:${_pubkey(1)}:other',
              recipients: [_pubkey(4)],
            ),
          ],
        });

        final created = await repository.loadCreatedBadges();

        expect(created.single.awardCount, 2);
        expect(created.single.recipientCount, 2);
      });

      test('reports no awards for a definition nobody received', () async {
        _stubQueries(nostrClient, {
          'created:${_pubkey(1)}': [
            _definitionEvent(
              id: _eventId(68),
              pubkey: _pubkey(1),
              dTag: 'scene-stealer',
              name: 'Scene Stealer',
              imageUrl: 'https://media.divine.video/scene.png',
            ),
          ],
        });

        final created = await repository.loadCreatedBadges();

        expect(created.single.awardCount, 0);
        expect(created.single.recipientCount, 0);
        expect(created.single.imageUrl, 'https://media.divine.video/scene.png');
      });

      test('falls back to the thumbnail when there is no image', () async {
        _stubQueries(nostrClient, {
          'created:${_pubkey(1)}': [
            _definitionEvent(
              id: _eventId(69),
              pubkey: _pubkey(1),
              dTag: 'scene-stealer',
              name: 'Scene Stealer',
              thumbnails: const ['https://media.divine.video/thumb.png'],
            ),
          ],
        });

        final created = await repository.loadCreatedBadges();

        expect(created.single.imageUrl, 'https://media.divine.video/thumb.png');
      });

      test('throws a StateError without a current pubkey', () async {
        final anonymous = BadgeRepository(
          nostrClient: nostrClient,
          sharedPreferences: preferences,
          currentPubkey: () => null,
          signEvent: ({required kind, required content, required tags}) async =>
              null,
        );

        await expectLater(
          anonymous.loadCreatedBadges(),
          throwsA(isA<StateError>()),
        );
      });
    });

    test('loadIssuedBadges lists newest badge first and names it', () async {
      _stubQueries(nostrClient, {
        'issued': [
          _awardEvent(
            id: _eventId(80),
            issuerPubkey: _pubkey(1),
            definitionCoordinate: '30009:${_pubkey(1)}:older-badge',
            recipients: [_pubkey(2)],
          ),
          _awardEvent(
            id: _eventId(81),
            issuerPubkey: _pubkey(1),
            definitionCoordinate: '30009:${_pubkey(1)}:newer-badge',
            recipients: [_pubkey(3)],
            createdAt: 5000,
          ),
        ],
        'definition:30009:${_pubkey(1)}:newer-badge': [
          _definitionEvent(
            id: _eventId(82),
            pubkey: _pubkey(1),
            dTag: 'newer-badge',
            name: 'Newer Badge',
          ),
        ],
      });

      final issued = await repository.loadIssuedBadges();

      expect(issued.map((badge) => badge.displayName), [
        'Newer Badge',
        // No definition on the relay, so the identifier stands in.
        'older-badge',
      ]);
    });

    group('accepting reflects before the relay serves the write back', () {
      final coordinate = '30009:${_pubkey(2)}:daily-diviner';
      late Event award;

      setUp(() {
        award = _awardEvent(
          id: _eventId(70),
          issuerPubkey: _pubkey(2),
          definitionCoordinate: coordinate,
          recipients: [_pubkey(1)],
        );
      });

      test('a reload right after accepting shows the badge accepted', () async {
        // The relay OKs the kind:10008 but keeps serving the previous list,
        // which is the window the dashboard used to render as "not accepted"
        // until the user pulled to refresh.
        _stubQueries(nostrClient, {
          'awarded': [award],
          'profileCurrent:${_pubkey(1)}': [
            _profileBadgesEvent(
              id: _eventId(71),
              pubkey: _pubkey(1),
              tags: const [],
              createdAt: 500,
            ),
          ],
        });

        await repository.acceptAward(
          BadgeAwardViewData(award: Nip58BadgeParser.parseAward(award)!),
        );

        expect(
          (await repository.loadAwardedBadges()).single.isAccepted,
          isTrue,
        );
      });

      test('a genuinely newer list from another device still wins', () async {
        _stubQueries(nostrClient, {
          'awarded': [award],
          'profileCurrent:${_pubkey(1)}': [
            _profileBadgesEvent(
              id: _eventId(72),
              pubkey: _pubkey(1),
              tags: const [],
              // The signer stamps the published event with createdAt 1000.
              createdAt: 4000,
            ),
          ],
        });

        await repository.acceptAward(
          BadgeAwardViewData(award: Nip58BadgeParser.parseAward(award)!),
        );

        expect(
          (await repository.loadAwardedBadges()).single.isAccepted,
          isFalse,
        );
      });

      test('another account does not inherit the published list', () async {
        _stubQueries(nostrClient, {
          'awarded': [award],
          'profileCurrent:${_pubkey(1)}': const [],
        });
        await repository.acceptAward(
          BadgeAwardViewData(award: Nip58BadgeParser.parseAward(award)!),
        );

        final badges = await repository.loadAcceptedBadgesForProfile(
          _pubkey(2),
        );

        expect(badges, isEmpty);
      });
    });

    group('editing reflects before the relay serves the write back', () {
      final coordinate = BadgeCoordinate(
        pubkey: _pubkey(1),
        identifier: 'scene-stealer',
      );

      /// The relay keeps answering with the pre-edit definition, which is the
      /// window the badge used to keep its old name in.
      void stubStaleDefinition() {
        _stubQueries(nostrClient, {
          'created:${_pubkey(1)}': [
            _definitionEvent(
              id: _eventId(60),
              pubkey: _pubkey(1),
              dTag: 'scene-stealer',
              name: 'Old Name',
              createdAt: 500,
            ),
          ],
          'definition:${coordinate.value}': [
            _definitionEvent(
              id: _eventId(61),
              pubkey: _pubkey(1),
              dTag: 'scene-stealer',
              name: 'Old Name',
              createdAt: 500,
            ),
          ],
        });
      }

      Future<void> publishEdit() => repository.saveDefinition(
        const BadgeDefinitionDraft(
          identifier: 'scene-stealer',
          name: 'New Name',
          imageUrl: _artworkUrl,
        ),
      );

      test('the detail page shows the edited name right away', () async {
        stubStaleDefinition();
        await publishEdit();

        final detail = await repository.loadBadgeDetail(coordinate);

        expect(detail.definition?.name, 'New Name');
      });

      test('the created list shows the edited name right away', () async {
        stubStaleDefinition();
        await publishEdit();

        final created = await repository.loadCreatedBadges();

        expect(created.single.displayName, 'New Name');
      });

      test('a brand-new badge appears before the relay serves it', () async {
        await publishEdit();

        expect(await repository.loadCreatedIdentifiers(), {'scene-stealer'});
      });

      test('an edit made on another device still wins', () async {
        await publishEdit();
        _stubQueries(nostrClient, {
          'definition:${coordinate.value}': [
            _definitionEvent(
              id: _eventId(62),
              pubkey: _pubkey(1),
              dTag: 'scene-stealer',
              name: 'Newer Elsewhere',
              // The signer stamps the published event with createdAt 1000.
              createdAt: 4000,
            ),
          ],
        });

        final detail = await repository.loadBadgeDetail(coordinate);

        expect(detail.definition?.name, 'Newer Elsewhere');
      });

      test('a deleted badge is not served back out of memory', () async {
        await publishEdit();

        await repository.deleteBadge(coordinate);

        expect(await repository.loadCreatedIdentifiers(), isEmpty);
      });
    });

    group('unhideAward', () {
      test('puts a dismissed award back on the awarded list', () async {
        _stubQueries(nostrClient, {
          'awarded': [
            _awardEvent(
              id: _eventId(84),
              issuerPubkey: _pubkey(2),
              definitionCoordinate: '30009:${_pubkey(2)}:daily-diviner',
              recipients: [_pubkey(1)],
            ),
          ],
        });
        await repository.hideAward(_eventId(84));

        await repository.unhideAward(_eventId(84));

        expect((await repository.loadAwardedBadges()).single.isHidden, isFalse);
        expect(
          preferences.getStringList('dismissed_badge_awards_${_pubkey(1)}'),
          isEmpty,
        );
      });

      test('does nothing for an award that was never dismissed', () async {
        await repository.unhideAward(_eventId(85));

        expect(
          preferences.getStringList('dismissed_badge_awards_${_pubkey(1)}'),
          isNull,
        );
      });

      test('throws a StateError without a current pubkey', () async {
        final anonymous = BadgeRepository(
          nostrClient: nostrClient,
          sharedPreferences: preferences,
          currentPubkey: () => null,
          signEvent: ({required kind, required content, required tags}) async =>
              null,
        );

        await expectLater(
          anonymous.unhideAward(_eventId(86)),
          throwsA(isA<StateError>()),
        );
      });
    });

    test('loadDashboard keeps dismissed awards out of awarded', () async {
      _stubQueries(nostrClient, {
        'awarded': [
          _awardEvent(
            id: _eventId(87),
            issuerPubkey: _pubkey(2),
            definitionCoordinate: '30009:${_pubkey(2)}:daily-diviner',
            recipients: [_pubkey(1)],
          ),
          _awardEvent(
            id: _eventId(88),
            issuerPubkey: _pubkey(2),
            definitionCoordinate: '30009:${_pubkey(2)}:weekly-diviner',
            recipients: [_pubkey(1)],
          ),
        ],
      });
      await repository.hideAward(_eventId(88));

      final dashboard = await repository.loadDashboard();

      expect(dashboard.awarded.single.awardEventId, _eventId(87));
      expect(dashboard.hidden.single.awardEventId, _eventId(88));
    });

    group('loadCreatedIdentifiers', () {
      test('collapses replaced definitions to one identifier', () async {
        _stubQueries(nostrClient, {
          'created:${_pubkey(1)}': [
            _definitionEvent(
              id: _eventId(94),
              pubkey: _pubkey(1),
              dTag: 'scene-stealer',
              name: 'Scene Stealer',
            ),
            _definitionEvent(
              id: _eventId(95),
              pubkey: _pubkey(1),
              dTag: 'scene-stealer',
              name: 'Scene Stealer v2',
              createdAt: 3000,
            ),
            _definitionEvent(
              id: _eventId(96),
              pubkey: _pubkey(1),
              dTag: 'loop-of-the-week',
              name: 'Loop of the Week',
            ),
          ],
        });

        expect(await repository.loadCreatedIdentifiers(), {
          'scene-stealer',
          'loop-of-the-week',
        });
      });

      test('is empty when the user has published no badges', () async {
        expect(await repository.loadCreatedIdentifiers(), isEmpty);
      });

      test('throws a StateError without a current pubkey', () async {
        final anonymous = BadgeRepository(
          nostrClient: nostrClient,
          sharedPreferences: preferences,
          currentPubkey: () => null,
          signEvent: ({required kind, required content, required tags}) async =>
              null,
        );

        await expectLater(
          anonymous.loadCreatedIdentifiers(),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('loadBadgeDetail', () {
      final coordinate = BadgeCoordinate(
        pubkey: _pubkey(2),
        identifier: 'scene-stealer',
      );

      test('resolves definition, awardees, and viewer acceptance', () async {
        _stubQueries(nostrClient, {
          'definition:${coordinate.value}': [
            _definitionEvent(
              pubkey: _pubkey(2),
              dTag: 'scene-stealer',
              name: 'Scene Stealer',
            ),
          ],
          'awardsFor:${coordinate.value}': [
            _awardEvent(
              id: _eventId(70),
              issuerPubkey: _pubkey(2),
              definitionCoordinate: coordinate.value,
              recipients: [_pubkey(1), _pubkey(3)],
            ),
          ],
          'profileCurrent:${_pubkey(1)}': [
            _profileBadgesEvent(
              id: _eventId(71),
              pubkey: _pubkey(1),
              tags: [
                ['a', coordinate.value],
                ['e', _eventId(70)],
              ],
            ),
          ],
        });

        final detail = await repository.loadBadgeDetail(coordinate);

        expect(detail.definition?.name, 'Scene Stealer');
        expect(detail.isOwner, isFalse);
        expect(detail.recipients.map((r) => r.pubkey), [
          _pubkey(1),
          _pubkey(3),
        ]);
        expect(detail.recipients.first.isAccepted, isTrue);
        expect(detail.recipients.first.awardEventId, _eventId(70));
        expect(detail.recipients.last.isAccepted, isFalse);
        expect(detail.viewerAward?.awardEventId, _eventId(70));
        expect(detail.viewerAward?.isAccepted, isTrue);
      });

      test('marks the viewer as owner for their own badge', () async {
        final ownCoordinate = BadgeCoordinate(
          pubkey: _pubkey(1),
          identifier: 'scene-stealer',
        );
        _stubQueries(nostrClient, {
          'awardsFor:${ownCoordinate.value}': [
            _awardEvent(
              id: _eventId(72),
              issuerPubkey: _pubkey(1),
              definitionCoordinate: ownCoordinate.value,
              recipients: [_pubkey(3)],
            ),
          ],
        });

        final detail = await repository.loadBadgeDetail(ownCoordinate);

        expect(detail.isOwner, isTrue);
        expect(detail.definition, isNull);
        expect(detail.viewerAward, isNull);
      });

      test(
        'keeps the newest award when a recipient was awarded twice',
        () async {
          _stubQueries(nostrClient, {
            'awardsFor:${coordinate.value}': [
              _awardEvent(
                id: _eventId(73),
                issuerPubkey: _pubkey(2),
                definitionCoordinate: coordinate.value,
                recipients: [_pubkey(3)],
              ),
              _awardEvent(
                id: _eventId(74),
                issuerPubkey: _pubkey(2),
                definitionCoordinate: coordinate.value,
                recipients: [_pubkey(3)],
                createdAt: 5000,
              ),
            ],
          });

          final detail = await repository.loadBadgeDetail(coordinate);

          expect(detail.recipients.single.awardEventId, _eventId(74));
        },
      );

      test('drops awards whose coordinate does not match', () async {
        _stubQueries(nostrClient, {
          'awardsFor:${coordinate.value}': [
            _awardEvent(
              id: _eventId(75),
              issuerPubkey: _pubkey(2),
              definitionCoordinate: '30009:${_pubkey(2)}:other-badge',
              recipients: [_pubkey(3)],
            ),
          ],
        });

        final detail = await repository.loadBadgeDetail(coordinate);

        expect(detail.recipients, isEmpty);
      });

      test('caps acceptance checks but always includes the viewer', () async {
        _stubQueries(nostrClient, {
          'awardsFor:${coordinate.value}': [
            _awardEvent(
              id: _eventId(76),
              issuerPubkey: _pubkey(2),
              definitionCoordinate: coordinate.value,
              recipients: [_pubkey(3), _pubkey(4), _pubkey(1)],
            ),
          ],
          'profileCurrent:${_pubkey(1)}': [
            _profileBadgesEvent(
              id: _eventId(77),
              pubkey: _pubkey(1),
              tags: [
                ['a', coordinate.value],
                ['e', _eventId(76)],
              ],
            ),
          ],
        });

        final detail = await repository.loadBadgeDetail(
          coordinate,
          recipientCheckLimit: 1,
        );

        expect(detail.recipients.map((r) => r.pubkey), [
          _pubkey(3),
          _pubkey(1),
        ]);
        expect(detail.viewerAward?.isAccepted, isTrue);
      });

      test('reports no viewer award when signed out', () async {
        final anonymous = BadgeRepository(
          nostrClient: nostrClient,
          sharedPreferences: preferences,
          currentPubkey: () => null,
          signEvent: ({required kind, required content, required tags}) async =>
              null,
        );
        _stubQueries(nostrClient, {
          'awardsFor:${coordinate.value}': [
            _awardEvent(
              id: _eventId(78),
              issuerPubkey: _pubkey(2),
              definitionCoordinate: coordinate.value,
              recipients: [_pubkey(3)],
            ),
          ],
        });

        final detail = await anonymous.loadBadgeDetail(coordinate);

        expect(detail.isOwner, isFalse);
        expect(detail.viewerAward, isNull);
        expect(detail.recipients, hasLength(1));
      });
    });

    group('saveDefinition', () {
      test('publishes a kind 30009 definition', () async {
        final definition = await repository.saveDefinition(
          const BadgeDefinitionDraft(
            identifier: ' scene-stealer ',
            name: ' Scene Stealer ',
            description: ' Steals the scroll. ',
            imageUrl: 'https://media.divine.video/scene.png',
            thumbnailUrl: 'https://media.divine.video/scene-thumb.png',
          ),
        );

        final event = lastSignedEvent()!;
        expect(event.kind, EventKind.badgeDefinition);
        expect(event.tags, [
          ['d', 'scene-stealer'],
          ['name', 'Scene Stealer'],
          ['description', 'Steals the scroll.'],
          ['image', 'https://media.divine.video/scene.png'],
          ['thumb', 'https://media.divine.video/scene-thumb.png'],
        ]);
        expect(definition.dTag, 'scene-stealer');
        expect(definition.coordinate, '30009:${_pubkey(1)}:scene-stealer');
      });

      test('omits the thumbnail tag when there is no custom thumb', () async {
        await repository.saveDefinition(
          const BadgeDefinitionDraft(
            identifier: 'scene-stealer',
            name: 'Scene Stealer',
            imageUrl: _artworkUrl,
          ),
        );

        expect(lastSignedEvent()!.tags, [
          ['d', 'scene-stealer'],
          ['name', 'Scene Stealer'],
          ['description', ''],
          ['image', _artworkUrl],
        ]);
      });

      test('rejects a draft without artwork', () async {
        await expectLater(
          repository.saveDefinition(
            const BadgeDefinitionDraft(
              identifier: 'scene-stealer',
              name: 'Scene Stealer',
              imageUrl: '  ',
            ),
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects a draft without an identifier', () async {
        await expectLater(
          repository.saveDefinition(
            const BadgeDefinitionDraft(
              identifier: '  ',
              name: 'Scene Stealer',
              imageUrl: _artworkUrl,
            ),
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('rejects a draft without a name', () async {
        await expectLater(
          repository.saveDefinition(
            const BadgeDefinitionDraft(
              identifier: 'scene-stealer',
              name: '  ',
              imageUrl: _artworkUrl,
            ),
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws a StateError without a current pubkey', () async {
        final anonymous = BadgeRepository(
          nostrClient: nostrClient,
          sharedPreferences: preferences,
          currentPubkey: () => null,
          signEvent: ({required kind, required content, required tags}) async =>
              null,
        );

        await expectLater(
          anonymous.saveDefinition(
            const BadgeDefinitionDraft(
              identifier: 'scene-stealer',
              name: 'Scene Stealer',
              imageUrl: _artworkUrl,
            ),
          ),
          throwsA(isA<StateError>()),
        );
      });

      test('throws a StateError when signing fails', () async {
        final unsigned = BadgeRepository(
          nostrClient: nostrClient,
          sharedPreferences: preferences,
          currentPubkey: () => _pubkey(1),
          signEvent: ({required kind, required content, required tags}) async =>
              null,
        );

        await expectLater(
          unsigned.saveDefinition(
            const BadgeDefinitionDraft(
              identifier: 'scene-stealer',
              name: 'Scene Stealer',
              imageUrl: _artworkUrl,
            ),
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'Could not sign badge definition event',
            ),
          ),
        );
      });

      test(
        'throws a StateError when the signed event is not a definition',
        () async {
          final stripped = BadgeRepository(
            nostrClient: nostrClient,
            sharedPreferences: preferences,
            currentPubkey: () => _pubkey(1),
            signEvent:
                ({required kind, required content, required tags}) async =>
                    _event(id: _eventId(80), pubkey: _pubkey(1), kind: kind),
          );

          await expectLater(
            stripped.saveDefinition(
              const BadgeDefinitionDraft(
                identifier: 'scene-stealer',
                name: 'Scene Stealer',
                imageUrl: _artworkUrl,
              ),
            ),
            throwsA(
              isA<StateError>().having(
                (error) => error.message,
                'message',
                'Signed badge definition event is not parseable',
              ),
            ),
          );
        },
      );

      test('throws a BadgePublishException when no relay accepts', () async {
        when(() => nostrClient.publishEventAwaitOk(any())).thenAnswer((
          invocation,
        ) async {
          return _rejectedPublishOutcome(
            invocation.positionalArguments.single as Event,
          );
        });

        await expectLater(
          repository.saveDefinition(
            const BadgeDefinitionDraft(
              identifier: 'scene-stealer',
              name: 'Scene Stealer',
              imageUrl: _artworkUrl,
            ),
          ),
          throwsA(isA<BadgePublishException>()),
        );
      });
    });

    group('awardBadge', () {
      final coordinate = BadgeCoordinate(
        pubkey: _pubkey(1),
        identifier: 'scene-stealer',
      );

      test('publishes a kind 8 award with deduplicated recipients', () async {
        final award = await repository.awardBadge(
          coordinate: coordinate,
          recipientPubkeys: [
            _pubkey(2),
            _pubkey(2),
            'not-a-key',
            _pubkey(3),
          ],
        );

        final event = lastSignedEvent()!;
        expect(event.kind, EventKind.badgeAward);
        expect(event.tags, [
          ['a', coordinate.value],
          ['p', _pubkey(2)],
          ['p', _pubkey(3)],
        ]);
        expect(award.recipientPubkeys, [_pubkey(2), _pubkey(3)]);
      });

      test('rejects an award without a usable recipient', () async {
        await expectLater(
          repository.awardBadge(
            coordinate: coordinate,
            recipientPubkeys: const ['not-a-key'],
          ),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('throws a StateError without a current pubkey', () async {
        final anonymous = BadgeRepository(
          nostrClient: nostrClient,
          sharedPreferences: preferences,
          currentPubkey: () => null,
          signEvent: ({required kind, required content, required tags}) async =>
              null,
        );

        await expectLater(
          anonymous.awardBadge(
            coordinate: coordinate,
            recipientPubkeys: [_pubkey(2)],
          ),
          throwsA(isA<StateError>()),
        );
      });

      test('throws a StateError when signing fails', () async {
        final unsigned = BadgeRepository(
          nostrClient: nostrClient,
          sharedPreferences: preferences,
          currentPubkey: () => _pubkey(1),
          signEvent: ({required kind, required content, required tags}) async =>
              null,
        );

        await expectLater(
          unsigned.awardBadge(
            coordinate: coordinate,
            recipientPubkeys: [_pubkey(2)],
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'Could not sign badge award event',
            ),
          ),
        );
      });

      test(
        'throws a StateError when the signed event is not an award',
        () async {
          final stripped = BadgeRepository(
            nostrClient: nostrClient,
            sharedPreferences: preferences,
            currentPubkey: () => _pubkey(1),
            signEvent:
                ({required kind, required content, required tags}) async =>
                    _event(id: _eventId(81), pubkey: _pubkey(1), kind: kind),
          );

          await expectLater(
            stripped.awardBadge(
              coordinate: coordinate,
              recipientPubkeys: [_pubkey(2)],
            ),
            throwsA(
              isA<StateError>().having(
                (error) => error.message,
                'message',
                'Signed badge award event is not parseable',
              ),
            ),
          );
        },
      );
    });

    group('deleteBadge', () {
      final coordinate = BadgeCoordinate(
        pubkey: _pubkey(1),
        identifier: 'scene-stealer',
      );

      test('requests deletion of the definition and its awards', () async {
        _stubQueries(nostrClient, {
          'definition:${coordinate.value}': [
            _definitionEvent(
              id: _eventId(90),
              pubkey: _pubkey(1),
              dTag: 'scene-stealer',
              name: 'Scene Stealer',
            ),
          ],
          'awardsFor:${coordinate.value}': [
            _awardEvent(
              id: _eventId(91),
              issuerPubkey: _pubkey(1),
              definitionCoordinate: coordinate.value,
              recipients: [_pubkey(2)],
            ),
            _awardEvent(
              id: _eventId(92),
              issuerPubkey: _pubkey(1),
              definitionCoordinate: coordinate.value,
              recipients: [_pubkey(3)],
            ),
          ],
        });

        await repository.deleteBadge(coordinate);

        final event = lastSignedEvent()!;
        expect(event.kind, EventKind.eventDeletion);
        expect(event.tags, [
          ['a', coordinate.value],
          ['e', _eventId(90)],
          ['e', _eventId(91)],
          ['e', _eventId(92)],
          ['k', '${EventKind.badgeDefinition}'],
          ['k', '${EventKind.badgeAward}'],
        ]);
      });

      test('leaves out the award kind when nothing was awarded', () async {
        _stubQueries(nostrClient, {
          'definition:${coordinate.value}': [
            _definitionEvent(
              id: _eventId(93),
              pubkey: _pubkey(1),
              dTag: 'scene-stealer',
              name: 'Scene Stealer',
            ),
          ],
        });

        await repository.deleteBadge(coordinate);

        expect(lastSignedEvent()!.tags, [
          ['a', coordinate.value],
          ['e', _eventId(93)],
          ['k', '${EventKind.badgeDefinition}'],
        ]);
      });

      test('still deletes when no definition event was found', () async {
        await repository.deleteBadge(coordinate);

        expect(lastSignedEvent()!.tags, [
          ['a', coordinate.value],
          ['k', '${EventKind.badgeDefinition}'],
        ]);
      });

      test("refuses to delete someone else's badge", () async {
        await expectLater(
          repository.deleteBadge(
            BadgeCoordinate(pubkey: _pubkey(2), identifier: 'scene-stealer'),
          ),
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'Cannot delete a badge issued by someone else',
            ),
          ),
        );
        expect(lastSignedEvent(), isNull);
      });

      test('throws a StateError without a current pubkey', () async {
        final anonymous = BadgeRepository(
          nostrClient: nostrClient,
          sharedPreferences: preferences,
          currentPubkey: () => null,
          signEvent: ({required kind, required content, required tags}) async =>
              null,
        );

        await expectLater(
          anonymous.deleteBadge(coordinate),
          throwsA(isA<StateError>()),
        );
      });

      test('throws a BadgePublishException when no relay accepts', () async {
        when(() => nostrClient.publishEventAwaitOk(any())).thenAnswer((
          invocation,
        ) async {
          return _rejectedPublishOutcome(
            invocation.positionalArguments.single as Event,
          );
        });

        await expectLater(
          repository.deleteBadge(coordinate),
          throwsA(isA<BadgePublishException>()),
        );
      });
    });

    test('loadDashboard reads the issued awards query once', () async {
      final callCounts = _stubQueries(nostrClient, {
        'created:${_pubkey(1)}': [
          _definitionEvent(
            id: _eventId(82),
            pubkey: _pubkey(1),
            dTag: 'scene-stealer',
            name: 'Scene Stealer',
          ),
        ],
        'issued': [
          _awardEvent(
            id: _eventId(83),
            issuerPubkey: _pubkey(1),
            definitionCoordinate: '30009:${_pubkey(1)}:scene-stealer',
            recipients: [_pubkey(2)],
          ),
        ],
      });

      final dashboard = await repository.loadDashboard();

      expect(dashboard.created.single.awardCount, 1);
      expect(dashboard.issued, hasLength(1));
      expect(callCounts['issued'], 1);
    });
  });

  group(ProfileBadgeViewData, () {
    test(
      'exposes issuer, recipients, deduplicated unique recipients, and a '
      'coordinate-derived name when no definition is present',
      () {
        final coordinate = '30009:${_pubkey(5)}:daily-diviner';
        final award = Nip58BadgeParser.parseAward(
          _awardEvent(
            id: _eventId(40),
            issuerPubkey: _pubkey(5),
            definitionCoordinate: coordinate,
            recipients: [_pubkey(6), _pubkey(6), _pubkey(7)],
          ),
        )!;
        final viewData = ProfileBadgeViewData(
          badge: Nip58ProfileBadgeRef(
            definitionCoordinate: coordinate,
            awardEventId: _eventId(40),
          ),
          award: award,
        );

        expect(viewData.issuerPubkey, _pubkey(5));
        expect(viewData.recipientPubkeys, [_pubkey(6), _pubkey(6), _pubkey(7)]);
        expect(viewData.uniqueRecipientPubkeys, [_pubkey(6), _pubkey(7)]);
        expect(viewData.displayName, 'daily-diviner');
        expect(viewData.description, isNull);
        expect(viewData.imageUrl, isNull);
      },
    );
  });

  group(BadgeAwardViewData, () {
    test(
      'exposes award id, coordinate, and a coordinate-derived name when no '
      'definition is present',
      () {
        final coordinate = '30009:${_pubkey(8)}:weekly-diviner';
        final award = Nip58BadgeParser.parseAward(
          _awardEvent(
            id: _eventId(41),
            issuerPubkey: _pubkey(8),
            definitionCoordinate: coordinate,
            recipients: [_pubkey(1)],
          ),
        )!;
        final viewData = BadgeAwardViewData(award: award);

        expect(viewData.awardEventId, _eventId(41));
        expect(viewData.definitionCoordinate, coordinate);
        expect(viewData.displayName, 'weekly-diviner');
        expect(viewData.imageUrl, isNull);
      },
    );

    test(
      'prefers the definition name and image when a definition is present',
      () {
        final coordinate = '30009:${_pubkey(8)}:weekly-diviner';
        final award = Nip58BadgeParser.parseAward(
          _awardEvent(
            id: _eventId(41),
            issuerPubkey: _pubkey(8),
            definitionCoordinate: coordinate,
            recipients: [_pubkey(1)],
          ),
        )!;
        final definition = Nip58BadgeParser.parseDefinition(
          _definitionEvent(
            pubkey: _pubkey(8),
            dTag: 'weekly-diviner',
            name: 'Weekly Diviner',
            imageUrl: 'https://media.divine.video/weekly.png',
          ),
        )!;
        final viewData = BadgeAwardViewData(
          award: award,
          definition: definition,
        );

        expect(viewData.displayName, 'Weekly Diviner');
        expect(viewData.imageUrl, 'https://media.divine.video/weekly.png');
      },
    );
  });
}

/// Stubs [NostrClient.queryEvents] with answer-keyed canned events and
/// returns a live map of query-key invocation counts for dedup assertions.
Map<String, int> _stubQueries(
  _MockNostrClient nostrClient,
  Map<String, List<Event>> eventsByQueryKey, {
  Map<String, Duration> delaysByQueryKey = const {},
  Map<String, Exception> errorsByQueryKey = const {},
}) {
  final callCounts = <String, int>{};
  when(() => nostrClient.queryEvents(any())).thenAnswer((invocation) async {
    final filters = invocation.positionalArguments.single as List<Filter>;
    final filter = filters.single;
    final key = _queryKey(filter);
    callCounts.update(key, (count) => count + 1, ifAbsent: () => 1);
    final delay = delaysByQueryKey[key];
    if (delay != null) {
      await Future<void>.delayed(delay);
    }
    final error = errorsByQueryKey[key];
    if (error != null) {
      throw error;
    }
    return eventsByQueryKey[key] ?? const <Event>[];
  });
  return callCounts;
}

String _queryKey(Filter filter) {
  if (filter.ids?.isNotEmpty == true) {
    return 'ids:${filter.ids!.join(',')}';
  }
  // Checked before `issued`: an issuer's own coordinate query carries both
  // `authors` and `a`, and only the `a` form is the detail-page lookup.
  if (filter.kinds?.contains(EventKind.badgeAward) == true &&
      filter.a?.isNotEmpty == true) {
    return 'awardsFor:${filter.a!.single}';
  }
  if (filter.kinds?.contains(EventKind.badgeDefinition) == true &&
      filter.authors?.isNotEmpty == true &&
      filter.d == null) {
    return 'created:${filter.authors!.single}';
  }
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
  int createdAt = 1000,
}) {
  return _event(
    id: id,
    pubkey: issuerPubkey,
    kind: EventKind.badgeAward,
    createdAt: createdAt,
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
  int createdAt = 1000,
}) {
  return _event(
    id: id,
    pubkey: pubkey,
    kind: EventKind.profileBadges,
    tags: tags,
    createdAt: createdAt,
  );
}

PublishOutcome _acceptedPublishOutcome(Event event) {
  return PublishOutcome(
    eventId: event.id,
    acceptedBy: const ['wss://relay.divine.video'],
    rejectedBy: const {},
    noResponseFrom: const [],
  );
}

PublishOutcome _rejectedPublishOutcome(Event event) {
  return PublishOutcome(
    eventId: event.id,
    acceptedBy: const [],
    rejectedBy: const {
      'wss://relay.divine.video': 'blocked: kind 10008 not in allowed list',
    },
    noResponseFrom: const [],
  );
}

Event _definitionEvent({
  required String pubkey,
  required String dTag,
  required String name,
  String? description,
  String? imageUrl,
  List<String> thumbnails = const [],
  String? id,
  int createdAt = 1000,
}) {
  return _event(
    id: id ?? _eventId(100),
    pubkey: pubkey,
    kind: EventKind.badgeDefinition,
    createdAt: createdAt,
    tags: [
      ['d', dTag],
      ['name', name],
      if (description != null) ['description', description],
      if (imageUrl != null) ['image', imageUrl],
      for (final thumbnail in thumbnails) ['thumb', thumbnail],
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

const _artworkUrl = 'https://media.divine.video/scene.png';

String _eventId(int seed) => seed.toRadixString(16).padLeft(64, '0');

String _pubkey(int seed) => (seed + 100).toRadixString(16).padLeft(64, '0');
