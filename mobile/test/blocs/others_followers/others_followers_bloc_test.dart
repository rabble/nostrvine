// ABOUTME: Tests for OthersFollowersBloc - another user's followers list
// ABOUTME: Tests loading from repository, error handling, and follow operations

import 'package:bloc_test/bloc_test.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/others_followers/others_followers_bloc.dart';

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

void main() {
  group('OthersFollowersBloc', () {
    late _MockFollowRepository mockFollowRepository;
    late _MockContentBlocklistRepository mockBlocklistRepository;
    const testCurrentUserPubkey =
        'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

    // Helper to create valid hex pubkeys (64 hex characters)
    String validPubkey(String suffix) {
      final hexSuffix = suffix.codeUnits
          .map((c) => c.toRadixString(16).padLeft(2, '0'))
          .join();
      return hexSuffix.padLeft(64, '0');
    }

    setUp(() async {
      mockFollowRepository = _MockFollowRepository();
      mockBlocklistRepository = _MockContentBlocklistRepository();

      // Default: nothing is blocked
      when(() => mockBlocklistRepository.isBlocked(any())).thenReturn(false);
      when(() => mockFollowRepository.isFollowing(any())).thenReturn(false);
    });

    OthersFollowersBloc createBloc() => OthersFollowersBloc(
      followRepository: mockFollowRepository,
      contentBlocklistRepository: mockBlocklistRepository,
      currentUserPubkey: testCurrentUserPubkey,
    );

    test('initial state is initial with empty list', () {
      final bloc = createBloc();
      expect(bloc.state, const OthersFollowersState());
      bloc.close();
    });

    group('OthersFollowersListLoadRequested', () {
      blocTest<OthersFollowersBloc, OthersFollowersState>(
        'emits [loading, success] with followers from repository',
        setUp: () {
          when(
            () => mockFollowRepository.watchOthersFollowersCached(
              any(),
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) => Stream<CacheResult<FollowersSnapshot>>.value(
              CacheResult.live(
                FollowersSnapshot(
                  pubkeys: [validPubkey('follower1'), validPubkey('follower2')],
                  count: 2,
                ),
              ),
            ),
          );
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(OthersFollowersListLoadRequested(validPubkey('target'))),
        verify: (bloc) {
          expect(bloc.state.status, OthersFollowersStatus.success);
          expect(bloc.state.followersPubkeys, [
            validPubkey('follower1'),
            validPubkey('follower2'),
          ]);
          expect(bloc.state.followerCount, 2);
          expect(bloc.state.targetPubkey, validPubkey('target'));
        },
      );

      blocTest<OthersFollowersBloc, OthersFollowersState>(
        'followerCount equals fetched list length',
        setUp: () {
          when(
            () => mockFollowRepository.watchOthersFollowersCached(
              any(),
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) => Stream<CacheResult<FollowersSnapshot>>.value(
              CacheResult.live(
                FollowersSnapshot(
                  pubkeys: [validPubkey('follower1')],
                  count: [validPubkey('follower1')].length,
                ),
              ),
            ),
          );
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(OthersFollowersListLoadRequested(validPubkey('target'))),
        verify: (bloc) {
          expect(bloc.state.followersPubkeys, hasLength(1));
          expect(bloc.state.followerCount, 1);
        },
      );

      blocTest<OthersFollowersBloc, OthersFollowersState>(
        'filters out current user when viewer is not following target',
        setUp: () {
          when(
            () => mockFollowRepository.watchOthersFollowersCached(
              any(),
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) => Stream<CacheResult<FollowersSnapshot>>.value(
              CacheResult.live(
                FollowersSnapshot(
                  pubkeys: [testCurrentUserPubkey, validPubkey('follower1')],
                  count: 2,
                ),
              ),
            ),
          );

          when(
            () => mockFollowRepository.isFollowing(validPubkey('target')),
          ).thenReturn(false);
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(OthersFollowersListLoadRequested(validPubkey('target'))),
        verify: (bloc) {
          expect(bloc.state.followersPubkeys, [validPubkey('follower1')]);
          expect(bloc.state.followerCount, 1);
        },
      );

      blocTest<OthersFollowersBloc, OthersFollowersState>(
        'keeps current user in list when viewer is following target',
        setUp: () {
          when(
            () => mockFollowRepository.watchOthersFollowersCached(
              any(),
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) => Stream<CacheResult<FollowersSnapshot>>.value(
              CacheResult.live(
                FollowersSnapshot(
                  pubkeys: [testCurrentUserPubkey, validPubkey('follower1')],
                  count: 2,
                ),
              ),
            ),
          );

          when(
            () => mockFollowRepository.isFollowing(validPubkey('target')),
          ).thenReturn(true);
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(OthersFollowersListLoadRequested(validPubkey('target'))),
        verify: (bloc) {
          expect(bloc.state.followersPubkeys, [
            testCurrentUserPubkey,
            validPubkey('follower1'),
          ]);
          expect(bloc.state.followerCount, 2);
        },
      );

      blocTest<OthersFollowersBloc, OthersFollowersState>(
        'emits [loading, success] with empty list when no followers',
        setUp: () {
          when(
            () => mockFollowRepository.watchOthersFollowersCached(
              any(),
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) => Stream<CacheResult<FollowersSnapshot>>.value(
              const CacheResult.live(
                FollowersSnapshot(pubkeys: <String>[], count: 0),
              ),
            ),
          );
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(OthersFollowersListLoadRequested(validPubkey('target'))),
        verify: (bloc) {
          expect(bloc.state.status, OthersFollowersStatus.success);
          expect(bloc.state.followersPubkeys, isEmpty);
          expect(bloc.state.followerCount, 0);
          expect(bloc.state.targetPubkey, validPubkey('target'));
        },
      );

      blocTest<OthersFollowersBloc, OthersFollowersState>(
        'emits [loading, failure] when repository throws',
        setUp: () {
          when(
            () => mockFollowRepository.watchOthersFollowersCached(
              any(),
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) => Stream<CacheResult<FollowersSnapshot>>.error(
              Exception('Network error'),
            ),
          );
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(OthersFollowersListLoadRequested(validPubkey('target'))),
        expect: () => [
          OthersFollowersState(
            status: OthersFollowersStatus.loading,
            targetPubkey: validPubkey('target'),
          ),
          OthersFollowersState(
            status: OthersFollowersStatus.failure,
            targetPubkey: validPubkey('target'),
          ),
        ],
      );

      blocTest<OthersFollowersBloc, OthersFollowersState>(
        'keeps cached data when refresh errors after cached emission',
        setUp: () {
          when(
            () => mockFollowRepository.watchOthersFollowersCached(
              any(),
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer((_) async* {
            yield CacheResult.cached(
              FollowersSnapshot(pubkeys: [validPubkey('cached')], count: 10),
            );
            throw Exception('Network error');
          });
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(OthersFollowersListLoadRequested(validPubkey('target'))),
        verify: (bloc) {
          expect(bloc.state.status, OthersFollowersStatus.success);
          expect(bloc.state.followersPubkeys, [validPubkey('cached')]);
          expect(bloc.state.followerCount, 10);
          expect(bloc.state.isRefreshing, isFalse);
        },
        errors: () => [isA<Exception>()],
      );

      blocTest<OthersFollowersBloc, OthersFollowersState>(
        'stores targetPubkey in state for retry',
        setUp: () {
          when(
            () => mockFollowRepository.watchOthersFollowersCached(
              any(),
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) => Stream<CacheResult<FollowersSnapshot>>.value(
              const CacheResult.live(
                FollowersSnapshot(pubkeys: <String>[], count: 0),
              ),
            ),
          );
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(OthersFollowersListLoadRequested(validPubkey('target'))),
        verify: (bloc) {
          expect(bloc.state.targetPubkey, validPubkey('target'));
        },
      );

      blocTest<OthersFollowersBloc, OthersFollowersState>(
        'calls repository with correct pubkey',
        setUp: () {
          when(
            () => mockFollowRepository.watchOthersFollowersCached(
              any(),
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) => Stream<CacheResult<FollowersSnapshot>>.value(
              const CacheResult.live(
                FollowersSnapshot(pubkeys: <String>[], count: 0),
              ),
            ),
          );
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(OthersFollowersListLoadRequested(validPubkey('target'))),
        verify: (_) {
          verify(
            () => mockFollowRepository.watchOthersFollowersCached(
              validPubkey('target'),
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).called(1);
        },
      );

      blocTest<OthersFollowersBloc, OthersFollowersState>(
        'fetches when forceRefresh is true even if data is fresh',
        setUp: () {
          when(
            () => mockFollowRepository.watchOthersFollowersCached(
              any(),
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).thenAnswer(
            (_) => Stream<CacheResult<FollowersSnapshot>>.value(
              CacheResult.live(
                FollowersSnapshot(
                  pubkeys: [validPubkey('follower1')],
                  count: 1,
                ),
              ),
            ),
          );
        },
        build: createBloc,
        seed: () => OthersFollowersState(
          status: OthersFollowersStatus.success,
          followersPubkeys: [validPubkey('follower1')],
          authoritativeFollowerCount: 1,
          targetPubkey: validPubkey('target'),
        ),
        act: (bloc) => bloc.add(
          OthersFollowersListLoadRequested(
            validPubkey('target'),
            forceRefresh: true,
          ),
        ),
        verify: (bloc) {
          verify(
            () => mockFollowRepository.watchOthersFollowersCached(
              any(),
              forceRefresh: any(named: 'forceRefresh'),
            ),
          ).called(1);
          expect(bloc.state.status, OthersFollowersStatus.success);
        },
      );
    });

    blocTest<OthersFollowersBloc, OthersFollowersState>(
      'clears the previous target followers when switching profiles',
      setUp: () {
        when(
          () => mockFollowRepository.watchOthersFollowersCached(
            any(),
            forceRefresh: any(named: 'forceRefresh'),
          ),
        ).thenAnswer(
          (_) => const Stream<CacheResult<FollowersSnapshot>>.empty(),
        );
      },
      build: createBloc,
      seed: () => OthersFollowersState(
        status: OthersFollowersStatus.success,
        followersPubkeys: [validPubkey('a'), validPubkey('b')],
        rawFollowersPubkeys: [validPubkey('a'), validPubkey('b')],
        authoritativeFollowerCount: 500,
        targetPubkey: validPubkey('target'),
      ),
      act: (bloc) =>
          bloc.add(OthersFollowersListLoadRequested(validPubkey('other'))),
      verify: (bloc) {
        // Carrying the previous target's raw pubkeys over would leave the
        // visible count deriving from someone else's follower list.
        expect(bloc.state.rawFollowersPubkeys, isEmpty);
        expect(bloc.state.followersPubkeys, isEmpty);
        expect(bloc.state.authoritativeFollowerCount, equals(0));
        expect(bloc.state.followerCount, equals(0));
      },
    );

    group('OthersFollowersIncrementRequested', () {
      blocTest<OthersFollowersBloc, OthersFollowersState>(
        'adds follower pubkey to list and increments count',
        build: createBloc,
        seed: () => OthersFollowersState(
          status: OthersFollowersStatus.success,
          followersPubkeys: [validPubkey('existing')],
          rawFollowersPubkeys: [validPubkey('existing')],
          authoritativeFollowerCount: 500,
          targetPubkey: validPubkey('target'),
        ),
        act: (bloc) =>
            bloc.add(OthersFollowersIncrementRequested(validPubkey('new'))),
        expect: () => [
          OthersFollowersState(
            status: OthersFollowersStatus.success,
            followersPubkeys: [validPubkey('existing'), validPubkey('new')],
            rawFollowersPubkeys: [validPubkey('existing'), validPubkey('new')],
            authoritativeFollowerCount: 501,
            targetPubkey: validPubkey('target'),
          ),
        ],
      );

      blocTest<OthersFollowersBloc, OthersFollowersState>(
        'keeps the visible count steady when the new follower is blocked',
        setUp: () {
          when(
            () => mockBlocklistRepository.isBlocked(validPubkey('new')),
          ).thenReturn(true);
        },
        build: createBloc,
        seed: () => OthersFollowersState(
          status: OthersFollowersStatus.success,
          followersPubkeys: [validPubkey('existing')],
          rawFollowersPubkeys: [validPubkey('existing')],
          authoritativeFollowerCount: 500,
          targetPubkey: validPubkey('target'),
        ),
        act: (bloc) =>
            bloc.add(OthersFollowersIncrementRequested(validPubkey('new'))),
        verify: (bloc) {
          // The target really did gain a follower, so the authoritative count
          // moves; the viewer just cannot see that follower, so the displayed
          // count must not.
          expect(bloc.state.authoritativeFollowerCount, equals(501));
          expect(bloc.state.followersPubkeys, [validPubkey('existing')]);
          expect(bloc.state.followerCount, equals(500));
        },
      );

      blocTest<OthersFollowersBloc, OthersFollowersState>(
        'does not add duplicate follower pubkey',
        build: createBloc,
        seed: () => OthersFollowersState(
          status: OthersFollowersStatus.success,
          followersPubkeys: [validPubkey('existing')],
          rawFollowersPubkeys: [validPubkey('existing')],
          authoritativeFollowerCount: 1,
          targetPubkey: validPubkey('target'),
        ),
        act: (bloc) => bloc.add(
          OthersFollowersIncrementRequested(validPubkey('existing')),
        ),
        expect: () => <OthersFollowersState>[],
      );

      blocTest<OthersFollowersBloc, OthersFollowersState>(
        'works with empty initial list',
        build: createBloc,
        seed: () => OthersFollowersState(
          status: OthersFollowersStatus.success,
          targetPubkey: validPubkey('target'),
        ),
        act: (bloc) =>
            bloc.add(OthersFollowersIncrementRequested(validPubkey('first'))),
        expect: () => [
          OthersFollowersState(
            status: OthersFollowersStatus.success,
            followersPubkeys: [validPubkey('first')],
            rawFollowersPubkeys: [validPubkey('first')],
            authoritativeFollowerCount: 1,
            targetPubkey: validPubkey('target'),
          ),
        ],
      );
    });

    group('OthersFollowersDecrementRequested', () {
      blocTest<OthersFollowersBloc, OthersFollowersState>(
        'removes follower pubkey from list and decrements count',
        build: createBloc,
        seed: () => OthersFollowersState(
          status: OthersFollowersStatus.success,
          followersPubkeys: [
            validPubkey('follower1'),
            validPubkey('follower2'),
          ],
          rawFollowersPubkeys: [
            validPubkey('follower1'),
            validPubkey('follower2'),
          ],
          authoritativeFollowerCount: 500,
          targetPubkey: validPubkey('target'),
        ),
        act: (bloc) => bloc.add(
          OthersFollowersDecrementRequested(validPubkey('follower1')),
        ),
        expect: () => [
          OthersFollowersState(
            status: OthersFollowersStatus.success,
            followersPubkeys: [validPubkey('follower2')],
            rawFollowersPubkeys: [validPubkey('follower2')],
            authoritativeFollowerCount: 499,
            targetPubkey: validPubkey('target'),
          ),
        ],
      );

      blocTest<OthersFollowersBloc, OthersFollowersState>(
        'does nothing when pubkey not in list',
        build: createBloc,
        seed: () => OthersFollowersState(
          status: OthersFollowersStatus.success,
          followersPubkeys: [validPubkey('existing')],
          rawFollowersPubkeys: [validPubkey('existing')],
          authoritativeFollowerCount: 1,
          targetPubkey: validPubkey('target'),
        ),
        act: (bloc) => bloc.add(
          OthersFollowersDecrementRequested(validPubkey('notexist')),
        ),
        expect: () => <OthersFollowersState>[],
      );

      blocTest<OthersFollowersBloc, OthersFollowersState>(
        'removes last follower leaving empty list with zero count',
        build: createBloc,
        seed: () => OthersFollowersState(
          status: OthersFollowersStatus.success,
          followersPubkeys: [validPubkey('only')],
          rawFollowersPubkeys: [validPubkey('only')],
          authoritativeFollowerCount: 1,
          targetPubkey: validPubkey('target'),
        ),
        act: (bloc) =>
            bloc.add(OthersFollowersDecrementRequested(validPubkey('only'))),
        expect: () => [
          OthersFollowersState(
            status: OthersFollowersStatus.success,
            targetPubkey: validPubkey('target'),
          ),
        ],
      );
    });
  });

  group('OthersFollowersState', () {
    test('supports value equality', () {
      const state1 = OthersFollowersState(
        status: OthersFollowersStatus.success,
        followersPubkeys: ['pubkey1'],
        targetPubkey: 'target',
      );
      const state2 = OthersFollowersState(
        status: OthersFollowersStatus.success,
        followersPubkeys: ['pubkey1'],
        targetPubkey: 'target',
      );

      expect(state1, equals(state2));
    });

    test('copyWith creates copy with updated values', () {
      const state = OthersFollowersState(targetPubkey: 'target1');

      final updated = state.copyWith(
        status: OthersFollowersStatus.loading,
        followersPubkeys: ['pubkey1'],
        targetPubkey: 'target2',
      );

      expect(updated.status, OthersFollowersStatus.loading);
      expect(updated.followersPubkeys, ['pubkey1']);
      expect(updated.targetPubkey, 'target2');
    });

    test('copyWith preserves values when not specified', () {
      const state = OthersFollowersState(
        status: OthersFollowersStatus.success,
        followersPubkeys: ['pubkey1'],
        targetPubkey: 'target',
      );

      final updated = state.copyWith();

      expect(updated.status, OthersFollowersStatus.success);
      expect(updated.followersPubkeys, ['pubkey1']);
      expect(updated.targetPubkey, 'target');
    });

    test('props includes all fields', () {
      const state = OthersFollowersState(
        status: OthersFollowersStatus.success,
        followersPubkeys: ['pubkey1'],
        authoritativeFollowerCount: 10,
        targetPubkey: 'target',
      );

      expect(state.props, [
        OthersFollowersStatus.success,
        ['pubkey1'],
        <String>[], // rawFollowersPubkeys
        10,
        'target',
        false, // isRefreshing
        false, // isFollowingTarget
      ]);
    });
  });
}
