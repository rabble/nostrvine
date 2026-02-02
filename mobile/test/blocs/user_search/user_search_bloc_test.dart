// ABOUTME: Tests for UserSearchBloc - user search via Funnelcake REST and NIP-50
// ABOUTME: Tests hybrid search, loading states, and error handling

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/user_search/user_search_bloc.dart';
import 'package:openvine/services/analytics_api_service.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockAnalyticsApiService extends Mock implements AnalyticsApiService {}

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
      const debounceDuration = Duration(milliseconds: 300);

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

    group('hybrid search with Funnelcake', () {
      late _MockAnalyticsApiService mockAnalyticsApiService;

      // Debounce duration used in the BLoC
      const debounceDuration = Duration(milliseconds: 300);

      setUp(() {
        mockAnalyticsApiService = _MockAnalyticsApiService();
      });

      UserSearchBloc createHybridBloc() => UserSearchBloc(
        profileRepository: mockProfileRepository,
        analyticsApiService: mockAnalyticsApiService,
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'uses Funnelcake first then WebSocket when both available',
        setUp: () {
          when(() => mockAnalyticsApiService.isAvailable).thenReturn(true);
          when(
            () => mockAnalyticsApiService.searchProfiles(
              query: 'alice',
              limit: 50,
            ),
          ).thenAnswer(
            (_) async => [
              {
                'pubkey': '${'a' * 64}',
                'display_name': 'Alice REST',
                'created_at': 1700000000,
              },
            ],
          );
          when(
            () => mockProfileRepository.searchUsers(query: 'alice'),
          ).thenAnswer(
            (_) async => [createTestProfile('${'b' * 64}', 'Bob WS')],
          );
        },
        build: createHybridBloc,
        act: (bloc) => bloc.add(const UserSearchQueryChanged('alice')),
        wait: debounceDuration,
        expect: () => [
          const UserSearchState(
            status: UserSearchStatus.loading,
            query: 'alice',
          ),
          // First emit from REST results
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.success)
              .having((s) => s.results.length, 'results.length', 1)
              .having(
                (s) => s.results.first.displayName,
                'first result name',
                'Alice REST',
              ),
          // Final emit with merged results
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.success)
              .having((s) => s.results.length, 'results.length', 2),
        ],
        verify: (_) {
          verify(
            () => mockAnalyticsApiService.searchProfiles(
              query: 'alice',
              limit: 50,
            ),
          ).called(1);
          verify(
            () => mockProfileRepository.searchUsers(query: 'alice'),
          ).called(1);
        },
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'skips Funnelcake when not available',
        setUp: () {
          when(() => mockAnalyticsApiService.isAvailable).thenReturn(false);
          when(
            () => mockProfileRepository.searchUsers(query: 'alice'),
          ).thenAnswer(
            (_) async => [createTestProfile('${'a' * 64}', 'Alice WS')],
          );
        },
        build: createHybridBloc,
        act: (bloc) => bloc.add(const UserSearchQueryChanged('alice')),
        wait: debounceDuration,
        expect: () => [
          const UserSearchState(
            status: UserSearchStatus.loading,
            query: 'alice',
          ),
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.success)
              .having((s) => s.results.length, 'results.length', 1)
              .having(
                (s) => s.results.first.displayName,
                'first result name',
                'Alice WS',
              ),
        ],
        verify: (_) {
          verifyNever(
            () => mockAnalyticsApiService.searchProfiles(
              query: any(named: 'query'),
              limit: any(named: 'limit'),
            ),
          );
          verify(
            () => mockProfileRepository.searchUsers(query: 'alice'),
          ).called(1);
        },
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'shows REST results even if WebSocket fails',
        setUp: () {
          when(() => mockAnalyticsApiService.isAvailable).thenReturn(true);
          when(
            () => mockAnalyticsApiService.searchProfiles(
              query: 'alice',
              limit: 50,
            ),
          ).thenAnswer(
            (_) async => [
              {
                'pubkey': '${'a' * 64}',
                'display_name': 'Alice REST',
                'created_at': 1700000000,
              },
            ],
          );
          when(
            () => mockProfileRepository.searchUsers(query: 'alice'),
          ).thenThrow(Exception('WebSocket failed'));
        },
        build: createHybridBloc,
        act: (bloc) => bloc.add(const UserSearchQueryChanged('alice')),
        wait: debounceDuration,
        expect: () => [
          const UserSearchState(
            status: UserSearchStatus.loading,
            query: 'alice',
          ),
          // REST results emitted, stays success even though WS failed
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.success)
              .having((s) => s.results.length, 'results.length', 1),
        ],
      );

      blocTest<UserSearchBloc, UserSearchState>(
        'deduplicates results by pubkey (REST takes priority)',
        setUp: () {
          when(() => mockAnalyticsApiService.isAvailable).thenReturn(true);
          final samePubkey = '${'c' * 64}';
          when(
            () => mockAnalyticsApiService.searchProfiles(
              query: 'charlie',
              limit: 50,
            ),
          ).thenAnswer(
            (_) async => [
              {
                'pubkey': samePubkey,
                'display_name': 'Charlie REST',
                'created_at': 1700000000,
              },
            ],
          );
          when(
            () => mockProfileRepository.searchUsers(query: 'charlie'),
          ).thenAnswer(
            (_) async => [createTestProfile(samePubkey, 'Charlie WS')],
          );
        },
        build: createHybridBloc,
        act: (bloc) => bloc.add(const UserSearchQueryChanged('charlie')),
        wait: debounceDuration,
        expect: () => [
          const UserSearchState(
            status: UserSearchStatus.loading,
            query: 'charlie',
          ),
          // REST results emitted first
          isA<UserSearchState>()
              .having((s) => s.status, 'status', UserSearchStatus.success)
              .having((s) => s.results.length, 'results.length', 1)
              .having(
                (s) => s.results.first.displayName,
                'first result name',
                'Charlie REST',
              ),
        ],
        verify: (_) {
          // Both REST and WS were called
          verify(
            () => mockAnalyticsApiService.searchProfiles(
              query: 'charlie',
              limit: 50,
            ),
          ).called(1);
          verify(
            () => mockProfileRepository.searchUsers(query: 'charlie'),
          ).called(1);
        },
      );
    });
  });
}
