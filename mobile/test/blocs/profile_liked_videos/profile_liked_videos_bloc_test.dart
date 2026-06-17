// ABOUTME: Tests for ProfileLikedVideosBloc - syncing and fetching liked videos
// ABOUTME: Tests syncing from repository, loading from cache, and state management

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:cache_sync/cache_sync.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:content_policy/content_policy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/profile_liked_videos/profile_liked_videos_bloc.dart';
import 'package:openvine/blocs/profile_shared/profile_video_list_snapshot.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockLikesRepository extends Mock implements LikesRepository {}

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

/// In-memory [CacheDao] so the bloc's [CacheSync] reads/writes are isolated
/// per test without touching disk.
class _InMemoryCacheDao implements CacheDao {
  final Map<String, String> _store = {};

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> write({
    required String key,
    required String payload,
    Duration? ttl,
  }) async {
    _store[key] = payload;
  }

  @override
  Future<void> delete(String key) async => _store.remove(key);

  @override
  Future<void> deletePrefix(String prefix) async =>
      _store.removeWhere((key, _) => key.startsWith(prefix));

  @override
  Future<int> totalPayloadBytes() async =>
      _store.values.fold<int>(0, (sum, v) => sum + v.length);

  @override
  Future<void> evictOldest(int bytesToFree) async {}
}

