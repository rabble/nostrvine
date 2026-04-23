// ABOUTME: Tests for ProfileSavedVideosBloc — loading bookmarked videos from
// ABOUTME: BookmarkService and paginating through VideosRepository.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/profile_saved_videos/profile_saved_videos_bloc.dart';
import 'package:openvine/services/bookmark_service.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockBookmarkService extends Mock implements BookmarkService {}

class _MockVideosRepository extends Mock implements VideosRepository {}

void main() {
  group('ProfileSavedVideosBloc', () {
    late _MockBookmarkService mockBookmarkService;
    late _MockVideosRepository mockVideosRepository;

    setUp(() {
      mockBookmarkService = _MockBookmarkService();
      mockVideosRepository = _MockVideosRepository();
    });

    ProfileSavedVideosBloc createBloc() => ProfileSavedVideosBloc(
      bookmarkService: Future.value(mockBookmarkService),
      videosRepository: mockVideosRepository,
    );

    VideoEvent createTestVideo(String id) {
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
      expect(bloc.state.status, ProfileSavedVideosStatus.initial);
      expect(bloc.state.videos, isEmpty);
      expect(bloc.state.savedEventIds, isEmpty);
      expect(bloc.state.error, isNull);
      bloc.close();
    });

    group('ProfileSavedVideosState', () {
      test('isLoaded returns true when status is success', () {
        const initialState = ProfileSavedVideosState();
        const successState = ProfileSavedVideosState(
          status: ProfileSavedVideosStatus.success,
        );

        expect(initialState.isLoaded, isFalse);
        expect(successState.isLoaded, isTrue);
      });

      test('isLoading returns true when status is loading or syncing', () {
        const loadingState = ProfileSavedVideosState(
          status: ProfileSavedVideosStatus.loading,
        );
        const syncingState = ProfileSavedVideosState(
          status: ProfileSavedVideosStatus.syncing,
        );
        const successState = ProfileSavedVideosState(
          status: ProfileSavedVideosStatus.success,
        );

        expect(loadingState.isLoading, isTrue);
        expect(syncingState.isLoading, isTrue);
        expect(successState.isLoading, isFalse);
      });
    });

    group('ProfileSavedVideosSyncRequested', () {
      blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
        'emits success with empty list when there are no bookmarks',
        setUp: () {
          when(() => mockBookmarkService.globalBookmarks).thenReturn(const []);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ProfileSavedVideosSyncRequested()),
        expect: () => [
          const ProfileSavedVideosState(
            status: ProfileSavedVideosStatus.syncing,
          ),
          const ProfileSavedVideosState(
            status: ProfileSavedVideosStatus.success,
            hasMoreContent: false,
          ),
        ],
      );

      blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
        'filters non-event bookmarks (hashtags, urls) and loads videos for '
        'event bookmarks',
        setUp: () {
          when(() => mockBookmarkService.globalBookmarks).thenReturn(const [
            BookmarkItem(type: 'e', id: 'video-1'),
            BookmarkItem(type: 't', id: 'flutter'),
            BookmarkItem(type: 'e', id: 'video-2'),
            BookmarkItem(type: 'r', id: 'https://example.com'),
          ]);
          when(
            () => mockVideosRepository.getVideosByIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          ).thenAnswer(
            (_) async => [
              createTestVideo('video-1'),
              createTestVideo('video-2'),
            ],
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ProfileSavedVideosSyncRequested()),
        verify: (bloc) {
          expect(bloc.state.status, ProfileSavedVideosStatus.success);
          expect(bloc.state.videos, hasLength(2));
          expect(bloc.state.savedEventIds, equals(['video-1', 'video-2']));
          expect(bloc.state.hasMoreContent, isFalse);
          verify(
            () => mockVideosRepository.getVideosByIds(
              ['video-1', 'video-2'],
              cacheResults: true,
            ),
          ).called(1);
        },
      );

      blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
        'emits failure when fetching videos throws',
        setUp: () {
          when(() => mockBookmarkService.globalBookmarks).thenReturn(const [
            BookmarkItem(type: 'e', id: 'video-1'),
          ]);
          when(
            () => mockVideosRepository.getVideosByIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          ).thenThrow(Exception('relay error'));
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ProfileSavedVideosSyncRequested()),
        verify: (bloc) {
          expect(bloc.state.status, ProfileSavedVideosStatus.failure);
          expect(bloc.state.error, ProfileSavedVideosError.loadFailed);
        },
        errors: () => [isA<Exception>()],
      );
    });

    group('ProfileSavedVideosLoadMoreRequested', () {
      // Build a list that exceeds the 18-item page size so hasMoreContent
      // starts true and a second fetch is required.
      final manyBookmarks = List.generate(
        25,
        (i) => BookmarkItem(type: 'e', id: 'video-$i'),
      );

      blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
        'fetches the next page and advances offset',
        setUp: () {
          when(
            () => mockBookmarkService.globalBookmarks,
          ).thenReturn(manyBookmarks);
          when(
            () => mockVideosRepository.getVideosByIds(
              any(),
              cacheResults: any(named: 'cacheResults'),
            ),
          ).thenAnswer((invocation) async {
            final ids = invocation.positionalArguments.first as List<String>;
            return ids.map(createTestVideo).toList();
          });
        },
        build: createBloc,
        act: (bloc) async {
          bloc.add(const ProfileSavedVideosSyncRequested());
          // Wait for sync to complete before requesting more.
          await bloc.stream.firstWhere(
            (state) => state.status == ProfileSavedVideosStatus.success,
          );
          bloc.add(const ProfileSavedVideosLoadMoreRequested());
        },
        verify: (bloc) {
          expect(bloc.state.status, ProfileSavedVideosStatus.success);
          expect(bloc.state.videos, hasLength(25));
          expect(bloc.state.nextPageOffset, 25);
          expect(bloc.state.hasMoreContent, isFalse);
          expect(bloc.state.isLoadingMore, isFalse);
        },
      );

      blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
        'is a no-op when hasMoreContent is false',
        build: createBloc,
        seed: () => const ProfileSavedVideosState(
          status: ProfileSavedVideosStatus.success,
          hasMoreContent: false,
        ),
        act: (bloc) => bloc.add(const ProfileSavedVideosLoadMoreRequested()),
        expect: () => const <ProfileSavedVideosState>[],
      );

      blocTest<ProfileSavedVideosBloc, ProfileSavedVideosState>(
        'is a no-op when already loading more',
        build: createBloc,
        seed: () => const ProfileSavedVideosState(
          status: ProfileSavedVideosStatus.success,
          isLoadingMore: true,
        ),
        act: (bloc) => bloc.add(const ProfileSavedVideosLoadMoreRequested()),
        expect: () => const <ProfileSavedVideosState>[],
      );
    });
  });
}
