// ABOUTME: Tests for ProfileRepository's NIP-39 identity-tags source API —
// ABOUTME: kind-10011 consult order, kind-0 fallback, and caching (#3936).

import 'package:db_client/db_client.dart' hide Filter, ProfileStats;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockUserProfilesDao extends Mock implements UserProfilesDao {}

class _MockIdentityEventsDao extends Mock implements IdentityEventsDao {}

class _MockHttpClient extends Mock implements Client {}

const _pubkey =
    'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

const _kind0Tags = [
  ['i', 'github:legacy', 'legacy-proof'],
  ['p', 'not-an-i-tag'],
];

Event _identityEvent({
  int createdAt = 1000,
  int kind = ProfileRepository.identityEventKind,
  List<List<String>> tags = const [
    ['i', 'github:modern', 'modern-proof'],
    ['alt', 'External Identities'],
  ],
}) {
  return Event(_pubkey, kind, tags, '', createdAt: createdAt);
}

IdentityEventRow _row({
  required String tagsJson,
  int sourceKind = ProfileRepository.identityEventKind,
}) {
  return IdentityEventRow(
    pubkey: _pubkey,
    tagsJson: tagsJson,
    sourceKind: sourceKind,
  );
}

void main() {
  late _MockNostrClient nostrClient;
  late _MockIdentityEventsDao identityEventsDao;
  late ProfileRepository repository;

  setUpAll(() {
    registerFallbackValue(<Filter>[]);
  });

  ProfileRepository buildRepository({bool withDao = true}) {
    return ProfileRepository(
      nostrClient: nostrClient,
      userProfilesDao: _MockUserProfilesDao(),
      httpClient: _MockHttpClient(),
      identityEventsDao: withDao ? identityEventsDao : null,
    );
  }

  setUp(() {
    nostrClient = _MockNostrClient();
    identityEventsDao = _MockIdentityEventsDao();
    repository = buildRepository();

    when(
      () => identityEventsDao.upsertEvent(
        pubkey: any(named: 'pubkey'),
        tagsJson: any(named: 'tagsJson'),
        sourceKind: any(named: 'sourceKind'),
      ),
    ).thenAnswer((_) async {});
  });

  void stubQuery(List<Event> events) {
    when(
      () => nostrClient.queryEvents(any(), useCache: false),
    ).thenAnswer((_) async => events);
  }

  group('ProfileRepository.cachedIdentityTags', () {
    test('returns null when no DAO is wired', () async {
      final bare = buildRepository(withDao: false);
      expect(await bare.cachedIdentityTags(_pubkey), isNull);
    });

    test('returns null when no row is cached', () async {
      when(
        () => identityEventsDao.getEvent(_pubkey),
      ).thenAnswer((_) async => null);
      expect(await repository.cachedIdentityTags(_pubkey), isNull);
    });

    test('returns the decoded cached tags', () async {
      when(() => identityEventsDao.getEvent(_pubkey)).thenAnswer(
        (_) async => _row(tagsJson: '[["i","github:modern","modern-proof"]]'),
      );
      expect(
        await repository.cachedIdentityTags(_pubkey),
        equals([
          ['i', 'github:modern', 'modern-proof'],
        ]),
      );
    });

    test('returns null when the cached row is corrupt', () async {
      when(
        () => identityEventsDao.getEvent(_pubkey),
      ).thenAnswer((_) async => _row(tagsJson: 'not json'));
      expect(await repository.cachedIdentityTags(_pubkey), isNull);
    });

    test(
      'returns null when the cached row is valid JSON of the wrong shape '
      '(TypeError, not just Exception)',
      () async {
        // Valid JSON whose shape breaks the decode casts throws a TypeError
        // (an Error, not an Exception); the decoder must still degrade to
        // null rather than let it escape to a reportable crash.
        for (final malformed in const ['{"not":"a list"}', '[1,2,3]']) {
          when(
            () => identityEventsDao.getEvent(_pubkey),
          ).thenAnswer((_) async => _row(tagsJson: malformed));
          expect(
            await repository.cachedIdentityTags(_pubkey),
            isNull,
            reason: 'wrong-shape "$malformed" should decode to null',
          );
        }
      },
    );
  });

  group('ProfileRepository.freshIdentityTags', () {
    test(
      'returns the live kind-10011 i tags and caches them, picking the '
      'newest event',
      () async {
        stubQuery([
          _identityEvent(createdAt: 100),
          _identityEvent(
            createdAt: 200,
            tags: const [
              ['i', 'github:newest', 'newest-proof'],
            ],
          ),
        ]);

        final tags = await repository.freshIdentityTags(
          pubkey: _pubkey,
          kind0Tags: _kind0Tags,
        );

        expect(
          tags,
          equals([
            ['i', 'github:newest', 'newest-proof'],
          ]),
        );
        verify(
          () => identityEventsDao.upsertEvent(
            pubkey: _pubkey,
            tagsJson: '[["i","github:newest","newest-proof"]]',
            sourceKind: ProfileRepository.identityEventKind,
          ),
        ).called(1);
      },
    );

    test(
      'breaks a same-second tie by lowest event id (deterministic across '
      'relay return order)',
      () async {
        final eventA = _identityEvent(
          createdAt: 500,
          tags: const [
            ['i', 'github:aaa', 'proof-a'],
          ],
        );
        final eventB = _identityEvent(
          createdAt: 500,
          tags: const [
            ['i', 'github:bbb', 'proof-b'],
          ],
        );
        // Both share created_at, so NIP-01 picks the lowest event id.
        final winner = eventA.id.compareTo(eventB.id) < 0 ? eventA : eventB;
        final expectedTags = [
          for (final tag in winner.tags)
            if (tag.length >= 3 && tag[0] == 'i') tag,
        ];

        stubQuery([eventA, eventB]);
        expect(
          await repository.freshIdentityTags(
            pubkey: _pubkey,
            kind0Tags: _kind0Tags,
          ),
          equals(expectedTags),
        );

        stubQuery([eventB, eventA]);
        expect(
          await repository.freshIdentityTags(
            pubkey: _pubkey,
            kind0Tags: _kind0Tags,
          ),
          equals(expectedTags),
          reason: 'winner must not depend on relay return order',
        );
      },
    );

    test('strips non-i tags from the live event', () async {
      stubQuery([_identityEvent()]);

      final tags = await repository.freshIdentityTags(
        pubkey: _pubkey,
        kind0Tags: _kind0Tags,
      );

      expect(
        tags,
        equals([
          ['i', 'github:modern', 'modern-proof'],
        ]),
      );
    });

    test('works without a DAO (no persistence)', () async {
      stubQuery([_identityEvent()]);
      final bare = buildRepository(withDao: false);

      final tags = await bare.freshIdentityTags(
        pubkey: _pubkey,
        kind0Tags: _kind0Tags,
      );

      expect(tags, hasLength(1));
      verifyNever(
        () => identityEventsDao.upsertEvent(
          pubkey: any(named: 'pubkey'),
          tagsJson: any(named: 'tagsJson'),
          sourceKind: any(named: 'sourceKind'),
        ),
      );
    });

    test(
      'keeps a cached kind-10011 row when the live query finds nothing '
      '(transient relay miss must not downgrade the source)',
      () async {
        stubQuery(const []);
        when(() => identityEventsDao.getEvent(_pubkey)).thenAnswer(
          (_) async => _row(tagsJson: '[["i","github:modern","modern-proof"]]'),
        );

        final tags = await repository.freshIdentityTags(
          pubkey: _pubkey,
          kind0Tags: _kind0Tags,
        );

        expect(
          tags,
          equals([
            ['i', 'github:modern', 'modern-proof'],
          ]),
        );
        verifyNever(
          () => identityEventsDao.upsertEvent(
            pubkey: any(named: 'pubkey'),
            tagsJson: any(named: 'tagsJson'),
            sourceKind: any(named: 'sourceKind'),
          ),
        );
      },
    );

    test(
      'falls back to kind-0 i tags when a cached kind-10011 row is corrupt, '
      'and caches the fallback',
      () async {
        stubQuery(const []);
        when(
          () => identityEventsDao.getEvent(_pubkey),
        ).thenAnswer((_) async => _row(tagsJson: 'not json'));

        final tags = await repository.freshIdentityTags(
          pubkey: _pubkey,
          kind0Tags: _kind0Tags,
        );

        expect(
          tags,
          equals([
            ['i', 'github:legacy', 'legacy-proof'],
          ]),
        );
        verify(
          () => identityEventsDao.upsertEvent(
            pubkey: _pubkey,
            tagsJson: '[["i","github:legacy","legacy-proof"]]',
            sourceKind: 0,
          ),
        ).called(1);
      },
    );

    test(
      'falls back to kind-0 i tags when nothing is cached, and does not '
      'treat a kind-0-sourced row as authoritative',
      () async {
        stubQuery(const []);
        when(() => identityEventsDao.getEvent(_pubkey)).thenAnswer(
          (_) async => _row(
            tagsJson: '[["i","github:stale","stale-proof"]]',
            sourceKind: 0,
          ),
        );

        final tags = await repository.freshIdentityTags(
          pubkey: _pubkey,
          kind0Tags: _kind0Tags,
        );

        expect(
          tags,
          equals([
            ['i', 'github:legacy', 'legacy-proof'],
          ]),
        );
      },
    );

    test('falls back to kind-0 i tags when the relay query throws', () async {
      when(
        () => nostrClient.queryEvents(any(), useCache: false),
      ).thenThrow(Exception('relay down'));
      when(
        () => identityEventsDao.getEvent(_pubkey),
      ).thenAnswer((_) async => null);

      final tags = await repository.freshIdentityTags(
        pubkey: _pubkey,
        kind0Tags: _kind0Tags,
      );

      expect(
        tags,
        equals([
          ['i', 'github:legacy', 'legacy-proof'],
        ]),
      );
    });

    test('ignores non-kind-10011 events in the relay response', () async {
      stubQuery([_identityEvent(kind: 0)]);
      when(
        () => identityEventsDao.getEvent(_pubkey),
      ).thenAnswer((_) async => null);

      final tags = await repository.freshIdentityTags(
        pubkey: _pubkey,
        kind0Tags: _kind0Tags,
      );

      expect(
        tags,
        equals([
          ['i', 'github:legacy', 'legacy-proof'],
        ]),
      );
    });
  });
}
