// ABOUTME: Tests for ProfileLikedVideosBloc - syncing and fetching liked videos
// ABOUTME: Tests syncing from repository, loading from cache, and state management

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/blocs/profile_liked_videos/profile_liked_videos_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/services/video_event_service.dart';

class _MockLikesRepository extends Mock implements LikesRepository {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockNostrClient extends Mock implements NostrClient {}

class _FakeFilter extends Fake implements Filter {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeFilter());
    registerFallbackValue(<Filter>[]);
  });

  group('ProfileLikedVideosBloc', () {
    late _MockLikesRepository mockLikesRepository;
    late _MockVideoEventService mockVideoEventService;
    late _MockNostrClient mockNostrClient;
    late StreamController<Set<String>> likedIdsController;

    setUp(() {
      mockLikesRepository = _MockLikesRepository();
      mockVideoEventService = _MockVideoEventService();
      mockNostrClient = _MockNostrClient();
      likedIdsController = StreamController<Set<String>>.broadcast();

      // Default stub for watchLikedEventIds
      when(
        () => mockLikesRepository.watchLikedEventIds(),
      ).thenAnswer((_) => likedIdsController.stream);
    });

    tearDown(() {
      likedIdsController.close();
    });

    ProfileLikedVideosBloc createBloc() => ProfileLikedVideosBloc(
      likesRepository: mockLikesRepository,
      videoEventService: mockVideoEventService,
      nostrClient: mockNostrClient,
    );

    VideoEvent createTestVideo(String id) {
      // Create a minimal VideoEvent for testing
      final now = DateTime.now();
      return VideoEvent(
        id: id,
        pubkey: '0' * 64,
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        content: '',
        timestamp: now,
        title: 'Test Video $id',
        videoUrl: 'https://example.com/video.mp4',
        thumbnailUrl: 'https://example.com/thumb.jpg',
      );
    }

    test('initial state is initial with empty collections', () {
      final bloc = createBloc();
      expect(bloc.state.status, ProfileLikedVideosStatus.initial);
      expect(bloc.state.videos, isEmpty);
      expect(bloc.state.likedEventIds, isEmpty);
      expect(bloc.state.error, isNull);
      bloc.close();
    });

    group('ProfileLikedVideosState', () {
      test('isLoaded returns true when status is success', () {
        const initialState = ProfileLikedVideosState();
        const successState = ProfileLikedVideosState(
          status: ProfileLikedVideosStatus.success,
        );

        expect(initialState.isLoaded, isFalse);
        expect(successState.isLoaded, isTrue);
      });

      test('isLoading returns true when status is loading or syncing', () {
        const initialState = ProfileLikedVideosState();
        const loadingState = ProfileLikedVideosState(
          status: ProfileLikedVideosStatus.loading,
        );
        const syncingState = ProfileLikedVideosState(
          status: ProfileLikedVideosStatus.syncing,
        );

        expect(initialState.isLoading, isFalse);
        expect(loadingState.isLoading, isTrue);
        expect(syncingState.isLoading, isTrue);
      });

      test('copyWith creates copy with updated values', () {
        const state = ProfileLikedVideosState();

        final updated = state.copyWith(
          status: ProfileLikedVideosStatus.success,
          likedEventIds: ['event1'],
        );

        expect(updated.status, ProfileLikedVideosStatus.success);
        expect(updated.likedEventIds, ['event1']);
      });

      test('copyWith preserves values when not specified', () {
        const state = ProfileLikedVideosState(
          status: ProfileLikedVideosStatus.success,
          likedEventIds: ['event1'],
        );

        final updated = state.copyWith();

        expect(updated.status, ProfileLikedVideosStatus.success);
        expect(updated.likedEventIds, ['event1']);
      });

      test('copyWith clearError removes error', () {
        const state = ProfileLikedVideosState(
          error: ProfileLikedVideosError.loadFailed,
        );

        final updated = state.copyWith(clearError: true);

        expect(updated.error, isNull);
      });
    });

    group('ProfileLikedVideosSyncRequested', () {
      blocTest<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        'emits [syncing, success] with empty videos when no liked IDs',
        setUp: () {
          when(
            () => mockLikesRepository.syncUserReactions(),
          ).thenAnswer((_) async => const LikesSyncResult.empty());
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ProfileLikedVideosSyncRequested()),
        expect: () => [
          const ProfileLikedVideosState(
            status: ProfileLikedVideosStatus.syncing,
          ),
          const ProfileLikedVideosState(
            status: ProfileLikedVideosStatus.success,
            videos: [],
            likedEventIds: [],
            hasMoreContent: false,
          ),
        ],
      );

      blocTest<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        'emits [syncing, loading, success] when videos found in cache',
        setUp: () {
          final video1 = createTestVideo('event1');
          final video2 = createTestVideo('event2');

          when(() => mockLikesRepository.syncUserReactions()).thenAnswer(
            (_) async => const LikesSyncResult(
              orderedEventIds: ['event1', 'event2'],
              eventIdToReactionId: {
                'event1': 'reaction1',
                'event2': 'reaction2',
              },
            ),
          );
          when(
            () => mockVideoEventService.getVideoById('event1'),
          ).thenReturn(video1);
          when(
            () => mockVideoEventService.getVideoById('event2'),
          ).thenReturn(video2);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ProfileLikedVideosSyncRequested()),
        expect: () => [
          const ProfileLikedVideosState(
            status: ProfileLikedVideosStatus.syncing,
          ),
          isA<ProfileLikedVideosState>()
              .having(
                (s) => s.status,
                'status',
                ProfileLikedVideosStatus.loading,
              )
              .having((s) => s.likedEventIds, 'likedEventIds', [
                'event1',
                'event2',
              ]),
          isA<ProfileLikedVideosState>()
              .having(
                (s) => s.status,
                'status',
                ProfileLikedVideosStatus.success,
              )
              .having((s) => s.videos.length, 'videos count', 2),
        ],
      );

      blocTest<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        'emits [syncing, failure] when sync fails',
        setUp: () {
          when(
            () => mockLikesRepository.syncUserReactions(),
          ).thenThrow(const SyncFailedException('Network error'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ProfileLikedVideosSyncRequested()),
        expect: () => [
          const ProfileLikedVideosState(
            status: ProfileLikedVideosStatus.syncing,
          ),
          const ProfileLikedVideosState(
            status: ProfileLikedVideosStatus.failure,
            error: ProfileLikedVideosError.syncFailed,
          ),
        ],
      );

      blocTest<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        'does not re-sync while already syncing',
        setUp: () {
          when(
            () => mockLikesRepository.syncUserReactions(),
          ).thenAnswer((_) async => const LikesSyncResult.empty());
        },
        build: createBloc,
        seed: () => const ProfileLikedVideosState(
          status: ProfileLikedVideosStatus.syncing,
        ),
        act: (bloc) => bloc.add(const ProfileLikedVideosSyncRequested()),
        expect: () => <ProfileLikedVideosState>[],
        verify: (_) {
          verifyNever(() => mockLikesRepository.syncUserReactions());
        },
      );

      blocTest<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        'preserves order of liked event IDs in result',
        setUp: () {
          final video1 = createTestVideo('event1');
          final video2 = createTestVideo('event2');
          final video3 = createTestVideo('event3');

          when(() => mockLikesRepository.syncUserReactions()).thenAnswer(
            (_) async => const LikesSyncResult(
              orderedEventIds: ['event3', 'event1', 'event2'],
              eventIdToReactionId: {},
            ),
          );
          when(
            () => mockVideoEventService.getVideoById('event1'),
          ).thenReturn(video1);
          when(
            () => mockVideoEventService.getVideoById('event2'),
          ).thenReturn(video2);
          when(
            () => mockVideoEventService.getVideoById('event3'),
          ).thenReturn(video3);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ProfileLikedVideosSyncRequested()),
        expect: () => [
          const ProfileLikedVideosState(
            status: ProfileLikedVideosStatus.syncing,
          ),
          isA<ProfileLikedVideosState>().having(
            (s) => s.status,
            'status',
            ProfileLikedVideosStatus.loading,
          ),
          isA<ProfileLikedVideosState>()
              .having(
                (s) => s.status,
                'status',
                ProfileLikedVideosStatus.success,
              )
              .having(
                (s) => s.videos.map((v) => v.id).toList(),
                'video IDs order',
                ['event3', 'event1', 'event2'],
              ),
        ],
      );
    });

    group('ProfileLikedVideosSubscriptionRequested', () {
      blocTest<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        'removes video when unliked via stream',
        setUp: () {
          final video1 = createTestVideo('event1');
          final video2 = createTestVideo('event2');

          when(
            () => mockVideoEventService.getVideoById('event1'),
          ).thenReturn(video1);
          when(
            () => mockVideoEventService.getVideoById('event2'),
          ).thenReturn(video2);
        },
        build: createBloc,
        seed: () => ProfileLikedVideosState(
          status: ProfileLikedVideosStatus.success,
          likedEventIds: const ['event1', 'event2'],
          videos: [createTestVideo('event1'), createTestVideo('event2')],
        ),
        act: (bloc) async {
          // Start subscription first
          bloc.add(const ProfileLikedVideosSubscriptionRequested());
          // Wait for subscription to be set up
          await Future<void>.delayed(const Duration(milliseconds: 50));
          // Emit stream with event2 removed (unliked)
          likedIdsController.add({'event1'});
        },
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<ProfileLikedVideosState>()
              .having((s) => s.likedEventIds, 'likedEventIds', ['event1'])
              .having((s) => s.videos.length, 'videos count', 1)
              .having((s) => s.videos.first.id, 'remaining video', 'event1'),
        ],
      );

      blocTest<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        'ignores stream changes during initial or syncing status',
        build: createBloc,
        seed: () => const ProfileLikedVideosState(
          status: ProfileLikedVideosStatus.syncing,
        ),
        act: (bloc) async {
          bloc.add(const ProfileLikedVideosSubscriptionRequested());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          likedIdsController.add({'event1'});
        },
        wait: const Duration(milliseconds: 100),
        expect: () => <ProfileLikedVideosState>[],
      );

      blocTest<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        'updates likedEventIds when video is liked',
        build: createBloc,
        seed: () => const ProfileLikedVideosState(
          status: ProfileLikedVideosStatus.success,
          likedEventIds: ['event1'],
        ),
        act: (bloc) async {
          bloc.add(const ProfileLikedVideosSubscriptionRequested());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          likedIdsController.add({'event1', 'event2'});
        },
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<ProfileLikedVideosState>().having(
            (s) => s.likedEventIds,
            'likedEventIds',
            containsAll(['event1', 'event2']),
          ),
        ],
      );
    });

    group('close', () {
      test('cancels liked IDs subscription', () async {
        final bloc = createBloc();

        await bloc.close();

        // After closing, stream events should not cause errors
        expect(() => likedIdsController.add({'event1'}), returnsNormally);
      });
    });

    group('Other user profile (targetUserPubkey)', () {
      // 64-character hex pubkeys for testing
      final currentUserPubkey = 'a' * 64;
      final otherUserPubkey = 'b' * 64;

      setUp(() {
        // Set up current user pubkey
        when(() => mockNostrClient.publicKey).thenReturn(currentUserPubkey);

        // Set up fetchUserLikes for other user
        when(
          () => mockLikesRepository.fetchUserLikes(any()),
        ).thenAnswer((_) async => <String>[]);
      });

      ProfileLikedVideosBloc createBlocForOtherUser() => ProfileLikedVideosBloc(
        likesRepository: mockLikesRepository,
        videoEventService: mockVideoEventService,
        nostrClient: mockNostrClient,
        targetUserPubkey: otherUserPubkey,
      );

      blocTest<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        'fetches likes via repository.fetchUserLikes for other user',
        build: createBlocForOtherUser,
        act: (bloc) => bloc.add(const ProfileLikedVideosSyncRequested()),
        wait: const Duration(milliseconds: 100),
        expect: () => [
          const ProfileLikedVideosState(
            status: ProfileLikedVideosStatus.syncing,
          ),
          const ProfileLikedVideosState(
            status: ProfileLikedVideosStatus.success,
            videos: [],
            likedEventIds: [],
            hasMoreContent: false,
          ),
        ],
        verify: (_) {
          // Should NOT use syncUserReactions for other users
          verifyNever(() => mockLikesRepository.syncUserReactions());
          // Should use fetchUserLikes with the target user's pubkey
          verify(
            () => mockLikesRepository.fetchUserLikes(otherUserPubkey),
          ).called(1);
        },
      );

      blocTest<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        'does not subscribe to repository stream for other user profile',
        build: createBlocForOtherUser,
        act: (bloc) async {
          bloc.add(const ProfileLikedVideosSubscriptionRequested());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          // Try to emit on the liked IDs stream
          likedIdsController.add({'event1'});
        },
        wait: const Duration(milliseconds: 100),
        expect: () => <ProfileLikedVideosState>[],
      );

      blocTest<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        'uses syncUserReactions when targetUserPubkey matches current user',
        setUp: () {
          when(
            () => mockLikesRepository.syncUserReactions(),
          ).thenAnswer((_) async => const LikesSyncResult.empty());
        },
        build: () => ProfileLikedVideosBloc(
          likesRepository: mockLikesRepository,
          videoEventService: mockVideoEventService,
          nostrClient: mockNostrClient,
          targetUserPubkey: currentUserPubkey,
        ),
        act: (bloc) => bloc.add(const ProfileLikedVideosSyncRequested()),
        expect: () => [
          const ProfileLikedVideosState(
            status: ProfileLikedVideosStatus.syncing,
          ),
          const ProfileLikedVideosState(
            status: ProfileLikedVideosStatus.success,
            videos: [],
            likedEventIds: [],
            hasMoreContent: false,
          ),
        ],
        verify: (_) {
          // Should use syncUserReactions when pubkey matches current user
          verify(() => mockLikesRepository.syncUserReactions()).called(1);
          // Should NOT use fetchUserLikes for own profile
          verifyNever(() => mockLikesRepository.fetchUserLikes(any()));
        },
      );
    });
  });
}
