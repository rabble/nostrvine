// ABOUTME: Tests for HashtagSearchBloc - hashtag search via HashtagService
// ABOUTME: Tests loading states, error handling, debouncing, and result merging

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/hashtag_search/hashtag_search_bloc.dart';
import 'package:openvine/services/hashtag_service.dart';
import 'package:openvine/services/top_hashtags_service.dart';

class _MockHashtagService extends Mock implements HashtagService {}

class _MockTopHashtagsService extends Mock implements TopHashtagsService {}

void main() {
  group(HashtagSearchBloc, () {
    late _MockHashtagService mockHashtagService;
    late _MockTopHashtagsService mockTopHashtagsService;

    setUp(() {
      mockHashtagService = _MockHashtagService();
      mockTopHashtagsService = _MockTopHashtagsService();

      // Default stubs
      when(() => mockHashtagService.refreshHashtagStats()).thenReturn(null);
      when(() => mockHashtagService.searchHashtags(any())).thenReturn([]);
      when(
        () => mockTopHashtagsService.searchHashtags(
          any(),
          limit: any(named: 'limit'),
        ),
      ).thenReturn([]);
    });

    HashtagSearchBloc createBloc() => HashtagSearchBloc(
      hashtagService: mockHashtagService,
      topHashtagsService: mockTopHashtagsService,
    );

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
            () => mockHashtagService.searchHashtags('music'),
          ).thenReturn(['music', 'musician']);
          when(
            () => mockTopHashtagsService.searchHashtags(
              'music',
              limit: any(named: 'limit'),
            ),
          ).thenReturn(['music', 'musicvideo']);
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
          verify(() => mockHashtagService.refreshHashtagStats()).called(1);
          verify(() => mockHashtagService.searchHashtags('music')).called(1);
          verify(
            () => mockTopHashtagsService.searchHashtags(
              'music',
              limit: any(named: 'limit'),
            ),
          ).called(1);
        },
      );

      blocTest<HashtagSearchBloc, HashtagSearchState>(
        'prioritizes HashtagService results over TopHashtagsService',
        setUp: () {
          when(
            () => mockHashtagService.searchHashtags('art'),
          ).thenReturn(['art', 'artist']);
          when(
            () => mockTopHashtagsService.searchHashtags(
              'art',
              limit: any(named: 'limit'),
            ),
          ).thenReturn(['art', 'artistic', 'artshow']);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const HashtagSearchQueryChanged('art')),
        wait: debounceDuration,
        expect: () => [
          const HashtagSearchState(
            status: HashtagSearchStatus.loading,
            query: 'art',
          ),
          const HashtagSearchState(
            status: HashtagSearchStatus.success,
            query: 'art',
            // 'art' deduplicated, live results first
            results: ['art', 'artist', 'artistic', 'artshow'],
          ),
        ],
      );

      blocTest<HashtagSearchBloc, HashtagSearchState>(
        'deduplicates results case-insensitively',
        setUp: () {
          when(
            () => mockHashtagService.searchHashtags('bitcoin'),
          ).thenReturn(['Bitcoin', 'bitcoin']);
          when(
            () => mockTopHashtagsService.searchHashtags(
              'bitcoin',
              limit: any(named: 'limit'),
            ),
          ).thenReturn(['BITCOIN', 'bitcoinmining']);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const HashtagSearchQueryChanged('bitcoin')),
        wait: debounceDuration,
        expect: () => [
          const HashtagSearchState(
            status: HashtagSearchStatus.loading,
            query: 'bitcoin',
          ),
          const HashtagSearchState(
            status: HashtagSearchStatus.success,
            query: 'bitcoin',
            // Only first occurrence of each kept
            results: ['Bitcoin', 'bitcoinmining'],
          ),
        ],
      );

      blocTest<HashtagSearchBloc, HashtagSearchState>(
        'emits [loading, failure] when search throws',
        setUp: () {
          when(
            () => mockHashtagService.searchHashtags('error'),
          ).thenThrow(Exception('search failed'));
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
        'emits initial state when query is empty',
        build: createBloc,
        act: (bloc) => bloc.add(const HashtagSearchQueryChanged('')),
        wait: debounceDuration,
        expect: () => [const HashtagSearchState()],
        verify: (_) {
          verifyNever(() => mockHashtagService.searchHashtags(any()));
        },
      );

      blocTest<HashtagSearchBloc, HashtagSearchState>(
        'emits initial state when query is whitespace only',
        build: createBloc,
        act: (bloc) => bloc.add(const HashtagSearchQueryChanged('   ')),
        wait: debounceDuration,
        expect: () => [const HashtagSearchState()],
        verify: (_) {
          verifyNever(() => mockHashtagService.searchHashtags(any()));
        },
      );

      blocTest<HashtagSearchBloc, HashtagSearchState>(
        'trims whitespace from query',
        setUp: () {
          when(
            () => mockHashtagService.searchHashtags('cats'),
          ).thenReturn(['cats']);
          when(
            () => mockTopHashtagsService.searchHashtags(
              'cats',
              limit: any(named: 'limit'),
            ),
          ).thenReturn([]);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const HashtagSearchQueryChanged('  cats  ')),
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
          verify(() => mockHashtagService.searchHashtags('cats')).called(1);
        },
      );

      blocTest<HashtagSearchBloc, HashtagSearchState>(
        'returns empty results when no hashtags match',
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
        'debounces rapid query changes and only processes final query',
        setUp: () {
          when(
            () => mockHashtagService.searchHashtags('final'),
          ).thenReturn(['finalize']);
          when(
            () => mockTopHashtagsService.searchHashtags(
              'final',
              limit: any(named: 'limit'),
            ),
          ).thenReturn([]);
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
          verify(() => mockHashtagService.searchHashtags('final')).called(1);
          verifyNever(() => mockHashtagService.searchHashtags('f'));
          verifyNever(() => mockHashtagService.searchHashtags('fi'));
          verifyNever(() => mockHashtagService.searchHashtags('fin'));
          verifyNever(() => mockHashtagService.searchHashtags('fina'));
        },
      );

      blocTest<HashtagSearchBloc, HashtagSearchState>(
        'refreshes hashtag stats before searching',
        setUp: () {
          when(() => mockHashtagService.searchHashtags('test')).thenReturn([]);
          when(
            () => mockTopHashtagsService.searchHashtags(
              'test',
              limit: any(named: 'limit'),
            ),
          ).thenReturn([]);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const HashtagSearchQueryChanged('test')),
        wait: debounceDuration,
        verify: (_) {
          verify(() => mockHashtagService.refreshHashtagStats()).called(1);
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
