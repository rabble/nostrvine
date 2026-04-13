// ABOUTME: Tests for the CategoriesBloc
// ABOUTME: Verifies category loading, selection, pagination, sorting, and deselection

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/categories/categories_bloc.dart';
import 'package:openvine/models/video_category.dart';
import 'package:openvine/repositories/categories_repository.dart';

class _MockCategoriesRepository extends Mock implements CategoriesRepository {}

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

const _viewerPubkey =
    '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';

void main() {
  late _MockCategoriesRepository mockRepository;
  late _MockFunnelcakeApiClient mockApiClient;

  setUp(() {
    mockApiClient = _MockFunnelcakeApiClient();
    mockRepository = _MockCategoriesRepository();
    // CategoriesBloc uses repository.apiClient for video-level calls.
    when(() => mockRepository.apiClient).thenReturn(mockApiClient);
  });

  group(CategoriesBloc, () {
    group('CategoriesLoadRequested', () {
      final categories = [
        const VideoCategory(name: 'music', videoCount: 1500),
        const VideoCategory(name: 'comedy', videoCount: 900),
        const VideoCategory(name: 'dance', videoCount: 800),
      ];

      blocTest<CategoriesBloc, CategoriesState>(
        'emits [loading, loaded] when categories load successfully',
        setUp: () {
          when(
            () => mockRepository.getCategories(),
          ).thenAnswer((_) async => categories);
        },
        build: () => CategoriesBloc(
          categoriesRepository: mockRepository,
          currentUserPubkey: _viewerPubkey,
        ),
        act: (bloc) => bloc.add(const CategoriesLoadRequested()),
        expect: () => [
          const CategoriesState(categoriesStatus: CategoriesStatus.loading),
          const CategoriesState(
            categoriesStatus: CategoriesStatus.loaded,
            categories: [
              VideoCategory(name: 'music', videoCount: 1500),
              VideoCategory(name: 'comedy', videoCount: 900),
              VideoCategory(name: 'dance', videoCount: 800),
            ],
          ),
        ],
        verify: (_) {
          verify(() => mockRepository.getCategories()).called(1);
        },
      );

      blocTest<CategoriesBloc, CategoriesState>(
        'emits [loading, error] when repository throws',
        setUp: () {
          when(
            () => mockRepository.getCategories(),
          ).thenThrow(const FunnelcakeException('Network error'));
        },
        build: () => CategoriesBloc(
          categoriesRepository: mockRepository,
          currentUserPubkey: _viewerPubkey,
        ),
        act: (bloc) => bloc.add(const CategoriesLoadRequested()),
        expect: () => [
          const CategoriesState(categoriesStatus: CategoriesStatus.loading),
          isA<CategoriesState>()
              .having(
                (s) => s.categoriesStatus,
                'categoriesStatus',
                CategoriesStatus.error,
              )
              .having(
                (s) => s.categoriesStatus,
                'failure status',
                CategoriesStatus.error,
              ),
        ],
      );

      test(
        'does not re-fetch while a load is already in progress',
        () async {
          // Use a Completer to keep the first request suspended so the second
          // event arrives while the bloc is still in loading state.
          final completer = Completer<List<VideoCategory>>();
          when(
            () => mockRepository.getCategories(),
          ).thenAnswer((_) => completer.future);

          final bloc = CategoriesBloc(categoriesRepository: mockRepository);

          // First request — bloc enters loading state.
          bloc.add(const CategoriesLoadRequested());
          await Future<void>.delayed(Duration.zero);

          // Second request while first is still suspended.
          bloc.add(const CategoriesLoadRequested());
          await Future<void>.delayed(Duration.zero);

          // Only one network call should have been made.
          verify(() => mockRepository.getCategories()).called(1);

          // Clean up.
          completer.complete([]);
          await bloc.close();
        },
      );
    });

    group('CategorySelected', () {
      const category = VideoCategory(name: 'music', videoCount: 1500);

      final mockVideoStats = [
        _createVideoStats('id1'),
        _createVideoStats('id2'),
      ];

      blocTest<CategoriesBloc, CategoriesState>(
        'emits [loading, loaded] with videos for selected category',
        setUp: () {
          when(
            () => mockApiClient.getVideosByCategory(
              category: 'music',
            ),
          ).thenAnswer((_) async => mockVideoStats);
        },
        build: () => CategoriesBloc(categoriesRepository: mockRepository),
        act: (bloc) => bloc.add(const CategorySelected(category)),
        expect: () => [
          const CategoriesState(
            selectedCategory: category,
            videosStatus: CategoriesVideosStatus.loading,
            hasMoreVideos: true,
          ),
          isA<CategoriesState>()
              .having(
                (s) => s.videosStatus,
                'videosStatus',
                CategoriesVideosStatus.loaded,
              )
              .having((s) => s.videos.length, 'videos.length', 2)
              .having((s) => s.hasMoreVideos, 'hasMoreVideos', false),
        ],
      );

      blocTest<CategoriesBloc, CategoriesState>(
        'emits error when API throws on category selection',
        setUp: () {
          when(
            () => mockApiClient.getVideosByCategory(
              category: 'music',
            ),
          ).thenThrow(const FunnelcakeException('Failed'));
        },
        build: () => CategoriesBloc(categoriesRepository: mockRepository),
        act: (bloc) => bloc.add(const CategorySelected(category)),
        expect: () => [
          const CategoriesState(
            selectedCategory: category,
            videosStatus: CategoriesVideosStatus.loading,
            hasMoreVideos: true,
          ),
          isA<CategoriesState>().having(
            (s) => s.videosStatus,
            'videosStatus',
            CategoriesVideosStatus.error,
          ),
        ],
      );
    });

    group('CategoryVideosSortChanged', () {
      const category = VideoCategory(name: 'music', videoCount: 1500);

      blocTest<CategoriesBloc, CategoriesState>(
        'loads category-scoped recommendations when sort changes to forYou',
        setUp: () {
          when(
            () => mockApiClient.getRecommendations(
              pubkey: any(named: 'pubkey'),
              limit: 50,
              category: 'music',
            ),
          ).thenAnswer(
            (_) async => RecommendationsResponse(
              videos: [_createVideoStats('recommended-id')],
              source: 'personalized',
            ),
          );
          when(
            () => mockApiClient.getVideosByCategory(
              category: 'music',
              sort: 'forYou',
            ),
          ).thenAnswer((_) async => const []);
        },
        seed: () => const CategoriesState(
          selectedCategory: category,
          videosStatus: CategoriesVideosStatus.loaded,
        ),
        build: () => CategoriesBloc(
          categoriesRepository: mockRepository,
          currentUserPubkey: _viewerPubkey,
        ),
        act: (bloc) => bloc.add(const CategoryVideosSortChanged('forYou')),
        expect: () => [
          isA<CategoriesState>()
              .having((s) => s.sortOrder, 'sortOrder', 'forYou')
              .having(
                (s) => s.videosStatus,
                'videosStatus',
                CategoriesVideosStatus.loading,
              ),
          isA<CategoriesState>()
              .having(
                (s) => s.videosStatus,
                'videosStatus',
                CategoriesVideosStatus.loaded,
              )
              .having((s) => s.videos.length, 'videos.length', 1),
        ],
        verify: (_) {
          verify(
            () => mockApiClient.getRecommendations(
              pubkey: any(named: 'pubkey'),
              limit: 50,
              category: 'music',
            ),
          ).called(1);
          verifyNever(
            () => mockApiClient.getVideosByCategory(
              category: 'music',
              sort: 'forYou',
            ),
          );
        },
      );

      blocTest<CategoriesBloc, CategoriesState>(
        'falls back to Hot when forYou recommendations return no videos',
        setUp: () {
          when(
            () => mockApiClient.getRecommendations(
              pubkey: any(named: 'pubkey'),
              limit: 50,
              category: 'music',
            ),
          ).thenAnswer(
            (_) async => const RecommendationsResponse(
              videos: [],
              source: 'popular',
            ),
          );
          when(
            () => mockApiClient.getVideosByCategory(
              category: 'music',
            ),
          ).thenAnswer((_) async => [_createVideoStats('hot-fallback-id')]);
          when(
            () => mockApiClient.getVideosByCategory(
              category: 'music',
              sort: 'forYou',
            ),
          ).thenAnswer((_) async => const []);
        },
        seed: () => const CategoriesState(
          selectedCategory: category,
          videosStatus: CategoriesVideosStatus.loaded,
        ),
        build: () => CategoriesBloc(
          categoriesRepository: mockRepository,
          currentUserPubkey: _viewerPubkey,
        ),
        act: (bloc) => bloc.add(const CategoryVideosSortChanged('forYou')),
        expect: () => [
          isA<CategoriesState>()
              .having((s) => s.sortOrder, 'sortOrder', 'forYou')
              .having(
                (s) => s.videosStatus,
                'videosStatus',
                CategoriesVideosStatus.loading,
              ),
          isA<CategoriesState>()
              .having(
                (s) => s.videosStatus,
                'videosStatus',
                CategoriesVideosStatus.loaded,
              )
              .having((s) => s.videos.length, 'videos.length', 1),
        ],
        verify: (_) {
          verify(
            () => mockApiClient.getRecommendations(
              pubkey: any(named: 'pubkey'),
              limit: 50,
              category: 'music',
            ),
          ).called(1);
          verify(
            () => mockApiClient.getVideosByCategory(category: 'music'),
          ).called(1);
          verifyNever(
            () => mockApiClient.getVideosByCategory(
              category: 'music',
              sort: 'forYou',
            ),
          );
        },
      );

      blocTest<CategoriesBloc, CategoriesState>(
        'reloads videos with new sort order',
        setUp: () {
          when(
            () => mockApiClient.getVideosByCategory(
              category: 'music',
              sort: 'loops',
              platform: 'vine',
            ),
          ).thenAnswer((_) async => [_createVideoStats('id1')]);
        },
        seed: () => const CategoriesState(
          selectedCategory: category,
          videosStatus: CategoriesVideosStatus.loaded,
        ),
        build: () => CategoriesBloc(categoriesRepository: mockRepository),
        act: (bloc) => bloc.add(const CategoryVideosSortChanged('classic')),
        expect: () => [
          isA<CategoriesState>()
              .having((s) => s.sortOrder, 'sortOrder', 'classic')
              .having(
                (s) => s.videosStatus,
                'videosStatus',
                CategoriesVideosStatus.loading,
              ),
          isA<CategoriesState>()
              .having(
                (s) => s.videosStatus,
                'videosStatus',
                CategoriesVideosStatus.loaded,
              )
              .having((s) => s.videos.length, 'videos.length', 1),
        ],
      );

      blocTest<CategoriesBloc, CategoriesState>(
        'does nothing when no category selected',
        build: () => CategoriesBloc(categoriesRepository: mockRepository),
        act: (bloc) => bloc.add(const CategoryVideosSortChanged('classic')),
        expect: () => <CategoriesState>[],
      );
    });

    group('CategoryDeselected', () {
      blocTest<CategoriesBloc, CategoriesState>(
        'clears selected category and videos',
        seed: () => const CategoriesState(
          selectedCategory: VideoCategory(name: 'music', videoCount: 1500),
          videosStatus: CategoriesVideosStatus.loaded,
        ),
        build: () => CategoriesBloc(categoriesRepository: mockRepository),
        act: (bloc) => bloc.add(const CategoryDeselected()),
        expect: () => [
          isA<CategoriesState>()
              .having((s) => s.selectedCategory, 'selectedCategory', isNull)
              .having(
                (s) => s.videosStatus,
                'videosStatus',
                CategoriesVideosStatus.initial,
              )
              .having((s) => s.videos, 'videos', isEmpty),
        ],
      );
    });
  });
}

VideoStats _createVideoStats(String id) {
  return VideoStats(
    id: id,
    pubkey: 'abcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890',
    videoUrl: 'https://example.com/video.mp4',
    thumbnail: 'https://example.com/thumb.jpg',
    title: 'Test Video $id',
    createdAt: DateTime.now(),
    kind: 34236,
    dTag: id,
    reactions: 0,
    comments: 0,
    reposts: 0,
    engagementScore: 0,
  );
}
