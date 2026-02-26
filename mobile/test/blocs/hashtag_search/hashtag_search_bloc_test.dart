// ABOUTME: Tests for HashtagSearchBloc - hashtag search via HashtagRepository.
// ABOUTME: Tests loading states, error handling, debouncing, and API delegation.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:hashtag_repository/hashtag_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/hashtag_search/hashtag_search_bloc.dart';

class _MockHashtagRepository extends Mock implements HashtagRepository {}

void main() {
  group(HashtagSearchBloc, () {
    late _MockHashtagRepository mockHashtagRepository;

    setUp(() {
      mockHashtagRepository = _MockHashtagRepository();

      // Default stub
      when(
        () => mockHashtagRepository.searchHashtags(
          query: any(named: 'query'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => []);
    });

    HashtagSearchBloc createBloc() =>
        HashtagSearchBloc(hashtagRepository: mockHashtagRepository);

    test('initial state is correct', () {
      final bloc = createBloc();
      expect(bloc.state.status, HashtagSearchStatus.initial);
      expect(bloc.state.query, isEmpty);
      expect(bloc.state.results, isEmpty);
      bloc.close();
    });

    group('HashtagSearchQueryChanged', () {
      // Debounce duration used in the BLoC + buffer
      const debounceDuration = Duration(milliseconds: 400);

      blocTest<HashtagSearchBloc, HashtagSearchState>(
        'emits [loading, success] when search succeeds',
        setUp: () {
          when(
            () => mockHashtagRepository.searchHashtags(query: 'music'),
          ).thenAnswer((_) async => ['music', 'musician', 'musicvideo']);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const HashtagSearchQueryChanged('music')),
        wait: debounceDuration,
        expect: () => [
          const HashtagSearchState(
            status: HashtagSearchStatus.loading,
            query: 'music',
          ),
          const HashtagSearchState(
            status: HashtagSearchStatus.success,
            query: 'music',
            results: ['music', 'musician', 'musicvideo'],
          ),
        ],
        verify: (_) {
          verify(
            () => mockHashtagRepository.searchHashtags(query: 'music'),
          ).called(1);
        },
      );

      blocTest<HashtagSearchBloc, HashtagSearchState>(
        'emits [loading, success] with empty results when no matches',
        build: createBloc,
        act: (bloc) => bloc.add(const HashtagSearchQueryChanged('zzzzz')),
        wait: debounceDuration,
        expect: () => [
          const HashtagSearchState(
            status: HashtagSearchStatus.loading,
            query: 'zzzzz',
          ),
          const HashtagSearchState(
            status: HashtagSearchStatus.success,
            query: 'zzzzz',
          ),
        ],
      );

      blocTest<HashtagSearchBloc, HashtagSearchState>(
        'emits [loading, failure] when repository throws',
        setUp: () {
          when(
            () => mockHashtagRepository.searchHashtags(query: 'error'),
          ).thenThrow(const FunnelcakeException('search failed'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const HashtagSearchQueryChanged('error')),
        wait: debounceDuration,
        expect: () => [
          const HashtagSearchState(
            status: HashtagSearchStatus.loading,
            query: 'error',
          ),
          const HashtagSearchState(
            status: HashtagSearchStatus.failure,
            query: 'error',
          ),
        ],
      );

      blocTest<HashtagSearchBloc, HashtagSearchState>(
        'emits [loading, failure] when repository throws timeout',
        setUp: () {
          when(
            () => mockHashtagRepository.searchHashtags(query: 'slow'),
          ).thenThrow(const FunnelcakeTimeoutException());
        },
        build: createBloc,
        act: (bloc) => bloc.add(const HashtagSearchQueryChanged('slow')),
        wait: debounceDuration,
        expect: () => [
          const HashtagSearchState(
            status: HashtagSearchStatus.loading,
            query: 'slow',
          ),
          const HashtagSearchState(
            status: HashtagSearchStatus.failure,
            query: 'slow',
          ),
        ],
      );

      blocTest<HashtagSearchBloc, HashtagSearchState>(
        'emits initial state when query is empty',
        build: createBloc,
        act: (bloc) => bloc.add(const HashtagSearchQueryChanged('')),
        wait: debounceDuration,
        expect: () => [const HashtagSearchState()],
        verify: (_) {
          verifyNever(
            () => mockHashtagRepository.searchHashtags(
              query: any(named: 'query'),
              limit: any(named: 'limit'),
            ),
          );
        },
      );

      blocTest<HashtagSearchBloc, HashtagSearchState>(
        'emits initial state when query is whitespace only',
        build: createBloc,
        act: (bloc) => bloc.add(const HashtagSearchQueryChanged('   ')),
        wait: debounceDuration,
        expect: () => [const HashtagSearchState()],
        verify: (_) {
          verifyNever(
            () => mockHashtagRepository.searchHashtags(
              query: any(named: 'query'),
              limit: any(named: 'limit'),
            ),
          );
        },
      );

      blocTest<HashtagSearchBloc, HashtagSearchState>(
        'normalizes query by trimming and lowercasing',
        setUp: () {
          when(
            () => mockHashtagRepository.searchHashtags(query: 'cats'),
          ).thenAnswer((_) async => ['cats']);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const HashtagSearchQueryChanged('  CATS  ')),
        wait: debounceDuration,
        expect: () => [
          const HashtagSearchState(
            status: HashtagSearchStatus.loading,
            query: 'cats',
          ),
          const HashtagSearchState(
            status: HashtagSearchStatus.success,
            query: 'cats',
            results: ['cats'],
          ),
        ],
        verify: (_) {
          verify(
            () => mockHashtagRepository.searchHashtags(query: 'cats'),
          ).called(1);
        },
      );

      blocTest<HashtagSearchBloc, HashtagSearchState>(
        'debounces rapid query changes and only processes final query',
        setUp: () {
          when(
            () => mockHashtagRepository.searchHashtags(query: 'final'),
          ).thenAnswer((_) async => ['finalize']);
        },
        build: createBloc,
        act: (bloc) {
          bloc
            ..add(const HashtagSearchQueryChanged('f'))
            ..add(const HashtagSearchQueryChanged('fi'))
            ..add(const HashtagSearchQueryChanged('fin'))
            ..add(const HashtagSearchQueryChanged('fina'))
            ..add(const HashtagSearchQueryChanged('final'));
        },
        wait: debounceDuration,
        expect: () => [
          const HashtagSearchState(
            status: HashtagSearchStatus.loading,
            query: 'final',
          ),
          const HashtagSearchState(
            status: HashtagSearchStatus.success,
            query: 'final',
            results: ['finalize'],
          ),
        ],
        verify: (_) {
          // Only the final query should be processed due to debounce
          verify(
            () => mockHashtagRepository.searchHashtags(query: 'final'),
          ).called(1);
          verifyNever(
            () => mockHashtagRepository.searchHashtags(
              query: 'f',
              limit: any(named: 'limit'),
            ),
          );
          verifyNever(
            () => mockHashtagRepository.searchHashtags(
              query: 'fi',
              limit: any(named: 'limit'),
            ),
          );
          verifyNever(
            () => mockHashtagRepository.searchHashtags(
              query: 'fin',
              limit: any(named: 'limit'),
            ),
          );
          verifyNever(
            () => mockHashtagRepository.searchHashtags(
              query: 'fina',
              limit: any(named: 'limit'),
            ),
          );
        },
      );
    });

    group('HashtagSearchCleared', () {
      blocTest<HashtagSearchBloc, HashtagSearchState>(
        'resets to initial state',
        build: createBloc,
        seed: () => const HashtagSearchState(
          status: HashtagSearchStatus.success,
          query: 'music',
          results: ['music', 'musician'],
        ),
        act: (bloc) => bloc.add(const HashtagSearchCleared()),
        expect: () => [const HashtagSearchState()],
      );
    });

    group('HashtagSearchState', () {
      test('copyWith creates copy with updated values', () {
        const state = HashtagSearchState();

        final updated = state.copyWith(
          status: HashtagSearchStatus.success,
          query: 'test',
          results: ['test', 'testing'],
        );

        expect(updated.status, HashtagSearchStatus.success);
        expect(updated.query, 'test');
        expect(updated.results, ['test', 'testing']);
      });

      test('copyWith preserves existing values when not specified', () {
        const state = HashtagSearchState(
          status: HashtagSearchStatus.success,
          query: 'music',
          results: ['music'],
        );

        final updated = state.copyWith(status: HashtagSearchStatus.loading);

        expect(updated.status, HashtagSearchStatus.loading);
        expect(updated.query, 'music');
        expect(updated.results, ['music']);
      });

      test('props includes all fields', () {
        const state = HashtagSearchState(
          status: HashtagSearchStatus.success,
          query: 'music',
          results: ['music', 'musician'],
        );

        expect(state.props, [
          HashtagSearchStatus.success,
          'music',
          ['music', 'musician'],
        ]);
      });
    });
  });
}
