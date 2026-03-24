// ABOUTME: Tests for the CategoriesBloc
// ABOUTME: Verifies category loading, selection, pagination, sorting, and deselection

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/categories/categories_bloc.dart';
import 'package:openvine/models/video_category.dart';

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

void main() {
  late _MockFunnelcakeApiClient mockApiClient;

  setUp(() {
    mockApiClient = _MockFunnelcakeApiClient();
  });

  group(CategoriesBloc, () {
    group('CategoriesLoadRequested', () {
      final categoriesJson = [
        {'name': 'music', 'video_count': 1500},
        {'name': 'comedy', 'video_count': 900},
        {'name': 'dance', 'video_count': 800},
      ];

      blocTest<CategoriesBloc, CategoriesState>(
        'emits [loading, loaded] when categories load successfully',
        setUp: () {
          when(
            () => mockApiClient.getCategories(limit: 100),
          ).thenAnswer((_) async => categoriesJson);
        },
        build: () => CategoriesBloc(funnelcakeApiClient: mockApiClient),
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
          verify(() => mockApiClient.getCategories(limit: 100)).called(1);
        },
      );

      blocTest<CategoriesBloc, CategoriesState>(
        'emits [loading, error] when API throws',
        setUp: () {
          when(
            () => mockApiClient.getCategories(limit: 100),
          ).thenThrow(const FunnelcakeException('Network error'));
        },
        build: () => CategoriesBloc(funnelcakeApiClient: mockApiClient),
        act: (bloc) => bloc.add(const CategoriesLoadRequested()),
        expect: () => [
          const CategoriesState(categoriesStatus: CategoriesStatus.loading),
          isA<CategoriesState>()
              .having(
                (s) => s.categoriesStatus,
                'categoriesStatus',
                CategoriesStatus.error,
              )
              .having((s) => s.errorMessage, 'errorMessage', isNotNull),
        ],
      );

      blocTest<CategoriesBloc, CategoriesState>(
        'filters out categories with empty names or zero videos',
        setUp: () {
          when(() => mockApiClient.getCategories(limit: 100)).thenAnswer(
            (_) async => [
              {'name': 'music', 'video_count': 100},
              {'name': '', 'video_count': 50},
              {'name': 'dance', 'video_count': 0},
            ],
          );
        },
        build: () => CategoriesBloc(funnelcakeApiClient: mockApiClient),
        act: (bloc) => bloc.add(const CategoriesLoadRequested()),
        expect: () => [
          const CategoriesState(categoriesStatus: CategoriesStatus.loading),
          const CategoriesState(
            categoriesStatus: CategoriesStatus.loaded,
            categories: [VideoCategory(name: 'music', videoCount: 100)],
          ),
        ],
      );

      blocTest<CategoriesBloc, CategoriesState>(
        'orders featured categories first using the curated design order',
        setUp: () {
          when(() => mockApiClient.getCategories(limit: 100)).thenAnswer(
            (_) async => [
              {'name': 'technology', 'video_count': 30},
              {'name': 'music', 'video_count': 20},
              {'name': 'fashion', 'video_count': 10},
              {'name': 'animals', 'video_count': 40},
              {'name': 'comedy', 'video_count': 15},
              {'name': 'art', 'video_count': 50},
            ],
          );
        },
        build: () => CategoriesBloc(funnelcakeApiClient: mockApiClient),
        act: (bloc) => bloc.add(const CategoriesLoadRequested()),
        expect: () => [
          const CategoriesState(categoriesStatus: CategoriesStatus.loading),
          const CategoriesState(
            categoriesStatus: CategoriesStatus.loaded,
            categories: [
              VideoCategory(name: 'animals', videoCount: 40),
              VideoCategory(name: 'fashion', videoCount: 10),
              VideoCategory(name: 'music', videoCount: 20),
              VideoCategory(name: 'art', videoCount: 50),
              VideoCategory(name: 'technology', videoCount: 30),
              VideoCategory(name: 'comedy', videoCount: 15),
            ],
          ),
        ],
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
        build: () => CategoriesBloc(funnelcakeApiClient: mockApiClient),
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
        build: () => CategoriesBloc(funnelcakeApiClient: mockApiClient),
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
        build: () => CategoriesBloc(funnelcakeApiClient: mockApiClient),
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
        build: () => CategoriesBloc(funnelcakeApiClient: mockApiClient),
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
        build: () => CategoriesBloc(funnelcakeApiClient: mockApiClient),
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
