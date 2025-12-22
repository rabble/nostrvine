// ABOUTME: Tests for FollowersBloc - loading followers list and toggle follow
// ABOUTME: Uses bloc_test for state emission verification and mocktail for mocks

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart' as nostr_sdk;
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/blocs/followers/followers_bloc.dart';
import 'package:openvine/repositories/follow_repository.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _FakeFilter extends Fake implements Filter {}

void main() {
  setUpAll(() {
    registerFallbackValue(<Filter>[_FakeFilter()]);
  });

  group('FollowersBloc', () {
    late _MockNostrClient mockNostrClient;
    late _MockFollowRepository mockFollowRepository;
    late StreamController<nostr_sdk.Event> eventStreamController;

    // Helper to create valid hex pubkeys (64 hex characters)
    String validPubkey(String suffix) {
      final hexSuffix = suffix.codeUnits
          .map((c) => c.toRadixString(16).padLeft(2, '0'))
          .join();
      return hexSuffix.padLeft(64, '0');
    }

    setUp(() {
      mockNostrClient = _MockNostrClient();
      mockFollowRepository = _MockFollowRepository();
      eventStreamController = StreamController<nostr_sdk.Event>.broadcast();

      // Default stub for subscribe - returns empty stream
      when(
        () => mockNostrClient.subscribe(any()),
      ).thenAnswer((_) => eventStreamController.stream);

      // Default stub for isFollowing
      when(() => mockFollowRepository.isFollowing(any())).thenReturn(false);
    });

    tearDown(() {
      eventStreamController.close();
    });

    FollowersBloc createBloc() => FollowersBloc(
      followRepository: mockFollowRepository,
      nostrClient: mockNostrClient,
    );

    test('initial state is correct', () {
      final bloc = createBloc();
      expect(bloc.state, const FollowersState());
      bloc.close();
    });

    group('FollowersListLoadRequested', () {
      blocTest<FollowersBloc, FollowersState>(
        'emits [loading, success] when load completes with followers',
        setUp: () {
          final targetPubkey = validPubkey('target');
          final followerPubkey = validPubkey('follower1');

          // Create a stream that emits events then completes
          final controller = StreamController<nostr_sdk.Event>();
          when(
            () => mockNostrClient.subscribe(any()),
          ).thenAnswer((_) => controller.stream);

          // Schedule event emission and close
          Future.delayed(const Duration(milliseconds: 50), () {
            controller.add(
              nostr_sdk.Event(
                followerPubkey,
                3,
                [
                  ['p', targetPubkey],
                ],
                '',
                createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              ),
            );
            controller.close();
          });
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(FollowersListLoadRequested(validPubkey('target'))),
        wait: const Duration(milliseconds: 200),
        expect: () => [
          FollowersState(
            status: FollowersStatus.loading,
            targetPubkey: validPubkey('target'),
          ),
          FollowersState(
            status: FollowersStatus.success,
            targetPubkey: validPubkey('target'),
            followersPubkeys: [validPubkey('follower1')],
          ),
        ],
      );

      blocTest<FollowersBloc, FollowersState>(
        'emits [loading, success] with empty list when no followers',
        setUp: () {
          // Stream that immediately completes
          when(
            () => mockNostrClient.subscribe(any()),
          ).thenAnswer((_) => const Stream.empty());
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(FollowersListLoadRequested(validPubkey('target'))),
        wait: const Duration(milliseconds: 100),
        expect: () => [
          FollowersState(
            status: FollowersStatus.loading,
            targetPubkey: validPubkey('target'),
          ),
          FollowersState(
            status: FollowersStatus.success,
            targetPubkey: validPubkey('target'),
            followersPubkeys: const [],
          ),
        ],
      );

      blocTest<FollowersBloc, FollowersState>(
        'deduplicates followers when same pubkey appears multiple times',
        setUp: () {
          final targetPubkey = validPubkey('target');
          final followerPubkey = validPubkey('follower1');

          final controller = StreamController<nostr_sdk.Event>();
          when(
            () => mockNostrClient.subscribe(any()),
          ).thenAnswer((_) => controller.stream);

          // Emit same follower twice
          Future.delayed(const Duration(milliseconds: 50), () {
            controller.add(
              nostr_sdk.Event(
                followerPubkey,
                3,
                [
                  ['p', targetPubkey],
                ],
                '',
                createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              ),
            );
            controller.add(
              nostr_sdk.Event(
                followerPubkey, // Same pubkey
                3,
                [
                  ['p', targetPubkey],
                ],
                '',
                createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
              ),
            );
            controller.close();
          });
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(FollowersListLoadRequested(validPubkey('target'))),
        wait: const Duration(milliseconds: 200),
        expect: () => [
          FollowersState(
            status: FollowersStatus.loading,
            targetPubkey: validPubkey('target'),
          ),
          // Only one state with the follower (deduplicated)
          FollowersState(
            status: FollowersStatus.success,
            targetPubkey: validPubkey('target'),
            followersPubkeys: [validPubkey('follower1')],
          ),
        ],
      );

      blocTest<FollowersBloc, FollowersState>(
        'subscribes with correct filter (kind 3, p tag)',
        build: createBloc,
        act: (bloc) =>
            bloc.add(FollowersListLoadRequested(validPubkey('target'))),
        wait: const Duration(milliseconds: 100),
        verify: (_) {
          final captured = verify(
            () => mockNostrClient.subscribe(captureAny()),
          ).captured;
          expect(captured.length, 1);
          final filters = captured.first as List<Filter>;
          expect(filters.length, 1);
          expect(filters[0].kinds, contains(3));
          expect(filters[0].p, contains(validPubkey('target')));
        },
      );

      blocTest<FollowersBloc, FollowersState>(
        'clears previous followers when loading new list',
        setUp: () {
          when(
            () => mockNostrClient.subscribe(any()),
          ).thenAnswer((_) => const Stream.empty());
        },
        build: createBloc,
        seed: () => FollowersState(
          status: FollowersStatus.success,
          targetPubkey: validPubkey('old'),
          followersPubkeys: [validPubkey('old_follower')],
        ),
        act: (bloc) => bloc.add(FollowersListLoadRequested(validPubkey('new'))),
        wait: const Duration(milliseconds: 100),
        expect: () => [
          FollowersState(
            status: FollowersStatus.loading,
            targetPubkey: validPubkey('new'),
            followersPubkeys: const [], // Cleared
          ),
          FollowersState(
            status: FollowersStatus.success,
            targetPubkey: validPubkey('new'),
            followersPubkeys: const [],
          ),
        ],
      );
    });

    group('FollowerToggleFollowRequested', () {
      blocTest<FollowersBloc, FollowersState>(
        'calls follow when not currently following',
        setUp: () {
          when(() => mockFollowRepository.isFollowing(any())).thenReturn(false);
          when(
            () => mockFollowRepository.follow(any()),
          ).thenAnswer((_) async {});
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(FollowerToggleFollowRequested(validPubkey('user'))),
        wait: const Duration(milliseconds: 100),
        verify: (_) {
          verify(
            () => mockFollowRepository.follow(validPubkey('user')),
          ).called(1);
          verifyNever(() => mockFollowRepository.unfollow(any()));
        },
      );

      blocTest<FollowersBloc, FollowersState>(
        'calls unfollow when currently following',
        setUp: () {
          when(
            () => mockFollowRepository.isFollowing(validPubkey('user')),
          ).thenReturn(true);
          when(
            () => mockFollowRepository.unfollow(any()),
          ).thenAnswer((_) async {});
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(FollowerToggleFollowRequested(validPubkey('user'))),
        wait: const Duration(milliseconds: 100),
        verify: (_) {
          verify(
            () => mockFollowRepository.unfollow(validPubkey('user')),
          ).called(1);
          verifyNever(() => mockFollowRepository.follow(any()));
        },
      );

      blocTest<FollowersBloc, FollowersState>(
        'handles follow error gracefully',
        setUp: () {
          when(() => mockFollowRepository.isFollowing(any())).thenReturn(false);
          when(
            () => mockFollowRepository.follow(any()),
          ).thenThrow(Exception('Network error'));
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(FollowerToggleFollowRequested(validPubkey('user'))),
        wait: const Duration(milliseconds: 100),
        // Should not throw or emit error state - just logs
        expect: () => <FollowersState>[],
      );

      blocTest<FollowersBloc, FollowersState>(
        'handles unfollow error gracefully',
        setUp: () {
          when(() => mockFollowRepository.isFollowing(any())).thenReturn(true);
          when(
            () => mockFollowRepository.unfollow(any()),
          ).thenThrow(Exception('Network error'));
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(FollowerToggleFollowRequested(validPubkey('user'))),
        wait: const Duration(milliseconds: 100),
        // Should not throw or emit error state - just logs
        expect: () => <FollowersState>[],
      );
    });

    group('isFollowing', () {
      test('delegates to FollowRepository', () {
        when(
          () => mockFollowRepository.isFollowing(validPubkey('user')),
        ).thenReturn(true);
        when(
          () => mockFollowRepository.isFollowing(validPubkey('other')),
        ).thenReturn(false);

        final bloc = createBloc();

        expect(bloc.isFollowing(validPubkey('user')), isTrue);
        expect(bloc.isFollowing(validPubkey('other')), isFalse);

        verify(
          () => mockFollowRepository.isFollowing(validPubkey('user')),
        ).called(1);
        verify(
          () => mockFollowRepository.isFollowing(validPubkey('other')),
        ).called(1);

        bloc.close();
      });
    });

    group('close', () {
      test('cancels nostr subscription', () async {
        final controller = StreamController<nostr_sdk.Event>();
        when(
          () => mockNostrClient.subscribe(any()),
        ).thenAnswer((_) => controller.stream);

        final bloc = createBloc();
        bloc.add(FollowersListLoadRequested(validPubkey('target')));
        await Future<void>.delayed(const Duration(milliseconds: 50));

        await bloc.close();

        // Stream should be closable without errors
        await controller.close();
      });
    });
  });

  group('FollowersState', () {
    test('supports value equality', () {
      const state1 = FollowersState(
        status: FollowersStatus.success,
        followersPubkeys: ['pubkey1'],
        targetPubkey: 'target',
      );
      const state2 = FollowersState(
        status: FollowersStatus.success,
        followersPubkeys: ['pubkey1'],
        targetPubkey: 'target',
      );

      expect(state1, equals(state2));
    });

    test('copyWith creates copy with updated values', () {
      const state = FollowersState(
        status: FollowersStatus.initial,
        followersPubkeys: [],
        targetPubkey: 'target1',
      );

      final updated = state.copyWith(
        status: FollowersStatus.loading,
        followersPubkeys: ['pubkey1'],
        targetPubkey: 'target2',
      );

      expect(updated.status, FollowersStatus.loading);
      expect(updated.followersPubkeys, ['pubkey1']);
      expect(updated.targetPubkey, 'target2');
    });

    test('copyWith preserves values when not specified', () {
      const state = FollowersState(
        status: FollowersStatus.success,
        followersPubkeys: ['pubkey1'],
        targetPubkey: 'target',
      );

      final updated = state.copyWith();

      expect(updated.status, FollowersStatus.success);
      expect(updated.followersPubkeys, ['pubkey1']);
      expect(updated.targetPubkey, 'target');
    });

    test('props includes all fields', () {
      const state = FollowersState(
        status: FollowersStatus.success,
        followersPubkeys: ['pubkey1'],
        targetPubkey: 'target',
      );

      expect(state.props, [
        FollowersStatus.success,
        ['pubkey1'],
        'target',
      ]);
    });
  });
}
