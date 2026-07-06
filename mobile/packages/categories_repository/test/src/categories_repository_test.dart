// ABOUTME: Tests for CategoriesRepository
// ABOUTME: Verifies caching, filtering, and featured-first ordering

import 'package:cache_sync/cache_sync.dart';
import 'package:categories_repository/categories_repository.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart'
    show RecommendationsResponse, VideoCategory, VideoStats;
import 'package:test/test.dart';

import '../../../cache_sync/test/fake_cache_dao.dart';

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

void main() {
  const blockedPubkey = 'blocked_pubkey';
  const allowedPubkey = 'allowed_pubkey';

  group(CategoriesRepository, () {
    late _MockFunnelcakeApiClient apiClient;
    late CategoriesRepository repository;

    setUp(() {
      apiClient = _MockFunnelcakeApiClient();
      repository = CategoriesRepository(
        funnelcakeApiClient: apiClient,
        blockFilter: (pubkey) => pubkey == blockedPubkey,
      );
    });

    const sampleCategories = <VideoCategory>[
      VideoCategory(name: 'comedy', videoCount: 500),
      VideoCategory(name: 'animals', videoCount: 300),
      VideoCategory(name: 'music', videoCount: 200),
    ];

    group('getCategories', () {
      test('fetches categories from API', () async {
        when(
          () => apiClient.getCategories(limit: 100),
        ).thenAnswer((_) async => sampleCategories);

        final result = await repository.getCategories();

        expect(result, hasLength(3));
        verify(() => apiClient.getCategories(limit: 100)).called(1);
      });

      test('returns cached result on second call', () async {
        when(
          () => apiClient.getCategories(limit: 100),
        ).thenAnswer((_) async => sampleCategories);

        await repository.getCategories();
        await repository.getCategories();

        verify(() => apiClient.getCategories(limit: 100)).called(1);
      });

      test('bypasses cache when forceRefresh is true', () async {
        when(
          () => apiClient.getCategories(limit: 100),
        ).thenAnswer((_) async => sampleCategories);

        await repository.getCategories();
        await repository.getCategories(forceRefresh: true);

        verify(() => apiClient.getCategories(limit: 100)).called(2);
      });

      test('filters out empty names', () async {
        when(() => apiClient.getCategories(limit: 100)).thenAnswer(
          (_) async => const [
            VideoCategory(name: 'comedy', videoCount: 500),
            VideoCategory(name: '', videoCount: 100),
          ],
        );

        final result = await repository.getCategories();

        expect(result, hasLength(1));
        expect(result.first.name, equals('comedy'));
      });

      test('filters out zero video counts', () async {
        when(() => apiClient.getCategories(limit: 100)).thenAnswer(
          (_) async => const [
            VideoCategory(name: 'comedy', videoCount: 500),
            VideoCategory(name: 'empty', videoCount: 0),
          ],
        );

        final result = await repository.getCategories();

        expect(result, hasLength(1));
      });

      test('sorts featured categories first', () async {
        when(() => apiClient.getCategories(limit: 100)).thenAnswer(
          (_) async => const [
            VideoCategory(name: 'comedy', videoCount: 500),
            VideoCategory(name: 'animals', videoCount: 300),
            VideoCategory(name: 'unknown_category', videoCount: 100),
          ],
        );

        final result = await repository.getCategories();

        // 'animals' is featured, so should come first
        expect(result.first.name, equals('animals'));
      });
    });

    group('watchCategoriesCached', () {
      late FakeCacheDao cacheDao;

      setUp(() async {
        cacheDao = FakeCacheDao();
        await CacheSync.init(dao: cacheDao);
      });

      test('emits disk-cached categories before live refresh', () async {
        const refreshedCategories = <VideoCategory>[
          VideoCategory(name: 'animals', videoCount: 350),
          VideoCategory(name: 'music', videoCount: 250),
        ];
        var calls = 0;
        when(() => apiClient.getCategories(limit: 100)).thenAnswer((_) async {
          calls += 1;
          return calls == 1 ? sampleCategories : refreshedCategories;
        });

        await repository.watchCategoriesCached().toList();

        final restartedRepository = CategoriesRepository(
          funnelcakeApiClient: apiClient,
          blockFilter: (pubkey) => pubkey == blockedPubkey,
        );

        final results = await restartedRepository
            .watchCategoriesCached()
            .toList();

        expect(results, hasLength(2));
        expect(results[0].isStale, isTrue);
        expect(results[0].data, [
          const VideoCategory(name: 'animals', videoCount: 300),
          const VideoCategory(name: 'music', videoCount: 200),
          const VideoCategory(name: 'comedy', videoCount: 500),
        ]);
        expect(results[1].isLive, isTrue);
        expect(results[1].data, refreshedCategories);
        verify(() => apiClient.getCategories(limit: 100)).called(2);
      });

      test('force refresh bypasses the disk cache', () async {
        var calls = 0;
        when(() => apiClient.getCategories(limit: 100)).thenAnswer((_) async {
          calls += 1;
          return calls == 1
              ? sampleCategories
              : const [VideoCategory(name: 'music', videoCount: 250)];
        });

        await repository.watchCategoriesCached().toList();

        final results = await repository
            .watchCategoriesCached(forceRefresh: true)
            .toList();

        expect(results, hasLength(1));
        expect(results.single.isLive, isTrue);
        expect(results.single.data, [
          const VideoCategory(name: 'music', videoCount: 250),
        ]);
        verify(() => apiClient.getCategories(limit: 100)).called(2);
      });
    });

    group('getVideosForCategory', () {
      test(
        'filters blocked authors without breaking hasMore metadata',
        () async {
          when(
            () => apiClient.getVideosByCategory(
              category: 'music',
              before: any(named: 'before'),
              sort: any(named: 'sort'),
              platform: any(named: 'platform'),
            ),
          ).thenAnswer(
            (_) async => List<VideoStats>.generate(
              50,
              (index) => _videoStats(
                id: 'id-$index',
                pubkey: index == 0 ? blockedPubkey : allowedPubkey,
              ),
            ),
          );

          final page = await repository.getVideosForCategory(category: 'music');

          expect(page.videos, hasLength(49));
          expect(
            page.videos.every((video) => video.pubkey != blockedPubkey),
            isTrue,
          );
          expect(page.hasMore, isTrue);
        },
      );
    });

    group('getRecommendedVideos', () {
      test('filters blocked authors from recommendations', () async {
        when(
          () => apiClient.getRecommendations(
            pubkey: 'viewer_pubkey',
            limit: 50,
            category: 'music',
          ),
        ).thenAnswer(
          (_) async => RecommendationsResponse(
            videos: [
              _videoStats(id: 'blocked-id', pubkey: blockedPubkey),
              _videoStats(id: 'allowed-id', pubkey: allowedPubkey),
            ],
            source: 'personalized',
          ),
        );

        final videos = await repository.getRecommendedVideos(
          pubkey: 'viewer_pubkey',
          category: 'music',
        );

        expect(videos, hasLength(1));
        expect(videos.single.id, 'allowed-id');
        expect(videos.single.pubkey, allowedPubkey);
      });

      test(
        'collapses a republished coordinate returned twice in one page',
        () async {
          when(
            () => apiClient.getRecommendations(
              pubkey: 'viewer_pubkey',
              limit: 50,
            ),
          ).thenAnswer(
            (_) async => RecommendationsResponse(
              videos: [
                _videoStats(
                  id: 'event-a',
                  pubkey: allowedPubkey,
                  dTag: 'shared-d-tag',
                ),
                _videoStats(
                  id: 'event-b',
                  pubkey: allowedPubkey,
                  dTag: 'shared-d-tag',
                ),
              ],
              source: 'personalized',
            ),
          );

          final videos = await repository.getRecommendedVideos(
            pubkey: 'viewer_pubkey',
          );

          expect(videos, hasLength(1));
          expect(videos.single.id, 'event-a');
        },
      );
    });

    group('invalidateCache', () {
      test('clears cache so next call fetches fresh data', () async {
        when(
          () => apiClient.getCategories(limit: 100),
        ).thenAnswer((_) async => sampleCategories);

        await repository.getCategories();
        repository.invalidateCache();
        await repository.getCategories();

        verify(() => apiClient.getCategories(limit: 100)).called(2);
      });
    });
  });
}

VideoStats _videoStats({
  required String id,
  required String pubkey,
  String? dTag,
}) {
  return VideoStats(
    id: id,
    pubkey: pubkey,
    videoUrl: 'https://example.com/$id.mp4',
    thumbnail: 'https://example.com/$id.jpg',
    title: 'Video $id',
    createdAt: DateTime(2026),
    kind: 34236,
    dTag: dTag ?? id,
    reactions: 0,
    comments: 0,
    reposts: 0,
    engagementScore: 0,
  );
}
