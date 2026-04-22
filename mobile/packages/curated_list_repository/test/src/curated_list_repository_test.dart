import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show Event;
import 'package:test/test.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

/// 64-char hex pubkey for test events.
const _testPubkey =
    'aabbccddaabbccddaabbccddaabbccdd'
    'aabbccddaabbccddaabbccddaabbccdd';

/// A second 64-char hex ID used as a video event reference.
const _videoEventId =
    '1111111111111111111111111111111111111111111111111111111111111111';

/// Additional hex IDs for multi-ref thumbnail tests.
const _videoEventId2 =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _videoEventId3 =
    '3333333333333333333333333333333333333333333333333333333333333333';

/// Creates a kind 30005 Nostr event with the given [tags] and [content].
Event _makeEvent({
  List<List<String>> tags = const [],
  String content = '',
  int? createdAt,
}) {
  return Event(
    _testPubkey,
    30005,
    tags.map(List<String>.from).toList(),
    content,
    createdAt: createdAt ?? 1718400000,
  );
}

/// Creates a kind 34236 (addressable short video) Nostr event with a
/// thumbnail tag.
Event _makeVideoEvent({String? thumbnail}) {
  return Event(
    _testPubkey,
    34236,
    [
      ['d', 'test-video'],
      ['title', 'Test Video'],
      ['url', 'https://example.com/video.mp4'],
      if (thumbnail != null) ['thumb', thumbnail],
    ],
    '',
    createdAt: 1718400000,
  );
}

/// Creates a kind 34236 video event with a specific [id] for relay
/// batching tests where the returned event must match the queried hex ID.
Event _makeVideoEventWithId(String id, {String? thumbnail}) {
  return Event.fromJson({
    'id': id,
    'pubkey': _testPubkey,
    'created_at': 1718400000,
    'kind': 34236,
    'tags': [
      ['d', 'test-video'],
      ['title', 'Test Video'],
      ['url', 'https://example.com/video.mp4'],
      if (thumbnail != null) ['thumb', thumbnail],
    ],
    'content': '',
    'sig': '',
  });
}

