// ABOUTME: Tests for UserSearchBloc - user search via NIP-50
// ABOUTME: Tests search query handling, loading states, and error handling

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

    UserSearchBloc createBloc() => UserSearchBloc(
          profileRepository: mockProfileRepository,
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

    test('initial state is correct', () {
      final bloc = createBloc();
      expect(bloc.state.status, UserSearchStatus.initial);
      expect(bloc.state.query, isEmpty);
      expect(bloc.state.results, isEmpty);
      expect(bloc.state.errorMessage, isNull);
      bloc.close();
    });

    group('UserSearchQueryChanged', () {
      blocTest<UserSearchBloc, UserSearchState>(
        'emits [loading, success] when search succeeds',
        setUp: () {
          when(() => mockProfileRepository.searchUsers(query: 'alice'))
              .thenAnswer(
            (_) async => [createTestProfile('${'a' * 64}', 'Alice')],
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const UserSearchQueryChanged('alice')),
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
          verify(() => mockProfileRepository.searchUsers(query: 'alice'))
              .called(1);
        },
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'emits [loading, failure] when search fails',
        setUp: () {
          when(() => mockProfileRepository.searchUsers(query: 'error'))
              .thenThrow(Exception('Network error'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const UserSearchQueryChanged('error')),
        expect: () => [
          const UserSearchState(
            status: UserSearchStatus.loading,
            query: 'error',
          ),
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.failure)
              .having((s) => s.errorMessage, 'errorMessage', isNotNull),
        ],
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'emits initial state when query is empty',
        build: createBloc,
        act: (bloc) => bloc.add(const UserSearchQueryChanged('')),
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
          when(() => mockProfileRepository.searchUsers(query: 'bob'))
              .thenAnswer((_) async => []);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const UserSearchQueryChanged('  bob  ')),
        expect: () => [
          const UserSearchState(
            status: UserSearchStatus.loading,
            query: 'bob',
          ),
          const UserSearchState(
            status: UserSearchStatus.success,
            query: 'bob',
          ),
        ],
        verify: (_) {
          verify(() => mockProfileRepository.searchUsers(query: 'bob'))
              .called(1);
        },
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'returns empty results when no users match',
        setUp: () {
          when(() => mockProfileRepository.searchUsers(query: 'xyz'))
              .thenAnswer((_) async => []);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const UserSearchQueryChanged('xyz')),
        expect: () => [
          const UserSearchState(
            status: UserSearchStatus.loading,
            query: 'xyz',
          ),
          const UserSearchState(
            status: UserSearchStatus.success,
            query: 'xyz',
          ),
        ],
      );
    });

    group('UserSearchCleared', () {
      blocTest<UserSearchBloc, UserSearchState>(
        'resets to initial state',
        setUp: () {
          when(() => mockProfileRepository.searchUsers(query: 'alice'))
              .thenAnswer(
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
        expect(updated.errorMessage, isNull);
      });

      test('copyWith clears errorMessage when not provided', () {
        const state = UserSearchState(
          status: UserSearchStatus.failure,
          errorMessage: 'error',
        );

        final updated = state.copyWith(status: UserSearchStatus.loading);

        expect(updated.status, UserSearchStatus.loading);
        expect(updated.errorMessage, isNull);
      });

      test('props includes all fields', () {
        final profile = createTestProfile('${'a' * 64}', 'Alice');
        final state = UserSearchState(
          status: UserSearchStatus.success,
          query: 'alice',
          results: [profile],
          errorMessage: null,
        );

        expect(
          state.props,
          [UserSearchStatus.success, 'alice', [profile], null],
        );
      });
    });
  });
}
