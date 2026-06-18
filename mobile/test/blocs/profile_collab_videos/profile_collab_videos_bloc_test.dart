// ABOUTME: Tests for ProfileCollabVideosBloc - fetching and paginating collab
// ABOUTME: videos. Tests confirmed repository fetch and state management.

import 'package:bloc_test/bloc_test.dart';
import 'package:cache_sync/cache_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/profile_collab_videos/profile_collab_videos_bloc.dart';
import 'package:openvine/blocs/profile_shared/profile_video_cursor_snapshot.dart';
import 'package:videos_repository/videos_repository.dart';

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
  group(ProfileCollabVideosBloc, () {
    late _MockVideosRepository mockVideosRepository;
    late _InMemoryCacheDao cacheDao;

    // 64-character hex pubkeys for testing
    const targetPubkey =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const authorPubkey =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

    setUp(() async {
      mockVideosRepository = _MockVideosRepository();
      cacheDao = _InMemoryCacheDao();
      await CacheSync.init(dao: cacheDao);
    });

    ProfileCollabVideosBloc createBloc() => ProfileCollabVideosBloc(
      videosRepository: mockVideosRepository,
      targetUserPubkey: targetPubkey,
    );

    VideoEvent createTestVideo({
      required String id,
      required String pubkey,
      List<String> collaboratorPubkeys = const [],
      int createdAt = 1700000000,
    }) {
      final timestamp = DateTime.fromMillisecondsSinceEpoch(createdAt * 1000);
      return VideoEvent(
        id: id,
        pubkey: pubkey,
        createdAt: createdAt,
        content: '',
        timestamp: timestamp,
        title: 'Test Video $id',
        videoUrl: 'https://example.com/video.mp4',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        vineId: 'vine-$id',
        collaboratorPubkeys: collaboratorPubkeys,
      );
    }

    test('initial state is initial with empty collections', () {
      final bloc = createBloc();
      expect(bloc.state.status, ProfileCollabVideosStatus.initial);
      expect(bloc.state.videos, isEmpty);
      expect(bloc.state.status, isNot(ProfileCollabVideosStatus.failure));
      expect(bloc.state.isLoadingMore, isFalse);
      expect(bloc.state.hasMoreContent, isTrue);
      expect(bloc.state.paginationCursor, isNull);
      bloc.close();
    });

    group(ProfileCollabVideosState, () {
      test('isLoaded returns true when status is success', () {
        const initialState = ProfileCollabVideosState();
        const successState = ProfileCollabVideosState(
          status: ProfileCollabVideosStatus.success,
        );

        expect(initialState.isLoaded, isFalse);
        expect(successState.isLoaded, isTrue);
      });

      test('isLoading returns true when status is loading', () {
        const initialState = ProfileCollabVideosState();
        const loadingState = ProfileCollabVideosState(
          status: ProfileCollabVideosStatus.loading,
        );

        expect(initialState.isLoading, isFalse);
        expect(loadingState.isLoading, isTrue);
      });

      test('copyWith creates copy with updated values', () {
        const state = ProfileCollabVideosState();
        final updated = state.copyWith(
          status: ProfileCollabVideosStatus.success,
          videos: [
            createTestVideo(
              id: 'v1',
              pubkey: authorPubkey,
              collaboratorPubkeys: [targetPubkey],
            ),
          ],
          hasMoreContent: false,
          paginationCursor: 1700000000,
        );

        expect(updated.status, ProfileCollabVideosStatus.success);
        expect(updated.videos, hasLength(1));
        expect(updated.hasMoreContent, isFalse);
        expect(updated.paginationCursor, equals(1700000000));
      });

      test('copyWith status resets from failure', () {
        const state = ProfileCollabVideosState(
          status: ProfileCollabVideosStatus.failure,
        );
        final updated = state.copyWith(
          status: ProfileCollabVideosStatus.initial,
        );

        expect(updated.status, ProfileCollabVideosStatus.initial);
      });

      test('props are correct for Equatable', () {
        const state1 = ProfileCollabVideosState();
        const state2 = ProfileCollabVideosState();

        expect(state1, equals(state2));
      });
    });

    group('ProfileCollabVideosFetchRequested', () {
      blocTest<ProfileCollabVideosBloc, ProfileCollabVideosState>(
        'emits [loading, success] when fetch succeeds with collab videos',
        build: () {
          when(
            () => mockVideosRepository.getCollabVideos(
              taggedPubkey: targetPubkey,
              limit: any(named: 'limit'),
            ),
          ).thenAnswer(
            (_) async => [
              createTestVideo(
                id: 'v1',
                pubkey: authorPubkey,
                collaboratorPubkeys: [targetPubkey],
              ),
            ],
          );
          return createBloc();
        },
        act: (bloc) => bloc.add(const ProfileCollabVideosFetchRequested()),
        expect: () => [
          isA<ProfileCollabVideosState>().having(
            (s) => s.status,
            'status',
            ProfileCollabVideosStatus.loading,
          ),
          isA<ProfileCollabVideosState>()
              .having(
                (s) => s.status,
                'status',
                ProfileCollabVideosStatus.success,
              )
              .having((s) => s.videos, 'videos', hasLength(1))
              .having(
                (s) => s.status,
                'status',
                isNot(ProfileCollabVideosStatus.failure),
              ),
        ],
      );

      blocTest<ProfileCollabVideosBloc, ProfileCollabVideosState>(
        'emits [loading, success] with empty list when no collab videos',
        build: () {
          when(
            () => mockVideosRepository.getCollabVideos(
              taggedPubkey: targetPubkey,
              limit: any(named: 'limit'),
            ),
          ).thenAnswer((_) async => []);
          return createBloc();
        },
        act: (bloc) => bloc.add(const ProfileCollabVideosFetchRequested()),
        expect: () => [
          isA<ProfileCollabVideosState>().having(
            (s) => s.status,
            'status',
            ProfileCollabVideosStatus.loading,
          ),
          isA<ProfileCollabVideosState>()
              .having(
                (s) => s.status,
                'status',
                ProfileCollabVideosStatus.success,
              )
              .having((s) => s.videos, 'videos', isEmpty)
              .having((s) => s.hasMoreContent, 'hasMoreContent', isFalse),
        ],
      );

      blocTest<ProfileCollabVideosBloc, ProfileCollabVideosState>(
        'trusts repository results as confirmed collabs without p-tag filtering',
        build: () {
          when(
            () => mockVideosRepository.getCollabVideos(
              taggedPubkey: targetPubkey,
              limit: any(named: 'limit'),
            ),
          ).thenAnswer(
            (_) async => [
              createTestVideo(
                id: 'v1',
                pubkey: targetPubkey,
              ),
              createTestVideo(
                id: 'v2',
                pubkey: authorPubkey,
                collaboratorPubkeys: ['someoneelse'],
              ),
            ],
          );
          return createBloc();
        },
        act: (bloc) => bloc.add(const ProfileCollabVideosFetchRequested()),
        expect: () => [
          isA<ProfileCollabVideosState>().having(
            (s) => s.status,
            'status',
            ProfileCollabVideosStatus.loading,
          ),
          isA<ProfileCollabVideosState>()
              .having(
                (s) => s.status,
                'status',
                ProfileCollabVideosStatus.success,
              )
              .having((s) => s.videos, 'videos', hasLength(2))
              .having((s) => s.videos[0].id, 'first video id', equals('v1'))
              .having((s) => s.videos[1].id, 'second video id', equals('v2')),
        ],
      );

      blocTest<ProfileCollabVideosBloc, ProfileCollabVideosState>(
        'emits [loading, failure] when fetch throws',
        build: () {
          when(
            () => mockVideosRepository.getCollabVideos(
              taggedPubkey: targetPubkey,
              limit: any(named: 'limit'),
            ),
          ).thenThrow(Exception('Network error'));
          return createBloc();
        },
        act: (bloc) => bloc.add(const ProfileCollabVideosFetchRequested()),
        expect: () => [
          isA<ProfileCollabVideosState>().having(
            (s) => s.status,
            'status',
            ProfileCollabVideosStatus.loading,
          ),
          isA<ProfileCollabVideosState>()
              .having(
                (s) => s.status,
                'status',
                ProfileCollabVideosStatus.failure,
              )
              .having(
                (s) => s.status,
                'failure status',
                ProfileCollabVideosStatus.failure,
              ),
        ],
      );

      blocTest<ProfileCollabVideosBloc, ProfileCollabVideosState>(
        'reopen serves cache, then reconciles against the confirmed feed',
        build: () {
          // Authoritative confirmed feed now: [new, cached-1] — cached-2 is no
          // longer confirmed (removed), new was added.
          when(
            () => mockVideosRepository.getCollabVideos(
              taggedPubkey: targetPubkey,
              limit: any(named: 'limit'),
            ),
          ).thenAnswer(
            (_) async => [
              createTestVideo(id: 'new', pubkey: authorPubkey),
              createTestVideo(id: 'cached-1', pubkey: authorPubkey),
            ],
          );
          return createBloc();
        },
        setUp: () async {
          await cacheDao.write(
            key: '$targetPubkey:profile_collab_videos',
            payload: ProfileVideoCursorSnapshot(
              videos: [
                createTestVideo(id: 'cached-1', pubkey: authorPubkey),
                createTestVideo(id: 'cached-2', pubkey: authorPubkey),
              ],
              paginationCursor: 100,
              hasMoreContent: false,
            ).toJson(),
          );
        },
        act: (bloc) => bloc.add(const ProfileCollabVideosFetchRequested()),
        wait: const Duration(milliseconds: 50),
        expect: () => [
          // Cached feed served instantly.
          isA<ProfileCollabVideosState>()
              .having((s) => s.isRefreshing, 'isRefreshing', true)
              .having((s) => s.videos.map((v) => v.id).toList(), 'cached', [
                'cached-1',
                'cached-2',
              ]),
          // Fresh page is authoritative: new prepended, the unconfirmed
          // cached-2 dropped.
          isA<ProfileCollabVideosState>()
              .having((s) => s.isRefreshing, 'isRefreshing', false)
              .having((s) => s.videos.map((v) => v.id).toList(), 'reconciled', [
                'new',
                'cached-1',
              ]),
        ],
      );

      blocTest<ProfileCollabVideosBloc, ProfileCollabVideosState>(
        'reopen preserves cached tail after a full first-page overlap',
        build: () {
          when(
            () => mockVideosRepository.getCollabVideos(
              taggedPubkey: targetPubkey,
              limit: any(named: 'limit'),
            ),
          ).thenAnswer(
            (_) async => [
              for (var i = 1; i <= 17; i++)
                createTestVideo(id: 'cached-$i', pubkey: authorPubkey),
              createTestVideo(id: 'new-confirmed', pubkey: authorPubkey),
            ],
          );
          return createBloc();
        },
        setUp: () async {
          await cacheDao.write(
            key: '$targetPubkey:profile_collab_videos',
            payload: ProfileVideoCursorSnapshot(
              videos: [
                for (var i = 1; i <= 17; i++)
                  createTestVideo(id: 'cached-$i', pubkey: authorPubkey),
                createTestVideo(id: 'tail-1', pubkey: authorPubkey),
              ],
              paginationCursor: 100,
              hasMoreContent: true,
            ).toJson(),
          );
        },
        act: (bloc) => bloc.add(const ProfileCollabVideosFetchRequested()),
        wait: const Duration(milliseconds: 50),
        expect: () => [
          isA<ProfileCollabVideosState>()
              .having((s) => s.isRefreshing, 'isRefreshing', true)
              .having((s) => s.videos.last.id, 'cached tail', 'tail-1'),
          isA<ProfileCollabVideosState>()
              .having((s) => s.isRefreshing, 'isRefreshing', false)
              .having(
                (s) => s.videos.map((v) => v.id).toList(),
                'videos',
                [
                  for (var i = 1; i <= 17; i++) 'cached-$i',
                  'new-confirmed',
                  'tail-1',
                ],
              )
              .having((s) => s.hasMoreContent, 'hasMoreContent', isTrue),
        ],
      );

      blocTest<ProfileCollabVideosBloc, ProfileCollabVideosState>(
        'droppable: ignores a second fetch while one is in flight',
        build: () {
          when(
            () => mockVideosRepository.getCollabVideos(
              taggedPubkey: targetPubkey,
              limit: any(named: 'limit'),
            ),
          ).thenAnswer((_) async => []);
          return createBloc();
        },
        act: (bloc) {
          bloc
            ..add(const ProfileCollabVideosFetchRequested())
            ..add(const ProfileCollabVideosFetchRequested());
        },
        wait: const Duration(milliseconds: 50),
        verify: (_) {
          verify(
            () => mockVideosRepository.getCollabVideos(
              taggedPubkey: targetPubkey,
              limit: any(named: 'limit'),
            ),
          ).called(1);
        },
      );
    });

    group('ProfileCollabVideosLoadMoreRequested', () {
      blocTest<ProfileCollabVideosBloc, ProfileCollabVideosState>(
        'appends new videos to existing list',
        build: () {
          when(
            () => mockVideosRepository.getCollabVideos(
              taggedPubkey: targetPubkey,
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer(
            (_) async => [
              createTestVideo(
                id: 'v3',
                pubkey: authorPubkey,
                collaboratorPubkeys: [targetPubkey],
                createdAt: 1699999000,
              ),
            ],
          );
          return createBloc();
        },
        seed: () => ProfileCollabVideosState(
          status: ProfileCollabVideosStatus.success,
          videos: [
            createTestVideo(
              id: 'v1',
              pubkey: authorPubkey,
              collaboratorPubkeys: [targetPubkey],
            ),
          ],
          paginationCursor: 1700000000,
        ),
        act: (bloc) => bloc.add(const ProfileCollabVideosLoadMoreRequested()),
        expect: () => [
          isA<ProfileCollabVideosState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            isTrue,
          ),
          isA<ProfileCollabVideosState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', isFalse)
              .having((s) => s.videos, 'videos', hasLength(2)),
        ],
      );

      blocTest<ProfileCollabVideosBloc, ProfileCollabVideosState>(
        'does not load more when not in success state',
        build: createBloc,
        seed: () => const ProfileCollabVideosState(
          status: ProfileCollabVideosStatus.loading,
        ),
        act: (bloc) => bloc.add(const ProfileCollabVideosLoadMoreRequested()),
        expect: () => <ProfileCollabVideosState>[],
      );

      blocTest<ProfileCollabVideosBloc, ProfileCollabVideosState>(
        'does not load more when already loading more',
        build: createBloc,
        seed: () => const ProfileCollabVideosState(
          status: ProfileCollabVideosStatus.success,
          isLoadingMore: true,
        ),
        act: (bloc) => bloc.add(const ProfileCollabVideosLoadMoreRequested()),
        expect: () => <ProfileCollabVideosState>[],
      );

      blocTest<ProfileCollabVideosBloc, ProfileCollabVideosState>(
        'does not load more when no more content',
        build: createBloc,
        seed: () => const ProfileCollabVideosState(
          status: ProfileCollabVideosStatus.success,
          hasMoreContent: false,
        ),
        act: (bloc) => bloc.add(const ProfileCollabVideosLoadMoreRequested()),
        expect: () => <ProfileCollabVideosState>[],
      );

      blocTest<ProfileCollabVideosBloc, ProfileCollabVideosState>(
        'deduplicates videos from load more results',
        build: () {
          when(
            () => mockVideosRepository.getCollabVideos(
              taggedPubkey: targetPubkey,
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenAnswer(
            (_) async => [
              // Duplicate of existing video
              createTestVideo(
                id: 'v1',
                pubkey: authorPubkey,
                collaboratorPubkeys: [targetPubkey],
              ),
              // New video
              createTestVideo(
                id: 'v2',
                pubkey: authorPubkey,
                collaboratorPubkeys: [targetPubkey],
              ),
            ],
          );
          return createBloc();
        },
        seed: () => ProfileCollabVideosState(
          status: ProfileCollabVideosStatus.success,
          videos: [
            createTestVideo(
              id: 'v1',
              pubkey: authorPubkey,
              collaboratorPubkeys: [targetPubkey],
            ),
          ],
          paginationCursor: 1700000000,
        ),
        act: (bloc) => bloc.add(const ProfileCollabVideosLoadMoreRequested()),
        expect: () => [
          isA<ProfileCollabVideosState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            isTrue,
          ),
          isA<ProfileCollabVideosState>()
              .having((s) => s.videos, 'videos', hasLength(2))
              .having((s) => s.isLoadingMore, 'isLoadingMore', isFalse),
        ],
      );

      blocTest<ProfileCollabVideosBloc, ProfileCollabVideosState>(
        'handles error during load more gracefully',
        build: () {
          when(
            () => mockVideosRepository.getCollabVideos(
              taggedPubkey: targetPubkey,
              limit: any(named: 'limit'),
              until: any(named: 'until'),
            ),
          ).thenThrow(Exception('Network error'));
          return createBloc();
        },
        seed: () => ProfileCollabVideosState(
          status: ProfileCollabVideosStatus.success,
          videos: [
            createTestVideo(
              id: 'v1',
              pubkey: authorPubkey,
              collaboratorPubkeys: [targetPubkey],
            ),
          ],
          paginationCursor: 1700000000,
        ),
        act: (bloc) => bloc.add(const ProfileCollabVideosLoadMoreRequested()),
        expect: () => [
          isA<ProfileCollabVideosState>().having(
            (s) => s.isLoadingMore,
            'isLoadingMore',
            isTrue,
          ),
          isA<ProfileCollabVideosState>()
              .having((s) => s.isLoadingMore, 'isLoadingMore', isFalse)
              // Original videos preserved on error
              .having((s) => s.videos, 'videos', hasLength(1)),
        ],
      );
    });
  });
}
