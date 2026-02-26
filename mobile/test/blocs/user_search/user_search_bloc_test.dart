// ABOUTME: Tests for UserSearchBloc - user search via ProfileRepository
// ABOUTME: Tests loading states, error handling, debouncing, and pagination

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/user_search/user_search_bloc.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  group('UserSearchBloc', () {
    late _MockProfileRepository mockProfileRepository;

    setUp(() {
      mockProfileRepository = _MockProfileRepository();
    });

    UserSearchBloc createBloc() =>
        UserSearchBloc(profileRepository: mockProfileRepository);

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
      expect(bloc.state.offset, 0);
      expect(bloc.state.hasMore, isFalse);
      expect(bloc.state.isLoadingMore, isFalse);
      bloc.close();
    });

    group('UserSearchQueryChanged', () {
      // Debounce duration used in the BLoC
      const debounceDuration = Duration(milliseconds: 400);

      blocTest<UserSearchBloc, UserSearchState>(
        'emits [loading, success] when search succeeds',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsers(
              query: 'alice',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) async => [createTestProfile('a' * 64, 'Alice')],
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
              .having((s) => s.status, 'status', UserSearchStatus.success)
              .having((s) => s.query, 'query', 'alice')
              .having((s) => s.results.length, 'results.length', 1)
              .having(
                (s) => s.results.first.displayName,
                'first result name',
                'Alice',
              )
              .having((s) => s.offset, 'offset', 1)
              .having((s) => s.hasMore, 'hasMore', false),
        ],
        verify: (_) {
          verify(
            () => mockProfileRepository.searchUsers(
              query: 'alice',
              limit: 50,
              sortBy: 'followers',
              hasVideos: true,
            ),
          ).called(1);
        },
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'sets hasMore to true when results equal page size',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsers(
              query: 'test',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer((_) async => createTestProfiles(50));
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
              .having((s) => s.status, 'status', UserSearchStatus.success)
              .having((s) => s.results.length, 'results.length', 50)
              .having((s) => s.offset, 'offset', 50)
              .having((s) => s.hasMore, 'hasMore', true),
        ],
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'emits [loading, failure] when search fails',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsers(
              query: 'error',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenThrow(Exception('Network error'));
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
            () => mockProfileRepository.searchUsers(query: any(named: 'query')),
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
            () => mockProfileRepository.searchUsers(query: any(named: 'query')),
          );
        },
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'trims whitespace from query',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsers(
              query: 'bob',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer((_) async => []);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const UserSearchQueryChanged('  bob  ')),
        wait: debounceDuration,
        expect: () => [
          const UserSearchState(status: UserSearchStatus.loading, query: 'bob'),
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.success)
              .having((s) => s.query, 'query', 'bob')
              .having((s) => s.results, 'results', isEmpty),
        ],
        verify: (_) {
          verify(
            () => mockProfileRepository.searchUsers(
              query: 'bob',
              limit: 50,
              sortBy: 'followers',
              hasVideos: true,
            ),
          ).called(1);
        },
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'returns empty results when no users match',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsers(
              query: 'xyz',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer((_) async => []);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const UserSearchQueryChanged('xyz')),
        wait: debounceDuration,
        expect: () => [
          const UserSearchState(status: UserSearchStatus.loading, query: 'xyz'),
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
            () => mockProfileRepository.searchUsers(
              query: 'final',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer((_) async => []);
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
              .having((s) => s.status, 'status', UserSearchStatus.success)
              .having((s) => s.query, 'query', 'final'),
        ],
        verify: (_) {
          // Only the final query should be processed due to debounce
          verify(
            () => mockProfileRepository.searchUsers(
              query: 'final',
              limit: 50,
              sortBy: 'followers',
              hasVideos: true,
            ),
          ).called(1);
          verifyNever(
            () => mockProfileRepository.searchUsers(
              query: 'f',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          );
          verifyNever(
            () => mockProfileRepository.searchUsers(
              query: 'fi',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          );
          verifyNever(
            () => mockProfileRepository.searchUsers(
              query: 'fin',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          );
          verifyNever(
            () => mockProfileRepository.searchUsers(
              query: 'fina',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          );
        },
      );
    });

    group('UserSearchLoadMore', () {
      blocTest<UserSearchBloc, UserSearchState>(
        'appends results and updates offset when loading more',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsers(
              query: 'alice',
              limit: 50,
              offset: 50,
              sortBy: 'followers',
              hasVideos: true,
            ),
          ).thenAnswer((_) async => createTestProfiles(10));
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
        'sets hasMore to true when load more returns full page',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsers(
              query: 'alice',
              limit: 50,
              offset: 50,
              sortBy: 'followers',
              hasVideos: true,
            ),
          ).thenAnswer((_) async => createTestProfiles(50));
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
            () => mockProfileRepository.searchUsers(
              query: 'alice',
              limit: 50,
              offset: 50,
              sortBy: 'followers',
              hasVideos: true,
            ),
          ).thenThrow(Exception('Network error'));
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
        setUp: () {
          when(
            () => mockProfileRepository.searchUsers(
              query: 'alice',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer(
            (_) async => [createTestProfile('a' * 64, 'Alice')],
          );
        },
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
        'passes hasVideos: false to profileRepository when configured',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsers(
              query: 'test',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer((_) async => []);
        },
        build: () => UserSearchBloc(
          profileRepository: mockProfileRepository,
          hasVideos: false,
        ),
        act: (bloc) => bloc.add(const UserSearchQueryChanged('test')),
        wait: debounceDuration,
        verify: (_) {
          verify(
            () => mockProfileRepository.searchUsers(
              query: 'test',
              limit: 50,
              sortBy: 'followers',
            ),
          ).called(1);
        },
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'passes hasVideos: false to profileRepository on load more',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsers(
              query: 'alice',
              limit: 50,
              offset: 50,
              sortBy: 'followers',
            ),
          ).thenAnswer((_) async => createTestProfiles(10));
        },
        build: () => UserSearchBloc(
          profileRepository: mockProfileRepository,
          hasVideos: false,
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
            () => mockProfileRepository.searchUsers(
              query: 'alice',
              limit: 50,
              offset: 50,
              sortBy: 'followers',
            ),
          ).called(1);
        },
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'defaults hasVideos to true when not specified',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsers(
              query: 'test',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
              hasVideos: any(named: 'hasVideos'),
            ),
          ).thenAnswer((_) async => []);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const UserSearchQueryChanged('test')),
        wait: debounceDuration,
        verify: (_) {
          verify(
            () => mockProfileRepository.searchUsers(
              query: 'test',
              limit: 50,
              sortBy: 'followers',
              hasVideos: true,
            ),
          ).called(1);
        },
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
          1,
          true,
          false,
        ]);
      });
    });
  });
}
