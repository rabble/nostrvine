// ABOUTME: Tests for ProfileCollabVideosBloc - fetching and paginating collab
// ABOUTME: videos. Tests funnelcake-primary fetch, client-side filtering, and
// ABOUTME: state management.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/profile_collab_videos/profile_collab_videos_bloc.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockVideosRepository extends Mock implements VideosRepository {}

void main() {
  group(ProfileCollabVideosBloc, () {
    late _MockVideosRepository mockVideosRepository;

    // 64-character hex pubkeys for testing
    const targetPubkey =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const authorPubkey =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

    setUp(() {
      mockVideosRepository = _MockVideosRepository();
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
      expect(bloc.state.error, isNull);
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

      test('copyWith clearError sets error to null', () {
        const state = ProfileCollabVideosState(error: 'Some error');
        final updated = state.copyWith(clearError: true);

        expect(updated.error, isNull);
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
                createdAt: 1700000000,
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
              .having((s) => s.error, 'error', isNull),
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
        'filters out videos where target user is the author',
        build: () {
          when(
            () => mockVideosRepository.getCollabVideos(
              taggedPubkey: targetPubkey,
              limit: any(named: 'limit'),
            ),
          ).thenAnswer(
            (_) async => [
              // Author is targetPubkey - should be filtered OUT
              createTestVideo(
                id: 'v1',
                pubkey: targetPubkey,
                collaboratorPubkeys: [targetPubkey],
              ),
              // Author is someone else, target is collab - should STAY
              createTestVideo(
                id: 'v2',
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
              .having((s) => s.videos.first.id, 'first video id', equals('v2')),
        ],
      );

      blocTest<ProfileCollabVideosBloc, ProfileCollabVideosState>(
        'filters out videos where target is not in collaboratorPubkeys',
        build: () {
          when(
            () => mockVideosRepository.getCollabVideos(
              taggedPubkey: targetPubkey,
              limit: any(named: 'limit'),
            ),
          ).thenAnswer(
            (_) async => [
              // Target NOT in collaborators - should be filtered OUT
              createTestVideo(
                id: 'v1',
                pubkey: authorPubkey,
                collaboratorPubkeys: ['someoneelse'],
              ),
              // Target IS in collaborators - should STAY
              createTestVideo(
                id: 'v2',
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
              .having((s) => s.videos, 'videos', hasLength(1))
              .having((s) => s.videos.first.id, 'first video id', equals('v2')),
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
              .having((s) => s.error, 'error', isNotNull),
        ],
      );

      blocTest<ProfileCollabVideosBloc, ProfileCollabVideosState>(
        'does not re-fetch when already loading',
        build: () {
          when(
            () => mockVideosRepository.getCollabVideos(
              taggedPubkey: targetPubkey,
              limit: any(named: 'limit'),
            ),
          ).thenAnswer((_) async => []);
          return createBloc();
        },
        seed: () => const ProfileCollabVideosState(
          status: ProfileCollabVideosStatus.loading,
        ),
        act: (bloc) => bloc.add(const ProfileCollabVideosFetchRequested()),
        expect: () => <ProfileCollabVideosState>[],
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
              createdAt: 1700000000,
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
