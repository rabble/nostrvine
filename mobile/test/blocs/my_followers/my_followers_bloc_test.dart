// ABOUTME: Tests for MyFollowersBloc - current user's followers list
// ABOUTME: Tests loading from repository stream and blocklist filtering

import 'package:bloc_test/bloc_test.dart';
import 'package:content_blocklist_service/content_blocklist_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/my_followers/my_followers_bloc.dart';

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockContentBlocklistService extends Mock
    implements ContentBlocklistService {}

void main() {
  group(MyFollowersBloc, () {
    late _MockFollowRepository mockFollowRepository;
    late _MockContentBlocklistService mockBlocklistService;

    // Helper to create valid hex pubkeys (64 hex characters)
    String validPubkey(String suffix) {
      final hexSuffix = suffix.codeUnits
          .map((c) => c.toRadixString(16).padLeft(2, '0'))
          .join();
      return hexSuffix.padLeft(64, '0');
    }

    setUp(() {
      mockFollowRepository = _MockFollowRepository();
      mockBlocklistService = _MockContentBlocklistService();

      // Default: nothing is blocked
      when(() => mockBlocklistService.isBlocked(any())).thenReturn(false);
      when(
        () => mockBlocklistService.isFollowSevered(any()),
      ).thenReturn(false);
    });

    MyFollowersBloc createBloc() => MyFollowersBloc(
      followRepository: mockFollowRepository,
      contentBlocklistService: mockBlocklistService,
    );

    test('initial state is initial with empty list', () {
      final bloc = createBloc();
      expect(bloc.state, const MyFollowersState());
      bloc.close();
    });

    group('MyFollowersListLoadRequested', () {
      blocTest<MyFollowersBloc, MyFollowersState>(
        'emits [loading, success] when no cache exists',
        setUp: () {
          when(() => mockFollowRepository.watchMyFollowers()).thenAnswer(
            (_) => Stream.value(
              (
                pubkeys: [
                  validPubkey('follower1'),
                  validPubkey('follower2'),
                ],
                count: 2,
              ),
            ),
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
            followerCount: 2,
          ),
        ],
      );

      blocTest<MyFollowersBloc, MyFollowersState>(
        'emits [loading, cached, fresh] when cache yields then fresh data',
        setUp: () {
          when(() => mockFollowRepository.watchMyFollowers()).thenAnswer(
            (_) => Stream.fromIterable([
              (pubkeys: [validPubkey('old')], count: 1),
              (
                pubkeys: [
                  validPubkey('follower1'),
                  validPubkey('follower2'),
                ],
                count: 2,
              ),
            ]),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyFollowersListLoadRequested()),
        expect: () => [
          const MyFollowersState(status: MyFollowersStatus.loading),
          MyFollowersState(
            status: MyFollowersStatus.success,
            followersPubkeys: [validPubkey('old')],
            followerCount: 1,
          ),
          MyFollowersState(
            status: MyFollowersStatus.success,
            followersPubkeys: [
              validPubkey('follower1'),
              validPubkey('follower2'),
            ],
            followerCount: 2,
          ),
        ],
      );

      blocTest<MyFollowersBloc, MyFollowersState>(
        'uses higher count from service when list is incomplete',
        setUp: () {
          when(() => mockFollowRepository.watchMyFollowers()).thenAnswer(
            (_) => Stream.value(
              (pubkeys: [validPubkey('follower1')], count: 500),
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyFollowersListLoadRequested()),
        expect: () => [
          const MyFollowersState(status: MyFollowersStatus.loading),
          MyFollowersState(
            status: MyFollowersStatus.success,
            followersPubkeys: [validPubkey('follower1')],
            followerCount: 500,
          ),
        ],
      );

      blocTest<MyFollowersBloc, MyFollowersState>(
        'emits [loading, success] with empty list when no followers',
        setUp: () {
          when(() => mockFollowRepository.watchMyFollowers()).thenAnswer(
            (_) => Stream.value((pubkeys: <String>[], count: 0)),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyFollowersListLoadRequested()),
        expect: () => [
          const MyFollowersState(status: MyFollowersStatus.loading),
          const MyFollowersState(status: MyFollowersStatus.success),
        ],
      );

      blocTest<MyFollowersBloc, MyFollowersState>(
        'emits [loading, failure] when stream throws and no data',
        setUp: () {
          when(() => mockFollowRepository.watchMyFollowers()).thenAnswer(
            (_) => Stream.error(Exception('Network error')),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyFollowersListLoadRequested()),
        expect: () => [
          const MyFollowersState(status: MyFollowersStatus.loading),
          const MyFollowersState(status: MyFollowersStatus.failure),
        ],
      );

      blocTest<MyFollowersBloc, MyFollowersState>(
        'keeps cached data when stream errors after first yield',
        setUp: () {
          when(() => mockFollowRepository.watchMyFollowers()).thenAnswer(
            (_) async* {
              yield (pubkeys: [validPubkey('cached')], count: 1);
              throw Exception('Network error');
            },
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyFollowersListLoadRequested()),
        expect: () => [
          const MyFollowersState(status: MyFollowersStatus.loading),
          MyFollowersState(
            status: MyFollowersStatus.success,
            followersPubkeys: [validPubkey('cached')],
            followerCount: 1,
          ),
        ],
      );

      blocTest<MyFollowersBloc, MyFollowersState>(
        'filters blocked users from stream results',
        setUp: () {
          final blocked = validPubkey('blocked');
          when(() => mockBlocklistService.isBlocked(blocked)).thenReturn(true);

          when(() => mockFollowRepository.watchMyFollowers()).thenAnswer(
            (_) => Stream.value(
              (pubkeys: [blocked, validPubkey('ok')], count: 2),
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyFollowersListLoadRequested()),
        expect: () => [
          const MyFollowersState(status: MyFollowersStatus.loading),
          MyFollowersState(
            status: MyFollowersStatus.success,
            followersPubkeys: [validPubkey('ok')],
            followerCount: 2,
          ),
        ],
      );
    });

    group('MyFollowersBlocklistChanged', () {
      blocTest<MyFollowersBloc, MyFollowersState>(
        're-filters followers when blocklist changes',
        setUp: () {
          when(() => mockFollowRepository.watchMyFollowers()).thenAnswer(
            (_) => Stream.value(
              (
                pubkeys: [validPubkey('a'), validPubkey('b')],
                count: 2,
              ),
            ),
          );
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const MyFollowersListLoadRequested());
          await Future<void>.delayed(Duration.zero);
          // Now block user 'a'
          when(
            () => mockBlocklistService.isBlocked(validPubkey('a')),
          ).thenReturn(true);
          bloc.add(const MyFollowersBlocklistChanged());
        },
        skip: 2, // skip loading + initial success
        expect: () => [
          MyFollowersState(
            status: MyFollowersStatus.success,
            followersPubkeys: [validPubkey('b')],
            followerCount: 2,
          ),
        ],
      );

      blocTest<MyFollowersBloc, MyFollowersState>(
        'does nothing when not in success state',
        build: createBloc,
        act: (bloc) => bloc.add(const MyFollowersBlocklistChanged()),
        expect: () => <MyFollowersState>[],
      );
    });
  });

  group(MyFollowersState, () {
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
      const state = MyFollowersState();

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
        followerCount: 10,
      );

      expect(state.props, [
        MyFollowersStatus.success,
        ['pubkey1'],
        10,
      ]);
    });
  });
}
