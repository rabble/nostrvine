// ABOUTME: Tests for MyFollowingBloc - current user's following list
// ABOUTME: Tests CacheSync stream, toggle operations, and blocklist filtering

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

void main() {
  group(MyFollowingBloc, () {
    late _MockFollowRepository mockFollowRepository;
    late _MockContentBlocklistRepository mockBlocklistRepository;

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
      when(() => mockFollowRepository.followingPubkeys).thenReturn(const []);
      when(
        () => mockFollowRepository.followingStream,
      ).thenAnswer((_) => const Stream<List<String>>.empty());
    });

    MyFollowingBloc createBloc() => MyFollowingBloc(
      followRepository: mockFollowRepository,
      contentBlocklistRepository: mockBlocklistRepository,
    );

    test('initial state is initial when repository cache is empty', () {
      final bloc = createBloc();
      expect(bloc.state, const MyFollowingState());
      bloc.close();
    });

    test('initial state is seeded from repository cache when available', () {
      when(
        () => mockFollowRepository.followingPubkeys,
      ).thenReturn([validPubkey('cached')]);

      final bloc = createBloc();
      expect(
        bloc.state,
        MyFollowingState(
          status: MyFollowingStatus.success,
          rawFollowingPubkeys: [validPubkey('cached')],
          followingPubkeys: [validPubkey('cached')],
        ),
      );
      bloc.close();
    });

    group('MyFollowingListLoadRequested', () {
      blocTest<MyFollowingBloc, MyFollowingState>(
        'emits success with pubkeys from stream',
        setUp: () {
          when(() => mockFollowRepository.watchMyFollowingCached()).thenAnswer(
            (_) => Stream.value(
              CacheResult.live(
                FollowingSnapshot(
                  pubkeys: [
                    validPubkey('following1'),
                    validPubkey('following2'),
                  ],
                  count: 2,
                ),
              ),
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyFollowingListLoadRequested()),
        verify: (bloc) {
          expect(bloc.state.status, MyFollowingStatus.success);
          expect(bloc.state.followingPubkeys, [
            validPubkey('following1'),
            validPubkey('following2'),
          ]);
        },
      );

      blocTest<MyFollowingBloc, MyFollowingState>(
        'emits isRefreshing=false after fresh data (no cache)',
        setUp: () {
          when(() => mockFollowRepository.watchMyFollowingCached()).thenAnswer(
            (_) => Stream.value(
              CacheResult.live(
                FollowingSnapshot(
                  pubkeys: [validPubkey('following1')],
                  count: 1,
                ),
              ),
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyFollowingListLoadRequested()),
        verify: (bloc) {
          expect(bloc.state.isRefreshing, isFalse);
        },
      );

      blocTest<MyFollowingBloc, MyFollowingState>(
        'emits success with empty list when following is empty',
        setUp: () {
          when(() => mockFollowRepository.watchMyFollowingCached()).thenAnswer(
            (_) => Stream.value(
              const CacheResult.live(
                FollowingSnapshot(pubkeys: <String>[], count: 0),
              ),
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyFollowingListLoadRequested()),
        verify: (bloc) {
          expect(bloc.state.status, MyFollowingStatus.success);
          expect(bloc.state.followingPubkeys, isEmpty);
        },
      );

      blocTest<MyFollowingBloc, MyFollowingState>(
        'emits failure when stream errors before any visible data exists',
        setUp: () {
          when(
            () => mockFollowRepository.followingPubkeys,
          ).thenReturn(const []);
          when(() => mockFollowRepository.watchMyFollowingCached()).thenAnswer(
            (_) => Stream<CacheResult<FollowingSnapshot>>.error(
              Exception('Network error'),
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyFollowingListLoadRequested()),
        verify: (bloc) {
          expect(bloc.state.status, MyFollowingStatus.failure);
          expect(bloc.state.isRefreshing, isFalse);
        },
        errors: () => [isA<Exception>()],
      );

      blocTest<MyFollowingBloc, MyFollowingState>(
        'keeps visible data when cached refresh errors',
        setUp: () {
          when(() => mockFollowRepository.watchMyFollowingCached()).thenAnswer((
            _,
          ) async* {
            yield CacheResult.cached(
              FollowingSnapshot(pubkeys: [validPubkey('cached')], count: 1),
            );
            throw Exception('Network error');
          });
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyFollowingListLoadRequested()),
        verify: (bloc) {
          expect(bloc.state.status, MyFollowingStatus.success);
          expect(bloc.state.followingPubkeys, [validPubkey('cached')]);
          expect(bloc.state.isRefreshing, isFalse);
        },
        errors: () => [isA<Exception>()],
      );

      blocTest<MyFollowingBloc, MyFollowingState>(
        'emits multiple states as stream yields multiple values',
        setUp: () {
          when(() => mockFollowRepository.watchMyFollowingCached()).thenAnswer(
            (_) => Stream.fromIterable([
              CacheResult.live(
                FollowingSnapshot(pubkeys: [validPubkey('old')], count: 1),
              ),
              CacheResult.live(
                FollowingSnapshot(
                  pubkeys: [
                    validPubkey('following1'),
                    validPubkey('following2'),
                  ],
                  count: 2,
                ),
              ),
            ]),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyFollowingListLoadRequested()),
        verify: (bloc) {
          expect(bloc.state.status, MyFollowingStatus.success);
          expect(bloc.state.followingPubkeys, [
            validPubkey('following1'),
            validPubkey('following2'),
          ]);
        },
      );
    });

    group('MyFollowingToggleRequested', () {
      blocTest<MyFollowingBloc, MyFollowingState>(
        'calls toggleFollow on repository',
        setUp: () {
          when(
            () => mockFollowRepository.toggleFollow(any()),
          ).thenAnswer((_) async {});
          when(
            () => mockFollowRepository.watchMyFollowingCached(),
          ).thenAnswer((_) => const Stream.empty());
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
        're-dispatches load after successful toggle so cache layer '
        're-observes new follow set',
        setUp: () {
          when(
            () => mockFollowRepository.toggleFollow(any()),
          ).thenAnswer((_) async {});
          when(() => mockFollowRepository.watchMyFollowingCached()).thenAnswer(
            (_) => Stream.value(
              CacheResult.live(
                FollowingSnapshot(pubkeys: [validPubkey('user')], count: 1),
              ),
            ),
          );
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(MyFollowingToggleRequested(validPubkey('user'))),
        verify: (_) {
          // Toggle issues the relay write and the BLoC re-fetches via
          // watchMyFollowingCached so the disk cache layer + UI both
          // observe the new state (replaces the old BehaviorSubject-replay
          // reactivity that broke the stale/live contract).
          verify(() => mockFollowRepository.toggleFollow(any())).called(1);
          verify(() => mockFollowRepository.watchMyFollowingCached()).called(1);
        },
      );

      blocTest<MyFollowingBloc, MyFollowingState>(
        'emits toggleFailure when toggleFollow throws',
        setUp: () {
          when(
            () => mockFollowRepository.toggleFollow(any()),
          ).thenThrow(Exception('Network error'));
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(MyFollowingToggleRequested(validPubkey('user'))),
        verify: (bloc) {
          expect(bloc.state.status, MyFollowingStatus.toggleFailure);
        },
      );

      blocTest<MyFollowingBloc, MyFollowingState>(
        'uses droppable transformer — second rapid toggle is dropped',
        setUp: () {
          var callCount = 0;
          when(() => mockFollowRepository.toggleFollow(any())).thenAnswer((
            _,
          ) async {
            callCount++;
            if (callCount == 1) {
              await Future<void>.delayed(const Duration(milliseconds: 50));
            }
          });
          when(
            () => mockFollowRepository.watchMyFollowingCached(),
          ).thenAnswer((_) => const Stream.empty());
        },
        build: createBloc,
        act: (bloc) async {
          bloc
            ..add(MyFollowingToggleRequested(validPubkey('user')))
            ..add(MyFollowingToggleRequested(validPubkey('user')));
          await Future<void>.delayed(const Duration(milliseconds: 100));
        },
        verify: (_) {
          verify(
            () => mockFollowRepository.toggleFollow(validPubkey('user')),
          ).called(1);
        },
      );
    });

    test('applies live repository updates after initial load', () async {
      final controller = StreamController<List<String>>.broadcast();
      when(
        () => mockFollowRepository.followingStream,
      ).thenAnswer((_) => controller.stream);
      when(
        () => mockFollowRepository.watchMyFollowingCached(),
      ).thenAnswer((_) => const Stream.empty());

      final bloc = createBloc();
      bloc.add(const MyFollowingListLoadRequested());
      await Future<void>.delayed(Duration.zero);

      controller.add([validPubkey('live1'), validPubkey('live2')]);
      await Future<void>.delayed(Duration.zero);

      expect(bloc.state.status, MyFollowingStatus.success);
      expect(bloc.state.followingPubkeys, [
        validPubkey('live1'),
        validPubkey('live2'),
      ]);

      await bloc.close();
      await controller.close();
    });

    group('blocklist filtering', () {
      blocTest<MyFollowingBloc, MyFollowingState>(
        'filters blocked users from following list',
        setUp: () {
          when(
            () => mockBlocklistRepository.isBlocked(validPubkey('blocked')),
          ).thenReturn(true);
          when(() => mockFollowRepository.watchMyFollowingCached()).thenAnswer(
            (_) => Stream.value(
              CacheResult.live(
                FollowingSnapshot(
                  pubkeys: [
                    validPubkey('following1'),
                    validPubkey('blocked'),
                    validPubkey('following2'),
                  ],
                  count: 3,
                ),
              ),
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const MyFollowingListLoadRequested()),
        verify: (bloc) {
          expect(
            bloc.state.followingPubkeys,
            containsAll([validPubkey('following1'), validPubkey('following2')]),
          );
          expect(
            bloc.state.followingPubkeys,
            isNot(contains(validPubkey('blocked'))),
          );
        },
      );

      blocTest<MyFollowingBloc, MyFollowingState>(
        'MyFollowingBlocklistChanged re-filters cached pubkeys',
        setUp: () {
          when(() => mockFollowRepository.watchMyFollowingCached()).thenAnswer(
            (_) => Stream.value(
              CacheResult.live(
                FollowingSnapshot(
                  pubkeys: [validPubkey('following1'), validPubkey('toBlock')],
                  count: 2,
                ),
              ),
            ),
          );
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const MyFollowingListLoadRequested());
          await Future<void>.delayed(Duration.zero);
          when(
            () => mockBlocklistRepository.isBlocked(validPubkey('toBlock')),
          ).thenReturn(true);
          bloc.add(const MyFollowingBlocklistChanged());
        },
        verify: (bloc) {
          expect(
            bloc.state.followingPubkeys,
            isNot(contains(validPubkey('toBlock'))),
          );
          expect(
            bloc.state.followingPubkeys,
            contains(validPubkey('following1')),
          );
        },
      );
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

      test('isFollowing returns true when pubkey is in list', () {
        const state = MyFollowingState(
          status: MyFollowingStatus.success,
          followingPubkeys: ['pubkey1', 'pubkey2'],
        );

        expect(state.isFollowing('pubkey1'), isTrue);
        expect(state.isFollowing('pubkey2'), isTrue);
        expect(state.isFollowing('pubkey3'), isFalse);
      });

      test('isRefreshing included in equality check', () {
        const state1 = MyFollowingState(isRefreshing: true);
        const state2 = MyFollowingState();

        expect(state1, isNot(equals(state2)));
      });

      test('copyWith preserves values when not specified', () {
        const state = MyFollowingState(
          status: MyFollowingStatus.success,
          followingPubkeys: ['pubkey1'],
          isRefreshing: true,
        );

        final updated = state.copyWith();

        expect(updated.status, MyFollowingStatus.success);
        expect(updated.followingPubkeys, ['pubkey1']);
        expect(updated.isRefreshing, isTrue);
      });
    });
  });
}
