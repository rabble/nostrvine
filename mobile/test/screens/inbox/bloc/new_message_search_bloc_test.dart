// ABOUTME: Tests for NewMessageSearchBloc — contact loading, filtering,
// ABOUTME: network search, and merge behavior.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/screens/inbox/bloc/new_message_search_bloc.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockProfileRepository extends Mock implements ProfileRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

void main() {
  group(NewMessageSearchBloc, () {
    late _MockProfileRepository mockProfileRepo;
    late _MockFollowRepository mockFollowRepo;

    const debounceDuration = Duration(milliseconds: 400);

    setUp(() {
      mockProfileRepo = _MockProfileRepository();
      mockFollowRepo = _MockFollowRepository();
    });

    NewMessageSearchBloc createBloc() => NewMessageSearchBloc(
      profileRepository: mockProfileRepo,
      followRepository: mockFollowRepo,
    );

    UserProfile createTestProfile(
      String pubkey,
      String displayName, {
      String? nip05,
    }) {
      return UserProfile(
        pubkey: pubkey,
        displayName: displayName,
        nip05: nip05,
        createdAt: DateTime.now(),
        eventId: 'event-$pubkey',
        rawData: {'display_name': displayName},
      );
    }

    test('initial state is loadingContacts', () {
      when(() => mockFollowRepo.followingPubkeys).thenReturn([]);
      final bloc = createBloc();
      expect(bloc.state.status, NewMessageSearchStatus.loadingContacts);
      expect(bloc.state.contacts, isEmpty);
      expect(bloc.state.query, isEmpty);
      expect(bloc.state.results, isEmpty);
      bloc.close();
    });

    group('NewMessageSearchStarted', () {
      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'loads followed contacts sorted alphabetically',
        setUp: () {
          when(
            () => mockFollowRepo.followingPubkeys,
          ).thenReturn(['b' * 64, 'a' * 64]);
          when(
            () => mockProfileRepo.getCachedProfile(pubkey: 'b' * 64),
          ).thenAnswer((_) async => createTestProfile('b' * 64, 'Bob'));
          when(
            () => mockProfileRepo.getCachedProfile(pubkey: 'a' * 64),
          ).thenAnswer((_) async => createTestProfile('a' * 64, 'Alice'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const NewMessageSearchStarted()),
        expect: () => [
          isA<NewMessageSearchState>()
              .having((s) => s.status, 'status', NewMessageSearchStatus.idle)
              .having((s) => s.contacts, 'contacts', hasLength(2))
              .having(
                (s) => s.contacts.first.displayName,
                'first contact',
                'Alice',
              )
              .having(
                (s) => s.contacts.last.displayName,
                'last contact',
                'Bob',
              ),
        ],
      );

      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'emits idle with empty contacts when no follows',
        setUp: () {
          when(() => mockFollowRepo.followingPubkeys).thenReturn([]);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const NewMessageSearchStarted()),
        expect: () => [
          const NewMessageSearchState(status: NewMessageSearchStatus.idle),
        ],
      );

      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'skips null profiles from cache',
        setUp: () {
          when(
            () => mockFollowRepo.followingPubkeys,
          ).thenReturn(['a' * 64, 'b' * 64]);
          when(
            () => mockProfileRepo.getCachedProfile(pubkey: 'a' * 64),
          ).thenAnswer((_) async => createTestProfile('a' * 64, 'Alice'));
          when(
            () => mockProfileRepo.getCachedProfile(pubkey: 'b' * 64),
          ).thenAnswer((_) async => null);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const NewMessageSearchStarted()),
        expect: () => [
          isA<NewMessageSearchState>()
              .having((s) => s.status, 'status', NewMessageSearchStatus.idle)
              .having((s) => s.contacts, 'contacts', hasLength(1))
              .having(
                (s) => s.contacts.first.displayName,
                'displayName',
                'Alice',
              ),
        ],
      );
    });

    group('NewMessageSearchQueryChanged', () {
      final alice = createTestProfile('a' * 64, 'Alice', nip05: 'alice@ex.com');
      final bob = createTestProfile('b' * 64, 'Bob');
      final charlie = createTestProfile('c' * 64, 'Charlie');

      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'filters contacts locally then merges with network results',
        setUp: () {
          when(
            () => mockProfileRepo.searchUsers(
              query: 'alice',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
            ),
          ).thenAnswer(
            (_) async => [createTestProfile('a' * 64, 'Alice Network')],
          );
        },
        build: createBloc,
        seed: () => NewMessageSearchState(
          status: NewMessageSearchStatus.idle,
          contacts: [alice, bob, charlie],
        ),
        act: (bloc) => bloc.add(const NewMessageSearchQueryChanged('alice')),
        wait: debounceDuration,
        expect: () => [
          // Searching with local filter (only Alice matches)
          isA<NewMessageSearchState>()
              .having(
                (s) => s.status,
                'status',
                NewMessageSearchStatus.searching,
              )
              .having((s) => s.query, 'query', 'alice')
              .having((s) => s.results, 'results', hasLength(1))
              .having(
                (s) => s.results.first.displayName,
                'local match',
                'Alice',
              ),
          // Success with merged results (network takes precedence)
          isA<NewMessageSearchState>()
              .having(
                (s) => s.status,
                'status',
                NewMessageSearchStatus.searchSuccess,
              )
              .having((s) => s.results, 'results', hasLength(1))
              .having(
                (s) => s.results.first.displayName,
                'network precedence',
                'Alice Network',
              ),
        ],
      );

      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'filters contacts by NIP-05',
        setUp: () {
          when(
            () => mockProfileRepo.searchUsers(
              query: 'alice@ex',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
            ),
          ).thenAnswer((_) async => []);
        },
        build: createBloc,
        seed: () => NewMessageSearchState(
          status: NewMessageSearchStatus.idle,
          contacts: [alice, bob],
        ),
        act: (bloc) => bloc.add(const NewMessageSearchQueryChanged('alice@ex')),
        wait: debounceDuration,
        expect: () => [
          isA<NewMessageSearchState>()
              .having(
                (s) => s.status,
                'status',
                NewMessageSearchStatus.searching,
              )
              .having((s) => s.results, 'results', hasLength(1))
              .having((s) => s.results.first.nip05, 'nip05', 'alice@ex.com'),
          isA<NewMessageSearchState>()
              .having(
                (s) => s.status,
                'status',
                NewMessageSearchStatus.searchSuccess,
              )
              .having((s) => s.results, 'results', hasLength(1)),
        ],
      );

      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'merges local contacts with network results deduplicating by pubkey',
        setUp: () {
          when(
            () => mockProfileRepo.searchUsers(
              query: 'bo',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
            ),
          ).thenAnswer(
            (_) async => [
              createTestProfile('b' * 64, 'Bob Network'),
              createTestProfile('d' * 64, 'Bobby New'),
            ],
          );
        },
        build: createBloc,
        seed: () => NewMessageSearchState(
          status: NewMessageSearchStatus.idle,
          contacts: [alice, bob, charlie],
        ),
        act: (bloc) => bloc.add(const NewMessageSearchQueryChanged('bo')),
        wait: debounceDuration,
        expect: () => [
          // Searching — local filter matches Bob
          isA<NewMessageSearchState>()
              .having(
                (s) => s.status,
                'status',
                NewMessageSearchStatus.searching,
              )
              .having((s) => s.results, 'results', hasLength(1)),
          // Success — network Bob + Bobby merged, local Bob deduped
          isA<NewMessageSearchState>()
              .having(
                (s) => s.status,
                'status',
                NewMessageSearchStatus.searchSuccess,
              )
              .having((s) => s.results, 'results', hasLength(2))
              .having(
                (s) => s.results.first.displayName,
                'network takes precedence',
                'Bob Network',
              ),
        ],
      );

      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'preserves local contacts on network failure',
        setUp: () {
          when(
            () => mockProfileRepo.searchUsers(
              query: 'alice',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
            ),
          ).thenThrow(Exception('Network error'));
        },
        build: createBloc,
        seed: () => NewMessageSearchState(
          status: NewMessageSearchStatus.idle,
          contacts: [alice, bob],
        ),
        act: (bloc) => bloc.add(const NewMessageSearchQueryChanged('alice')),
        wait: debounceDuration,
        expect: () => [
          isA<NewMessageSearchState>()
              .having(
                (s) => s.status,
                'status',
                NewMessageSearchStatus.searching,
              )
              .having((s) => s.results, 'results', hasLength(1)),
          isA<NewMessageSearchState>()
              .having(
                (s) => s.status,
                'status',
                NewMessageSearchStatus.searchFailure,
              )
              .having(
                (s) => s.results,
                'local contacts preserved',
                hasLength(1),
              ),
        ],
      );

      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'resets to idle when query is empty',
        build: createBloc,
        seed: () => NewMessageSearchState(
          status: NewMessageSearchStatus.searchSuccess,
          contacts: [alice],
          query: 'alice',
          results: [alice],
        ),
        act: (bloc) => bloc.add(const NewMessageSearchQueryChanged('')),
        wait: debounceDuration,
        expect: () => [
          isA<NewMessageSearchState>()
              .having((s) => s.status, 'status', NewMessageSearchStatus.idle)
              .having((s) => s.query, 'query', isEmpty)
              .having((s) => s.results, 'results', isEmpty)
              .having((s) => s.contacts, 'contacts preserved', hasLength(1)),
        ],
      );

      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'resets to idle when query is a single character',
        build: createBloc,
        seed: () => NewMessageSearchState(
          status: NewMessageSearchStatus.searchSuccess,
          contacts: [alice],
          query: 'alice',
          results: [alice],
        ),
        act: (bloc) => bloc.add(const NewMessageSearchQueryChanged('a')),
        wait: debounceDuration,
        expect: () => [
          isA<NewMessageSearchState>()
              .having((s) => s.status, 'status', NewMessageSearchStatus.idle)
              .having((s) => s.query, 'query', isEmpty)
              .having((s) => s.results, 'results', isEmpty),
        ],
      );

      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'debounces rapid query changes and processes only the final query',
        setUp: () {
          when(
            () => mockProfileRepo.searchUsers(
              query: 'alice',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
            ),
          ).thenAnswer((_) async => []);
        },
        build: createBloc,
        seed: () => NewMessageSearchState(
          status: NewMessageSearchStatus.idle,
          contacts: [alice, bob],
        ),
        act: (bloc) {
          bloc
            ..add(const NewMessageSearchQueryChanged('al'))
            ..add(const NewMessageSearchQueryChanged('ali'))
            ..add(const NewMessageSearchQueryChanged('alic'))
            ..add(const NewMessageSearchQueryChanged('alice'));
        },
        wait: debounceDuration,
        expect: () => [
          isA<NewMessageSearchState>()
              .having(
                (s) => s.status,
                'status',
                NewMessageSearchStatus.searching,
              )
              .having((s) => s.query, 'query', 'alice'),
          isA<NewMessageSearchState>().having(
            (s) => s.status,
            'status',
            NewMessageSearchStatus.searchSuccess,
          ),
        ],
        verify: (_) {
          verify(
            () => mockProfileRepo.searchUsers(
              query: 'alice',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
            ),
          ).called(1);
          verifyNever(
            () => mockProfileRepo.searchUsers(
              query: 'al',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
            ),
          );
        },
      );
    });

    group('NewMessageSearchCleared', () {
      blocTest<NewMessageSearchBloc, NewMessageSearchState>(
        'resets to idle and clears query and results',
        build: createBloc,
        seed: () => NewMessageSearchState(
          status: NewMessageSearchStatus.searchSuccess,
          contacts: [createTestProfile('a' * 64, 'Alice')],
          query: 'alice',
          results: [createTestProfile('a' * 64, 'Alice')],
        ),
        act: (bloc) => bloc.add(const NewMessageSearchCleared()),
        expect: () => [
          isA<NewMessageSearchState>()
              .having((s) => s.status, 'status', NewMessageSearchStatus.idle)
              .having((s) => s.query, 'query', isEmpty)
              .having((s) => s.results, 'results', isEmpty)
              .having((s) => s.contacts, 'contacts preserved', hasLength(1)),
        ],
      );
    });

    group('NewMessageSearchState', () {
      test('copyWith creates copy with updated values', () {
        const state = NewMessageSearchState();
        final updated = state.copyWith(
          status: NewMessageSearchStatus.idle,
          query: 'test',
        );

        expect(updated.status, NewMessageSearchStatus.idle);
        expect(updated.query, 'test');
        expect(updated.contacts, isEmpty);
        expect(updated.results, isEmpty);
      });

      test('copyWith preserves existing values when not specified', () {
        final profile = createTestProfile('a' * 64, 'Alice');
        final state = NewMessageSearchState(
          status: NewMessageSearchStatus.searchSuccess,
          contacts: [profile],
          query: 'alice',
          results: [profile],
        );

        final updated = state.copyWith(
          status: NewMessageSearchStatus.searching,
        );

        expect(updated.status, NewMessageSearchStatus.searching);
        expect(updated.contacts, hasLength(1));
        expect(updated.query, 'alice');
        expect(updated.results, hasLength(1));
      });

      test('isSearchActive returns true when query is not empty', () {
        const state = NewMessageSearchState(query: 'test');
        expect(state.isSearchActive, isTrue);
      });

      test('isSearchActive returns false when query is empty', () {
        const state = NewMessageSearchState();
        expect(state.isSearchActive, isFalse);
      });
    });
  });
}
