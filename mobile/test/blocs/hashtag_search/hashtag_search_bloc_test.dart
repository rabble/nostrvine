// ABOUTME: Tests for HashtagSearchBloc - hashtag search via HashtagRepository.
// ABOUTME: Tests loading states, error handling, debouncing, and API delegation.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:hashtag_repository/hashtag_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/hashtag_search/hashtag_search_bloc.dart';
import 'package:openvine/services/feed_performance_tracker.dart';

class _MockHashtagRepository extends Mock implements HashtagRepository {}

class _MockFeedPerformanceTracker extends Mock
    implements FeedPerformanceTracker {}

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
      when(
        () => mockHashtagRepository.countHashtagsLocally(
          query: any(named: 'query'),
        ),
      ).thenReturn(0);
    });

    HashtagSearchBloc createBloc() =>
        HashtagSearchBloc(hashtagRepository: mockHashtagRepository);

    HashtagSearchBloc createBlocWithLocalFallback(
      List<String> Function(String query) fallback,
    ) => HashtagSearchBloc(
      hashtagRepository: mockHashtagRepository,
      localHashtagSearch: (query, {limit = 20}) async => fallback(query),
    );

    test('initial state is correct', () {
      final bloc = createBloc();
      expect(bloc.state.status, HashtagSearchStatus.initial);
      expect(bloc.state.query, isEmpty);
      expect(bloc.state.results, isEmpty);
      expect(bloc.state.resultCount, isNull);
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
            resultCount: 3,
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
            resultCount: 0,
          ),
        ],
      );

      blocTest<HashtagSearchBloc, HashtagSearchState>(
        'falls back to local hashtag search when remote returns no matches',
        build: () => createBlocWithLocalFallback(
          (query) => query == 'cdmx' ? ['cdmx'] : const [],
        ),
        act: (bloc) => bloc.add(const HashtagSearchQueryChanged('cdmx')),
        wait: debounceDuration,
        expect: () => [
          const HashtagSearchState(
            status: HashtagSearchStatus.loading,
            query: 'cdmx',
          ),
          const HashtagSearchState(
            status: HashtagSearchStatus.success,
            query: 'cdmx',
            results: ['cdmx'],
            resultCount: 1,
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
        'falls back to local hashtag search when repository throws',
        setUp: () {
          when(
            () => mockHashtagRepository.searchHashtags(query: 'error'),
          ).thenThrow(const FunnelcakeException('search failed'));
        },
        build: () => createBlocWithLocalFallback(
          (query) => query == 'error' ? ['errortag'] : const [],
        ),
        act: (bloc) => bloc.add(const HashtagSearchQueryChanged('error')),
        wait: debounceDuration,
        expect: () => [
          const HashtagSearchState(
            status: HashtagSearchStatus.loading,
            query: 'error',
          ),
          const HashtagSearchState(
            status: HashtagSearchStatus.success,
            query: 'error',
            results: ['errortag'],
            resultCount: 1,
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
        'emits initial state when query is a single character',
        build: createBloc,
        act: (bloc) => bloc.add(const HashtagSearchQueryChanged('a')),
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
        'does not re-search when query has not changed',
        build: createBloc,
        seed: () => const HashtagSearchState(
          status: HashtagSearchStatus.success,
          query: 'flutter',
          results: ['flutter', 'flutterdev'],
        ),
        act: (bloc) => bloc.add(const HashtagSearchQueryChanged('flutter')),
        wait: const Duration(milliseconds: 400),
        expect: () => <HashtagSearchState>[],
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
            resultCount: 1,
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
            resultCount: 1,
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

      blocTest<HashtagSearchBloc, HashtagSearchState>(
        'emits local count only when full results are not requested',
        setUp: () {
          when(
            () => mockHashtagRepository.countHashtagsLocally(query: 'music'),
          ).thenReturn(4);
        },
        build: createBloc,
        act: (bloc) => bloc.add(
          const HashtagSearchQueryChanged('music', fetchResults: false),
        ),
        wait: debounceDuration,
        expect: () => const [
          HashtagSearchState(query: 'music', resultCount: 4),
        ],
        verify: (_) {
          verify(
            () => mockHashtagRepository.countHashtagsLocally(query: 'music'),
          ).called(1);
          verifyNever(
            () => mockHashtagRepository.searchHashtags(
              query: any(named: 'query'),
              limit: any(named: 'limit'),
            ),
          );
        },
      );

      blocTest<HashtagSearchBloc, HashtagSearchState>(
        'runs full search after a count-only update for the same query',
        setUp: () {
          when(
            () => mockHashtagRepository.countHashtagsLocally(query: 'music'),
          ).thenReturn(2);
          when(
            () => mockHashtagRepository.searchHashtags(query: 'music'),
          ).thenAnswer((_) async => ['music', 'musician']);
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(
            const HashtagSearchQueryChanged('music', fetchResults: false),
          );
          await Future<void>.delayed(debounceDuration);
          bloc.add(const HashtagSearchQueryChanged('music'));
        },
        wait: debounceDuration,
        expect: () => const [
          HashtagSearchState(query: 'music', resultCount: 2),
          HashtagSearchState(
            status: HashtagSearchStatus.loading,
            query: 'music',
          ),
          HashtagSearchState(
            status: HashtagSearchStatus.success,
            query: 'music',
            results: ['music', 'musician'],
            resultCount: 2,
          ),
        ],
      );

      blocTest<HashtagSearchBloc, HashtagSearchState>(
        'preserves existing results for same query when fetchResults is false',
        build: createBloc,
        seed: () => const HashtagSearchState(
          status: HashtagSearchStatus.success,
          query: 'music',
          results: ['music', 'musician'],
          resultCount: 2,
        ),
        act: (bloc) => bloc.add(
          const HashtagSearchQueryChanged('music', fetchResults: false),
        ),
        wait: debounceDuration,
        expect: () => [],
        verify: (_) {
          verifyNever(
            () => mockHashtagRepository.countHashtagsLocally(
              query: any(named: 'query'),
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
        expect(updated.resultCount, isNull);
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
          -1,
        ]);
      });
    });

    group('feed performance tracking', () {
      late _MockHashtagRepository mockRepo;
      late _MockFeedPerformanceTracker mockTracker;

      // Debounce duration used in the BLoC + buffer
      const debounceDuration = Duration(milliseconds: 400);

      setUp(() {
        mockRepo = _MockHashtagRepository();
        mockTracker = _MockFeedPerformanceTracker();

        when(
          () => mockRepo.searchHashtags(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) async => []);
      });

      HashtagSearchBloc createBlocWithTracker() => HashtagSearchBloc(
        hashtagRepository: mockRepo,
        feedTracker: mockTracker,
      );

      blocTest<HashtagSearchBloc, HashtagSearchState>(
        'calls startFeedLoad, markFirstVideosReceived, and '
        'markFeedDisplayed on success',
        setUp: () {
          when(
            () => mockRepo.searchHashtags(query: 'music'),
          ).thenAnswer((_) async => ['music', 'musician', 'musicvideo']);
        },
        build: createBlocWithTracker,
        act: (bloc) => bloc.add(const HashtagSearchQueryChanged('music')),
        wait: debounceDuration,
        verify: (_) {
          verify(() => mockTracker.startFeedLoad('hashtag_search')).called(1);
          verify(
            () => mockTracker.markFirstVideosReceived('hashtag_search', 3),
          ).called(1);
          verify(
            () => mockTracker.markFeedDisplayed('hashtag_search', 3),
          ).called(1);
        },
      );

      blocTest<HashtagSearchBloc, HashtagSearchState>(
        'calls trackFeedError on failure',
        setUp: () {
          when(
            () => mockRepo.searchHashtags(query: 'error'),
          ).thenThrow(const FunnelcakeException('search failed'));
        },
        build: createBlocWithTracker,
        act: (bloc) => bloc.add(const HashtagSearchQueryChanged('error')),
        wait: debounceDuration,
        verify: (_) {
          verify(() => mockTracker.startFeedLoad('hashtag_search')).called(1);
          verify(
            () => mockTracker.trackFeedError(
              'hashtag_search',
              errorType: 'search_failed',
              errorMessage: any(named: 'errorMessage'),
            ),
          ).called(1);
          verifyNever(() => mockTracker.markFirstVideosReceived(any(), any()));
          verifyNever(() => mockTracker.markFeedDisplayed(any(), any()));
        },
      );

      blocTest<HashtagSearchBloc, HashtagSearchState>(
        'does not call tracker for empty query',
        build: createBlocWithTracker,
        act: (bloc) => bloc.add(const HashtagSearchQueryChanged('')),
        wait: debounceDuration,
        verify: (_) {
          verifyNever(() => mockTracker.startFeedLoad(any()));
        },
      );
    });
  });
}
