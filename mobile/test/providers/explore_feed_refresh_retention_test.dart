import 'dart:async';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/video_filter_builder.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

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
    late _MockContentBlocklistRepository mockBlocklistRepository;
    late _MockVideosRepository mockVideosRepository;
    late _MockFunnelcakeApiClient mockFunnelcakeApiClient;
    late _MockAuthService mockAuthService;
    late _MockNostrClient mockNostrClient;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();

      mockVideoEventService = _MockVideoEventService();
      mockBlocklistRepository = _MockContentBlocklistRepository();
      mockVideosRepository = _MockVideosRepository();
      mockFunnelcakeApiClient = _MockFunnelcakeApiClient();
      mockAuthService = _MockAuthService();
      mockNostrClient = _MockNostrClient();

      when(() => mockVideoEventService.filterVideoList(any())).thenAnswer((
        invocation,
      ) {
        return List<VideoEvent>.from(
          invocation.positionalArguments.first as List,
        );
      });
      when(
        () => mockBlocklistRepository.shouldFilterFromFeeds(any()),
      ).thenReturn(false);
      when(
        () => mockAuthService.currentPublicKeyHex,
      ).thenReturn('viewer-pubkey');
    });

    test(
      'popular now keeps existing videos visible while refresh is in flight',
      () async {
        final refreshCompleter = Completer<WatchingVideosResponse>();
        var watchingCallCount = 0;

        when(
          () => mockFunnelcakeApiClient.getWatchingVideosPage(
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer((_) {
          watchingCallCount += 1;
          if (watchingCallCount == 1) {
            return Future.value(_watchingResponse(['popular-now-initial']));
          }
          return refreshCompleter.future;
        });

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            appReadyProvider.overrideWithValue(true),
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
            contentBlocklistRepositoryProvider.overrideWithValue(
              mockBlocklistRepository,
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

        refreshCompleter.complete(_watchingResponse(['popular-now-refreshed']));
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
      'popular now refresh during resume-time rebuild stays on REST path',
      () async {
        final resumeBuildCompleter = Completer<WatchingVideosResponse>();
        final refreshCompleter = Completer<WatchingVideosResponse>();
        var watchingCallCount = 0;

        when(
          () => mockFunnelcakeApiClient.getWatchingVideosPage(
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer((_) {
          watchingCallCount += 1;
          if (watchingCallCount == 1) {
            return Future.value(_watchingResponse(['popular-now-initial']));
          }
          if (watchingCallCount == 2) {
            return resumeBuildCompleter.future;
          }
          return refreshCompleter.future;
        });

        when(() => mockVideoEventService.popularNowVideos).thenReturn([]);
        when(
          () => mockVideoEventService.subscribeToVideoFeed(
            subscriptionType: SubscriptionType.popularNow,
            limit: AppConstants.paginationBatchSize,
            sortBy: VideoSortField.createdAt,
            force: true,
          ),
        ).thenAnswer((_) async {});

        List<Object> overridesFor(bool appReady) => [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          appReadyProvider.overrideWithValue(appReady),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          contentBlocklistRepositoryProvider.overrideWithValue(
            mockBlocklistRepository,
          ),
          funnelcakeApiClientProvider.overrideWithValue(
            mockFunnelcakeApiClient,
          ),
          funnelcakeAvailableProvider.overrideWith(
            _AlwaysAvailableFunnelcake.new,
          ),
          nostrServiceProvider.overrideWithValue(mockNostrClient),
        ];

        final container = ProviderContainer(
          overrides: overridesFor(true).cast(),
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

        container.updateOverrides(overridesFor(false).cast());
        await container.read(funnelcakeAvailableProvider.future);
        await pumpEventQueue();
        await pumpEventQueue();

        final backgroundState = container.read(popularNowFeedProvider).value;
        expect(backgroundState, isNotNull);
        expect(backgroundState!.videos.map((video) => video.id), [
          'popular-now-initial',
        ]);

        container.updateOverrides(overridesFor(true).cast());
        await container.read(funnelcakeAvailableProvider.future);
        await pumpEventQueue();

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
        expect(
          watchingCallCount,
          3,
          reason:
              'Refresh should keep using REST while the resume rebuild is in flight',
        );
        verifyNever(
          () => mockVideoEventService.subscribeToVideoFeed(
            subscriptionType: SubscriptionType.popularNow,
            limit: AppConstants.paginationBatchSize,
            sortBy: VideoSortField.createdAt,
            force: true,
          ),
        );

        resumeBuildCompleter.complete(
          _watchingResponse(['popular-now-resumed']),
        );
        refreshCompleter.complete(_watchingResponse(['popular-now-refreshed']));
        await refreshFuture;
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
            offset: any(named: 'offset'),
            period: any(named: 'period'),
            variant: any(named: 'variant'),
            fetchMultiplier: any(named: 'fetchMultiplier'),
            skipCache: any(named: 'skipCache'),
          ),
        ).thenAnswer((invocation) {
          requestCount += 1;
          final skipCache = invocation.namedArguments[#skipCache] as bool?;
          if (requestCount == 1) {
            expect(skipCache, isNot(true));
            return Future.value(initialVideos);
          }
          expect(skipCache, isTrue);
          return refreshCompleter.future;
        });

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            appReadyProvider.overrideWithValue(true),
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
            contentBlocklistRepositoryProvider.overrideWithValue(
              mockBlocklistRepository,
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
        verify(
          () => mockVideosRepository.getPopularVideos(
            limit: AppConstants.paginationBatchSize,
            variant: PopularVideosVariant.native,
            skipCache: true,
          ),
        ).called(1);
      },
    );

    test('popular videos native source uses age-decayed v2 popular', () async {
      when(
        () => mockVideosRepository.getPopularVideos(
          limit: any(named: 'limit'),
          until: any(named: 'until'),
          offset: any(named: 'offset'),
          period: any(named: 'period'),
          variant: any(named: 'variant'),
          fetchMultiplier: any(named: 'fetchMultiplier'),
          skipCache: any(named: 'skipCache'),
        ),
      ).thenAnswer((_) async => [_video('popular-age-decayed')]);

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          appReadyProvider.overrideWithValue(true),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          contentBlocklistRepositoryProvider.overrideWithValue(
            mockBlocklistRepository,
          ),
          videosRepositoryProvider.overrideWithValue(mockVideosRepository),
          nostrServiceProvider.overrideWithValue(mockNostrClient),
        ],
      );
      addTearDown(container.dispose);

      final state = await container.read(popularVideosFeedProvider.future);

      expect(state.videos.map((video) => video.id), ['popular-age-decayed']);
      verify(
        () => mockVideosRepository.getPopularVideos(
          limit: AppConstants.paginationBatchSize,
          variant: PopularVideosVariant.native,
        ),
      ).called(1);
      verifyNever(
        () => mockVideosRepository.getNativePopularVideosPage(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          skipCache: any(named: 'skipCache'),
        ),
      );
    });

    test(
      'popular videos preserves existing videos when refresh fails',
      () async {
        final initialVideos = [_video('popular-initial')];
        var requestCount = 0;

        when(
          () => mockVideosRepository.getPopularVideos(
            limit: any(named: 'limit'),
            until: any(named: 'until'),
            offset: any(named: 'offset'),
            period: any(named: 'period'),
            variant: any(named: 'variant'),
            fetchMultiplier: any(named: 'fetchMultiplier'),
            skipCache: any(named: 'skipCache'),
          ),
        ).thenAnswer((invocation) {
          requestCount += 1;
          final skipCache = invocation.namedArguments[#skipCache] as bool?;
          if (requestCount == 1) {
            return Future.value(initialVideos);
          }
          expect(skipCache, isTrue);
          throw StateError('age-decayed refresh failed');
        });

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            appReadyProvider.overrideWithValue(true),
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
            contentBlocklistRepositoryProvider.overrideWithValue(
              mockBlocklistRepository,
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

        await container.read(popularVideosFeedProvider.notifier).refresh();

        final finalState = container.read(popularVideosFeedProvider).value;
        expect(finalState, isNotNull);
        expect(finalState!.videos.map((video) => video.id), [
          'popular-initial',
        ]);
        expect(finalState.isRefreshing, isFalse);
        expect(finalState.error, contains('age-decayed refresh failed'));
      },
    );

    test(
      'popular videos load more uses timestamp cursor and filters duplicates',
      () async {
        final initialRawVideos = [
          _video('popular-initial'),
          for (var i = 1; i < AppConstants.paginationBatchSize; i++)
            _vineArchiveVideo(
              'popular-vine-$i',
              createdAt: 1_742_169_600 - i,
            ),
        ];
        final loadMoreRawVideos = [
          _video('popular-initial'),
          _video('popular-more'),
        ];
        const oldestInitialCursor =
            1_742_169_600 - (AppConstants.paginationBatchSize - 1);
        final requestedCursors = <int?>[];

        when(
          () => mockVideosRepository.getPopularVideos(
            limit: any(named: 'limit'),
            until: any(named: 'until'),
            offset: any(named: 'offset'),
            period: any(named: 'period'),
            variant: any(named: 'variant'),
            fetchMultiplier: any(named: 'fetchMultiplier'),
            skipCache: any(named: 'skipCache'),
          ),
        ).thenAnswer((invocation) async {
          final until = invocation.namedArguments[#until] as int?;
          requestedCursors.add(until);
          if (until == null) {
            return initialRawVideos;
          }
          if (until == oldestInitialCursor) {
            return loadMoreRawVideos;
          }
          throw StateError('unexpected cursor $until');
        });

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            appReadyProvider.overrideWithValue(true),
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
            contentBlocklistRepositoryProvider.overrideWithValue(
              mockBlocklistRepository,
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
        expect(initialState.hasMoreContent, isTrue);

        await container.read(popularVideosFeedProvider.notifier).loadMore();

        final finalState = container.read(popularVideosFeedProvider).value;
        expect(finalState, isNotNull);
        expect(finalState!.videos.map((video) => video.id), [
          'popular-initial',
          'popular-more',
        ]);
        expect(finalState.hasMoreContent, isFalse);
        expect(finalState.isLoadingMore, isFalse);
        expect(requestedCursors, [null, oldestInitialCursor]);
      },
    );

    test('popular videos does not fall back to native leaderboard', () async {
      when(
        () => mockVideosRepository.getPopularVideos(
          limit: any(named: 'limit'),
          until: any(named: 'until'),
          offset: any(named: 'offset'),
          period: any(named: 'period'),
          variant: any(named: 'variant'),
          fetchMultiplier: any(named: 'fetchMultiplier'),
          skipCache: any(named: 'skipCache'),
        ),
      ).thenThrow(StateError('age-decayed popular unavailable'));

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          appReadyProvider.overrideWithValue(true),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          contentBlocklistRepositoryProvider.overrideWithValue(
            mockBlocklistRepository,
          ),
          videosRepositoryProvider.overrideWithValue(mockVideosRepository),
          nostrServiceProvider.overrideWithValue(mockNostrClient),
        ],
      );
      addTearDown(container.dispose);

      final state = await container.read(popularVideosFeedProvider.future);

      expect(state.videos, isEmpty);
      expect(state.hasMoreContent, isFalse);
      expect(state.error, contains('age-decayed popular unavailable'));
      verifyNever(
        () => mockVideosRepository.getNativePopularVideosPage(
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          skipCache: any(named: 'skipCache'),
        ),
      );
    });

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
            contentBlocklistRepositoryProvider.overrideWithValue(
              mockBlocklistRepository,
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

    // Regression for #3849. Pre-fix, popular_now's refresh() flipped a sticky
    // _usingRestApi=false in the catch fall-through, so the *next* refresh
    // skipped REST entirely and stayed on Nostr until app restart. The fix
    // re-checks funnelcakeAvailable per call, so a transient REST failure
    // must not disable REST for subsequent refreshes.
    test(
      'popular now re-attempts REST after a transient refresh failure',
      () async {
        var watchingCallCount = 0;

        when(
          () => mockFunnelcakeApiClient.getWatchingVideosPage(
            limit: any(named: 'limit'),
            before: any(named: 'before'),
          ),
        ).thenAnswer((_) async {
          watchingCallCount += 1;
          if (watchingCallCount == 2) {
            throw const FunnelcakeApiException(
              message: 'transient',
              statusCode: 500,
            );
          }
          return _watchingResponse(['popular-now-call-$watchingCallCount']);
        });

        // Mocks needed for the Nostr fall-through that runs after refresh #1
        // fails — we don't assert on the Nostr state, only that REST recovers
        // afterwards.
        when(() => mockVideoEventService.popularNowVideos).thenReturn([]);
        when(
          () => mockVideoEventService.subscribeToVideoFeed(
            subscriptionType: SubscriptionType.popularNow,
            limit: AppConstants.paginationBatchSize,
            sortBy: VideoSortField.createdAt,
            force: true,
          ),
        ).thenAnswer((_) async {});

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sharedPreferences),
            appReadyProvider.overrideWithValue(true),
            videoEventServiceProvider.overrideWithValue(mockVideoEventService),
            contentBlocklistRepositoryProvider.overrideWithValue(
              mockBlocklistRepository,
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

        // Build: REST call #1 succeeds.
        final initialState = await container.read(
          popularNowFeedProvider.future,
        );
        expect(initialState.videos.map((video) => video.id), [
          'popular-now-call-1',
        ]);

        // Refresh #1: REST call #2 throws — must not poison subsequent calls.
        await container.read(popularNowFeedProvider.notifier).refresh();

        // Refresh #2: REST call #3 must be issued. Pre-fix this never ran.
        await container.read(popularNowFeedProvider.notifier).refresh();

        expect(
          watchingCallCount,
          3,
          reason:
              'Refresh after a REST failure must re-attempt REST, not skip it.',
        );
        final recoveredState = container.read(popularNowFeedProvider).value;
        expect(recoveredState, isNotNull);
        expect(recoveredState!.videos.map((video) => video.id), [
          'popular-now-call-3',
        ]);
      },
    );
  });
}

WatchingVideosResponse _watchingResponse(
  List<String> ids, {
  int? nextCursor,
  bool? hasMore,
}) {
  return WatchingVideosResponse(
    videos: ids.map(_videoStats).toList(),
    nextCursor: nextCursor,
    hasMore: hasMore,
  );
}

VideoEvent _video(
  String id, {
  int createdAt = 1_742_169_600,
  Map<String, String> rawTags = const {
    'd': 'seed',
    'x': '1',
    'y': '2',
    'z': '3',
  },
}) {
  return VideoEvent(
    id: id,
    pubkey: 'author-$id',
    createdAt: createdAt,
    content: 'video $id',
    timestamp: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
    videoUrl: 'https://example.com/$id.mp4',
    thumbnailUrl: 'https://example.com/$id.jpg',
    rawTags: rawTags,
    originalLoops: AppConstants.paginationBatchSize,
  );
}

VideoEvent _vineArchiveVideo(String id, {int createdAt = 1_742_169_600}) {
  return _video(
    id,
    createdAt: createdAt,
    rawTags: const {
      'd': 'seed',
      'x': '1',
      'y': '2',
      'z': '3',
      'platform': 'vine',
    },
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
