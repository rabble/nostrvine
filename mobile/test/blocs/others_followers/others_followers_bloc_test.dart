// ABOUTME: Tests for OthersFollowersBloc - another user's followers list
// ABOUTME: Tests loading from repository, error handling, and follow operations

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/others_followers/others_followers_bloc.dart';
import 'package:openvine/repositories/follow_repository.dart';

class _MockFollowRepository extends Mock implements FollowRepository {}

void main() {
  group('OthersFollowersBloc', () {
    late _MockFollowRepository mockFollowRepository;

    // Helper to create valid hex pubkeys (64 hex characters)
    String validPubkey(String suffix) {
      final hexSuffix = suffix.codeUnits
          .map((c) => c.toRadixString(16).padLeft(2, '0'))
          .join();
      return hexSuffix.padLeft(64, '0');
    }

    setUp(() {
      mockFollowRepository = _MockFollowRepository();
    });

    OthersFollowersBloc createBloc() =>
        OthersFollowersBloc(followRepository: mockFollowRepository);

    test('initial state is initial with empty list', () {
      final bloc = createBloc();
      expect(
        bloc.state,
        const OthersFollowersState(),
      );
      bloc.close();
    });

    group('OthersFollowersListLoadRequested', () {
      blocTest<OthersFollowersBloc, OthersFollowersState>(
        'emits [loading, success] with followers from repository',
        setUp: () {
          when(() => mockFollowRepository.getFollowers(any())).thenAnswer(
            (_) async => [validPubkey('follower1'), validPubkey('follower2')],
          );
          when(
            () => mockFollowRepository.getFollowerCount(any()),
          ).thenAnswer((_) async => 2);
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
          expect(bloc.state.lastFetchedAt, isNotNull);
        },
      );

      blocTest<OthersFollowersBloc, OthersFollowersState>(
        'uses higher count from service when list is incomplete',
        setUp: () {
          when(
            () => mockFollowRepository.getFollowers(any()),
          ).thenAnswer((_) async => [validPubkey('follower1')]);
          when(
            () => mockFollowRepository.getFollowerCount(any()),
          ).thenAnswer((_) async => 500);
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(OthersFollowersListLoadRequested(validPubkey('target'))),
        verify: (bloc) {
          expect(bloc.state.followersPubkeys, hasLength(1));
          expect(bloc.state.followerCount, 500);
        },
      );

      blocTest<OthersFollowersBloc, OthersFollowersState>(
        'emits [loading, success] with empty list when no followers',
        setUp: () {
          when(
            () => mockFollowRepository.getFollowers(any()),
          ).thenAnswer((_) async => []);
          when(
            () => mockFollowRepository.getFollowerCount(any()),
          ).thenAnswer((_) async => 0);
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(OthersFollowersListLoadRequested(validPubkey('target'))),
        verify: (bloc) {
          expect(bloc.state.status, OthersFollowersStatus.success);
          expect(bloc.state.followersPubkeys, isEmpty);
          expect(bloc.state.followerCount, 0);
          expect(bloc.state.targetPubkey, validPubkey('target'));
          expect(bloc.state.lastFetchedAt, isNotNull);
        },
      );

      blocTest<OthersFollowersBloc, OthersFollowersState>(
        'emits [loading, failure] when repository throws',
        setUp: () {
          when(
            () => mockFollowRepository.getFollowers(any()),
          ).thenThrow(Exception('Network error'));
          when(
            () => mockFollowRepository.getFollowerCount(any()),
          ).thenAnswer((_) async => 0);
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
        'stores targetPubkey in state for retry',
        setUp: () {
          when(
            () => mockFollowRepository.getFollowers(any()),
          ).thenAnswer((_) async => []);
          when(
            () => mockFollowRepository.getFollowerCount(any()),
          ).thenAnswer((_) async => 0);
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
            () => mockFollowRepository.getFollowers(any()),
          ).thenAnswer((_) async => []);
          when(
            () => mockFollowRepository.getFollowerCount(any()),
          ).thenAnswer((_) async => 0);
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(OthersFollowersListLoadRequested(validPubkey('target'))),
        verify: (_) {
          verify(
            () => mockFollowRepository.getFollowers(validPubkey('target')),
          ).called(1);
        },
      );

      blocTest<OthersFollowersBloc, OthersFollowersState>(
        'skips fetch when data is fresh for same target',
        setUp: () {
          when(
            () => mockFollowRepository.getFollowers(any()),
          ).thenAnswer((_) async => [validPubkey('follower1')]);
          when(
            () => mockFollowRepository.getFollowerCount(any()),
          ).thenAnswer((_) async => 1);
        },
        build: createBloc,
        seed: () => OthersFollowersState(
          status: OthersFollowersStatus.success,
          followersPubkeys: [validPubkey('follower1')],
          followerCount: 1,
          targetPubkey: validPubkey('target'),
          lastFetchedAt: DateTime.now(), // Fresh data
        ),
        act: (bloc) =>
            bloc.add(OthersFollowersListLoadRequested(validPubkey('target'))),
        expect: () => <OthersFollowersState>[], // No state change
        verify: (_) {
          verifyNever(() => mockFollowRepository.getFollowers(any()));
        },
      );

      blocTest<OthersFollowersBloc, OthersFollowersState>(
        'fetches when forceRefresh is true even if data is fresh',
        setUp: () {
          when(
            () => mockFollowRepository.getFollowers(any()),
          ).thenAnswer((_) async => [validPubkey('follower1')]);
          when(
            () => mockFollowRepository.getFollowerCount(any()),
          ).thenAnswer((_) async => 1);
        },
        build: createBloc,
        seed: () => OthersFollowersState(
          status: OthersFollowersStatus.success,
          followersPubkeys: [validPubkey('follower1')],
          followerCount: 1,
          targetPubkey: validPubkey('target'),
          lastFetchedAt: DateTime.now(), // Fresh data
        ),
        act: (bloc) => bloc.add(
          OthersFollowersListLoadRequested(
            validPubkey('target'),
            forceRefresh: true,
          ),
        ),
        verify: (bloc) {
          verify(() => mockFollowRepository.getFollowers(any())).called(1);
          expect(bloc.state.status, OthersFollowersStatus.success);
        },
      );
    });

    group('OthersFollowersIncrementRequested', () {
      blocTest<OthersFollowersBloc, OthersFollowersState>(
        'adds follower pubkey to list and increments count',
        build: createBloc,
        seed: () => OthersFollowersState(
          status: OthersFollowersStatus.success,
          followersPubkeys: [validPubkey('existing')],
          followerCount: 500,
          targetPubkey: validPubkey('target'),
        ),
        act: (bloc) =>
            bloc.add(OthersFollowersIncrementRequested(validPubkey('new'))),
        expect: () => [
          OthersFollowersState(
            status: OthersFollowersStatus.success,
            followersPubkeys: [validPubkey('existing'), validPubkey('new')],
            followerCount: 501,
            targetPubkey: validPubkey('target'),
          ),
        ],
      );

      blocTest<OthersFollowersBloc, OthersFollowersState>(
        'does not add duplicate follower pubkey',
        build: createBloc,
        seed: () => OthersFollowersState(
          status: OthersFollowersStatus.success,
          followersPubkeys: [validPubkey('existing')],
          followerCount: 1,
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
            followerCount: 1,
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
          followerCount: 500,
          targetPubkey: validPubkey('target'),
        ),
        act: (bloc) => bloc.add(
          OthersFollowersDecrementRequested(validPubkey('follower1')),
        ),
        expect: () => [
          OthersFollowersState(
            status: OthersFollowersStatus.success,
            followersPubkeys: [validPubkey('follower2')],
            followerCount: 499,
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
          followerCount: 1,
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
          followerCount: 1,
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
      const state = OthersFollowersState(
        targetPubkey: 'target1',
      );

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
      final testTime = DateTime(2024, 1, 1, 12);
      final state = OthersFollowersState(
        status: OthersFollowersStatus.success,
        followersPubkeys: const ['pubkey1'],
        followerCount: 10,
        targetPubkey: 'target',
        lastFetchedAt: testTime,
      );

      expect(state.props, [
        OthersFollowersStatus.success,
        ['pubkey1'],
        10,
        'target',
        testTime,
      ]);
    });

    test('isStale returns true when lastFetchedAt is null', () {
      const state = OthersFollowersState();
      expect(state.isStale, isTrue);
    });

    test('isStale returns true when data is older than cacheTtl', () {
      final oldTime = DateTime.now().subtract(
        OthersFollowersState.cacheTtl + const Duration(seconds: 1),
      );
      final state = OthersFollowersState(lastFetchedAt: oldTime);
      expect(state.isStale, isTrue);
    });

    test('isStale returns false when data is fresh', () {
      final recentTime = DateTime.now().subtract(const Duration(seconds: 10));
      final state = OthersFollowersState(lastFetchedAt: recentTime);
      expect(state.isStale, isFalse);
    });
  });
}
