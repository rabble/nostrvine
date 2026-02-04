// ABOUTME: Tests for UserSearchBloc - user search via ProfileRepository
// ABOUTME: Tests loading states, error handling, and debouncing

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

    test('initial state is correct', () {
      final bloc = createBloc();
      expect(bloc.state.status, UserSearchStatus.initial);
      expect(bloc.state.query, isEmpty);
      expect(bloc.state.results, isEmpty);
      bloc.close();
    });

    group('UserSearchQueryChanged', () {
      // Debounce duration used in the BLoC
      const debounceDuration = Duration(milliseconds: 400);

      blocTest<UserSearchBloc, UserSearchState>(
        'emits [loading, success] when search succeeds',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsers(query: 'alice'),
          ).thenAnswer(
            (_) async => [createTestProfile('${'a' * 64}', 'Alice')],
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
              ),
        ],
        verify: (_) {
          verify(
            () => mockProfileRepository.searchUsers(query: 'alice'),
          ).called(1);
        },
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'emits [loading, failure] when search fails',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsers(query: 'error'),
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
            () => mockProfileRepository.searchUsers(query: 'bob'),
          ).thenAnswer((_) async => []);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const UserSearchQueryChanged('  bob  ')),
        wait: debounceDuration,
        expect: () => [
          const UserSearchState(status: UserSearchStatus.loading, query: 'bob'),
          const UserSearchState(status: UserSearchStatus.success, query: 'bob'),
        ],
        verify: (_) {
          verify(
            () => mockProfileRepository.searchUsers(query: 'bob'),
          ).called(1);
        },
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'returns empty results when no users match',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsers(query: 'xyz'),
          ).thenAnswer((_) async => []);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const UserSearchQueryChanged('xyz')),
        wait: debounceDuration,
        expect: () => [
          const UserSearchState(status: UserSearchStatus.loading, query: 'xyz'),
          const UserSearchState(status: UserSearchStatus.success, query: 'xyz'),
        ],
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'debounces rapid query changes and only processes final query',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsers(query: 'final'),
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
          const UserSearchState(
            status: UserSearchStatus.success,
            query: 'final',
          ),
        ],
        verify: (_) {
          // Only the final query should be processed due to debounce
          verify(
            () => mockProfileRepository.searchUsers(query: 'final'),
          ).called(1);
          verifyNever(() => mockProfileRepository.searchUsers(query: 'f'));
          verifyNever(() => mockProfileRepository.searchUsers(query: 'fi'));
          verifyNever(() => mockProfileRepository.searchUsers(query: 'fin'));
          verifyNever(() => mockProfileRepository.searchUsers(query: 'fina'));
        },
      );
    });

    group('UserSearchCleared', () {
      blocTest<UserSearchBloc, UserSearchState>(
        'resets to initial state',
        setUp: () {
          when(
            () => mockProfileRepository.searchUsers(query: 'alice'),
          ).thenAnswer(
            (_) async => [createTestProfile('${'a' * 64}', 'Alice')],
          );
        },
        build: createBloc,
        seed: () => UserSearchState(
          status: UserSearchStatus.success,
          query: 'alice',
          results: [createTestProfile('${'a' * 64}', 'Alice')],
        ),
        act: (bloc) => bloc.add(const UserSearchCleared()),
        expect: () => [const UserSearchState()],
      );
    });

    group('UserSearchState', () {
      test('copyWith creates copy with updated values', () {
        const state = UserSearchState();

        final updated = state.copyWith(
          status: UserSearchStatus.success,
          query: 'test',
        );

        expect(updated.status, UserSearchStatus.success);
        expect(updated.query, 'test');
        expect(updated.results, isEmpty);
      });

      test('props includes all fields', () {
        final profile = createTestProfile('${'a' * 64}', 'Alice');
        final state = UserSearchState(
          status: UserSearchStatus.success,
          query: 'alice',
          results: [profile],
        );

        expect(state.props, [
          UserSearchStatus.success,
          'alice',
          [profile],
        ]);
      });
    });
  });
}
