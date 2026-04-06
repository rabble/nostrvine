// ABOUTME: Tests for UserSearchBloc - user search via ProfileRepository
// ABOUTME: Tests streaming states, error handling, debouncing, and pagination

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/user_search/user_search_bloc.dart';
import 'package:openvine/services/feed_performance_tracker.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockFeedPerformanceTracker extends Mock
    implements FeedPerformanceTracker {}

void main() {
  group('UserSearchBloc', () {
    late _MockProfileRepository mockProfileRepository;

    setUp(() {
      mockProfileRepository = _MockProfileRepository();
      when(
        () =>
            mockProfileRepository.countUsersLocally(query: any(named: 'query')),
      ).thenAnswer((_) async => 0);
    });

    UserSearchBloc createBloc({
      Duration? searchTimeout = const Duration(seconds: 20),
    }) => UserSearchBloc(
      profileRepository: mockProfileRepository,
      searchTimeout: searchTimeout,
    );

    UserProfile createTestProfile(String pubkey, String displayName) {
      return UserProfile(
        pubkey: pubkey,
        displayName: displayName,
        createdAt: DateTime.now(),
        eventId: 'event-$pubkey',
        rawData: {'display_name': displayName},
      );
    }

    List<UserProfile> createTestProfiles(int count) {
      return List.generate(
        count,
        (i) => createTestProfile(
          '${i.toString().padLeft(2, '0')}${'a' * 62}',
          'User $i',
        ),
      );
    }

    test('initial state is correct', () {
      final bloc = createBloc();
      expect(bloc.state.status, UserSearchStatus.initial);
      expect(bloc.state.query, isEmpty);
      expect(bloc.state.results, isEmpty);
      expect(bloc.state.resultCount, isNull);
      expect(bloc.state.offset, 0);
      expect(bloc.state.hasMore, isFalse);
      expect(bloc.state.isLoadingMore, isFalse);
      bloc.close();
    });

    group('UserSearchQueryChanged', () {
      // Debounce duration used in the BLoC
      const debounceDuration = Duration(milliseconds: 400);

      blocTest<UserSearchBloc, UserSearchState>(
        'emits [searching, searching(results), success] when search succeeds',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'alice',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) => Stream.value([createTestProfile('a' * 64, 'Alice')]),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const UserSearchQueryChanged('alice')),
        wait: debounceDuration,
        expect: () => [
          const UserSearchState(
            status: UserSearchStatus.loading,
            query: 'alice',
          ),
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.loading)
              .having((s) => s.query, 'query', 'alice')
              .having((s) => s.results.length, 'results.length', 1)
              .having(
                (s) => s.results.first.displayName,
                'first result name',
                'Alice',
              ),
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.success)
              .having((s) => s.offset, 'offset', 1)
              .having((s) => s.hasMore, 'hasMore', false),
        ],
        verify: (_) {
          verify(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'alice',
              limit: 50,
              sortBy: 'followers',
            ),
          ).called(1);
        },
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'sets hasMore to true when results equal page size',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'test',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer((_) => Stream.value(createTestProfiles(50)));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const UserSearchQueryChanged('test')),
        wait: debounceDuration,
        expect: () => [
          const UserSearchState(
            status: UserSearchStatus.loading,
            query: 'test',
          ),
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.loading)
              .having((s) => s.results.length, 'results.length', 50),
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.success)
              .having((s) => s.offset, 'offset', 50)
              .having((s) => s.hasMore, 'hasMore', true),
        ],
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'emits [searching, failure] when search fails',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'error',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) => Stream<List<UserProfile>>.error(Exception('Network error')),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const UserSearchQueryChanged('error')),
        wait: debounceDuration,
        expect: () => [
          const UserSearchState(
            status: UserSearchStatus.loading,
            query: 'error',
          ),
          const UserSearchState(
            status: UserSearchStatus.failure,
            query: 'error',
          ),
        ],
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'emits initial state when query is empty',
        build: createBloc,
        act: (bloc) => bloc.add(const UserSearchQueryChanged('')),
        wait: debounceDuration,
        expect: () => [const UserSearchState()],
        verify: (_) {
          verifyNever(
            () => mockProfileRepository.searchUsersProgressive(
              query: any(named: 'query'),
            ),
          );
        },
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'emits initial state when query is whitespace only',
        build: createBloc,
        act: (bloc) => bloc.add(const UserSearchQueryChanged('   ')),
        wait: debounceDuration,
        expect: () => [const UserSearchState()],
        verify: (_) {
          verifyNever(
            () => mockProfileRepository.searchUsersProgressive(
              query: any(named: 'query'),
            ),
          );
        },
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'emits initial state when query is a single character',
        build: createBloc,
        act: (bloc) => bloc.add(const UserSearchQueryChanged('a')),
        wait: debounceDuration,
        expect: () => [const UserSearchState()],
        verify: (_) {
          verifyNever(
            () => mockProfileRepository.searchUsersProgressive(
              query: any(named: 'query'),
            ),
          );
        },
      );

      blocTest<UserSearchBloc, UserSearchState>(
        're-searches when same query is submitted again',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'flutter',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) => Stream.value([createTestProfile('b' * 64, 'Flutter Dev 2')]),
          );
        },
        build: createBloc,
        seed: () => UserSearchState(
          status: UserSearchStatus.success,
          query: 'flutter',
          results: [createTestProfile('a' * 64, 'Flutter Dev')],
          offset: 1,
        ),
        act: (bloc) => bloc.add(const UserSearchQueryChanged('flutter')),
        wait: debounceDuration,
        expect: () => [
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.loading)
              .having((s) => s.query, 'query', 'flutter')
              .having((s) => s.results, 'results', isEmpty),
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.loading)
              .having((s) => s.results, 'results', hasLength(1))
              .having(
                (s) => s.results.first.displayName,
                'displayName',
                'Flutter Dev 2',
              ),
          isA<UserSearchState>().having(
            (s) => s.status,
            'status',
            UserSearchStatus.success,
          ),
        ],
        verify: (_) {
          verify(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'flutter',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).called(1);
        },
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'trims whitespace from query',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'bob',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer((_) => Stream.value([]));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const UserSearchQueryChanged('  bob  ')),
        wait: debounceDuration,
        expect: () => [
          const UserSearchState(status: UserSearchStatus.loading, query: 'bob'),
          // Stream yields empty list → searching with resultCount: 0
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.loading)
              .having((s) => s.resultCount, 'resultCount', 0),
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.success)
              .having((s) => s.query, 'query', 'bob')
              .having((s) => s.results, 'results', isEmpty),
        ],
        verify: (_) {
          verify(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'bob',
              limit: 50,
              sortBy: 'followers',
            ),
          ).called(1);
        },
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'returns empty results when no users match',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'xyz',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer((_) => Stream.value([]));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const UserSearchQueryChanged('xyz')),
        wait: debounceDuration,
        expect: () => [
          const UserSearchState(status: UserSearchStatus.loading, query: 'xyz'),
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.loading)
              .having((s) => s.resultCount, 'resultCount', 0),
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.success)
              .having((s) => s.query, 'query', 'xyz')
              .having((s) => s.results, 'results', isEmpty),
        ],
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'debounces rapid query changes and only processes final query',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'final',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer((_) => Stream.value([]));
        },
        build: createBloc,
        act: (bloc) {
          bloc
            ..add(const UserSearchQueryChanged('f'))
            ..add(const UserSearchQueryChanged('fi'))
            ..add(const UserSearchQueryChanged('fin'))
            ..add(const UserSearchQueryChanged('fina'))
            ..add(const UserSearchQueryChanged('final'));
        },
        wait: debounceDuration,
        expect: () => [
          const UserSearchState(
            status: UserSearchStatus.loading,
            query: 'final',
          ),
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.loading)
              .having((s) => s.resultCount, 'resultCount', 0),
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.success)
              .having((s) => s.query, 'query', 'final'),
        ],
        verify: (_) {
          // Only the final query should be processed due to debounce
          verify(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'final',
              limit: 50,
              sortBy: 'followers',
            ),
          ).called(1);
          verifyNever(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'f',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          );
          verifyNever(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'fi',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          );
          verifyNever(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'fin',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          );
          verifyNever(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'fina',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          );
        },
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'emits progressive results from multi-yield stream',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'alice',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) => Stream.fromIterable([
              // First yield: local cached result
              [createTestProfile('a' * 64, 'Alice Local')],
              // Second yield: merged with remote
              [
                createTestProfile('a' * 64, 'Alice Local'),
                createTestProfile('b' * 64, 'Alice Remote'),
              ],
            ]),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const UserSearchQueryChanged('alice')),
        wait: debounceDuration,
        expect: () => [
          const UserSearchState(
            status: UserSearchStatus.loading,
            query: 'alice',
          ),
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.loading)
              .having((s) => s.results.length, 'results.length', 1),
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.loading)
              .having((s) => s.results.length, 'results.length', 2),
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.success)
              .having((s) => s.results.length, 'results.length', 2),
        ],
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'emits success with partial results when stream times out',
        setUp: () {
          final controller = StreamController<List<UserProfile>>();
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'slow',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer((_) {
            // Emit one batch then stall (never close the stream).
            controller.add([createTestProfile('a' * 64, 'Slow User')]);
            return controller.stream;
          });
        },
        build: () =>
            createBloc(searchTimeout: const Duration(milliseconds: 10)),
        act: (bloc) => bloc.add(const UserSearchQueryChanged('slow')),
        wait: const Duration(milliseconds: 500),
        expect: () => [
          const UserSearchState(
            status: UserSearchStatus.loading,
            query: 'slow',
          ),
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.loading)
              .having((s) => s.results.length, 'results.length', 1),
          // Timeout fires → success with accumulated results
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.success)
              .having((s) => s.results.length, 'results.length', 1)
              .having((s) => s.hasMore, 'hasMore', false),
        ],
      );
    });

    group('UserSearchLoadMore', () {
      blocTest<UserSearchBloc, UserSearchState>(
        'appends results and updates offset when loading more',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'alice',
              limit: 50,
              offset: 50,
              sortBy: 'followers',
            ),
          ).thenAnswer((_) => Stream.value(createTestProfiles(10)));
        },
        build: createBloc,
        seed: () => UserSearchState(
          status: UserSearchStatus.success,
          query: 'alice',
          results: createTestProfiles(50),
          offset: 50,
          hasMore: true,
        ),
        act: (bloc) => bloc.add(const UserSearchLoadMore()),
        expect: () => [
          isA<UserSearchState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', true)
              .having((s) => s.results.length, 'results.length', 50),
          isA<UserSearchState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', false)
              .having((s) => s.results.length, 'results.length', 60)
              .having((s) => s.offset, 'offset', 60)
              .having((s) => s.hasMore, 'hasMore', false),
        ],
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'uses last emission when stream yields multiple times',
        setUp: () {
          final partial = createTestProfiles(5);
          final full = createTestProfiles(10);
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'alice',
              limit: 50,
              offset: 50,
              sortBy: 'followers',
            ),
          ).thenAnswer((_) => Stream.fromIterable([partial, full]));
        },
        build: createBloc,
        seed: () => UserSearchState(
          status: UserSearchStatus.success,
          query: 'alice',
          results: createTestProfiles(50),
          offset: 50,
          hasMore: true,
        ),
        act: (bloc) => bloc.add(const UserSearchLoadMore()),
        expect: () => [
          isA<UserSearchState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            true,
          ),
          isA<UserSearchState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', false)
              .having((s) => s.results.length, 'results.length', 60)
              .having((s) => s.offset, 'offset', 60)
              .having((s) => s.hasMore, 'hasMore', false),
        ],
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'sets hasMore to true when load more returns full page',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'alice',
              limit: 50,
              offset: 50,
              sortBy: 'followers',
            ),
          ).thenAnswer((_) => Stream.value(createTestProfiles(50)));
        },
        build: createBloc,
        seed: () => UserSearchState(
          status: UserSearchStatus.success,
          query: 'alice',
          results: createTestProfiles(50),
          offset: 50,
          hasMore: true,
        ),
        act: (bloc) => bloc.add(const UserSearchLoadMore()),
        expect: () => [
          isA<UserSearchState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            true,
          ),
          isA<UserSearchState>()
              .having((s) => s.results.length, 'results.length', 100)
              .having((s) => s.offset, 'offset', 100)
              .having((s) => s.hasMore, 'hasMore', true),
        ],
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'does nothing when hasMore is false',
        build: createBloc,
        seed: () => UserSearchState(
          status: UserSearchStatus.success,
          query: 'alice',
          results: createTestProfiles(10),
          offset: 10,
        ),
        act: (bloc) => bloc.add(const UserSearchLoadMore()),
        expect: () => <UserSearchState>[],
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'does nothing when already loading more',
        build: createBloc,
        seed: () => UserSearchState(
          status: UserSearchStatus.success,
          query: 'alice',
          results: createTestProfiles(50),
          offset: 50,
          hasMore: true,
          isLoadingMore: true,
        ),
        act: (bloc) => bloc.add(const UserSearchLoadMore()),
        expect: () => <UserSearchState>[],
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'does nothing when query is empty',
        build: createBloc,
        seed: () => const UserSearchState(hasMore: true),
        act: (bloc) => bloc.add(const UserSearchLoadMore()),
        expect: () => <UserSearchState>[],
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'resets isLoadingMore on failure',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'alice',
              limit: 50,
              offset: 50,
              sortBy: 'followers',
            ),
          ).thenAnswer(
            (_) => Stream<List<UserProfile>>.error(Exception('Network error')),
          );
        },
        build: createBloc,
        seed: () => UserSearchState(
          status: UserSearchStatus.success,
          query: 'alice',
          results: createTestProfiles(50),
          offset: 50,
          hasMore: true,
        ),
        act: (bloc) => bloc.add(const UserSearchLoadMore()),
        expect: () => [
          isA<UserSearchState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            true,
          ),
          isA<UserSearchState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', false)
              .having((s) => s.results.length, 'results.length', 50),
        ],
      );
    });

    group('UserSearchCleared', () {
      blocTest<UserSearchBloc, UserSearchState>(
        'resets to initial state',
        build: createBloc,
        seed: () => UserSearchState(
          status: UserSearchStatus.success,
          query: 'alice',
          results: [createTestProfile('a' * 64, 'Alice')],
          offset: 1,
        ),
        act: (bloc) => bloc.add(const UserSearchCleared()),
        expect: () => [const UserSearchState()],
      );
    });

    group('hasVideos parameter', () {
      const debounceDuration = Duration(milliseconds: 400);

      blocTest<UserSearchBloc, UserSearchState>(
        'passes hasVideos: true to profileRepository when configured',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'test',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer((_) => Stream.value([]));
        },
        build: () => UserSearchBloc(
          profileRepository: mockProfileRepository,
          hasVideos: true,
        ),
        act: (bloc) => bloc.add(const UserSearchQueryChanged('test')),
        wait: debounceDuration,
        verify: (_) {
          verify(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'test',
              limit: 50,
              sortBy: 'followers',
              hasVideos: true,
            ),
          ).called(1);
        },
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'passes hasVideos: true to profileRepository on load more',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'alice',
              limit: 50,
              offset: 50,
              sortBy: 'followers',
              hasVideos: true,
            ),
          ).thenAnswer((_) => Stream.value(createTestProfiles(10)));
        },
        build: () => UserSearchBloc(
          profileRepository: mockProfileRepository,
          hasVideos: true,
        ),
        seed: () => UserSearchState(
          status: UserSearchStatus.success,
          query: 'alice',
          results: createTestProfiles(50),
          offset: 50,
          hasMore: true,
        ),
        act: (bloc) => bloc.add(const UserSearchLoadMore()),
        verify: (_) {
          verify(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'alice',
              limit: 50,
              offset: 50,
              sortBy: 'followers',
              hasVideos: true,
            ),
          ).called(1);
        },
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'defaults hasVideos to false when not specified',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'test',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer((_) => Stream.value([]));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const UserSearchQueryChanged('test')),
        wait: debounceDuration,
        verify: (_) {
          verifyNever(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'test',
              limit: 50,
              sortBy: 'followers',
              hasVideos: true,
            ),
          );
        },
      );
    });

    group('results preservation on failure', () {
      const debounceDuration = Duration(milliseconds: 400);

      blocTest<UserSearchBloc, UserSearchState>(
        'clears previous results and emits failure when a subsequent query '
        'fails',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'alice',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) => Stream.value([createTestProfile('a' * 64, 'Alice')]),
          );
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'error',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) => Stream<List<UserProfile>>.error(Exception('Network error')),
          );
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const UserSearchQueryChanged('alice'));
          await Future<void>.delayed(debounceDuration);
          bloc.add(const UserSearchQueryChanged('error'));
        },
        wait: debounceDuration,
        expect: () => [
          const UserSearchState(
            status: UserSearchStatus.loading,
            query: 'alice',
          ),
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.loading)
              .having((s) => s.results.length, 'results.length', 1),
          isA<UserSearchState>().having(
            (s) => s.status,
            'status',
            UserSearchStatus.success,
          ),
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.loading)
              .having((s) => s.query, 'query', 'error')
              .having((s) => s.results, 'results cleared', isEmpty),
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.failure)
              .having((s) => s.results, 'results still empty', isEmpty),
        ],
      );
    });

    group('multiple sequential results', () {
      const debounceDuration = Duration(milliseconds: 400);

      blocTest<UserSearchBloc, UserSearchState>(
        'replaces previous results when a new query succeeds',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'alice',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) => Stream.value([createTestProfile('a' * 64, 'Alice')]),
          );
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'bob',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) => Stream.value([
              createTestProfile('b' * 64, 'Bob'),
              createTestProfile('c' * 64, 'Bobby'),
            ]),
          );
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const UserSearchQueryChanged('alice'));
          await Future<void>.delayed(debounceDuration);
          bloc.add(const UserSearchQueryChanged('bob'));
        },
        wait: debounceDuration,
        expect: () => [
          const UserSearchState(
            status: UserSearchStatus.loading,
            query: 'alice',
          ),
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.loading)
              .having((s) => s.results.length, 'results.length', 1)
              .having(
                (s) => s.results.first.displayName,
                'first result',
                'Alice',
              ),
          isA<UserSearchState>().having(
            (s) => s.status,
            'status',
            UserSearchStatus.success,
          ),
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.loading)
              .having((s) => s.query, 'query', 'bob'),
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.loading)
              .having((s) => s.results.length, 'results.length', 2)
              .having(
                (s) => s.results.first.displayName,
                'first result',
                'Bob',
              ),
          isA<UserSearchState>().having(
            (s) => s.status,
            'status',
            UserSearchStatus.success,
          ),
        ],
      );
    });

    group('null feed tracker', () {
      const debounceDuration = Duration(milliseconds: 400);

      blocTest<UserSearchBloc, UserSearchState>(
        'succeeds without errors when feedTracker is null',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsersProgressive(
              query: 'alice',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) => Stream.value([createTestProfile('a' * 64, 'Alice')]),
          );
        },
        build: () => UserSearchBloc(profileRepository: mockProfileRepository),
        act: (bloc) => bloc.add(const UserSearchQueryChanged('alice')),
        wait: debounceDuration,
        expect: () => [
          const UserSearchState(
            status: UserSearchStatus.loading,
            query: 'alice',
          ),
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.loading)
              .having((s) => s.results.length, 'results.length', 1),
          isA<UserSearchState>().having(
            (s) => s.status,
            'status',
            UserSearchStatus.success,
          ),
        ],
      );
    });

    group('UserSearchState', () {
      test('copyWith creates copy with updated values', () {
        const state = UserSearchState();

        final updated = state.copyWith(
          status: UserSearchStatus.success,
          query: 'test',
          offset: 10,
          hasMore: true,
          isLoadingMore: true,
        );

        expect(updated.status, UserSearchStatus.success);
        expect(updated.query, 'test');
        expect(updated.results, isEmpty);
        expect(updated.offset, 10);
        expect(updated.hasMore, isTrue);
        expect(updated.isLoadingMore, isTrue);
      });

      test('copyWith preserves existing values when not specified', () {
        final state = UserSearchState(
          status: UserSearchStatus.success,
          query: 'test',
          results: [createTestProfile('a' * 64, 'Alice')],
          offset: 10,
          hasMore: true,
          isLoadingMore: true,
        );

        final updated = state.copyWith(status: UserSearchStatus.loading);

        expect(updated.status, UserSearchStatus.loading);
        expect(updated.query, 'test');
        expect(updated.results, hasLength(1));
        expect(updated.resultCount, isNull);
        expect(updated.offset, 10);
        expect(updated.hasMore, isTrue);
        expect(updated.isLoadingMore, isTrue);
      });

      test('props includes all fields', () {
        final profile = createTestProfile('a' * 64, 'Alice');
        final state = UserSearchState(
          status: UserSearchStatus.success,
          query: 'alice',
          results: [profile],
          offset: 1,
          hasMore: true,
        );

        expect(state.props, [
          UserSearchStatus.success,
          'alice',
          [profile],
          -1,
          1,
          true,
          false,
        ]);
      });
    });

    group('feed performance tracking', () {
      late _MockProfileRepository mockRepo;
      late _MockFeedPerformanceTracker mockTracker;

      // Debounce duration used in the BLoC + buffer
      const debounceDuration = Duration(milliseconds: 400);

      setUp(() {
        mockRepo = _MockProfileRepository();
        mockTracker = _MockFeedPerformanceTracker();
      });

      UserSearchBloc createBlocWithTracker() =>
          UserSearchBloc(profileRepository: mockRepo, feedTracker: mockTracker);

      blocTest<UserSearchBloc, UserSearchState>(
        'calls startFeedLoad, markFirstVideosReceived, and '
        'markFeedDisplayed on success',
        setUp: () {
          when(
            () => mockRepo.searchUsersProgressive(
              query: 'alice',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) => Stream.value([createTestProfile('a' * 64, 'Alice')]),
          );
        },
        build: createBlocWithTracker,
        act: (bloc) => bloc.add(const UserSearchQueryChanged('alice')),
        wait: debounceDuration,
        verify: (_) {
          verify(() => mockTracker.startFeedLoad('user_search')).called(1);
          verify(
            () => mockTracker.markFirstVideosReceived('user_search', 1),
          ).called(1);
          verify(
            () => mockTracker.markFeedDisplayed('user_search', 1),
          ).called(1);
        },
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'calls trackFeedError on failure',
        setUp: () {
          when(
            () => mockRepo.searchUsersProgressive(
              query: 'error',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) => Stream<List<UserProfile>>.error(Exception('Network error')),
          );
        },
        build: createBlocWithTracker,
        act: (bloc) => bloc.add(const UserSearchQueryChanged('error')),
        wait: debounceDuration,
        verify: (_) {
          verify(() => mockTracker.startFeedLoad('user_search')).called(1);
          verify(
            () => mockTracker.trackFeedError(
              'user_search',
              errorType: 'search_failed',
              errorMessage: any(named: 'errorMessage'),
            ),
          ).called(1);
          verifyNever(() => mockTracker.markFirstVideosReceived(any(), any()));
          verifyNever(() => mockTracker.markFeedDisplayed(any(), any()));
        },
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'does not call tracker for empty query',
        build: createBlocWithTracker,
        act: (bloc) => bloc.add(const UserSearchQueryChanged('')),
        wait: debounceDuration,
        verify: (_) {
          verifyNever(() => mockTracker.startFeedLoad(any()));
        },
      );
    });
  });
}
