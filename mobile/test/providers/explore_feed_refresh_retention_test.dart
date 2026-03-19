import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/for_you_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/popular_now_feed_provider.dart';
import 'package:openvine/providers/popular_videos_feed_provider.dart';
import 'package:openvine/providers/readiness_gate_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/content_blocklist_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:riverpod/riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockContentBlocklistService extends Mock
    implements ContentBlocklistService {}

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

class _MockAuthService extends Mock implements AuthService {}

class _MockNostrClient extends Mock implements NostrClient {}

class _AlwaysAvailableFunnelcake extends FunnelcakeAvailable {
  @override
  Future<bool> build() async => true;
}

void main() {
  group('Explore feed refresh retention', () {
    late SharedPreferences sharedPreferences;
    late _MockVideoEventService mockVideoEventService;
    late _MockContentBlocklistService mockBlocklistService;
    late _MockVideosRepository mockVideosRepository;
    late _MockFunnelcakeApiClient mockFunnelcakeApiClient;
    late _MockAuthService mockAuthService;
    late _MockNostrClient mockNostrClient;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();

      mockVideoEventService = _MockVideoEventService();
      mockBlocklistService = _MockContentBlocklistService();
      mockVideosRepository = _MockVideosRepository();
      mockFunnelcakeApiClient = _MockFunnelcakeApiClient();
      mockAuthService = _MockAuthService();
      mockNostrClient = _MockNostrClient();

      when(
        () => mockVideoEventService.filterVideoList(any()),
      ).thenAnswer((invocation) {
        return List<VideoEvent>.from(
          invocation.positionalArguments.first as List,
        );
      });
      when(
        () => mockBlocklistService.shouldFilterFromFeeds(any()),
      ).thenReturn(false);
      when(
        () => mockAuthService.currentPublicKeyHex,
      ).thenReturn('viewer-pubkey');
    });

    test(
      'popular now keeps existing videos visible while refresh is in flight',
      () async {
        final refreshCompleter = Completer<List<VideoStats>>();
        var recentCallCount = 0;

        when(
          () => mockFunnelcakeApiClient.getRecentVideos(
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer((_) {
          recentCallCount += 1;
          if (recentCallCount == 1) {
            return Future.value([_videoStats('popular-now-initial')]);
          }
          return refreshCompleter.future;
        });

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            appReadyProvider.overrideWithValue(true),
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
            contentBlocklistServiceProvider.overrideWithValue(
              mockBlocklistService,
            ),
            funnelcakeApiClientProvider.overrideWithValue(
              mockFunnelcakeApiClient,
            ),
            funnelcakeAvailableProvider.overrideWith(
              _AlwaysAvailableFunnelcake.new,
            ),
            nostrServiceProvider.overrideWithValue(mockNostrClient),
          ],
        );
        addTearDown(container.dispose);

        await container.read(funnelcakeAvailableProvider.future);
        final subscription = container.listen(
          popularNowFeedProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);

        final initialState = await container.read(
          popularNowFeedProvider.future,
        );
        expect(initialState.videos.map((video) => video.id), [
          'popular-now-initial',
        ]);

        final refreshFuture = container
            .read(popularNowFeedProvider.notifier)
            .refresh();
        await pumpEventQueue();

        final refreshingState = container.read(popularNowFeedProvider).value;
        expect(refreshingState, isNotNull);
        expect(refreshingState!.videos.map((video) => video.id), [
          'popular-now-initial',
        ]);
        expect(refreshingState.isRefreshing, isTrue);

        refreshCompleter.complete([_videoStats('popular-now-refreshed')]);
        await refreshFuture;

        final finalState = container.read(popularNowFeedProvider).value;
        expect(finalState, isNotNull);
        expect(finalState!.videos.map((video) => video.id), [
          'popular-now-refreshed',
        ]);
        expect(finalState.isRefreshing, isFalse);
      },
    );

    test(
      'popular videos keeps existing videos visible while refresh is in flight',
      () async {
        final initialVideos = [_video('popular-initial')];
        final refreshedVideos = [_video('popular-refreshed')];
        final refreshCompleter = Completer<List<VideoEvent>>();
        var requestCount = 0;

        when(
          () => mockVideosRepository.getPopularVideos(
            limit: any(named: 'limit'),
            until: any(named: 'until'),
            fetchMultiplier: any(named: 'fetchMultiplier'),
          ),
        ).thenAnswer((_) {
          requestCount += 1;
          if (requestCount == 1) {
            return Future.value(initialVideos);
          }
          return refreshCompleter.future;
        });

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            appReadyProvider.overrideWithValue(true),
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
            contentBlocklistServiceProvider.overrideWithValue(
              mockBlocklistService,
            ),
            videosRepositoryProvider.overrideWithValue(mockVideosRepository),
            nostrServiceProvider.overrideWithValue(mockNostrClient),
          ],
        );
        addTearDown(container.dispose);

        final subscription = container.listen(
          popularVideosFeedProvider,
          (_, _) {},
        );
        addTearDown(subscription.close);

        final initialState = await container.read(
          popularVideosFeedProvider.future,
        );
        expect(initialState.videos.map((video) => video.id), [
          'popular-initial',
        ]);

        final refreshFuture = container
            .read(popularVideosFeedProvider.notifier)
            .refresh();
        await pumpEventQueue();

        final refreshingState = container.read(popularVideosFeedProvider).value;
        expect(refreshingState, isNotNull);
        expect(refreshingState!.videos.map((video) => video.id), [
          'popular-initial',
        ]);
        expect(refreshingState.isRefreshing, isTrue);

        refreshCompleter.complete(refreshedVideos);
        await refreshFuture;

        final finalState = container.read(popularVideosFeedProvider).value;
        expect(finalState, isNotNull);
        expect(finalState!.videos.map((video) => video.id), [
          'popular-refreshed',
        ]);
        expect(finalState.isRefreshing, isFalse);
      },
    );

    test(
      'for you keeps existing videos visible while refresh is in flight',
      () async {
        final refreshCompleter = Completer<RecommendationsResponse>();
        var requestCount = 0;

        when(
          () => mockFunnelcakeApiClient.getRecommendations(
            pubkey: any(named: 'pubkey'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) {
          requestCount += 1;
          if (requestCount == 1) {
            return Future.value(
              RecommendationsResponse(
                videos: [_videoStats('for-you-initial')],
                source: 'popular',
              ),
            );
          }
          return refreshCompleter.future;
        });

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            appReadyProvider.overrideWithValue(true),
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
            contentBlocklistServiceProvider.overrideWithValue(
              mockBlocklistService,
            ),
            funnelcakeApiClientProvider.overrideWithValue(
              mockFunnelcakeApiClient,
            ),
            authServiceProvider.overrideWithValue(mockAuthService),
            funnelcakeAvailableProvider.overrideWith(
              _AlwaysAvailableFunnelcake.new,
            ),
          ],
        );
        addTearDown(container.dispose);

        await container.read(funnelcakeAvailableProvider.future);
        final subscription = container.listen(forYouFeedProvider, (_, _) {});
        addTearDown(subscription.close);

        final initialState = await container.read(forYouFeedProvider.future);
        expect(initialState.videos.map((video) => video.id), [
          'for-you-initial',
        ]);

        final refreshFuture = container
            .read(forYouFeedProvider.notifier)
            .refresh();
        await pumpEventQueue();

        final refreshingState = container.read(forYouFeedProvider).value;
        expect(refreshingState, isNotNull);
        expect(refreshingState!.videos.map((video) => video.id), [
          'for-you-initial',
        ]);
        expect(refreshingState.isRefreshing, isTrue);

        refreshCompleter.complete(
          RecommendationsResponse(
            videos: [_videoStats('for-you-refreshed')],
            source: 'personalized',
          ),
        );
        await refreshFuture;

        final finalState = container.read(forYouFeedProvider).value;
        expect(finalState, isNotNull);
        expect(finalState!.videos.map((video) => video.id), [
          'for-you-refreshed',
        ]);
        expect(finalState.isRefreshing, isFalse);
      },
    );
  });
}

VideoEvent _video(String id) {
  return VideoEvent(
    id: id,
    pubkey: 'author-$id',
    createdAt: DateTime(2026, 3, 17).millisecondsSinceEpoch ~/ 1000,
    content: 'video $id',
    timestamp: DateTime(2026, 3, 17),
    videoUrl: 'https://example.com/$id.mp4',
    thumbnailUrl: 'https://example.com/$id.jpg',
    rawTags: const {'d': 'seed', 'x': '1', 'y': '2', 'z': '3'},
    originalLoops: AppConstants.paginationBatchSize,
  );
}

VideoStats _videoStats(String id) {
  return VideoStats(
    id: id,
    pubkey: 'author-$id',
    createdAt: DateTime(2026, 3, 17),
    kind: 34236,
    dTag: id,
    title: id,
    thumbnail: 'https://example.com/$id.jpg',
    videoUrl: 'https://example.com/$id.mp4',
    reactions: 0,
    comments: 0,
    reposts: 0,
    engagementScore: 0,
  );
}
