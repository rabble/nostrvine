// ABOUTME: Tests for ProfileRepostedVideosBloc - syncing and fetching reposted
// ABOUTME: videos. Tests syncing from repository, loading from cache, and state
// ABOUTME: management.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:cache_sync/cache_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/profile_reposted_videos/profile_reposted_videos_bloc.dart';
import 'package:openvine/blocs/profile_shared/profile_video_list_snapshot.dart';
import 'package:reposts_repository/reposts_repository.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockRepostsRepository extends Mock implements RepostsRepository {}

class _MockVideosRepository extends Mock implements VideosRepository {}

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
  group('ProfileRepostedVideosBloc', () {
    late _MockRepostsRepository mockRepostsRepository;
    late _MockVideosRepository mockVideosRepository;
    late _InMemoryCacheDao cacheDao;
    late StreamController<Set<String>> repostedIdsController;

    // 64-character hex pubkeys for testing
    const currentUserPubkey =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const otherUserPubkey =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

    setUp(() async {
      mockRepostsRepository = _MockRepostsRepository();
      mockVideosRepository = _MockVideosRepository();
      cacheDao = _InMemoryCacheDao();
      await CacheSync.init(dao: cacheDao);
      repostedIdsController = StreamController<Set<String>>.broadcast();

      // Default stub for watchRepostedAddressableIds
      when(
        () => mockRepostsRepository.watchRepostedAddressableIds(),
      ).thenAnswer((_) => repostedIdsController.stream);

      // Default stub for getOrderedRepostedAddressableIds (returns empty = no cache)
      // This forces the "no cache" flow which syncs from relay
      when(
        () => mockRepostsRepository.getOrderedRepostedAddressableIds(),
      ).thenAnswer((_) async => []);
    });

    tearDown(() {
      repostedIdsController.close();
    });

    ProfileRepostedVideosBloc createBloc({String? targetUserPubkey}) =>
        ProfileRepostedVideosBloc(
          repostsRepository: mockRepostsRepository,
          videosRepository: mockVideosRepository,
          currentUserPubkey: currentUserPubkey,
          targetUserPubkey: targetUserPubkey,
        );

    VideoEvent createTestVideo({
      required String id,
      required String pubkey,
      required String vineId,
    }) {
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
        vineId: vineId,
      );
    }

    /// Creates an addressable ID in the format: 34236:pubkey:d-tag
    String createAddressableId(String pubkey, String dTag) {
      return '34236:$pubkey:$dTag';
    }

    test('initial state is initial with empty collections', () {
      final bloc = createBloc();
      expect(bloc.state.status, ProfileRepostedVideosStatus.initial);
      expect(bloc.state.videos, isEmpty);
      expect(bloc.state.repostedAddressableIds, isEmpty);
      expect(bloc.state.error, isNull);
      bloc.close();
    });

    group('ProfileRepostedVideosState', () {
      test('isLoaded returns true when status is success', () {
        const initialState = ProfileRepostedVideosState();
        const successState = ProfileRepostedVideosState(
          status: ProfileRepostedVideosStatus.success,
        );

        expect(initialState.isLoaded, isFalse);
        expect(successState.isLoaded, isTrue);
      });

      test('isLoading returns true when status is loading or syncing', () {
        const initialState = ProfileRepostedVideosState();
        const loadingState = ProfileRepostedVideosState(
          status: ProfileRepostedVideosStatus.loading,
        );
        const syncingState = ProfileRepostedVideosState(
          status: ProfileRepostedVideosStatus.syncing,
        );

        expect(initialState.isLoading, isFalse);
        expect(loadingState.isLoading, isTrue);
        expect(syncingState.isLoading, isTrue);
      });

      test('copyWith creates copy with updated values', () {
        const state = ProfileRepostedVideosState();

        final updated = state.copyWith(
          status: ProfileRepostedVideosStatus.success,
          repostedAddressableIds: ['34236:abc:123'],
        );

        expect(updated.status, ProfileRepostedVideosStatus.success);
        expect(updated.repostedAddressableIds, ['34236:abc:123']);
      });

      test('copyWith preserves values when not specified', () {
        const state = ProfileRepostedVideosState(
          status: ProfileRepostedVideosStatus.success,
          repostedAddressableIds: ['34236:abc:123'],
        );

        final updated = state.copyWith();

        expect(updated.status, ProfileRepostedVideosStatus.success);
        expect(updated.repostedAddressableIds, ['34236:abc:123']);
      });

      test('copyWith clearError removes error', () {
        const state = ProfileRepostedVideosState(
          error: ProfileRepostedVideosError.loadFailed,
        );

        final updated = state.copyWith(clearError: true);

        expect(updated.error, isNull);
      });

      test('props includes all relevant fields', () {
        final state = ProfileRepostedVideosState(
          status: ProfileRepostedVideosStatus.success,
          videos: [
            createTestVideo(id: 'e1', pubkey: currentUserPubkey, vineId: 'd1'),
          ],
          repostedAddressableIds: const ['34236:abc:123'],
          isLoadingMore: true,
          hasMoreContent: false,
        );

        expect(state.props, [
          ProfileRepostedVideosStatus.success,
          state.videos,
          const ['34236:abc:123'],
          null,
          true, // isLoadingMore
          false, // isRefreshing
          false, // hasMoreContent
          0, // nextPageOffset
        ]);
      });

      test('copyWith updates isRefreshing', () {
        const state = ProfileRepostedVideosState();

        expect(state.isRefreshing, isFalse);
        expect(state.copyWith(isRefreshing: true).isRefreshing, isTrue);
      });
    });

    group('ProfileRepostedVideosSyncRequested', () {
      blocTest<ProfileRepostedVideosBloc, ProfileRepostedVideosState>(
        'emits [success] with empty videos when no reposted IDs',
        setUp: () {
          when(
            () => mockRepostsRepository.syncUserReposts(),
          ).thenAnswer((_) async => const RepostsSyncResult.empty());
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ProfileRepostedVideosSyncRequested()),
        wait: const Duration(milliseconds: 50),
        expect: () => [
          const ProfileRepostedVideosState(
            status: ProfileRepostedVideosStatus.success,
            hasMoreContent: false,
          ),
        ],
      );

      blocTest<ProfileRepostedVideosBloc, ProfileRepostedVideosState>(
        'emits [success] with videos when reposts found',
        setUp: () {
          final addressableId1 = createAddressableId(currentUserPubkey, 'd1');
          final addressableId2 = createAddressableId(currentUserPubkey, 'd2');
          final video1 = createTestVideo(
            id: 'e1',
            pubkey: currentUserPubkey,
            vineId: 'd1',
          );
          final video2 = createTestVideo(
            id: 'e2',
            pubkey: currentUserPubkey,
            vineId: 'd2',
          );

          when(() => mockRepostsRepository.syncUserReposts()).thenAnswer(
            (_) async => RepostsSyncResult(
              orderedAddressableIds: [addressableId1, addressableId2],
              addressableIdToRepostId: {
                addressableId1: 'repost1',
                addressableId2: 'repost2',
              },
            ),
          );
          when(
            () => mockVideosRepository.getVideosByAddressableIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          ).thenAnswer((_) async => [video1, video2]);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ProfileRepostedVideosSyncRequested()),
        wait: const Duration(milliseconds: 50),
        expect: () => [
          isA<ProfileRepostedVideosState>()
              .having(
                (s) => s.status,
                'status',
                ProfileRepostedVideosStatus.success,
              )
              .having((s) => s.isRefreshing, 'isRefreshing', false)
              .having(
                (s) => s.repostedAddressableIds.length,
                'addressable IDs count',
                2,
              )
              .having((s) => s.videos.length, 'videos count', 2)
              .having((s) => s.nextPageOffset, 'nextPageOffset', 2),
        ],
      );

      blocTest<ProfileRepostedVideosBloc, ProfileRepostedVideosState>(
        'emits [failure] when sync fails and nothing is cached',
        setUp: () {
          when(
            () => mockRepostsRepository.syncUserReposts(),
          ).thenThrow(const SyncFailedException('Network error'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ProfileRepostedVideosSyncRequested()),
        wait: const Duration(milliseconds: 50),
        expect: () => [
          const ProfileRepostedVideosState(
            status: ProfileRepostedVideosStatus.failure,
            error: ProfileRepostedVideosError.syncFailed,
          ),
        ],
      );

      blocTest<ProfileRepostedVideosBloc, ProfileRepostedVideosState>(
        'serves cached snapshot, then only flips the bar off when unchanged',
        setUp: () async {
          final id1 = createAddressableId(currentUserPubkey, 'd1');
          final id2 = createAddressableId(currentUserPubkey, 'd2');
          await cacheDao.write(
            key: '$currentUserPubkey:profile_reposted_videos',
            payload: ProfileVideoListSnapshot(
              videos: [
                createTestVideo(
                  id: 'e1',
                  pubkey: currentUserPubkey,
                  vineId: 'd1',
                ),
                createTestVideo(
                  id: 'e2',
                  pubkey: currentUserPubkey,
                  vineId: 'd2',
                ),
              ],
              itemIds: [id1, id2],
              nextPageOffset: 2,
              hasMoreContent: false,
            ).toJson(),
          );
          when(() => mockRepostsRepository.syncUserReposts()).thenAnswer(
            (_) async => RepostsSyncResult(
              orderedAddressableIds: [id1, id2],
              addressableIdToRepostId: const {},
            ),
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ProfileRepostedVideosSyncRequested()),
        wait: const Duration(milliseconds: 50),
        expect: () => [
          isA<ProfileRepostedVideosState>()
              .having((s) => s.isRefreshing, 'isRefreshing', true)
              .having((s) => s.videos.length, 'cached videos', 2),
          isA<ProfileRepostedVideosState>()
              .having((s) => s.isRefreshing, 'isRefreshing', false)
              .having((s) => s.videos.length, 'unchanged videos', 2),
        ],
        verify: (_) {
          verifyNever(
            () => mockVideosRepository.getVideosByAddressableIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          );
        },
      );

      blocTest<ProfileRepostedVideosBloc, ProfileRepostedVideosState>(
        'reopen restores the full scrolled-through list from cache',
        setUp: () async {
          final ids = List.generate(
            40,
            (i) => createAddressableId(currentUserPubkey, 'd$i'),
          );
          final videos = List.generate(
            36,
            (i) => createTestVideo(
              id: 'e$i',
              pubkey: currentUserPubkey,
              vineId: 'd$i',
            ),
          );
          await cacheDao.write(
            key: '$otherUserPubkey:profile_reposted_videos',
            payload: ProfileVideoListSnapshot(
              videos: videos,
              itemIds: ids,
              nextPageOffset: 36,
              hasMoreContent: true,
            ).toJson(),
          );
          when(
            () => mockRepostsRepository.fetchUserReposts(any()),
          ).thenAnswer((_) async => ids);
        },
        build: () => createBloc(targetUserPubkey: otherUserPubkey),
        act: (bloc) => bloc.add(const ProfileRepostedVideosSyncRequested()),
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<ProfileRepostedVideosState>()
              .having((s) => s.isRefreshing, 'isRefreshing', true)
              .having((s) => s.videos.length, 'cached videos', 36)
              .having((s) => s.nextPageOffset, 'nextPageOffset', 36),
          isA<ProfileRepostedVideosState>()
              .having((s) => s.isRefreshing, 'isRefreshing', false)
              .having((s) => s.videos.length, 'revalidated videos', 36),
        ],
      );

      blocTest<ProfileRepostedVideosBloc, ProfileRepostedVideosState>(
        'preserves order of reposted addressable IDs in result',
        setUp: () {
          final addressableId1 = createAddressableId(currentUserPubkey, 'd1');
          final addressableId2 = createAddressableId(currentUserPubkey, 'd2');
          final addressableId3 = createAddressableId(currentUserPubkey, 'd3');
          final video1 = createTestVideo(
            id: 'e1',
            pubkey: currentUserPubkey,
            vineId: 'd1',
          );
          final video2 = createTestVideo(
            id: 'e2',
            pubkey: currentUserPubkey,
            vineId: 'd2',
          );
          final video3 = createTestVideo(
            id: 'e3',
            pubkey: currentUserPubkey,
            vineId: 'd3',
          );

          when(() => mockRepostsRepository.syncUserReposts()).thenAnswer(
            (_) async => RepostsSyncResult(
              orderedAddressableIds: [
                addressableId3,
                addressableId1,
                addressableId2,
              ],
              addressableIdToRepostId: const {},
            ),
          );
          when(
            () => mockVideosRepository.getVideosByAddressableIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          ).thenAnswer((_) async => [video3, video1, video2]);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ProfileRepostedVideosSyncRequested()),
        wait: const Duration(milliseconds: 50),
        expect: () => [
          isA<ProfileRepostedVideosState>()
              .having(
                (s) => s.status,
                'status',
                ProfileRepostedVideosStatus.success,
              )
              .having(
                (s) => s.videos.map((v) => v.vineId).toList(),
                'video vineIds order',
                ['d3', 'd1', 'd2'],
              ),
        ],
      );
    });

    group('ProfileRepostedVideosSubscriptionRequested', () {
      blocTest<ProfileRepostedVideosBloc, ProfileRepostedVideosState>(
        'removes video when unreposted via stream',
        build: createBloc,
        seed: () {
          final addressableId1 = createAddressableId(currentUserPubkey, 'd1');
          final addressableId2 = createAddressableId(currentUserPubkey, 'd2');
          return ProfileRepostedVideosState(
            status: ProfileRepostedVideosStatus.success,
            repostedAddressableIds: [addressableId1, addressableId2],
            videos: [
              createTestVideo(
                id: 'e1',
                pubkey: currentUserPubkey,
                vineId: 'd1',
              ),
              createTestVideo(
                id: 'e2',
                pubkey: currentUserPubkey,
                vineId: 'd2',
              ),
            ],
          );
        },
        act: (bloc) async {
          // Start subscription first
          bloc.add(const ProfileRepostedVideosSubscriptionRequested());
          // Wait for subscription to be set up
          await Future<void>.delayed(const Duration(milliseconds: 50));
          // Emit stream with addressableId2 removed (unreposted)
          repostedIdsController.add({
            createAddressableId(currentUserPubkey, 'd1'),
          });
        },
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<ProfileRepostedVideosState>()
              .having(
                (s) => s.repostedAddressableIds.length,
                'addressable IDs count',
                1,
              )
              .having((s) => s.videos.length, 'videos count', 1)
              .having(
                (s) => s.videos.first.vineId,
                'remaining video vineId',
                'd1',
              ),
        ],
      );

      blocTest<ProfileRepostedVideosBloc, ProfileRepostedVideosState>(
        'ignores stream changes during initial or syncing status',
        build: createBloc,
        seed: () => const ProfileRepostedVideosState(
          status: ProfileRepostedVideosStatus.syncing,
        ),
        act: (bloc) async {
          bloc.add(const ProfileRepostedVideosSubscriptionRequested());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          repostedIdsController.add({
            createAddressableId(currentUserPubkey, 'd1'),
          });
        },
        wait: const Duration(milliseconds: 100),
        expect: () => <ProfileRepostedVideosState>[],
      );

      blocTest<ProfileRepostedVideosBloc, ProfileRepostedVideosState>(
        'fetches and prepends the video when a new repost arrives via stream',
        setUp: () {
          when(
            () => mockVideosRepository.getVideosByAddressableIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          ).thenAnswer(
            (_) async => [
              createTestVideo(
                id: 'e2',
                pubkey: currentUserPubkey,
                vineId: 'd2',
              ),
            ],
          );
        },
        build: createBloc,
        seed: () => ProfileRepostedVideosState(
          status: ProfileRepostedVideosStatus.success,
          repostedAddressableIds: [
            createAddressableId(currentUserPubkey, 'd1'),
          ],
          videos: [
            createTestVideo(id: 'e1', pubkey: currentUserPubkey, vineId: 'd1'),
          ],
          nextPageOffset: 1,
        ),
        act: (bloc) async {
          bloc.add(const ProfileRepostedVideosSubscriptionRequested());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          // d2 reposted, prepended (most-recent-first).
          repostedIdsController.add({
            createAddressableId(currentUserPubkey, 'd2'),
            createAddressableId(currentUserPubkey, 'd1'),
          });
        },
        wait: const Duration(milliseconds: 100),
        expect: () => [
          isA<ProfileRepostedVideosState>()
              .having(
                (s) => s.repostedAddressableIds,
                'repostedAddressableIds',
                containsAll([
                  createAddressableId(currentUserPubkey, 'd1'),
                  createAddressableId(currentUserPubkey, 'd2'),
                ]),
              )
              // The new repost is fetched and shown at the top.
              .having((s) => s.videos.map((v) => v.vineId).toList(), 'videos', [
                'd2',
                'd1',
              ]),
        ],
      );
    });

    group('ProfileRepostedVideosLoadMoreRequested', () {
      blocTest<ProfileRepostedVideosBloc, ProfileRepostedVideosState>(
        'does nothing when status is not success',
        build: createBloc,
        seed: () => const ProfileRepostedVideosState(
          status: ProfileRepostedVideosStatus.loading,
        ),
        act: (bloc) => bloc.add(const ProfileRepostedVideosLoadMoreRequested()),
        expect: () => <ProfileRepostedVideosState>[],
      );

      blocTest<ProfileRepostedVideosBloc, ProfileRepostedVideosState>(
        'does nothing when already loading more',
        build: createBloc,
        seed: () => const ProfileRepostedVideosState(
          status: ProfileRepostedVideosStatus.success,
          isLoadingMore: true,
        ),
        act: (bloc) => bloc.add(const ProfileRepostedVideosLoadMoreRequested()),
        expect: () => <ProfileRepostedVideosState>[],
      );

      blocTest<ProfileRepostedVideosBloc, ProfileRepostedVideosState>(
        'does nothing when no more content',
        build: createBloc,
        seed: () => const ProfileRepostedVideosState(
          status: ProfileRepostedVideosStatus.success,
          hasMoreContent: false,
        ),
        act: (bloc) => bloc.add(const ProfileRepostedVideosLoadMoreRequested()),
        expect: () => <ProfileRepostedVideosState>[],
      );

      blocTest<ProfileRepostedVideosBloc, ProfileRepostedVideosState>(
        'sets hasMoreContent to false when all videos loaded',
        build: createBloc,
        seed: () => ProfileRepostedVideosState(
          status: ProfileRepostedVideosStatus.success,
          videos: [
            createTestVideo(id: 'e1', pubkey: currentUserPubkey, vineId: 'd1'),
          ],
          repostedAddressableIds: [
            createAddressableId(currentUserPubkey, 'd1'),
          ],
          nextPageOffset: 1,
        ),
        act: (bloc) => bloc.add(const ProfileRepostedVideosLoadMoreRequested()),
        expect: () => [
          isA<ProfileRepostedVideosState>().having(
            (s) => s.hasMoreContent,
            'hasMoreContent',
            false,
          ),
        ],
      );

      blocTest<ProfileRepostedVideosBloc, ProfileRepostedVideosState>(
        'loads next page of videos',
        setUp: () {
          final video3 = createTestVideo(
            id: 'e3',
            pubkey: currentUserPubkey,
            vineId: 'd3',
          );
          when(
            () => mockVideosRepository.getVideosByAddressableIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          ).thenAnswer((_) async => [video3]);
        },
        build: createBloc,
        seed: () => ProfileRepostedVideosState(
          status: ProfileRepostedVideosStatus.success,
          repostedAddressableIds: [
            createAddressableId(currentUserPubkey, 'd1'),
            createAddressableId(currentUserPubkey, 'd2'),
            createAddressableId(currentUserPubkey, 'd3'),
          ],
          videos: [
            createTestVideo(id: 'e1', pubkey: currentUserPubkey, vineId: 'd1'),
            createTestVideo(id: 'e2', pubkey: currentUserPubkey, vineId: 'd2'),
          ],
        ),
        act: (bloc) => bloc.add(const ProfileRepostedVideosLoadMoreRequested()),
        expect: () => [
          isA<ProfileRepostedVideosState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            true,
          ),
          isA<ProfileRepostedVideosState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', false)
              .having((s) => s.videos.length, 'videos count', 3)
              .having((s) => s.hasMoreContent, 'hasMoreContent', false),
        ],
      );
    });

    group('close', () {
      test('cancels reposted IDs subscription', () async {
        final bloc = createBloc();

        await bloc.close();

        // After closing, stream events should not cause errors
        expect(
          () => repostedIdsController.add({
            createAddressableId(currentUserPubkey, 'd1'),
          }),
          returnsNormally,
        );
      });
    });

    group('Other user profile (targetUserPubkey)', () {
      setUp(() {
        // Set up fetchUserReposts for other user
        when(
          () => mockRepostsRepository.fetchUserReposts(any()),
        ).thenAnswer((_) async => <String>[]);
      });

      blocTest<ProfileRepostedVideosBloc, ProfileRepostedVideosState>(
        'fetches reposts via repository.fetchUserReposts for other user',
        build: () => createBloc(targetUserPubkey: otherUserPubkey),
        act: (bloc) => bloc.add(const ProfileRepostedVideosSyncRequested()),
        wait: const Duration(milliseconds: 100),
        expect: () => [
          const ProfileRepostedVideosState(
            status: ProfileRepostedVideosStatus.success,
            hasMoreContent: false,
          ),
        ],
        verify: (_) {
          // Should NOT use syncUserReposts for other users
          verifyNever(() => mockRepostsRepository.syncUserReposts());
          // Should use fetchUserReposts with the target user's pubkey
          verify(
            () => mockRepostsRepository.fetchUserReposts(otherUserPubkey),
          ).called(1);
        },
      );

      blocTest<ProfileRepostedVideosBloc, ProfileRepostedVideosState>(
        'does not subscribe to repository stream for other user profile',
        build: () => createBloc(targetUserPubkey: otherUserPubkey),
        act: (bloc) async {
          bloc.add(const ProfileRepostedVideosSubscriptionRequested());
          await Future<void>.delayed(const Duration(milliseconds: 50));
          // Try to emit on the reposted IDs stream
          repostedIdsController.add({
            createAddressableId(currentUserPubkey, 'd1'),
          });
        },
        wait: const Duration(milliseconds: 100),
        expect: () => <ProfileRepostedVideosState>[],
      );

      blocTest<ProfileRepostedVideosBloc, ProfileRepostedVideosState>(
        'uses syncUserReposts when targetUserPubkey matches current user',
        setUp: () {
          when(
            () => mockRepostsRepository.syncUserReposts(),
          ).thenAnswer((_) async => const RepostsSyncResult.empty());
        },
        build: () => createBloc(targetUserPubkey: currentUserPubkey),
        act: (bloc) => bloc.add(const ProfileRepostedVideosSyncRequested()),
        wait: const Duration(milliseconds: 50),
        expect: () => [
          const ProfileRepostedVideosState(
            status: ProfileRepostedVideosStatus.success,
            hasMoreContent: false,
          ),
        ],
        verify: (_) {
          // Should use syncUserReposts when pubkey matches current user
          verify(() => mockRepostsRepository.syncUserReposts()).called(1);
          // Should NOT use fetchUserReposts for own profile
          verifyNever(() => mockRepostsRepository.fetchUserReposts(any()));
        },
      );

      blocTest<ProfileRepostedVideosBloc, ProfileRepostedVideosState>(
        'loads videos for other user when reposts are found',
        setUp: () {
          final addressableId1 = createAddressableId(otherUserPubkey, 'd1');
          final video1 = createTestVideo(
            id: 'e1',
            pubkey: otherUserPubkey,
            vineId: 'd1',
          );

          when(
            () => mockRepostsRepository.fetchUserReposts(otherUserPubkey),
          ).thenAnswer((_) async => [addressableId1]);

          when(
            () => mockVideosRepository.getVideosByAddressableIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          ).thenAnswer((_) async => [video1]);
        },
        build: () => createBloc(targetUserPubkey: otherUserPubkey),
        act: (bloc) => bloc.add(const ProfileRepostedVideosSyncRequested()),
        wait: const Duration(milliseconds: 50),
        expect: () => [
          isA<ProfileRepostedVideosState>()
              .having(
                (s) => s.status,
                'status',
                ProfileRepostedVideosStatus.success,
              )
              .having((s) => s.videos.length, 'videos count', 1)
              .having(
                (s) => s.videos.first.pubkey,
                'video pubkey',
                otherUserPubkey,
              ),
        ],
      );
    });
  });
}
