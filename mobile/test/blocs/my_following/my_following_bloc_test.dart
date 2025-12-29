// ABOUTME: Tests for MyFollowingBloc - current user's following list
// ABOUTME: Tests reactive updates via repository stream and toggle operations

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';
import 'package:openvine/repositories/follow_repository.dart';

class _MockFollowRepository extends Mock implements FollowRepository {}

void main() {
  group('MyFollowingBloc', () {
    late _MockFollowRepository mockFollowRepository;
    late StreamController<List<String>> followingStreamController;

    // Helper to create valid hex pubkeys (64 hex characters)
    String validPubkey(String suffix) {
      final hexSuffix = suffix.codeUnits
          .map((c) => c.toRadixString(16).padLeft(2, '0'))
          .join();
      return hexSuffix.padLeft(64, '0');
    }

    setUp(() {
      mockFollowRepository = _MockFollowRepository();
      followingStreamController = StreamController<List<String>>.broadcast();

      when(
        () => mockFollowRepository.followingStream,
      ).thenAnswer((_) => followingStreamController.stream);
      when(() => mockFollowRepository.followingPubkeys).thenReturn([]);
    });

    tearDown(() {
      followingStreamController.close();
    });

    MyFollowingBloc createBloc() =>
        MyFollowingBloc(followRepository: mockFollowRepository);

    test('initial state is success with cached data', () {
      when(
        () => mockFollowRepository.followingPubkeys,
      ).thenReturn([validPubkey('following1')]);

      final bloc = createBloc();
      expect(
        bloc.state,
        MyFollowingState(
          status: MyFollowingStatus.success,
          followingPubkeys: [validPubkey('following1')],
        ),
      );
      bloc.close();
    });

    test('initial state is success with empty list when no cached data', () {
      when(() => mockFollowRepository.followingPubkeys).thenReturn([]);

      final bloc = createBloc();
      expect(
        bloc.state,
        const MyFollowingState(
          status: MyFollowingStatus.success,
          followingPubkeys: [],
        ),
      );
      bloc.close();
    });

    group('MyFollowingListLoadRequested', () {
      blocTest<MyFollowingBloc, MyFollowingState>(
        'listens to repository stream for updates',
        setUp: () {
          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn([validPubkey('following1')]);
          when(() => mockFollowRepository.followingStream).thenAnswer(
            (_) => Stream.value([
              validPubkey('following1'),
              validPubkey('following2'),
            ]),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyFollowingListLoadRequested()),
        expect: () => [
          MyFollowingState(
            status: MyFollowingStatus.success,
            followingPubkeys: [
              validPubkey('following1'),
              validPubkey('following2'),
            ],
          ),
        ],
      );

      blocTest<MyFollowingBloc, MyFollowingState>(
        'updates state when stream emits new values',
        setUp: () {
          when(() => mockFollowRepository.followingPubkeys).thenReturn([]);
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const MyFollowingListLoadRequested());
          await Future<void>.delayed(const Duration(milliseconds: 10));
          followingStreamController.add([validPubkey('user1')]);
          await Future<void>.delayed(const Duration(milliseconds: 10));
          followingStreamController.add([
            validPubkey('user1'),
            validPubkey('user2'),
          ]);
        },
        expect: () => [
          MyFollowingState(
            status: MyFollowingStatus.success,
            followingPubkeys: [validPubkey('user1')],
          ),
          MyFollowingState(
            status: MyFollowingStatus.success,
            followingPubkeys: [validPubkey('user1'), validPubkey('user2')],
          ),
        ],
      );
    });

    group('MyFollowingToggleRequested', () {
      blocTest<MyFollowingBloc, MyFollowingState>(
        'calls toggleFollow on repository',
        setUp: () {
          when(
            () => mockFollowRepository.toggleFollow(any()),
          ).thenAnswer((_) async {});
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(MyFollowingToggleRequested(validPubkey('user'))),
        verify: (_) {
          verify(
            () => mockFollowRepository.toggleFollow(validPubkey('user')),
          ).called(1);
        },
      );

      blocTest<MyFollowingBloc, MyFollowingState>(
        'handles toggleFollow error gracefully',
        setUp: () {
          when(
            () => mockFollowRepository.toggleFollow(any()),
          ).thenThrow(Exception('Network error'));
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(MyFollowingToggleRequested(validPubkey('user'))),
        // Should not throw or emit error state - just logs
        expect: () => <MyFollowingState>[],
      );
    });
  });

  group('MyFollowingState', () {
    test('supports value equality', () {
      const state1 = MyFollowingState(
        status: MyFollowingStatus.success,
        followingPubkeys: ['pubkey1'],
      );
      const state2 = MyFollowingState(
        status: MyFollowingStatus.success,
        followingPubkeys: ['pubkey1'],
      );

      expect(state1, equals(state2));
    });

    test('isFollowing returns true when pubkey in list', () {
      const state = MyFollowingState(
        status: MyFollowingStatus.success,
        followingPubkeys: ['pubkey1', 'pubkey2'],
      );

      expect(state.isFollowing('pubkey1'), isTrue);
      expect(state.isFollowing('pubkey2'), isTrue);
      expect(state.isFollowing('pubkey3'), isFalse);
    });

    test('copyWith creates copy with updated values', () {
      const state = MyFollowingState(
        status: MyFollowingStatus.initial,
        followingPubkeys: [],
      );

      final updated = state.copyWith(
        status: MyFollowingStatus.success,
        followingPubkeys: ['pubkey1'],
      );

      expect(updated.status, MyFollowingStatus.success);
      expect(updated.followingPubkeys, ['pubkey1']);
    });

    test('copyWith preserves values when not specified', () {
      const state = MyFollowingState(
        status: MyFollowingStatus.success,
        followingPubkeys: ['pubkey1'],
      );

      final updated = state.copyWith();

      expect(updated.status, MyFollowingStatus.success);
      expect(updated.followingPubkeys, ['pubkey1']);
    });

    test('props includes all fields', () {
      const state = MyFollowingState(
        status: MyFollowingStatus.success,
        followingPubkeys: ['pubkey1'],
      );

      expect(state.props, [
        MyFollowingStatus.success,
        ['pubkey1'],
      ]);
    });
  });
}