void main() {
  group('ProfileLikedVideosBloc', () {
    late _MockLikesRepository mockLikesRepository;
    late _MockVideosRepository mockVideosRepository;
    late _MockContentBlocklistRepository mockBlocklistRepository;
    late _InMemoryCacheDao cacheDao;
    late StreamController<List<String>> likedIdsController;
    late StreamController<ContentPolicyState> blocklistStateController;

    // Test pubkeys
    const currentUserPubkey =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const otherUserPubkey =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

    setUp(() async {
      mockLikesRepository = _MockLikesRepository();
      mockVideosRepository = _MockVideosRepository();
      mockBlocklistRepository = _MockContentBlocklistRepository();
      cacheDao = _InMemoryCacheDao();
      await CacheSync.init(dao: cacheDao);
      likedIdsController = StreamController<List<String>>.broadcast();
      blocklistStateController =
          StreamController<ContentPolicyState>.broadcast();

      // Default stub for watchLikedEventIds
      when(
        () => mockLikesRepository.watchLikedEventIds(),
      ).thenAnswer((_) => likedIdsController.stream);

      // Default stub for getOrderedLikedEventIds (returns empty = no cache)
      // This forces the "no cache" flow which syncs from relay
      when(
        () => mockLikesRepository.getOrderedLikedEventIds(),
      ).thenAnswer((_) async => []);

      // The bloc subscribes to stateStream in its constructor.
      when(
        () => mockBlocklistRepository.stateStream,
      ).thenAnswer((_) => blocklistStateController.stream);
      when(
        () => mockBlocklistRepository.filterContent<VideoEvent>(any(), any()),
      ).thenAnswer(
        (invocation) => invocation.positionalArguments[0] as List<VideoEvent>,
      );
    });

    tearDown(() {
      likedIdsController.close();
      blocklistStateController.close();
    });

    ProfileLikedVideosBloc createBloc({String? targetUserPubkey}) =>
        ProfileLikedVideosBloc(
          likesRepository: mockLikesRepository,
          videosRepository: mockVideosRepository,
          contentBlocklistRepository: mockBlocklistRepository,
          currentUserPubkey: currentUserPubkey,
          targetUserPubkey: targetUserPubkey,
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

      test('copyWith updates isRefreshing', () {
        const state = ProfileLikedVideosState();

        expect(state.isRefreshing, isFalse);
        expect(state.copyWith(isRefreshing: true).isRefreshing, isTrue);
      });
    });

    group('ProfileLikedVideosSyncRequested', () {
      blocTest<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        'emits [success] with empty videos when no liked IDs',
        setUp: () {
          when(
            () => mockLikesRepository.syncUserReactions(),
          ).thenAnswer((_) async => const LikesSyncResult.empty());
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ProfileLikedVideosSyncRequested()),
        wait: const Duration(milliseconds: 50),
        expect: () => [
          const ProfileLikedVideosState(
            status: ProfileLikedVideosStatus.success,
            hasMoreContent: false,
          ),
        ],
      );

      blocTest<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        'emits [success] with videos when liked videos found',
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
            () => mockVideosRepository.getVideosByIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          ).thenAnswer((_) async => [video1, video2]);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ProfileLikedVideosSyncRequested()),
        wait: const Duration(milliseconds: 50),
        expect: () => [
          isA<ProfileLikedVideosState>()
              .having(
                (s) => s.status,
                'status',
                ProfileLikedVideosStatus.success,
              )
              .having((s) => s.isRefreshing, 'isRefreshing', false)
              .having((s) => s.likedEventIds, 'likedEventIds', [
                'event1',
                'event2',
              ])
              .having((s) => s.videos.length, 'videos count', 2)
              .having((s) => s.nextPageOffset, 'nextPageOffset', 2),
        ],
      );

      blocTest<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        'emits [failure] when sync fails and nothing is cached',
        setUp: () {
          when(
            () => mockLikesRepository.syncUserReactions(),
          ).thenThrow(const SyncFailedException('Network error'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ProfileLikedVideosSyncRequested()),
        wait: const Duration(milliseconds: 50),
        expect: () => [
          const ProfileLikedVideosState(
            status: ProfileLikedVideosStatus.failure,
            error: ProfileLikedVideosError.syncFailed,
          ),
        ],
      );

      blocTest<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        'serves cached snapshot, then only flips the bar off when unchanged',
        setUp: () async {
          await cacheDao.write(
            key: '$currentUserPubkey:$currentUserPubkey:profile_liked_videos',
            payload: ProfileVideoListSnapshot(
              videos: [createTestVideo('a'), createTestVideo('b')],
              itemIds: const ['a', 'b'],
              nextPageOffset: 2,
              hasMoreContent: false,
            ).toJson(),
          );
          // Relay reports the same liked set → no change.
          when(() => mockLikesRepository.syncUserReactions()).thenAnswer(
            (_) async => const LikesSyncResult(
              orderedEventIds: ['a', 'b'],
              eventIdToReactionId: {},
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ProfileLikedVideosSyncRequested()),
        wait: const Duration(milliseconds: 50),
        expect: () => [
          // Cached snapshot served immediately, revalidation in flight.
          isA<ProfileLikedVideosState>()
              .having(
                (s) => s.status,
                'status',
                ProfileLikedVideosStatus.success,
              )
              .having((s) => s.isRefreshing, 'isRefreshing', true)
              .having(
                (s) => s.videos.map((v) => v.id).toList(),
                'cached videos',
                ['a', 'b'],
              ),
          // Nothing changed → bar off, same videos (no re-fetch).
          isA<ProfileLikedVideosState>()
              .having((s) => s.isRefreshing, 'isRefreshing', false)
              .having(
                (s) => s.videos.map((v) => v.id).toList(),
                'unchanged videos',
                ['a', 'b'],
              ),
        ],
        verify: (_) {
          // The whole point of the freeze fix: the loaded window is NOT
          // re-resolved on revalidation.
          verifyNever(
            () => mockVideosRepository.getVideosByIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          );
        },
      );

      blocTest<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        'warm revalidation drops unliked videos without re-fetching',
        setUp: () async {
          await cacheDao.write(
            key: '$currentUserPubkey:$currentUserPubkey:profile_liked_videos',
            payload: ProfileVideoListSnapshot(
              videos: [createTestVideo('a'), createTestVideo('b')],
              itemIds: const ['a', 'b'],
              nextPageOffset: 2,
              hasMoreContent: false,
            ).toJson(),
          );
          // 'b' was unliked while the tab was away.
          when(() => mockLikesRepository.syncUserReactions()).thenAnswer(
            (_) async => const LikesSyncResult(
              orderedEventIds: ['a'],
              eventIdToReactionId: {},
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ProfileLikedVideosSyncRequested()),
        wait: const Duration(milliseconds: 50),
        expect: () => [
          isA<ProfileLikedVideosState>()
              .having((s) => s.isRefreshing, 'isRefreshing', true)
              .having(
                (s) => s.videos.map((v) => v.id).toList(),
                'cached videos',
                ['a', 'b'],
              ),
          isA<ProfileLikedVideosState>()
              .having((s) => s.isRefreshing, 'isRefreshing', false)
              .having(
                (s) => s.videos.map((v) => v.id).toList(),
                'reconciled videos',
                ['a'],
              )
              .having((s) => s.likedEventIds, 'likedEventIds', ['a']),
        ],
        verify: (_) {
          verifyNever(
            () => mockVideosRepository.getVideosByIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          );
        },
      );

      blocTest<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        'reopen restores the full scrolled-through list from cache',
        setUp: () async {
          final cachedVideos = List.generate(36, (i) => createTestVideo('v$i'));
          final cachedIds = List.generate(40, (i) => 'v$i');
          await cacheDao.write(
            key: '$currentUserPubkey:$otherUserPubkey:profile_liked_videos',
            payload: ProfileVideoListSnapshot(
              videos: cachedVideos,
              itemIds: cachedIds,
              nextPageOffset: 36,
              hasMoreContent: true,
            ).toJson(),
          );
          when(
            () => mockLikesRepository.fetchUserLikes(any()),
          ).thenAnswer((_) async => cachedIds);
          when(
            () => mockVideosRepository.getVideosByIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          ).thenAnswer((invocation) async {
            final ids = invocation.positionalArguments[0] as List<String>;
            return ids.map(createTestVideo).toList();
          });
        },
        build: () => createBloc(targetUserPubkey: otherUserPubkey),
        act: (bloc) => bloc.add(const ProfileLikedVideosSyncRequested()),
        wait: const Duration(milliseconds: 100),
        expect: () => [
          // Cached emit restores all 36 scrolled videos instantly, not page 1.
          isA<ProfileLikedVideosState>()
              .having((s) => s.isRefreshing, 'isRefreshing', true)
              .having((s) => s.videos.length, 'cached videos', 36)
              .having((s) => s.nextPageOffset, 'nextPageOffset', 36),
          // Live emit revalidates the same 36-video window (does not shrink).
          isA<ProfileLikedVideosState>()
              .having((s) => s.isRefreshing, 'isRefreshing', false)
              .having((s) => s.videos.length, 'revalidated videos', 36)
              .having((s) => s.nextPageOffset, 'nextPageOffset', 36),
        ],
      );

      blocTest<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        'reopen of a capped snapshot revalidates without bulk-fetching the '
        'full liked list',
        setUp: () async {
          // Simulates a power user: the persisted window was capped to 50,
          // but the real liked list is far longer. The cap must not make
          // reconcile think 250 items were "added" and re-fetch them all.
          final cachedIds = List.generate(50, (i) => 'v$i');
          final cachedVideos = cachedIds.map(createTestVideo).toList();
          await cacheDao.write(
            key: '$currentUserPubkey:$currentUserPubkey:profile_liked_videos',
            payload: ProfileVideoListSnapshot(
              videos: cachedVideos,
              itemIds: cachedIds,
              nextPageOffset: 50,
              hasMoreContent: true,
            ).toJson(),
          );
          // Fresh full list: same top 50, then 250 more.
          final freshIds = List.generate(300, (i) => 'v$i');
          when(() => mockLikesRepository.syncUserReactions()).thenAnswer(
            (_) async => LikesSyncResult(
              orderedEventIds: freshIds,
              eventIdToReactionId: const {},
            ),
          );
          when(
            () => mockVideosRepository.getVideosByIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          ).thenAnswer((invocation) async {
            final ids = invocation.positionalArguments[0] as List<String>;
            return ids.map(createTestVideo).toList();
          });
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ProfileLikedVideosSyncRequested()),
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<ProfileLikedVideosState>()
              .having((s) => s.isRefreshing, 'isRefreshing', true)
              .having((s) => s.videos.length, 'cached videos', 50),
          // Window stays bounded to what was displayed; the full ID list is
          // restored in memory so pagination can continue past the cap.
          isA<ProfileLikedVideosState>()
              .having((s) => s.isRefreshing, 'isRefreshing', false)
              .having((s) => s.videos.length, 'revalidated videos', 50)
              .having((s) => s.likedEventIds.length, 'full id list', 300)
              .having((s) => s.hasMoreContent, 'hasMoreContent', true),
        ],
        verify: (_) {
          // The reconcile window is the displayed 50, all already cached, so
          // no video fetch happens — proving no 250-item bulk re-fetch.
          verifyNever(
            () => mockVideosRepository.getVideosByIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          );
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
          // VideosRepository preserves order from input
          when(
            () => mockVideosRepository.getVideosByIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          ).thenAnswer((_) async => [video3, video1, video2]);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ProfileLikedVideosSyncRequested()),
        wait: const Duration(milliseconds: 50),
        expect: () => [
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

      blocTest<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        'continues initial load through sparse liked IDs until videos render',
        setUp: () {
          final likedIds = List.generate(40, (index) => 'event${index + 1}');
          final secondBatchVideos = List.generate(
            18,
            (index) => createTestVideo('event${index + 19}'),
          );

          when(() => mockLikesRepository.syncUserReactions()).thenAnswer(
            (_) async => LikesSyncResult(
              orderedEventIds: likedIds,
              eventIdToReactionId: const {},
            ),
          );
          when(
            () => mockVideosRepository.getVideosByIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          ).thenAnswer((invocation) async {
            final ids = invocation.positionalArguments[0] as List<String>;
            if (ids.first == 'event19') {
              return secondBatchVideos;
            }
            return <VideoEvent>[];
          });
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ProfileLikedVideosSyncRequested()),
        wait: const Duration(milliseconds: 50),
        expect: () => [
          // SWR cold load fills a full page through the sparse IDs in one go.
          isA<ProfileLikedVideosState>()
              .having(
                (s) => s.status,
                'status',
                ProfileLikedVideosStatus.success,
              )
              .having((s) => s.videos.length, 'videos count', 18)
              .having((s) => s.nextPageOffset, 'nextPageOffset', 36)
              .having((s) => s.hasMoreContent, 'hasMoreContent', true),
        ],
        verify: (_) {
          verify(
            () => mockVideosRepository.getVideosByIds(
              any(
                that: equals(List.generate(18, (index) => 'event${index + 1}')),
              ),
              cacheResults: true,
            ),
          ).called(1);
          verify(
            () => mockVideosRepository.getVideosByIds(
              any(
                that: equals(
                  List.generate(18, (index) => 'event${index + 19}'),
                ),
              ),
            ),
          ).called(1);
        },
      );
    });

    group('ProfileLikedVideosSubscriptionRequested', () {
      blocTest<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        'removes video when unliked via stream',
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
          likedIdsController.add(['event1']);
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
          likedIdsController.add(['event1']);
        },
        wait: const Duration(milliseconds: 100),
        expect: () => <ProfileLikedVideosState>[],
      );

      blocTest<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        'fetches and prepends the video when a new like arrives via stream',
        setUp: () {
          when(
            () => mockVideosRepository.getVideosByIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          ).thenAnswer((_) async => [createTestVideo('event2')]);
        },
        build: createBloc,
        seed: () => ProfileLikedVideosState(
          status: ProfileLikedVideosStatus.success,
          likedEventIds: const ['event1'],
          videos: [createTestVideo('event1')],
          nextPageOffset: 1,
        ),
        act: (bloc) async {
          bloc.add(const ProfileLikedVideosSubscriptionRequested());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          // event2 liked, prepended (most-recent-first).
          likedIdsController.add(['event2', 'event1']);
        },
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<ProfileLikedVideosState>()
              .having((s) => s.likedEventIds, 'likedEventIds', [
                'event2',
                'event1',
              ])
              // The new like is fetched and shown at the top.
              .having((s) => s.videos.map((v) => v.id).toList(), 'videos', [
                'event2',
                'event1',
              ]),
        ],
      );
    });

    group('close', () {
      test('cancels liked IDs subscription', () async {
        final bloc = createBloc();

        await bloc.close();

        // After closing, stream events should not cause errors
        expect(() => likedIdsController.add(['event1']), returnsNormally);
      });
    });

    group('Other user profile (targetUserPubkey)', () {
      setUp(() {
        // Set up fetchUserLikes for other user
        when(
          () => mockLikesRepository.fetchUserLikes(any()),
        ).thenAnswer((_) async => <String>[]);
      });

      blocTest<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        'fetches likes via repository.fetchUserLikes for other user',
        build: () => createBloc(targetUserPubkey: otherUserPubkey),
        act: (bloc) => bloc.add(const ProfileLikedVideosSyncRequested()),
        wait: const Duration(milliseconds: 100),
        expect: () => [
          const ProfileLikedVideosState(
            status: ProfileLikedVideosStatus.success,
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
        build: () => createBloc(targetUserPubkey: otherUserPubkey),
        act: (bloc) async {
          bloc.add(const ProfileLikedVideosSubscriptionRequested());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          // Try to emit on the liked IDs stream
          likedIdsController.add(['event1']);
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
        build: () => createBloc(targetUserPubkey: currentUserPubkey),
        act: (bloc) => bloc.add(const ProfileLikedVideosSyncRequested()),
        wait: const Duration(milliseconds: 50),
        expect: () => [
          const ProfileLikedVideosState(
            status: ProfileLikedVideosStatus.success,
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

    group('ProfileLikedVideosLoadMoreRequested', () {
      blocTest<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        'loads next page of videos and advances nextPageOffset',
        setUp: () {
          final video3 = createTestVideo('event3');
          when(
            () => mockVideosRepository.getVideosByIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          ).thenAnswer((_) async => [video3]);
        },
        build: createBloc,
        seed: () => ProfileLikedVideosState(
          status: ProfileLikedVideosStatus.success,
          likedEventIds: const ['event1', 'event2', 'event3'],
          videos: [createTestVideo('event1'), createTestVideo('event2')],
          nextPageOffset: 2,
        ),
        act: (bloc) => bloc.add(const ProfileLikedVideosLoadMoreRequested()),
        expect: () => [
          isA<ProfileLikedVideosState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            true,
          ),
          isA<ProfileLikedVideosState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', false)
              .having((s) => s.videos.length, 'videos count', 3)
              .having((s) => s.hasMoreContent, 'hasMoreContent', false)
              .having((s) => s.nextPageOffset, 'nextPageOffset', 3),
        ],
      );

      blocTest<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        'persists the grown list to cache so reopen restores it',
        setUp: () {
          when(
            () => mockVideosRepository.getVideosByIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          ).thenAnswer((_) async => [createTestVideo('event3')]);
        },
        build: createBloc,
        seed: () => ProfileLikedVideosState(
          status: ProfileLikedVideosStatus.success,
          likedEventIds: const ['event1', 'event2', 'event3'],
          videos: [createTestVideo('event1'), createTestVideo('event2')],
          nextPageOffset: 2,
        ),
        act: (bloc) => bloc.add(const ProfileLikedVideosLoadMoreRequested()),
        wait: const Duration(milliseconds: 50),
        verify: (_) async {
          final cached = await CacheSync.read<ProfileVideoListSnapshot>(
            key: '$currentUserPubkey:$currentUserPubkey:profile_liked_videos',
            fromJson: ProfileVideoListSnapshot.fromJson,
          );
          expect(cached, isNotNull);
          expect(cached!.videos.map((v) => v.id).toList(), [
            'event1',
            'event2',
            'event3',
          ]);
          expect(cached.nextPageOffset, 3);
        },
      );

      blocTest<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        'advances nextPageOffset by IDs consumed even when some IDs '
        'do not resolve to videos',
        setUp: () {
          // Only 1 of 3 IDs resolves to a video (others missing from relay)
          final video5 = createTestVideo('event5');
          when(
            () => mockVideosRepository.getVideosByIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          ).thenAnswer((_) async => [video5]);
        },
        build: createBloc,
        seed: () => ProfileLikedVideosState(
          status: ProfileLikedVideosStatus.success,
          likedEventIds: const [
            'event1',
            'event2',
            'event3',
            'event4',
            'event5',
            'event6',
          ],
          videos: [createTestVideo('event1'), createTestVideo('event2')],
          nextPageOffset: 3,
        ),
        act: (bloc) => bloc.add(const ProfileLikedVideosLoadMoreRequested()),
        expect: () => [
          isA<ProfileLikedVideosState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            true,
          ),
          isA<ProfileLikedVideosState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', false)
              // Only 1 new video resolved, so 2 + 1 = 3 total
              .having((s) => s.videos.length, 'videos count', 3)
              // Offset advances by 3 IDs consumed (event4, event5, event6)
              .having((s) => s.nextPageOffset, 'nextPageOffset', 6)
              // All IDs consumed → no more content
              .having((s) => s.hasMoreContent, 'hasMoreContent', false),
        ],
      );

      blocTest<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        'continues load more through sparse liked IDs until a full page renders',
        setUp: () {
          final nextVisibleVideos = List.generate(
            18,
            (index) => createTestVideo('event${index + 21}'),
          );
          when(
            () => mockVideosRepository.getVideosByIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          ).thenAnswer((invocation) async {
            final ids = invocation.positionalArguments[0] as List<String>;
            if (ids.first == 'event21') {
              return nextVisibleVideos;
            }
            return <VideoEvent>[];
          });
        },
        build: createBloc,
        seed: () => ProfileLikedVideosState(
          status: ProfileLikedVideosStatus.success,
          likedEventIds: List.generate(42, (index) => 'event${index + 1}'),
          videos: [createTestVideo('event1'), createTestVideo('event2')],
          nextPageOffset: 2,
        ),
        act: (bloc) => bloc.add(const ProfileLikedVideosLoadMoreRequested()),
        expect: () => [
          isA<ProfileLikedVideosState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            true,
          ),
          isA<ProfileLikedVideosState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', false)
              .having((s) => s.videos.length, 'videos count', 20)
              .having((s) => s.nextPageOffset, 'nextPageOffset', 38)
              .having((s) => s.hasMoreContent, 'hasMoreContent', true),
        ],
      );

      blocTest<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        'emits hasMoreContent false when '
        'nextPageOffset >= likedEventIds.length',
        build: createBloc,
        seed: () => ProfileLikedVideosState(
          status: ProfileLikedVideosStatus.success,
          likedEventIds: const ['event1', 'event2'],
          videos: [createTestVideo('event1')],
          nextPageOffset: 2,
        ),
        act: (bloc) => bloc.add(const ProfileLikedVideosLoadMoreRequested()),
        expect: () => [
          isA<ProfileLikedVideosState>().having(
            (s) => s.hasMoreContent,
            'hasMoreContent',
            false,
          ),
        ],
        verify: (_) {
          // Should not even attempt to fetch videos
          verifyNever(
            () => mockVideosRepository.getVideosByIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          );
        },
      );

      blocTest<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        'deduplicates videos already present in state',
        setUp: () {
          // Repository returns a video that's already loaded
          final duplicateVideo = createTestVideo('event1');
          final newVideo = createTestVideo('event3');
          when(
            () => mockVideosRepository.getVideosByIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          ).thenAnswer((_) async => [duplicateVideo, newVideo]);
        },
        build: createBloc,
        seed: () => ProfileLikedVideosState(
          status: ProfileLikedVideosStatus.success,
          likedEventIds: const ['event1', 'event2', 'event3'],
          videos: [createTestVideo('event1')],
          nextPageOffset: 1,
        ),
        act: (bloc) => bloc.add(const ProfileLikedVideosLoadMoreRequested()),
        expect: () => [
          isA<ProfileLikedVideosState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            true,
          ),
          isA<ProfileLikedVideosState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', false)
              // Only event3 is new, so 1 + 1 = 2 (event1 deduped)
              .having((s) => s.videos.length, 'videos count', 2)
              .having((s) => s.videos.map((v) => v.id).toList(), 'video IDs', [
                'event1',
                'event3',
              ])
              .having((s) => s.nextPageOffset, 'nextPageOffset', 3)
              .having((s) => s.hasMoreContent, 'hasMoreContent', false),
        ],
      );

      blocTest<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        'filters blocked authors from newly fetched videos',
        setUp: () {
          final blockedVideo = createTestVideo('event2');
          final allowedVideo = createTestVideo('event3');
          when(
            () => mockVideosRepository.getVideosByIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          ).thenAnswer((_) async => [blockedVideo, allowedVideo]);
          when(
            () =>
                mockBlocklistRepository.filterContent<VideoEvent>(any(), any()),
          ).thenAnswer((invocation) {
            final videos =
                invocation.positionalArguments[0] as List<VideoEvent>;
            return videos.where((video) => video.id != 'event2').toList();
          });
        },
        build: createBloc,
        seed: () => ProfileLikedVideosState(
          status: ProfileLikedVideosStatus.success,
          likedEventIds: const ['event1', 'event2', 'event3'],
          videos: [createTestVideo('event1')],
          nextPageOffset: 1,
        ),
        act: (bloc) => bloc.add(const ProfileLikedVideosLoadMoreRequested()),
        expect: () => [
          isA<ProfileLikedVideosState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            true,
          ),
          isA<ProfileLikedVideosState>().having(
            (s) => s.videos.map((v) => v.id).toList(),
            'video IDs',
            ['event1', 'event3'],
          ),
        ],
      );

      blocTest<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        'does not load more when already loading',
        build: createBloc,
        seed: () => const ProfileLikedVideosState(
          status: ProfileLikedVideosStatus.success,
          isLoadingMore: true,
        ),
        act: (bloc) => bloc.add(const ProfileLikedVideosLoadMoreRequested()),
        expect: () => <ProfileLikedVideosState>[],
      );

      blocTest<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        'does not load more when no more content',
        build: createBloc,
        seed: () => const ProfileLikedVideosState(
          status: ProfileLikedVideosStatus.success,
          hasMoreContent: false,
        ),
        act: (bloc) => bloc.add(const ProfileLikedVideosLoadMoreRequested()),
        expect: () => <ProfileLikedVideosState>[],
      );
    });

    group('Subscription nextPageOffset adjustment', () {
      blocTest<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        'clamps nextPageOffset when unlike reduces likedEventIds',
        build: createBloc,
        seed: () => ProfileLikedVideosState(
          status: ProfileLikedVideosStatus.success,
          likedEventIds: const ['event1', 'event2', 'event3'],
          videos: [
            createTestVideo('event1'),
            createTestVideo('event2'),
            createTestVideo('event3'),
          ],
          nextPageOffset: 3,
        ),
        act: (bloc) async {
          bloc.add(const ProfileLikedVideosSubscriptionRequested());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          // event3 was unliked
          likedIdsController.add(['event1', 'event2']);
        },
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<ProfileLikedVideosState>()
              .having((s) => s.likedEventIds, 'likedEventIds', [
                'event1',
                'event2',
              ])
              .having((s) => s.videos.length, 'videos count', 2)
              // nextPageOffset clamped from 3 to 2
              .having((s) => s.nextPageOffset, 'nextPageOffset', 2),
        ],
      );

      blocTest<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        'prepends the fetched video and advances offset on a new like',
        setUp: () {
          when(
            () => mockVideosRepository.getVideosByIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          ).thenAnswer((_) async => [createTestVideo('event3')]);
        },
        build: createBloc,
        seed: () => ProfileLikedVideosState(
          status: ProfileLikedVideosStatus.success,
          likedEventIds: const ['event1', 'event2'],
          videos: [createTestVideo('event1'), createTestVideo('event2')],
          nextPageOffset: 2,
        ),
        act: (bloc) async {
          bloc.add(const ProfileLikedVideosSubscriptionRequested());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          // New like prepended
          likedIdsController.add(['event3', 'event1', 'event2']);
        },
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<ProfileLikedVideosState>()
              .having((s) => s.likedEventIds, 'likedEventIds', [
                'event3',
                'event1',
                'event2',
              ])
              // The new like is fetched and shown at the top.
              .having((s) => s.videos.map((v) => v.id).toList(), 'videos', [
                'event3',
                'event1',
                'event2',
              ])
              // nextPageOffset shifted forward by 1 (1 new like added)
              .having((s) => s.nextPageOffset, 'nextPageOffset', 3),
        ],
      );
    });

    group('ProfileLikedVideosBlocklistChanged', () {
      const blockedPubkey =
          'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
      const allowedPubkey =
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

      VideoEvent videoBy(String id, String pubkey) {
        final now = DateTime.now();
        return VideoEvent(
          id: id,
          pubkey: pubkey,
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          content: '',
          timestamp: now,
          title: 'Test Video $id',
          videoUrl: 'https://example.com/video.mp4',
          thumbnailUrl: 'https://example.com/thumb.jpg',
        );
      }

      void stubFilterRemovingBlocked() {
        when(
          () => mockBlocklistRepository.filterContent<VideoEvent>(any(), any()),
        ).thenAnswer(
          (invocation) =>
              (invocation.positionalArguments[0] as List<VideoEvent>)
                  .where((v) => v.pubkey != blockedPubkey)
                  .toList(),
        );
      }

      blocTest<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        'removes blocked authors from videos, leaving likedEventIds/offset',
        setUp: stubFilterRemovingBlocked,
        build: createBloc,
        seed: () => ProfileLikedVideosState(
          status: ProfileLikedVideosStatus.success,
          videos: [videoBy('a', blockedPubkey), videoBy('b', allowedPubkey)],
          likedEventIds: const ['a', 'b'],
          nextPageOffset: 2,
        ),
        act: (bloc) => bloc.add(const ProfileLikedVideosBlocklistChanged()),
        expect: () => [
          isA<ProfileLikedVideosState>()
              .having((s) => s.videos.map((v) => v.id).toList(), 'videos', [
                'b',
              ])
              .having((s) => s.likedEventIds, 'likedEventIds', ['a', 'b'])
              .having((s) => s.nextPageOffset, 'nextPageOffset', 2),
        ],
      );

      blocTest<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        'restores a now-unblocked author by re-resolving the loaded window',
        setUp: () {
          // 'a' was filtered out previously; the blocklist no longer filters
          // it (default filterContent stub returns the input unchanged).
          when(
            () => mockVideosRepository.getVideosByIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          ).thenAnswer(
            (_) async => [
              videoBy('a', allowedPubkey),
              videoBy('b', allowedPubkey),
            ],
          );
        },
        build: createBloc,
        // Window of 2 IDs, but only 'b' is currently shown ('a' was blocked).
        seed: () => ProfileLikedVideosState(
          status: ProfileLikedVideosStatus.success,
          videos: [videoBy('b', allowedPubkey)],
          likedEventIds: const ['a', 'b'],
          nextPageOffset: 2,
        ),
        act: (bloc) => bloc.add(const ProfileLikedVideosBlocklistChanged()),
        wait: const Duration(milliseconds: 50),
        expect: () => [
          // Re-resolving the window brings 'a' back.
          isA<ProfileLikedVideosState>().having(
            (s) => s.videos.map((v) => v.id).toList(),
            'videos',
            ['a', 'b'],
          ),
        ],
        verify: (_) {
          verify(
            () => mockVideosRepository.getVideosByIds(
              any(that: equals(['a', 'b'])),
              cacheResults: any(named: 'cacheResults'),
            ),
          ).called(1);
        },
      );

      blocTest<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        'a stateStream emission triggers the re-filter',
        setUp: stubFilterRemovingBlocked,
        build: createBloc,
        seed: () => ProfileLikedVideosState(
          status: ProfileLikedVideosStatus.success,
          videos: [videoBy('a', blockedPubkey), videoBy('b', allowedPubkey)],
          likedEventIds: const ['a', 'b'],
        ),
        act: (_) => blocklistStateController.add(ContentPolicyState.empty()),
        wait: const Duration(milliseconds: 50),
        expect: () => [
          isA<ProfileLikedVideosState>().having(
            (s) => s.videos.map((v) => v.id).toList(),
            'videos',
            ['b'],
          ),
        ],
      );

      blocTest<ProfileLikedVideosBloc, ProfileLikedVideosState>(
        'emits nothing when no loaded video is blocked',
        setUp: () {
          when(
            () =>
                mockBlocklistRepository.filterContent<VideoEvent>(any(), any()),
          ).thenAnswer(
            (invocation) => List<VideoEvent>.from(
              invocation.positionalArguments[0] as List<VideoEvent>,
            ),
          );
        },
        build: createBloc,
        seed: () => ProfileLikedVideosState(
          status: ProfileLikedVideosStatus.success,
          videos: [videoBy('b', allowedPubkey)],
          likedEventIds: const ['b'],
        ),
        act: (bloc) => bloc.add(const ProfileLikedVideosBlocklistChanged()),
        expect: () => const <ProfileLikedVideosState>[],
      );

      test('cancels the blocklist subscription on close', () async {
        final bloc = createBloc();
        await bloc.close();

        // A stateStream emission after close must not trigger a re-filter.
        blocklistStateController.add(ContentPolicyState.empty());
        await Future<void>.delayed(Duration.zero);

        verifyNever(
          () => mockBlocklistRepository.filterContent<VideoEvent>(any(), any()),
        );
      });
    });
  });
}
