// ABOUTME: Tests for PeopleListsRepositoryImpl relay publish and sync flow.
// ABOUTME: Covers submitted-only semantics, NIP-09 delete, and echo ordering.

import 'dart:async';
import 'dart:io';

import 'package:hive_ce/hive_ce.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:people_lists_repository/people_lists_repository.dart';
import 'package:test/test.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _FakeEvent extends Fake implements Event {}

class _FakeFilter extends Fake implements Filter {}

/// Test constants. Full 64-char pubkeys — never truncate.
const _ownerPubkey =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _memberA =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _memberB =
    '3333333333333333333333333333333333333333333333333333333333333333';

const int _peopleListKind = 30000;
const int _deletionKind = 5;

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(<Filter>[_FakeFilter()]);
  });

  group(PeopleListsRepositoryImpl, () {
    late Directory tempDir;
    late int boxCounter;

    Future<Box<dynamic>> Function() makeOpener() {
      final boxName = 'people_lists_repo_test_${boxCounter++}';
      return () async => Hive.openBox<dynamic>(boxName, path: tempDir.path);
    }

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'people_lists_repository_impl_test_',
      );
      Hive.init(tempDir.path);
      boxCounter = 0;
    });

    tearDown(() async {
      await Hive.close();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    PeopleListsRepositoryImpl buildRepository({
      required NostrClient nostrClient,
      LocalPeopleListsCache? cache,
    }) {
      return PeopleListsRepositoryImpl(
        nostrClient: nostrClient,
        cache: cache ?? LocalPeopleListsCache(openBox: makeOpener()),
      );
    }

    Event signedEvent({
      required int kind,
      required List<List<String>> tags,
      String content = '',
      int? createdAt,
    }) {
      return Event(
          _ownerPubkey,
          kind,
          tags,
          content,
          createdAt: createdAt,
        )
        // Mark as signed for callers that check sig presence.
        ..sig =
            'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee'
            'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
    }

    group('createList', () {
      test('returns submitted result when publishEvent returns a non-null '
          'event', () async {
        final client = _MockNostrClient();
        when(() => client.publicKey).thenReturn(_ownerPubkey);
        when(() => client.publishEvent(any())).thenAnswer((invocation) async {
          final event = invocation.positionalArguments.first as Event;
          return signedEvent(
            kind: event.kind,
            tags: event.tags,
            content: event.content,
            createdAt: event.createdAt,
          );
        });
        final repository = buildRepository(nostrClient: client);

        final result = await repository.createList(
          ownerPubkey: _ownerPubkey,
          name: 'Besties',
          description: 'the best',
          initialPubkeys: const [_memberA],
        );

        expect(result.status, equals(PeopleListPublishStatus.submitted));
        expect(result.submitted, isTrue);
        expect(result.eventId, isNotNull);
        expect(result.eventId, isNot(isEmpty));

        final stored = await repository.readLists(ownerPubkey: _ownerPubkey);
        expect(stored, hasLength(1));
        expect(stored.single.name, equals('Besties'));
        expect(stored.single.pubkeys, equals(const [_memberA]));
      });

      test('does not write to cache when publishEvent returns null', () async {
        final client = _MockNostrClient();
        when(() => client.publicKey).thenReturn(_ownerPubkey);
        when(() => client.publishEvent(any())).thenAnswer((_) async => null);
        final repository = buildRepository(nostrClient: client);

        final result = await repository.createList(
          ownerPubkey: _ownerPubkey,
          name: 'Besties',
        );

        expect(result.status, equals(PeopleListPublishStatus.failed));
        expect(result.submitted, isFalse);

        final stored = await repository.readLists(ownerPubkey: _ownerPubkey);
        expect(stored, isEmpty);
      });

      test('returns failed when publishEvent throws', () async {
        final client = _MockNostrClient();
        when(() => client.publicKey).thenReturn(_ownerPubkey);
        when(
          () => client.publishEvent(any()),
        ).thenThrow(StateError('network down'));
        final repository = buildRepository(nostrClient: client);

        final result = await repository.createList(
          ownerPubkey: _ownerPubkey,
          name: 'Besties',
        );

        expect(result.status, equals(PeopleListPublishStatus.failed));
        expect(result.error, isA<StateError>());
      });

      test('never reports confirmed status', () async {
        final client = _MockNostrClient();
        when(() => client.publicKey).thenReturn(_ownerPubkey);
        when(() => client.publishEvent(any())).thenAnswer((invocation) async {
          final event = invocation.positionalArguments.first as Event;
          return signedEvent(
            kind: event.kind,
            tags: event.tags,
            content: event.content,
            createdAt: event.createdAt,
          );
        });
        final repository = buildRepository(nostrClient: client);

        final result = await repository.createList(
          ownerPubkey: _ownerPubkey,
          name: 'Besties',
        );

        expect(
          PeopleListPublishStatus.values,
          isNot(
            contains(
              isA<PeopleListPublishStatus>().having(
                (s) => s.name,
                'name',
                'confirmed',
              ),
            ),
          ),
        );
        expect(result.status.name, equals('submitted'));
      });
    });

    group('addPubkey', () {
      test(
        'publishes a kind 30000 event with a full p tag for new pubkey',
        () async {
          final client = _MockNostrClient();
          when(() => client.publicKey).thenReturn(_ownerPubkey);
          when(() => client.publishEvent(any())).thenAnswer((invocation) async {
            final event = invocation.positionalArguments.first as Event;
            return signedEvent(
              kind: event.kind,
              tags: event.tags,
              content: event.content,
              createdAt: event.createdAt,
            );
          });
          final repository = buildRepository(nostrClient: client);

          await repository.createList(
            ownerPubkey: _ownerPubkey,
            name: 'Besties',
            initialPubkeys: const [_memberA],
          );

          final result = await repository.addPubkey(
            ownerPubkey: _ownerPubkey,
            listId: (await repository.readLists(
              ownerPubkey: _ownerPubkey,
            )).single.id,
            pubkey: _memberB,
          );

          expect(result.status, equals(PeopleListPublishStatus.submitted));
          final captured = verify(
            () => client.publishEvent(captureAny()),
          ).captured.cast<Event>();

          // First publish was createList, second was addPubkey.
          expect(captured, hasLength(2));
          final addEvent = captured.last;
          expect(addEvent.kind, equals(_peopleListKind));
          final pTags = addEvent.tags
              .where((tag) => tag.isNotEmpty && tag.first == 'p')
              .map((tag) => tag[1])
              .toList();
          expect(pTags, containsAll(<String>[_memberA, _memberB]));
          // Full pubkey preserved, not truncated.
          expect(
            pTags.every((pk) => pk.length == 64),
            isTrue,
            reason: 'p tags must carry full 64-char pubkeys',
          );

          final stored = await repository.readLists(ownerPubkey: _ownerPubkey);
          expect(stored.single.pubkeys, equals(const [_memberA, _memberB]));
        },
      );

      test('returns noop when pubkey is already in list', () async {
        final client = _MockNostrClient();
        when(() => client.publicKey).thenReturn(_ownerPubkey);
        when(() => client.publishEvent(any())).thenAnswer((invocation) async {
          final event = invocation.positionalArguments.first as Event;
          return signedEvent(
            kind: event.kind,
            tags: event.tags,
            content: event.content,
            createdAt: event.createdAt,
          );
        });
        final repository = buildRepository(nostrClient: client);

        await repository.createList(
          ownerPubkey: _ownerPubkey,
          name: 'Besties',
          initialPubkeys: const [_memberA],
        );
        final listId = (await repository.readLists(
          ownerPubkey: _ownerPubkey,
        )).single.id;

        clearInteractions(client);

        final result = await repository.addPubkey(
          ownerPubkey: _ownerPubkey,
          listId: listId,
          pubkey: _memberA,
        );

        expect(result.status, equals(PeopleListPublishStatus.noop));
        verifyNever(() => client.publishEvent(any()));
      });
    });

    group('removePubkey', () {
      test(
        'returns noop and does not publish when pubkey is not in list',
        () async {
          final client = _MockNostrClient();
          when(() => client.publicKey).thenReturn(_ownerPubkey);
          when(() => client.publishEvent(any())).thenAnswer((invocation) async {
            final event = invocation.positionalArguments.first as Event;
            return signedEvent(
              kind: event.kind,
              tags: event.tags,
              content: event.content,
              createdAt: event.createdAt,
            );
          });
          final repository = buildRepository(nostrClient: client);

          await repository.createList(
            ownerPubkey: _ownerPubkey,
            name: 'Besties',
            initialPubkeys: const [_memberA],
          );
          final listId = (await repository.readLists(
            ownerPubkey: _ownerPubkey,
          )).single.id;

          clearInteractions(client);

          final result = await repository.removePubkey(
            ownerPubkey: _ownerPubkey,
            listId: listId,
            pubkey: _memberB,
          );

          expect(result.status, equals(PeopleListPublishStatus.noop));
          verifyNever(() => client.publishEvent(any()));
        },
      );

      test('publishes replacement event without the removed pubkey', () async {
        final client = _MockNostrClient();
        when(() => client.publicKey).thenReturn(_ownerPubkey);
        when(() => client.publishEvent(any())).thenAnswer((invocation) async {
          final event = invocation.positionalArguments.first as Event;
          return signedEvent(
            kind: event.kind,
            tags: event.tags,
            content: event.content,
            createdAt: event.createdAt,
          );
        });
        final repository = buildRepository(nostrClient: client);

        await repository.createList(
          ownerPubkey: _ownerPubkey,
          name: 'Besties',
          initialPubkeys: const [_memberA, _memberB],
        );
        final listId = (await repository.readLists(
          ownerPubkey: _ownerPubkey,
        )).single.id;

        clearInteractions(client);

        final result = await repository.removePubkey(
          ownerPubkey: _ownerPubkey,
          listId: listId,
          pubkey: _memberA,
        );

        expect(result.status, equals(PeopleListPublishStatus.submitted));
        final captured = verify(
          () => client.publishEvent(captureAny()),
        ).captured.cast<Event>();
        expect(captured, hasLength(1));
        final published = captured.single;
        expect(published.kind, equals(_peopleListKind));
        final remainingPTags = published.tags
            .where((tag) => tag.isNotEmpty && tag.first == 'p')
            .map((tag) => tag[1])
            .toList();
        expect(remainingPTags, equals(const [_memberB]));

        final stored = await repository.readLists(ownerPubkey: _ownerPubkey);
        expect(stored.single.pubkeys, equals(const [_memberB]));
      });
    });

    group('deleteList', () {
      test('publishes NIP-09 kind 5 event with a and k tags, then tombstones '
          'locally', () async {
        final client = _MockNostrClient();
        when(() => client.publicKey).thenReturn(_ownerPubkey);
        when(() => client.publishEvent(any())).thenAnswer((invocation) async {
          final event = invocation.positionalArguments.first as Event;
          return signedEvent(
            kind: event.kind,
            tags: event.tags,
            content: event.content,
            createdAt: event.createdAt,
          );
        });
        final repository = buildRepository(nostrClient: client);

        await repository.createList(
          ownerPubkey: _ownerPubkey,
          name: 'Besties',
          initialPubkeys: const [_memberA],
        );
        final listId = (await repository.readLists(
          ownerPubkey: _ownerPubkey,
        )).single.id;

        clearInteractions(client);

        final result = await repository.deleteList(
          ownerPubkey: _ownerPubkey,
          listId: listId,
        );

        expect(result.status, equals(PeopleListPublishStatus.submitted));
        final captured = verify(
          () => client.publishEvent(captureAny()),
        ).captured.cast<Event>();
        expect(captured, hasLength(1));
        final deletion = captured.single;
        expect(deletion.kind, equals(_deletionKind));
        expect(deletion.content, equals('Deleted people list $listId'));
        expect(
          deletion.tags,
          containsOnce(
            equals(<String>[
              'a',
              '$_peopleListKind:$_ownerPubkey:$listId',
            ]),
          ),
        );
        expect(
          deletion.tags,
          containsOnce(equals(<String>['k', '$_peopleListKind'])),
        );

        final stored = await repository.readLists(ownerPubkey: _ownerPubkey);
        expect(stored, isEmpty);
      });

      test('does not tombstone locally when publish returns null', () async {
        final client = _MockNostrClient();
        when(() => client.publicKey).thenReturn(_ownerPubkey);

        // First call for createList succeeds, second (deleteList) fails.
        var publishCalls = 0;
        when(() => client.publishEvent(any())).thenAnswer((invocation) async {
          publishCalls++;
          if (publishCalls == 1) {
            final event = invocation.positionalArguments.first as Event;
            return signedEvent(
              kind: event.kind,
              tags: event.tags,
              content: event.content,
              createdAt: event.createdAt,
            );
          }
          return null;
        });
        final repository = buildRepository(nostrClient: client);

        await repository.createList(
          ownerPubkey: _ownerPubkey,
          name: 'Besties',
          initialPubkeys: const [_memberA],
        );
        final listId = (await repository.readLists(
          ownerPubkey: _ownerPubkey,
        )).single.id;

        final result = await repository.deleteList(
          ownerPubkey: _ownerPubkey,
          listId: listId,
        );

        expect(result.status, equals(PeopleListPublishStatus.failed));
        final stored = await repository.readLists(ownerPubkey: _ownerPubkey);
        expect(stored, hasLength(1));
      });
    });

    group('syncOwner', () {
      test(
        'queries kind 30000 by author and writes decoded lists to cache',
        () async {
          final client = _MockNostrClient();
          when(() => client.publicKey).thenReturn(_ownerPubkey);

          final remoteEvent = signedEvent(
            kind: _peopleListKind,
            tags: const [
              ['d', 'Crew'],
              ['title', 'Crew'],
              ['p', _memberA],
            ],
          );

          when(
            () => client.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => [remoteEvent]);

          final repository = buildRepository(nostrClient: client);

          await repository.syncOwner(ownerPubkey: _ownerPubkey);

          final capturedFilters = verify(
            () => client.queryEvents(
              captureAny(),
              useCache: any(named: 'useCache'),
            ),
          ).captured.cast<List<Filter>>();
          expect(capturedFilters, hasLength(1));
          final filter = capturedFilters.single.single;
          expect(filter.kinds, equals(const [_peopleListKind]));
          expect(filter.authors, equals(const [_ownerPubkey]));

          final stored = await repository.readLists(ownerPubkey: _ownerPubkey);
          expect(stored, hasLength(1));
          expect(stored.single.id, equals('Crew'));
          expect(stored.single.pubkeys, equals(const [_memberA]));
        },
      );

      test('filters out app block-list events with d=block', () async {
        final client = _MockNostrClient();
        when(() => client.publicKey).thenReturn(_ownerPubkey);

        final crewEvent = signedEvent(
          kind: _peopleListKind,
          tags: const [
            ['d', 'Crew'],
            ['title', 'Crew'],
            ['p', _memberA],
          ],
        );
        final blockEvent = signedEvent(
          kind: _peopleListKind,
          tags: const [
            ['d', 'block'],
            ['p', _memberB],
          ],
        );

        when(
          () => client.queryEvents(
            any(),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) async => [crewEvent, blockEvent]);

        final repository = buildRepository(nostrClient: client);

        await repository.syncOwner(ownerPubkey: _ownerPubkey);

        final stored = await repository.readLists(ownerPubkey: _ownerPubkey);
        expect(stored, hasLength(1));
        expect(stored.single.id, equals('Crew'));
      });

      test(
        'does not overwrite newer local list with stale relay echo',
        () async {
          final client = _MockNostrClient();
          when(() => client.publicKey).thenReturn(_ownerPubkey);

          // Local optimistic write will be far in the future.
          when(() => client.publishEvent(any())).thenAnswer((invocation) async {
            final event = invocation.positionalArguments.first as Event;
            return signedEvent(
              kind: event.kind,
              tags: event.tags,
              content: event.content,
              createdAt: event.createdAt,
            );
          });
          final repository = buildRepository(nostrClient: client);

          await repository.createList(
            ownerPubkey: _ownerPubkey,
            name: 'Besties',
            initialPubkeys: const [_memberA, _memberB],
          );

          final listId = (await repository.readLists(
            ownerPubkey: _ownerPubkey,
          )).single.id;

          // Now simulate a stale relay echo with an older createdAt and only
          // one pubkey — must not clobber the newer local state.
          final staleCreatedAt =
              DateTime.now()
                  .subtract(const Duration(hours: 1))
                  .millisecondsSinceEpoch ~/
              1000;
          final staleEvent = signedEvent(
            kind: _peopleListKind,
            tags: [
              ['d', listId],
              ['title', 'Besties'],
              ['p', _memberA],
            ],
            createdAt: staleCreatedAt,
          );

          when(
            () => client.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => [staleEvent]);

          await repository.syncOwner(ownerPubkey: _ownerPubkey);

          final stored = await repository.readLists(ownerPubkey: _ownerPubkey);
          expect(stored, hasLength(1));
          expect(
            stored.single.pubkeys,
            equals(const [_memberA, _memberB]),
            reason: 'newer local state must not be overwritten by stale echo',
          );
        },
      );
    });

    group('searchPublicLists', () {
      // Second owner pubkey for multi-owner deduplication tests.
      const secondOwner =
          '4444444444444444444444444444444444444444444444444444444444444444';

      Event peopleEvent({
        required String pubkey,
        required String dTag,
        required String title,
        required List<String> pubkeys,
        String? description,
        int? createdAt,
      }) {
        return Event(
          pubkey,
          _peopleListKind,
          [
            ['d', dTag],
            ['title', title],
            if (description != null) ['description', description],
            for (final pk in pubkeys) ['p', pk],
          ],
          '',
          createdAt: createdAt,
        );
      }

      test(
        'issues a kind 30000 relay query with the given limit',
        () async {
          final client = _MockNostrClient();
          when(() => client.publicKey).thenReturn(_ownerPubkey);
          when(
            () => client.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => const []);

          final repository = buildRepository(nostrClient: client);

          await repository.searchPublicLists('anything', limit: 25).toList();

          final capturedFilters = verify(
            () => client.queryEvents(
              captureAny(),
              useCache: any(named: 'useCache'),
            ),
          ).captured.cast<List<Filter>>();
          expect(capturedFilters, hasLength(1));
          final filter = capturedFilters.single.single;
          expect(filter.kinds, equals(const [_peopleListKind]));
          expect(filter.limit, equals(25));
        },
      );

      test('emits empty stream for a blank query', () async {
        final client = _MockNostrClient();
        final repository = buildRepository(nostrClient: client);

        final emissions = await repository.searchPublicLists('').toList();

        expect(emissions, isEmpty);
        verifyNever(
          () => client.queryEvents(
            any(),
            useCache: any(named: 'useCache'),
          ),
        );
      });

      test('emits empty stream for a whitespace-only query', () async {
        final client = _MockNostrClient();
        final repository = buildRepository(nostrClient: client);

        final emissions = await repository.searchPublicLists('   ').toList();

        expect(emissions, isEmpty);
      });

      test('emits a single match with the owner pubkey preserved', () async {
        final client = _MockNostrClient();
        when(() => client.publicKey).thenReturn(_ownerPubkey);

        final event = peopleEvent(
          pubkey: _ownerPubkey,
          dTag: 'punk-friends',
          title: 'Punk Friends',
          pubkeys: const [_memberA, _memberB],
        );
        when(
          () => client.queryEvents(
            any(),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) async => [event]);

        final repository = buildRepository(nostrClient: client);

        final emissions = await repository.searchPublicLists('punk').toList();

        expect(emissions, hasLength(1));
        final results = emissions.single;
        expect(results, hasLength(1));
        final result = results.single;
        expect(result.ownerPubkey, equals(_ownerPubkey));
        expect(result.ownerPubkey, hasLength(64));
        expect(result.list.id, equals('punk-friends'));
        expect(result.list.name, equals('Punk Friends'));
        expect(result.list.pubkeys, equals(const [_memberA, _memberB]));
        expect(
          result.addressableId,
          equals('$_peopleListKind:$_ownerPubkey:punk-friends'),
        );
      });

      test('filters out lists with no pubkeys', () async {
        final client = _MockNostrClient();
        when(() => client.publicKey).thenReturn(_ownerPubkey);

        final empty = peopleEvent(
          pubkey: _ownerPubkey,
          dTag: 'empty',
          title: 'Empty Crew',
          pubkeys: const [],
        );
        final full = peopleEvent(
          pubkey: _ownerPubkey,
          dTag: 'full',
          title: 'Crew',
          pubkeys: const [_memberA],
        );
        when(
          () => client.queryEvents(
            any(),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) async => [empty, full]);

        final repository = buildRepository(nostrClient: client);

        final emissions = await repository.searchPublicLists('crew').toList();

        expect(emissions, hasLength(1));
        expect(emissions.single, hasLength(1));
        expect(emissions.single.single.list.id, equals('full'));
      });

      test('filters out the app block list (d=block)', () async {
        final client = _MockNostrClient();
        when(() => client.publicKey).thenReturn(_ownerPubkey);

        final block = peopleEvent(
          pubkey: _ownerPubkey,
          dTag: 'block',
          title: 'Crew',
          pubkeys: const [_memberA],
        );
        when(
          () => client.queryEvents(
            any(),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) async => [block]);

        final repository = buildRepository(nostrClient: client);

        final emissions = await repository.searchPublicLists('crew').toList();

        expect(emissions, isEmpty);
      });

      test(
        'matches the query case-insensitively against name and description',
        () async {
          final client = _MockNostrClient();
          when(() => client.publicKey).thenReturn(_ownerPubkey);

          final byName = peopleEvent(
            pubkey: _ownerPubkey,
            dTag: 'by-name',
            title: 'Punk Legends',
            pubkeys: const [_memberA],
          );
          final byDescription = peopleEvent(
            pubkey: _ownerPubkey,
            dTag: 'by-desc',
            title: 'Crew',
            description: 'All the PUNK heroes',
            pubkeys: const [_memberA],
          );
          final nonMatching = peopleEvent(
            pubkey: _ownerPubkey,
            dTag: 'other',
            title: 'Jazz Friends',
            pubkeys: const [_memberA],
          );
          when(
            () => client.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => [byName, byDescription, nonMatching]);

          final repository = buildRepository(nostrClient: client);

          final emissions = await repository.searchPublicLists('PuNk').toList();

          expect(emissions, hasLength(1));
          final ids = emissions.single.map((r) => r.list.id).toList();
          expect(ids, containsAll(<String>['by-name', 'by-desc']));
          expect(ids, isNot(contains('other')));
        },
      );

      test(
        'deduplicates by addressable coordinate, not d tag alone',
        () async {
          // Two different owners both publish `d=friends` — these are
          // distinct addressable events and must both survive.
          final client = _MockNostrClient();
          when(() => client.publicKey).thenReturn(_ownerPubkey);

          final fromOwner = peopleEvent(
            pubkey: _ownerPubkey,
            dTag: 'friends',
            title: 'Owner Friends',
            pubkeys: const [_memberA],
          );
          final fromSecondOwner = peopleEvent(
            pubkey: secondOwner,
            dTag: 'friends',
            title: 'Second Friends',
            pubkeys: const [_memberB],
          );
          when(
            () => client.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => [fromOwner, fromSecondOwner]);

          final repository = buildRepository(nostrClient: client);

          final emissions = await repository
              .searchPublicLists('friends')
              .toList();

          expect(emissions, hasLength(1));
          final results = emissions.single;
          expect(results, hasLength(2));
          final owners = results.map((r) => r.ownerPubkey).toSet();
          expect(owners, equals({_ownerPubkey, secondOwner}));
          final coordinates = results.map((r) => r.addressableId).toSet();
          expect(
            coordinates,
            equals({
              '$_peopleListKind:$_ownerPubkey:friends',
              '$_peopleListKind:$secondOwner:friends',
            }),
          );
        },
      );

      test(
        'keeps the newest event when duplicates share an addressable '
        'coordinate',
        () async {
          final client = _MockNostrClient();
          when(() => client.publicKey).thenReturn(_ownerPubkey);

          final older = peopleEvent(
            pubkey: _ownerPubkey,
            dTag: 'crew',
            title: 'Crew',
            pubkeys: const [_memberA],
            createdAt: 1710000000,
          );
          final newer = peopleEvent(
            pubkey: _ownerPubkey,
            dTag: 'crew',
            title: 'Crew Updated',
            pubkeys: const [_memberA, _memberB],
            createdAt: 1710000500,
          );
          when(
            () => client.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => [older, newer]);

          final repository = buildRepository(nostrClient: client);

          final emissions = await repository.searchPublicLists('crew').toList();

          expect(emissions, hasLength(1));
          expect(emissions.single, hasLength(1));
          expect(emissions.single.single.list.name, equals('Crew Updated'));
          expect(
            emissions.single.single.list.pubkeys,
            equals(const [_memberA, _memberB]),
          );
        },
      );

      test('does not yield when no events match the query', () async {
        final client = _MockNostrClient();
        when(() => client.publicKey).thenReturn(_ownerPubkey);

        final event = peopleEvent(
          pubkey: _ownerPubkey,
          dTag: 'jazz',
          title: 'Jazz',
          pubkeys: const [_memberA],
        );
        when(
          () => client.queryEvents(
            any(),
            useCache: any(named: 'useCache'),
          ),
        ).thenAnswer((_) async => [event]);

        final repository = buildRepository(nostrClient: client);

        final emissions = await repository.searchPublicLists('polka').toList();

        expect(emissions, isEmpty);
      });
    });

    group('watchLists', () {
      test('emits cached lists on subscribe and after createList', () async {
        final client = _MockNostrClient();
        when(() => client.publicKey).thenReturn(_ownerPubkey);
        when(() => client.publishEvent(any())).thenAnswer((invocation) async {
          final event = invocation.positionalArguments.first as Event;
          return signedEvent(
            kind: event.kind,
            tags: event.tags,
            content: event.content,
            createdAt: event.createdAt,
          );
        });
        final repository = buildRepository(nostrClient: client);

        // Take the first two emissions: the initial empty snapshot on
        // subscribe, and the post-createList snapshot driven by the cache's
        // box watch. Using `take(2).toList()` lets the stream drive timing
        // instead of timed waits.
        final emissionsFuture = repository
            .watchLists(ownerPubkey: _ownerPubkey)
            .take(2)
            .toList();

        await repository.createList(
          ownerPubkey: _ownerPubkey,
          name: 'Besties',
          initialPubkeys: const [_memberA],
        );

        final emissions = await emissionsFuture;

        expect(emissions, hasLength(2));
        expect(emissions.first, isEmpty);
        expect(emissions.last, hasLength(1));
        expect(emissions.last.single.pubkeys, equals(const [_memberA]));
      });
    });
  });
}
