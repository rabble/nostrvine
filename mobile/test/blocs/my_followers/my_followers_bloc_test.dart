// ABOUTME: Tests for MyFollowersBloc - current user's followers list
// ABOUTME: Tests loading from repository and follow-back operations

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/my_followers/my_followers_bloc.dart';
import 'package:openvine/repositories/follow_repository.dart';

class _MockFollowRepository extends Mock implements FollowRepository {}

void main() {
  group('MyFollowersBloc', () {
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

    MyFollowersBloc createBloc() =>
        MyFollowersBloc(followRepository: mockFollowRepository);

    test('initial state is initial with empty list', () {
      final bloc = createBloc();
      expect(
        bloc.state,
        const MyFollowersState(
          status: MyFollowersStatus.initial,
          followersPubkeys: [],
        ),
      );
      bloc.close();
    });

    group('MyFollowersListLoadRequested', () {
      blocTest<MyFollowersBloc, MyFollowersState>(
        'emits [loading, success] with followers from repository',
        setUp: () {
          when(() => mockFollowRepository.getMyFollowers()).thenAnswer(
            (_) async => [validPubkey('follower1'), validPubkey('follower2')],
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyFollowersListLoadRequested()),
        expect: () => [
          const MyFollowersState(status: MyFollowersStatus.loading),
          MyFollowersState(
            status: MyFollowersStatus.success,
            followersPubkeys: [
              validPubkey('follower1'),
              validPubkey('follower2'),
            ],
          ),
        ],
      );

      blocTest<MyFollowersBloc, MyFollowersState>(
        'emits [loading, success] with empty list when no followers',
        setUp: () {
          when(
            () => mockFollowRepository.getMyFollowers(),
          ).thenAnswer((_) async => []);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyFollowersListLoadRequested()),
        expect: () => [
          const MyFollowersState(status: MyFollowersStatus.loading),
          const MyFollowersState(
            status: MyFollowersStatus.success,
            followersPubkeys: [],
          ),
        ],
      );

      blocTest<MyFollowersBloc, MyFollowersState>(
        'emits [loading, failure] when repository throws',
        setUp: () {
          when(
            () => mockFollowRepository.getMyFollowers(),
          ).thenThrow(Exception('Network error'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyFollowersListLoadRequested()),
        expect: () => [
          const MyFollowersState(status: MyFollowersStatus.loading),
          const MyFollowersState(status: MyFollowersStatus.failure),
        ],
      );
    });

    group('MyFollowersToggleFollowRequested', () {
      blocTest<MyFollowersBloc, MyFollowersState>(
        'calls toggleFollow on repository',
        setUp: () {
          when(
            () => mockFollowRepository.toggleFollow(any()),
          ).thenAnswer((_) async {});
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(MyFollowersToggleFollowRequested(validPubkey('follower'))),
        verify: (_) {
          verify(
            () => mockFollowRepository.toggleFollow(validPubkey('follower')),
          ).called(1);
        },
      );

      blocTest<MyFollowersBloc, MyFollowersState>(
        'handles toggleFollow error gracefully',
        setUp: () {
          when(
            () => mockFollowRepository.toggleFollow(any()),
          ).thenThrow(Exception('Network error'));
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(MyFollowersToggleFollowRequested(validPubkey('follower'))),
        // Should not throw or emit error state - just logs
        expect: () => <MyFollowersState>[],
      );
    });
  });

  group('MyFollowersState', () {
    test('supports value equality', () {
      const state1 = MyFollowersState(
        status: MyFollowersStatus.success,
        followersPubkeys: ['pubkey1'],
      );
      const state2 = MyFollowersState(
        status: MyFollowersStatus.success,
        followersPubkeys: ['pubkey1'],
      );

      expect(state1, equals(state2));
    });

    test('copyWith creates copy with updated values', () {
      const state = MyFollowersState(
        status: MyFollowersStatus.initial,
        followersPubkeys: [],
      );

      final updated = state.copyWith(
        status: MyFollowersStatus.success,
        followersPubkeys: ['pubkey1'],
      );

      expect(updated.status, MyFollowersStatus.success);
      expect(updated.followersPubkeys, ['pubkey1']);
    });

    test('copyWith preserves values when not specified', () {
      const state = MyFollowersState(
        status: MyFollowersStatus.success,
        followersPubkeys: ['pubkey1'],
      );

      final updated = state.copyWith();

      expect(updated.status, MyFollowersStatus.success);
      expect(updated.followersPubkeys, ['pubkey1']);
    });

    test('props includes all fields', () {
      const state = MyFollowersState(
        status: MyFollowersStatus.success,
        followersPubkeys: ['pubkey1'],
      );

      expect(state.props, [
        MyFollowersStatus.success,
        ['pubkey1'],
      ]);
    });
  });
}