void main() {
  group(CuratedListRepository, () {
    late _MockNostrClient nostrClient;
    late _MockFunnelcakeApiClient funnelcakeApiClient;
    late CuratedListRepository repository;

    final now = DateTime(2025, 6, 15);

    CuratedList createList({
      required String id,
      String name = 'Test List',
      List<String> videoEventIds = const [],
      String? description,
      bool isPublic = true,
      List<String> tags = const [],
      PlayOrder playOrder = PlayOrder.chronological,
    }) {
      return CuratedList(
        id: id,
        name: name,
        videoEventIds: videoEventIds,
        createdAt: now,
        updatedAt: now,
        description: description,
        isPublic: isPublic,
        tags: tags,
        playOrder: playOrder,
      );
    }

    setUp(() {
      nostrClient = _MockNostrClient();
      funnelcakeApiClient = _MockFunnelcakeApiClient();
      repository = CuratedListRepository(
        nostrClient: nostrClient,
        funnelcakeApiClient: funnelcakeApiClient,
      );
    });

    tearDown(() async {
      await repository.dispose();
    });

    test('can be instantiated', () {
      expect(
        CuratedListRepository(
          nostrClient: _MockNostrClient(),
          funnelcakeApiClient: _MockFunnelcakeApiClient(),
        ),
        isNotNull,
      );
    });

    group('subscribedListsStream', () {
      test('emits initial empty list', () async {
        await expectLater(
          repository.subscribedListsStream,
          emits(isEmpty),
        );
      });

      test('emits after setSubscribedLists', () async {
        final list = createList(id: 'list-a', name: 'List A');

        repository.setSubscribedLists([list]);

        await expectLater(
          repository.subscribedListsStream,
          emits(equals([list])),
        );
      });

      test('replays last value to new subscribers', () async {
        final list = createList(id: 'list-a');

        repository.setSubscribedLists([list]);

        // Subscribe after emission — BehaviorSubject replays.
        await expectLater(
          repository.subscribedListsStream,
          emits(equals([list])),
        );
      });

      test('emits unmodifiable list', () async {
        repository.setSubscribedLists([createList(id: 'list-a')]);

        final emitted = await repository.subscribedListsStream.first;

        expect(
          () => emitted.add(createList(id: 'hack')),
          throwsA(isA<UnsupportedError>()),
        );
      });
    });

    group('dispose', () {
      test('closes stream', () async {
        await repository.dispose();

        await expectLater(
          repository.subscribedListsStream,
          emitsInOrder(<dynamic>[isEmpty, emitsDone]),
        );
      });

      test('is idempotent', () async {
        await repository.dispose();
        await repository.dispose();

        // No exception thrown.
      });

      test('setSubscribedLists after dispose does not throw', () async {
        await repository.dispose();

        // Should not throw even though stream is closed.
        expect(
          () => repository.setSubscribedLists([createList(id: 'x')]),
          returnsNormally,
        );
      });
    });

    group('getSubscribedListVideoRefs', () {
      test('returns empty map when no lists are set', () {
        expect(repository.getSubscribedListVideoRefs(), isEmpty);
      });

      test('returns video refs keyed by list ID', () {
        const eventId =
            'aabbccdd11223344aabbccdd11223344'
            'aabbccdd11223344aabbccdd11223344';
        const addressableCoord = '34236:pubkey123:my-vine';

        repository.setSubscribedLists([
          createList(
            id: 'list-a',
            videoEventIds: [eventId, addressableCoord],
          ),
          createList(
            id: 'list-b',
            videoEventIds: [addressableCoord],
          ),
        ]);

        final refs = repository.getSubscribedListVideoRefs();

        expect(refs, hasLength(2));
        expect(refs['list-a'], equals([eventId, addressableCoord]));
        expect(refs['list-b'], equals([addressableCoord]));
      });

      test('excludes lists with empty videoEventIds', () {
        repository.setSubscribedLists([
          createList(id: 'has-videos', videoEventIds: ['video-id']),
          createList(id: 'empty-list'),
        ]);

        final refs = repository.getSubscribedListVideoRefs();

        expect(refs, hasLength(1));
        expect(refs.containsKey('has-videos'), isTrue);
        expect(refs.containsKey('empty-list'), isFalse);
      });

      test('returns unmodifiable map', () {
        repository.setSubscribedLists([
          createList(id: 'list-a', videoEventIds: ['video-id']),
        ]);

        final refs = repository.getSubscribedListVideoRefs();

        expect(
          () => refs['new-key'] = [],
          throwsA(isA<UnsupportedError>()),
        );
      });

      test('returns unmodifiable video ID lists', () {
        repository.setSubscribedLists([
          createList(id: 'list-a', videoEventIds: ['video-id']),
        ]);

        final refs = repository.getSubscribedListVideoRefs();

        expect(
          () => refs['list-a']!.add('injected'),
          throwsA(isA<UnsupportedError>()),
        );
      });
    });

    group('getListById', () {
      test('returns null when no lists are set', () {
        expect(repository.getListById('nonexistent'), isNull);
      });

      test('returns null for unknown ID', () {
        repository.setSubscribedLists([
          createList(id: 'list-a'),
        ]);

        expect(repository.getListById('unknown'), isNull);
      });

      test('returns correct list by ID', () {
        final listA = createList(id: 'list-a', name: 'List A');
        final listB = createList(id: 'list-b', name: 'List B');
        repository.setSubscribedLists([listA, listB]);

        expect(repository.getListById('list-a'), equals(listA));
        expect(repository.getListById('list-b'), equals(listB));
      });
    });

    group('setSubscribedLists', () {
      test('replaces previous data', () {
        repository
          ..setSubscribedLists([
            createList(id: 'old-list', videoEventIds: ['old-video']),
          ])
          ..setSubscribedLists([
            createList(id: 'new-list', videoEventIds: ['new-video']),
          ]);

        expect(repository.getListById('old-list'), isNull);
        expect(repository.getListById('new-list'), isNotNull);

        final refs = repository.getSubscribedListVideoRefs();
        expect(refs, hasLength(1));
        expect(refs.containsKey('new-list'), isTrue);
      });

      test('clears all data when set with empty list', () {
        repository
          ..setSubscribedLists([
            createList(id: 'list-a', videoEventIds: ['video']),
          ])
          ..setSubscribedLists([]);

        expect(repository.getSubscribedListVideoRefs(), isEmpty);
        expect(repository.getListById('list-a'), isNull);
      });

      test('handles duplicate IDs by keeping the last one', () {
        repository.setSubscribedLists([
          createList(id: 'same-id', name: 'First'),
          createList(id: 'same-id', name: 'Second'),
        ]);

        expect(repository.getListById('same-id')?.name, equals('Second'));
      });
    });

    group('getSubscribedLists', () {
      test('returns empty list initially', () {
        expect(repository.getSubscribedLists(), isEmpty);
      });

      test('returns all subscribed lists', () {
        final listA = createList(id: 'a');
        final listB = createList(id: 'b');
        repository.setSubscribedLists([listA, listB]);

        expect(repository.getSubscribedLists(), hasLength(2));
        expect(repository.getSubscribedLists(), contains(listA));
        expect(repository.getSubscribedLists(), contains(listB));
      });

      test('returns unmodifiable list', () {
        repository.setSubscribedLists([createList(id: 'a')]);

        expect(
          () => repository.getSubscribedLists().add(createList(id: 'hack')),
          throwsA(isA<UnsupportedError>()),
        );
      });
    });

    group('isSubscribedToList', () {
      test('returns false for unknown list', () {
        expect(repository.isSubscribedToList('unknown'), isFalse);
      });

      test('returns true for subscribed list', () {
        repository.setSubscribedLists([createList(id: 'list-a')]);

        expect(repository.isSubscribedToList('list-a'), isTrue);
      });
    });

    group('isVideoInList', () {
      test('returns false for unknown list', () {
        expect(repository.isVideoInList('unknown', 'video-1'), isFalse);
      });

      test('returns false when video is not in list', () {
        repository.setSubscribedLists([
          createList(id: 'list-a', videoEventIds: ['video-1']),
        ]);

        expect(repository.isVideoInList('list-a', 'video-2'), isFalse);
      });

      test('returns true when video is in list', () {
        repository.setSubscribedLists([
          createList(id: 'list-a', videoEventIds: ['video-1', 'video-2']),
        ]);

        expect(repository.isVideoInList('list-a', 'video-2'), isTrue);
      });
    });

    group('hasDefaultList', () {
      test('returns false when no default list exists', () {
        repository.setSubscribedLists([createList(id: 'other')]);

        expect(repository.hasDefaultList(), isFalse);
      });

      test('returns true when default list exists', () {
        repository.setSubscribedLists([
          createList(id: defaultListId),
        ]);

        expect(repository.hasDefaultList(), isTrue);
      });
    });

    group('getDefaultList', () {
      test('returns null when no default list exists', () {
        expect(repository.getDefaultList(), isNull);
      });

      test('returns the default list', () {
        final myList = createList(id: defaultListId, name: 'My List');
        repository.setSubscribedLists([myList]);

        expect(repository.getDefaultList(), equals(myList));
      });
    });

    group('searchLists', () {
      test('returns empty for blank query', () {
        repository.setSubscribedLists([createList(id: 'a', name: 'Test')]);

        expect(repository.searchLists(''), isEmpty);
        expect(repository.searchLists('   '), isEmpty);
      });

      test('matches by name case-insensitively', () {
        repository.setSubscribedLists([
          createList(id: 'a', name: 'Dance Moves'),
          createList(id: 'b', name: 'Cooking Tips'),
        ]);

        final results = repository.searchLists('dance');

        expect(results, hasLength(1));
        expect(results.first.id, equals('a'));
      });

      test('matches by description', () {
        repository.setSubscribedLists([
          createList(
            id: 'a',
            name: 'Collection',
            description: 'Amazing guitar solos',
          ),
        ]);

        final results = repository.searchLists('guitar');

        expect(results, hasLength(1));
      });

      test('matches by tags', () {
        repository.setSubscribedLists([
          createList(id: 'a', name: 'Playlist', tags: ['music', 'jazz']),
        ]);

        final results = repository.searchLists('jazz');

        expect(results, hasLength(1));
      });

      test('excludes private lists', () {
        repository.setSubscribedLists([
          createList(id: 'a', name: 'Secret Dance', isPublic: false),
          createList(id: 'b', name: 'Public Dance'),
        ]);

        final results = repository.searchLists('dance');

        expect(results, hasLength(1));
        expect(results.first.id, equals('b'));
      });
    });

    group('getListsByTag', () {
      test('returns matching public lists', () {
        repository.setSubscribedLists([
          createList(id: 'a', tags: ['music', 'dance']),
          createList(id: 'b', tags: ['cooking']),
          createList(id: 'c', tags: ['music'], isPublic: false),
        ]);

        final results = repository.getListsByTag('music');

        expect(results, hasLength(1));
        expect(results.first.id, equals('a'));
      });

      test('returns empty when no match', () {
        repository.setSubscribedLists([
          createList(id: 'a', tags: ['cooking']),
        ]);

        expect(repository.getListsByTag('music'), isEmpty);
      });
    });

    group('getAllTags', () {
      test('returns empty when no lists', () {
        expect(repository.getAllTags(), isEmpty);
      });

      test('returns unique sorted tags from public lists', () {
        repository.setSubscribedLists([
          createList(id: 'a', tags: ['music', 'dance']),
          createList(id: 'b', tags: ['dance', 'cooking']),
          createList(id: 'c', tags: ['secret'], isPublic: false),
        ]);

        expect(
          repository.getAllTags(),
          equals(['cooking', 'dance', 'music']),
        );
      });
    });

    group('getListsContainingVideo', () {
      test('returns empty when video is in no lists', () {
        repository.setSubscribedLists([
          createList(id: 'a', videoEventIds: ['other-video']),
        ]);

        expect(repository.getListsContainingVideo('my-video'), isEmpty);
      });

      test('returns all lists containing the video', () {
        repository.setSubscribedLists([
          createList(id: 'a', videoEventIds: ['v1', 'v2']),
          createList(id: 'b', videoEventIds: ['v2', 'v3']),
          createList(id: 'c', videoEventIds: ['v3']),
        ]);

        final results = repository.getListsContainingVideo('v2');

        expect(results, hasLength(2));
        expect(results.map((l) => l.id), containsAll(['a', 'b']));
      });
    });

    group('getOrderedVideoIds', () {
      test('returns empty for unknown list', () {
        expect(repository.getOrderedVideoIds('unknown'), isEmpty);
      });

      test('returns chronological order', () {
        repository.setSubscribedLists([
          createList(
            id: 'list',
            videoEventIds: ['v1', 'v2', 'v3'],
          ),
        ]);

        expect(
          repository.getOrderedVideoIds('list'),
          equals(['v1', 'v2', 'v3']),
        );
      });

      test('returns reverse order', () {
        repository.setSubscribedLists([
          createList(
            id: 'list',
            videoEventIds: ['v1', 'v2', 'v3'],
            playOrder: PlayOrder.reverse,
          ),
        ]);

        expect(
          repository.getOrderedVideoIds('list'),
          equals(['v3', 'v2', 'v1']),
        );
      });

      test('returns manual order as-is', () {
        repository.setSubscribedLists([
          createList(
            id: 'list',
            videoEventIds: ['v3', 'v1', 'v2'],
            playOrder: PlayOrder.manual,
          ),
        ]);

        expect(
          repository.getOrderedVideoIds('list'),
          equals(['v3', 'v1', 'v2']),
        );
      });

      test('returns shuffled order with same elements', () {
        repository.setSubscribedLists([
          createList(
            id: 'list',
            videoEventIds: ['v1', 'v2', 'v3'],
            playOrder: PlayOrder.shuffle,
          ),
        ]);

        final ordered = repository.getOrderedVideoIds('list');

        // Contains the same elements (order may vary).
        expect(ordered, unorderedEquals(['v1', 'v2', 'v3']));
      });

      test('does not mutate original list', () {
        repository
          ..setSubscribedLists([
            createList(
              id: 'list',
              videoEventIds: ['v1', 'v2', 'v3'],
              playOrder: PlayOrder.reverse,
            ),
          ])
          ..getOrderedVideoIds('list');

        // Original list is unchanged.
        final list = repository.getListById('list')!;
        expect(list.videoEventIds, equals(['v1', 'v2', 'v3']));
      });
    });

    group('searchAllLists', () {
      setUp(() {
        registerFallbackValue(<Filter>[]);
      });

      test('emits nothing for blank query', () async {
        await expectLater(
          repository.searchAllLists(''),
          emitsDone,
        );
      });

      test('emits nothing for whitespace-only query', () async {
        await expectLater(
          repository.searchAllLists('   '),
          emitsDone,
        );
      });

      test('emits 4 progressive yields with thumbnails', () async {
        // Set up local subscribed lists
        repository.setSubscribedLists([
          createList(id: 'local-1', name: 'Dance Local'),
        ]);

        when(() => nostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            _makeEvent(
              tags: [
                ['d', 'relay-1'],
                ['title', 'Dance Relay'],
                ['e', 'video-1'],
              ],
            ),
          ],
        );

        final emissions = await repository.searchAllLists('dance').toList();

        expect(emissions, hasLength(4));

        // Yield 1: local results immediately (no thumbnails)
        expect(emissions[0], hasLength(1));
        expect(emissions[0].first.id, equals('local-1'));

        // Yield 2: local results with thumbnails resolved
        expect(emissions[1], hasLength(1));
        expect(emissions[1].first.id, equals('local-1'));

        // Yield 3: local + relay merged (relay without thumbnails)
        expect(emissions[2], hasLength(2));
        expect(
          emissions[2].map((l) => l.id),
          containsAll(['local-1', 'relay-1']),
        );

        // Yield 4: fully enriched
        expect(emissions[3], hasLength(2));
        expect(
          emissions[3].map((l) => l.id),
          containsAll(['local-1', 'relay-1']),
        );
      });

      test('excludes local IDs from relay search', () async {
        repository.setSubscribedLists([
          createList(id: 'shared-id', name: 'Dance Local'),
        ]);

        when(() => nostrClient.queryEvents(any())).thenAnswer(
          (_) async => [],
        );

        await repository.searchAllLists('dance').toList();

        // Verify queryEvents was called (relay search happened)
        verify(() => nostrClient.queryEvents(any())).called(1);
      });

      test('deduplicates relay results with local results', () async {
        repository.setSubscribedLists([
          createList(id: 'shared-id', name: 'Dance Local'),
        ]);

        // Relay returns a list with the same ID — but excludeIds
        // should prevent it. Return a different one instead.
        when(() => nostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            _makeEvent(
              tags: [
                ['d', 'new-relay'],
                ['title', 'Dance Relay'],
                ['e', 'video-1'],
              ],
            ),
          ],
        );

        final emissions = await repository.searchAllLists('dance').toList();

        expect(emissions, hasLength(4));
        // Yield 3: local + relay (no duplicates)
        expect(emissions[2], hasLength(2));
      });

      test('resolves thumbnails from FunnelCake API', () async {
        repository.setSubscribedLists([
          createList(
            id: 'local-1',
            name: 'Dance Local',
            videoEventIds: [_videoEventId],
          ),
        ]);

        when(() => funnelcakeApiClient.getVideoStats(_videoEventId)).thenAnswer(
          (_) async => VideoStats(
            id: _videoEventId,
            pubkey: _testPubkey,
            createdAt: DateTime(2025),
            kind: 34236,
            dTag: 'd',
            title: 'Test',
            thumbnail: 'https://example.com/thumb.jpg',
            videoUrl: 'https://example.com/video.mp4',
            reactions: 0,
            comments: 0,
            reposts: 0,
            engagementScore: 0,
          ),
        );

        when(() => nostrClient.queryEvents(any())).thenAnswer((_) async => []);

        final emissions = await repository.searchAllLists('dance').toList();

        // Yield 2 should have thumbnail resolved via FunnelCake
        expect(emissions[1].first.thumbnailUrls, isNotEmpty);
        expect(
          emissions[1].first.thumbnailUrls.first,
          equals('https://example.com/thumb.jpg'),
        );
      });

      test('falls back to relay when FunnelCake fails', () async {
        repository.setSubscribedLists([
          createList(
            id: 'local-1',
            name: 'Dance Local',
            videoEventIds: [_videoEventId],
          ),
        ]);

        when(
          () => funnelcakeApiClient.getVideoStats(_videoEventId),
        ).thenThrow(Exception('API down'));

        // Batched relay fallback returns event matching _videoEventId,
        // then relay search returns empty.
        when(() => nostrClient.queryEvents(any())).thenAnswer((invocation) {
          final filters = invocation.positionalArguments[0] as List<dynamic>;
          final filter = filters.first;

          // Relay search for curated lists (kind 30005)
          if (filter is Filter && filter.kinds?.contains(30005) == true) {
            return Future.value(<Event>[]);
          }

          // Batched thumbnail fallback
          return Future.value([
            _makeVideoEventWithId(
              _videoEventId,
              thumbnail: 'https://relay.com/thumb.jpg',
            ),
          ]);
        });

        final emissions = await repository.searchAllLists('dance').toList();

        expect(emissions[1].first.thumbnailUrls, isNotEmpty);
        expect(
          emissions[1].first.thumbnailUrls.first,
          equals('https://relay.com/thumb.jpg'),
        );
      });

      test('resolves addressable coordinate thumbnails', () async {
        const addressableCoord = '34236:$_testPubkey:my-video';
        repository.setSubscribedLists([
          createList(
            id: 'local-1',
            name: 'Dance Local',
            videoEventIds: [addressableCoord],
          ),
        ]);

        when(() => nostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            _makeVideoEvent(thumbnail: 'https://relay.com/addr-thumb.jpg'),
          ],
        );

        final emissions = await repository.searchAllLists('dance').toList();

        expect(emissions[1].first.thumbnailUrls, isNotEmpty);
        expect(
          emissions[1].first.thumbnailUrls.first,
          equals('https://relay.com/addr-thumb.jpg'),
        );
      });

      test('skips invalid addressable coordinates', () async {
        repository.setSubscribedLists([
          createList(
            id: 'local-1',
            name: 'Dance Local',
            videoEventIds: ['invalid-coord'],
          ),
        ]);

        when(() => nostrClient.queryEvents(any())).thenAnswer((_) async => []);

        final emissions = await repository.searchAllLists('dance').toList();

        // Thumbnail resolution returns null for bad coord, list stays empty
        expect(emissions[1].first.thumbnailUrls, isEmpty);
      });

      test('filters null thumbnails from results', () async {
        repository.setSubscribedLists([
          createList(
            id: 'local-1',
            name: 'Dance Local',
            videoEventIds: [_videoEventId],
          ),
        ]);

        // FunnelCake returns null (not found)
        when(
          () => funnelcakeApiClient.getVideoStats(_videoEventId),
        ).thenAnswer((_) async => null);

        // Relay also returns empty
        when(() => nostrClient.queryEvents(any())).thenAnswer((_) async => []);

        final emissions = await repository.searchAllLists('dance').toList();

        expect(emissions[1].first.thumbnailUrls, isEmpty);
      });

      test('matches relay lists by description', () async {
        when(() => nostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            _makeEvent(
              tags: [
                ['d', 'relay-1'],
                ['title', 'My List'],
                ['description', 'Great dance videos'],
                ['e', 'video-1'],
              ],
            ),
          ],
        );

        final emissions = await repository.searchAllLists('dance').toList();

        // Yield 3 should include the relay list matched by description
        expect(emissions[2].any((l) => l.id == 'relay-1'), isTrue);
      });

      test('matches relay lists by tag', () async {
        when(() => nostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            _makeEvent(
              tags: [
                ['d', 'relay-1'],
                ['title', 'My List'],
                ['t', 'dance'],
                ['e', 'video-1'],
              ],
            ),
          ],
        );

        final emissions = await repository.searchAllLists('dance').toList();

        expect(emissions[2].any((l) => l.id == 'relay-1'), isTrue);
      });

      test('keeps newer relay duplicate over older', () async {
        when(() => nostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            _makeEvent(
              tags: [
                ['d', 'dup-id'],
                ['title', 'Dance Old'],
                ['e', 'video-1'],
              ],
              createdAt: 1718400000,
            ),
            _makeEvent(
              tags: [
                ['d', 'dup-id'],
                ['title', 'Dance New'],
                ['e', 'video-1'],
              ],
              createdAt: 1718500000,
            ),
          ],
        );

        final emissions = await repository.searchAllLists('dance').toList();

        final relayList = emissions[2].where((l) => l.id == 'dup-id').toList();
        expect(relayList, hasLength(1));
        expect(relayList.first.name, equals('Dance New'));
      });

      test('returns empty thumbnails when relay batch throws', () async {
        repository.setSubscribedLists([
          createList(
            id: 'local-1',
            name: 'Dance Local',
            videoEventIds: [_videoEventId],
          ),
        ]);

        when(
          () => funnelcakeApiClient.getVideoStats(_videoEventId),
        ).thenAnswer((_) async => null);

        // Batched relay fallback throws, relay search returns empty.
        when(() => nostrClient.queryEvents(any())).thenAnswer((invocation) {
          final filters = invocation.positionalArguments[0] as List<dynamic>;
          final filter = filters.first;

          // Relay search for curated lists (kind 30005)
          if (filter is Filter && filter.kinds?.contains(30005) == true) {
            return Future.value(<Event>[]);
          }

          // Batched thumbnail fallback throws
          throw Exception('relay timeout');
        });

        final emissions = await repository.searchAllLists('dance').toList();

        // Yield 2: relay batch failed, thumbnails empty
        expect(emissions[1].first.thumbnailUrls, isEmpty);
      });

      test(
        'skips unparseable relay events during thumbnail resolution',
        () async {
          repository.setSubscribedLists([
            createList(
              id: 'local-1',
              name: 'Dance Local',
              videoEventIds: [_videoEventId],
            ),
          ]);

          when(
            () => funnelcakeApiClient.getVideoStats(_videoEventId),
          ).thenAnswer((_) async => null);

          // Relay returns an event with kind 1 (text note) which causes
          // VideoEvent.fromNostrEvent to throw — exercises the on Exception
          // catch in _batchRelayThumbnails.
          when(() => nostrClient.queryEvents(any())).thenAnswer((invocation) {
            final filters = invocation.positionalArguments[0] as List<dynamic>;
            final filter = filters.first;

            if (filter is Filter && filter.kinds?.contains(30005) == true) {
              return Future.value(<Event>[]);
            }

            // Non-video event that will fail parsing
            return Future.value([
              Event.fromJson({
                'id': _videoEventId,
                'pubkey': _testPubkey,
                'created_at': 1718400000,
                'kind': 1, // text note — not a video kind
                'tags': <List<String>>[],
                'content': 'hello',
                'sig': '',
              }),
            ]);
          });

          final emissions = await repository.searchAllLists('dance').toList();

          // Thumbnail resolution skipped the unparseable event
          expect(emissions[1].first.thumbnailUrls, isEmpty);
        },
      );

      test('filters out private lists from all emissions', () async {
        repository.setSubscribedLists([
          createList(
            id: 'private-1',
            name: 'Dance Secret',
            isPublic: false,
          ),
          createList(id: 'public-1', name: 'Dance Public'),
        ]);

        when(() => nostrClient.queryEvents(any())).thenAnswer(
          (_) async => [],
        );

        final emissions = await repository.searchAllLists('dance').toList();

        for (final emission in emissions) {
          expect(
            emission.every((l) => l.id != 'private-1'),
            isTrue,
          );
        }
      });

      test('excludes relay lists with empty videoEventIds', () async {
        when(() => nostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            _makeEvent(
              tags: [
                ['d', 'empty-list'],
                ['title', 'Dance Empty'],
                // No 'e' or 'a' tags → videoEventIds is empty
              ],
            ),
            _makeEvent(
              tags: [
                ['d', 'good-list'],
                ['title', 'Dance Good'],
                ['e', 'video-1'],
              ],
            ),
          ],
        );

        final emissions = await repository.searchAllLists('dance').toList();

        final relayIds = emissions[2].map((l) => l.id).toList();
        expect(relayIds, isNot(contains('empty-list')));
        expect(relayIds, contains('good-list'));
      });

      test('skips malformed relay events without d-tag', () async {
        when(() => nostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            // Valid event
            _makeEvent(
              tags: [
                ['d', 'good-list'],
                ['title', 'Dance Good'],
                ['e', 'video-1'],
              ],
            ),
            // Malformed — no d-tag → fromEvent returns null
            _makeEvent(
              tags: [
                ['title', 'Dance Bad'],
                ['e', 'video-2'],
              ],
            ),
          ],
        );

        final emissions = await repository.searchAllLists('dance').toList();

        // Yield 3 (merged) should contain only the valid relay list
        final relayIds = emissions[2].map((l) => l.id).toList();
        expect(relayIds, contains('good-list'));
        expect(relayIds, isNot(contains(null)));
        expect(emissions[2], hasLength(1));
      });

      test('emissions are unmodifiable', () async {
        repository.setSubscribedLists([
          createList(id: 'local-1', name: 'Dance Local'),
        ]);

        when(() => nostrClient.queryEvents(any())).thenAnswer(
          (_) async => [],
        );

        final emissions = await repository.searchAllLists('dance').toList();

        for (final emission in emissions) {
          expect(
            () => emission.add(createList(id: 'hack')),
            throwsA(isA<UnsupportedError>()),
          );
        }
      });

      test('partial thumbnail resolution across sources', () async {
        repository.setSubscribedLists([
          createList(
            id: 'local-1',
            name: 'Dance Local',
            videoEventIds: [_videoEventId, _videoEventId2, _videoEventId3],
          ),
        ]);

        // FunnelCake: ref1 → thumbnail, ref2 → null, ref3 → throws
        when(
          () => funnelcakeApiClient.getVideoStats(_videoEventId),
        ).thenAnswer(
          (_) async => VideoStats(
            id: _videoEventId,
            pubkey: _testPubkey,
            createdAt: DateTime(2025),
            kind: 34236,
            dTag: 'd',
            title: 'Test',
            thumbnail: 'https://fc.com/thumb1.jpg',
            videoUrl: 'https://example.com/video.mp4',
            reactions: 0,
            comments: 0,
            reposts: 0,
            engagementScore: 0,
          ),
        );

        when(
          () => funnelcakeApiClient.getVideoStats(_videoEventId2),
        ).thenAnswer((_) async => null);

        when(
          () => funnelcakeApiClient.getVideoStats(_videoEventId3),
        ).thenThrow(Exception('API error'));

        // Batched relay fallback: ref2 and ref3 go in one query.
        // Only ref3 returns a video with a thumbnail (ref2 has no match).
        // Relay search call returns empty.
        when(() => nostrClient.queryEvents(any())).thenAnswer((invocation) {
          final filters = invocation.positionalArguments[0] as List<dynamic>;
          final filter = filters.first;

          // Relay search for curated lists (kind 30005)
          if (filter is Filter && filter.kinds?.contains(30005) == true) {
            return Future.value(<Event>[]);
          }

          // Batched thumbnail fallback — only ref3 resolves
          return Future.value([
            _makeVideoEventWithId(
              _videoEventId3,
              thumbnail: 'https://relay.com/thumb3.jpg',
            ),
          ]);
        });

        final emissions = await repository.searchAllLists('dance').toList();

        // Yield 2: thumbnails resolved — ref1 from FC, ref3 from relay
        final thumbs = emissions[1].first.thumbnailUrls;
        expect(thumbs, hasLength(2));
        expect(thumbs, contains('https://fc.com/thumb1.jpg'));
        expect(thumbs, contains('https://relay.com/thumb3.jpg'));
      });

      test('emits 4 yields even when relay returns empty', () async {
        repository.setSubscribedLists([
          createList(id: 'local-1', name: 'Dance Local'),
        ]);

        when(() => nostrClient.queryEvents(any())).thenAnswer(
          (_) async => [],
        );

        final emissions = await repository.searchAllLists('dance').toList();

        expect(emissions, hasLength(4));
        // All yields contain only the local result
        for (final emission in emissions) {
          expect(emission, hasLength(1));
          expect(emission.first.id, equals('local-1'));
        }
      });
    });

    group('getVideoListSummary', () {
      test('returns "Not in any lists" when video is nowhere', () {
        expect(
          repository.getVideoListSummary('v1'),
          equals('Not in any lists'),
        );
      });

      test('returns single list name', () {
        repository.setSubscribedLists([
          createList(
            id: 'a',
            name: 'My Favorites',
            videoEventIds: ['v1'],
          ),
        ]);

        expect(
          repository.getVideoListSummary('v1'),
          equals('In "My Favorites"'),
        );
      });

      test('returns comma-separated names for 2-3 lists', () {
        repository.setSubscribedLists([
          createList(id: 'a', name: 'Favs', videoEventIds: ['v1']),
          createList(id: 'b', name: 'Dance', videoEventIds: ['v1']),
        ]);

        expect(
          repository.getVideoListSummary('v1'),
          equals('In "Favs", "Dance"'),
        );
      });

      test('returns count for 4+ lists', () {
        repository.setSubscribedLists([
          createList(id: 'a', name: 'A', videoEventIds: ['v1']),
          createList(id: 'b', name: 'B', videoEventIds: ['v1']),
          createList(id: 'c', name: 'C', videoEventIds: ['v1']),
          createList(id: 'd', name: 'D', videoEventIds: ['v1']),
        ]);

        expect(
          repository.getVideoListSummary('v1'),
          equals('In 4 lists'),
        );
      });
    });

    group('searchAllPeopleLists', () {
      Event makePeopleEvent({
        required String dTag,
        required String title,
        List<String> pubkeys = const [],
        int createdAt = 1718400000,
      }) {
        return Event(
          _testPubkey,
          30000,
          [
            ['d', dTag],
            ['title', title],
            for (final pk in pubkeys) ['p', pk],
          ],
          '',
          createdAt: createdAt,
        );
      }

      test('returns empty stream for blank query', () async {
        final results = await repository.searchAllPeopleLists('').toList();
        expect(results, isEmpty);
      });

      test('returns empty stream for whitespace-only query', () async {
        final results = await repository.searchAllPeopleLists('   ').toList();
        expect(results, isEmpty);
      });

      test('returns empty stream when relay returns no events', () async {
        when(
          () => nostrClient.queryEvents(any()),
        ).thenAnswer((_) async => []);

        final results = await repository.searchAllPeopleLists('vine').toList();
        expect(results, isEmpty);
      });

      test('propagates relay exception', () async {
        when(
          () => nostrClient.queryEvents(any()),
        ).thenThrow(Exception('relay error'));

        expect(
          repository.searchAllPeopleLists('vine').toList(),
          throwsA(isA<Exception>()),
        );
      });

      test('returns matching people list', () async {
        final event = makePeopleEvent(
          dTag: 'pl1',
          title: 'Vine Creators',
          pubkeys: ['pk1', 'pk2'],
        );
        when(
          () => nostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [event]);

        final results = await repository.searchAllPeopleLists('vine').toList();

        expect(results, hasLength(1));
        expect(results.first, hasLength(1));
        expect(results.first.first.id, equals('pl1'));
        expect(results.first.first.name, equals('Vine Creators'));
        expect(results.first.first.pubkeys, equals(['pk1', 'pk2']));
      });

      test('excludes lists with no pubkeys', () async {
        final emptyList = makePeopleEvent(
          dTag: 'empty',
          title: 'Vine Empty',
          pubkeys: [],
        );
        final nonEmpty = makePeopleEvent(
          dTag: 'full',
          title: 'Vine Full',
          pubkeys: ['pk1'],
        );
        when(
          () => nostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [emptyList, nonEmpty]);

        final results = await repository.searchAllPeopleLists('vine').toList();

        expect(results, hasLength(1));
        expect(results.first.first.id, equals('full'));
      });

      test('excludes lists that do not match query', () async {
        final matching = makePeopleEvent(
          dTag: 'match',
          title: 'Vine Stars',
          pubkeys: ['pk1'],
        );
        final nonMatching = makePeopleEvent(
          dTag: 'other',
          title: 'Unrelated List',
          pubkeys: ['pk2'],
        );
        when(
          () => nostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [matching, nonMatching]);

        final results = await repository.searchAllPeopleLists('vine').toList();

        expect(results, hasLength(1));
        expect(results.first.first.id, equals('match'));
      });

      test('deduplicates by d-tag keeping newest', () async {
        final older = makePeopleEvent(
          dTag: 'pl1',
          title: 'Vine List',
          pubkeys: ['pk1'],
        );
        final newer = makePeopleEvent(
          dTag: 'pl1',
          title: 'Vine List Updated',
          pubkeys: ['pk1', 'pk2'],
          createdAt: 1718400001,
        );
        when(
          () => nostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [older, newer]);

        final results = await repository.searchAllPeopleLists('vine').toList();

        expect(results, hasLength(1));
        expect(results.first, hasLength(1));
        expect(results.first.first.name, equals('Vine List Updated'));
        expect(results.first.first.pubkeys, hasLength(2));
      });

      test('matches query against description', () async {
        final withDesc = Event(
          _testPubkey,
          30000,
          [
            ['d', 'pl1'],
            ['title', 'My List'],
            ['description', 'Top vine creators'],
            ['p', 'pk1'],
          ],
          '',
          createdAt: 1718400000,
        );
        when(
          () => nostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [withDesc]);

        final results = await repository.searchAllPeopleLists('vine').toList();

        expect(results, hasLength(1));
        expect(results.first.first.description, contains('vine'));
      });
    });
  });
}
