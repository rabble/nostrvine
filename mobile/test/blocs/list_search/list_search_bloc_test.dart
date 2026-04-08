import 'package:bloc_test/bloc_test.dart';
import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/list_search/list_search_bloc.dart';

class _MockCuratedListRepository extends Mock
    implements CuratedListRepository {}

void main() {
  group(ListSearchBloc, () {
    late _MockCuratedListRepository curatedListRepository;

    final now = DateTime(2024, 6, 15);
    final testCuratedList = CuratedList(
      id: 'cl1',
      name: 'Top Videos',
      pubkey: 'author1',
      videoEventIds: const ['vid1'],
      createdAt: now,
      updatedAt: now,
    );

    setUp(() {
      curatedListRepository = _MockCuratedListRepository();

      when(
        () => curatedListRepository.searchAllLists(any()),
      ).thenAnswer((_) => const Stream.empty());
    });

    ListSearchBloc buildBloc() => ListSearchBloc(
      curatedListRepository: curatedListRepository,
    );

    test('initial state is $ListSearchState', () {
      expect(buildBloc().state, equals(const ListSearchState()));
    });

    group(ListSearchQueryChanged, () {
      blocTest<ListSearchBloc, ListSearchState>(
        'emits loading then success when query matches',
        setUp: () {
          when(
            () => curatedListRepository.searchAllLists('videos'),
          ).thenAnswer((_) => Stream.value([testCuratedList]));
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const ListSearchQueryChanged('videos')),
        wait: const Duration(milliseconds: 400),
        expect: () => [
          const ListSearchState(
            status: ListSearchStatus.loading,
            query: 'videos',
          ),
          ListSearchState(
            status: ListSearchStatus.success,
            query: 'videos',
            results: [testCuratedList],
          ),
        ],
      );

      blocTest<ListSearchBloc, ListSearchState>(
        'emits success with empty results when no matches',
        build: buildBloc,
        act: (bloc) => bloc.add(const ListSearchQueryChanged('xyz')),
        wait: const Duration(milliseconds: 400),
        expect: () => [
          const ListSearchState(
            status: ListSearchStatus.loading,
            query: 'xyz',
          ),
          const ListSearchState(
            status: ListSearchStatus.success,
            query: 'xyz',
          ),
        ],
      );

      blocTest<ListSearchBloc, ListSearchState>(
        'resets to initial state for empty query',
        seed: () => ListSearchState(
          status: ListSearchStatus.success,
          query: 'old',
          results: [testCuratedList],
        ),
        build: buildBloc,
        act: (bloc) => bloc.add(const ListSearchQueryChanged('')),
        wait: const Duration(milliseconds: 400),
        expect: () => [const ListSearchState()],
      );

      blocTest<ListSearchBloc, ListSearchState>(
        'resets to initial state for short query',
        build: buildBloc,
        act: (bloc) => bloc.add(const ListSearchQueryChanged('a')),
        wait: const Duration(milliseconds: 400),
        expect: () => [const ListSearchState()],
      );

      blocTest<ListSearchBloc, ListSearchState>(
        'emits failure on exception',
        setUp: () {
          when(
            () => curatedListRepository.searchAllLists(any()),
          ).thenAnswer((_) => Stream.error(Exception('relay down')));
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const ListSearchQueryChanged('test')),
        wait: const Duration(milliseconds: 400),
        expect: () => [
          const ListSearchState(
            status: ListSearchStatus.loading,
            query: 'test',
          ),
          const ListSearchState(
            status: ListSearchStatus.failure,
            query: 'test',
          ),
        ],
        errors: () => [isA<Exception>()],
      );

      blocTest<ListSearchBloc, ListSearchState>(
        'yields progressive results as relay stream emits',
        setUp: () {
          final list2 = CuratedList(
            id: 'cl2',
            name: 'More Videos',
            pubkey: 'author2',
            videoEventIds: const ['vid2'],
            createdAt: now,
            updatedAt: now,
          );
          when(
            () => curatedListRepository.searchAllLists('vid'),
          ).thenAnswer(
            (_) => Stream.fromIterable([
              [testCuratedList],
              [testCuratedList, list2],
            ]),
          );
        },
        build: buildBloc,
        act: (bloc) => bloc.add(const ListSearchQueryChanged('vid')),
        wait: const Duration(milliseconds: 400),
        expect: () => [
          const ListSearchState(
            status: ListSearchStatus.loading,
            query: 'vid',
          ),
          ListSearchState(
            status: ListSearchStatus.success,
            query: 'vid',
            results: [testCuratedList],
          ),
          isA<ListSearchState>().having(
            (s) => s.results.length,
            'results.length',
            2,
          ),
        ],
      );
    });

    group(ListSearchCleared, () {
      blocTest<ListSearchBloc, ListSearchState>(
        'resets to initial state',
        seed: () => ListSearchState(
          status: ListSearchStatus.success,
          query: 'test',
          results: [testCuratedList],
        ),
        build: buildBloc,
        act: (bloc) => bloc.add(const ListSearchCleared()),
        expect: () => [const ListSearchState()],
      );
    });
  });
}
