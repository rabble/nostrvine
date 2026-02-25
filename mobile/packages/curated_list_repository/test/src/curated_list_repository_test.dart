import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group(CuratedListRepository, () {
    late CuratedListRepository repository;

    final now = DateTime(2025, 6, 15);

    CuratedList createList({
      required String id,
      String name = 'Test List',
      List<String> videoEventIds = const [],
    }) {
      return CuratedList(
        id: id,
        name: name,
        videoEventIds: videoEventIds,
        createdAt: now,
        updatedAt: now,
      );
    }

    setUp(() {
      repository = CuratedListRepository();
    });

    test('can be instantiated', () {
      expect(CuratedListRepository(), isNotNull);
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
  });
}
