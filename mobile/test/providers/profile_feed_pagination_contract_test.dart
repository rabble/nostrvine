import 'dart:async';
import 'dart:collection';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/profile_feed_provider.dart';
import 'package:openvine/providers/profile_feed_session_cache.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/state/video_feed_state.dart';

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockNostrClient extends Mock implements NostrClient {}

class _AlwaysAvailableFunnelcake extends FunnelcakeAvailable {
  @override
  Future<bool> build() async => true;
}

class _NeverAvailableFunnelcake extends FunnelcakeAvailable {
  @override
  Future<bool> build() async => false;
}

bool _controlledFunnelcakeAvailability = false;
final _controlledFunnelcakeAvailabilityProvider = Provider<bool>(
  (ref) => _controlledFunnelcakeAvailability,
);

class _ControlledFunnelcake extends FunnelcakeAvailable {
  @override
  Future<bool> build() async {
    return ref.watch(_controlledFunnelcakeAvailabilityProvider);
  }
}

void main() {
  const userId =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  group('estimateNextRestOffset', () {
    test('returns visibleCount when hasMoreContent is false', () {
      final state = VideoFeedState(
        videos: List.generate(
          37,
          (i) => VideoEvent(
            id: 'v$i',
            pubkey: userId,
            createdAt: 1000 - i,
            content: '',
            timestamp: DateTime(2026),
            title: 'V$i',
            videoUrl: 'https://example.com/v$i.mp4',
          ),
        ),
        hasMoreContent: false,
      );
      expect(ProfileFeed.estimateNextRestOffset(state), 37);
    });

    test('returns batchSize when visibleCount is less than one batch', () {
      final state = VideoFeedState(
        videos: List.generate(
          9,
          (i) => VideoEvent(
            id: 'v$i',
            pubkey: userId,
            createdAt: 1000 - i,
            content: '',
            timestamp: DateTime(2026),
            title: 'V$i',
            videoUrl: 'https://example.com/v$i.mp4',
          ),
        ),
        hasMoreContent: true,
      );
      // batchSize is 50 (from AppConstants.paginationBatchSize)
      expect(ProfileFeed.estimateNextRestOffset(state), 50);
    });

    test(
      'rounds up to next batch boundary when visibleCount exceeds one batch',
      () {
        final state = VideoFeedState(
          videos: List.generate(
            85,
            (i) => VideoEvent(
              id: 'v$i',
              pubkey: userId,
              createdAt: 1000 - i,
              content: '',
              timestamp: DateTime(2026),
              title: 'V$i',
              videoUrl: 'https://example.com/v$i.mp4',
            ),
          ),
          hasMoreContent: true,
        );
        // ceil(85/50)*50 = 100
        expect(ProfileFeed.estimateNextRestOffset(state), 100);
      },
    );

    test('returns exact batch boundary when visibleCount is a multiple', () {
      final state = VideoFeedState(
        videos: List.generate(
          100,
          (i) => VideoEvent(
            id: 'v$i',
            pubkey: userId,
            createdAt: 1000 - i,
            content: '',
            timestamp: DateTime(2026),
            title: 'V$i',
            videoUrl: 'https://example.com/v$i.mp4',
          ),
        ),
        hasMoreContent: true,
      );
      expect(ProfileFeed.estimateNextRestOffset(state), 100);
    });
  });

  group('ProfileFeed REST pagination contract', () {
    late _MockFunnelcakeApiClient mockFunnelcakeApiClient;
    late _MockVideoEventService mockVideoEventService;
    late _MockNostrClient mockNostrClient;

    setUp(() {
      _controlledFunnelcakeAvailability = false;
      mockFunnelcakeApiClient = _MockFunnelcakeApiClient();
      mockVideoEventService = _MockVideoEventService();
      mockNostrClient = _MockNostrClient();

      when(
        () => mockFunnelcakeApiClient.getBulkVideoStats(any()),
      ).thenAnswer((_) async => const BulkVideoStatsResponse(stats: {}));
      when(
        () => mockFunnelcakeApiClient.getVideoViews(any()),
      ).thenAnswer((_) async => 0);
      when(
        () => mockNostrClient.queryEvents(any()),
      ).thenAnswer((_) async => []);
      when(
        () => mockVideoEventService.addVideoUpdateListener(any()),
      ).thenReturn(() {});
      when(() => mockVideoEventService.addListener(any())).thenReturn(null);
      when(() => mockVideoEventService.removeListener(any())).thenReturn(null);
      when(
        () => mockVideoEventService.addNewVideoListener(any()),
      ).thenReturn(() {});
      when(
        () => mockVideoEventService.subscribeToUserVideos(userId),
      ).thenAnswer((_) async {});
      when(() => mockVideoEventService.authorVideos(userId)).thenReturn([]);
      when(() => mockVideoEventService.filterVideoList(any())).thenAnswer((
        invocation,
      ) {
        return invocation.positionalArguments.single as List<VideoEvent>;
      });
      when(
        () => mockVideoEventService.isVideoLocallyDeleted(any()),
      ).thenReturn(false);
    });

    ProviderContainer createContainer({
      bool funnelcakeAvailable = true,
      bool useControlledAvailability = false,
    }) {
      final container = ProviderContainer(
        overrides: [
          funnelcakeApiClientProvider.overrideWithValue(
            mockFunnelcakeApiClient,
          ),
          funnelcakeAvailableProvider.overrideWith(
            useControlledAvailability
                ? _ControlledFunnelcake.new
                : funnelcakeAvailable
                ? _AlwaysAvailableFunnelcake.new
                : _NeverAvailableFunnelcake.new,
          ),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          nostrServiceProvider.overrideWithValue(mockNostrClient),
          profileFeedSessionCacheProvider.overrideWith(
            (ref) => ProfileFeedSessionCache(),
          ),
          contentFilterVersionProvider.overrideWith((ref) => 0),
          divineHostFilterVersionProvider.overrideWith((ref) => 0),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test(
      'REST hydration keeps hasMoreContent true when a full page filters down',
      () async {
        when(
          () => mockFunnelcakeApiClient.getVideosByAuthor(pubkey: userId),
        ).thenAnswer((_) async => _videoStats(count: 50, pubkey: userId));
        when(() => mockVideoEventService.filterVideoList(any())).thenAnswer((
          invocation,
        ) {
          final videos =
              invocation.positionalArguments.single as List<VideoEvent>;
          return videos.take(9).toList();
        });

        final container = createContainer();
        await container.read(funnelcakeAvailableProvider.future);

        await container.read(profileFeedProvider(userId).future);

        final hydrated = Completer<VideoFeedState>();
        final subscription = container.listen<AsyncValue<VideoFeedState>>(
          profileFeedProvider(userId),
          (previous, next) {
            final value = next.asData?.value;
            if (value != null &&
                value.videos.length == 9 &&
                value.hasMoreContent &&
                !hydrated.isCompleted) {
              hydrated.complete(value);
            }
          },
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        final state = await hydrated.future.timeout(
          const Duration(milliseconds: 200),
        );
        expect(state.videos.length, 9);
        expect(state.hasMoreContent, isTrue);
      },
    );

    test(
      'initial load returns relay videos without waiting for a slower REST response',
      () async {
        final restCompleter = Completer<VideosByAuthorResponse>();
        addTearDown(() {
          if (!restCompleter.isCompleted) {
            restCompleter.complete(_videoStats(count: 0, pubkey: userId));
          }
        });

        when(
          () => mockFunnelcakeApiClient.getVideosByAuthor(pubkey: userId),
        ).thenAnswer((_) => restCompleter.future);
        when(() => mockVideoEventService.authorVideos(userId)).thenReturn([
          _relayVideo(
            id: 'relay-head',
            pubkey: userId,
            stableId: 'relay-head',
            createdAt: DateTime(2026, 3, 30, 12, 0, 30),
          ),
        ]);

        final container = createContainer();
        await container.read(funnelcakeAvailableProvider.future);

        final state = await container
            .read(profileFeedProvider(userId).future)
            .timeout(const Duration(milliseconds: 100));

        expect(state.videos.map((v) => v.id), ['relay-head']);
        expect(state.isInitialLoad, isFalse);
      },
    );

    test(
      'late Funnelcake availability refreshes relay-only profile videos with REST stats',
      () async {
        when(() => mockVideoEventService.authorVideos(userId)).thenReturn([
          _relayVideo(
            id: 'video-0',
            pubkey: userId,
            stableId: 'video-0',
            createdAt: DateTime(2026, 3, 30, 12),
          ),
        ]);
        when(
          () => mockFunnelcakeApiClient.getVideosByAuthor(pubkey: userId),
        ).thenAnswer(
          (_) async => VideosByAuthorResponse(
            videos: [
              VideoStats(
                id: 'video-0',
                pubkey: userId,
                createdAt: DateTime(2026, 3, 30, 12),
                kind: 22,
                dTag: 'video-0',
                title: 'Video 0',
                thumbnail: 'https://example.com/thumb-0.jpg',
                videoUrl: 'https://example.com/video-0.mp4',
                reactions: 0,
                comments: 0,
                reposts: 0,
                engagementScore: 0,
              ),
            ],
          ),
        );
        when(
          () => mockFunnelcakeApiClient.getVideoViews('video-0'),
        ).thenAnswer((_) async => 42);

        final container = createContainer(useControlledAvailability: true);

        final initialState = await container.read(
          profileFeedProvider(userId).future,
        );
        expect(initialState.videos, hasLength(1));
        expect(initialState.videos.single.totalLoops, 0);
        expect(initialState.isFetchingTotalCount, isFalse);

        final hydrated = Completer<VideoFeedState>();
        final subscription = container.listen<AsyncValue<VideoFeedState>>(
          profileFeedProvider(userId),
          (previous, next) {
            final value = next.asData?.value;
            if (value != null &&
                value.videos.length == 1 &&
                value.videos.single.totalLoops == 42 &&
                !hydrated.isCompleted) {
              hydrated.complete(value);
            }
          },
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        _controlledFunnelcakeAvailability = true;
        container.invalidate(_controlledFunnelcakeAvailabilityProvider);

        final hydratedState = await hydrated.future.timeout(
          const Duration(milliseconds: 300),
        );
        expect(hydratedState.videos.single.rawTags['views'], '42');
        expect(hydratedState.videos.single.totalLoops, 42);
      },
    );

    test(
      'late REST merge keeps relay head item and adds REST pagination metadata',
      () async {
        final restCompleter = Completer<VideosByAuthorResponse>();
        addTearDown(() {
          if (!restCompleter.isCompleted) {
            restCompleter.complete(_videoStats(count: 0, pubkey: userId));
          }
        });

        when(
          () => mockFunnelcakeApiClient.getVideosByAuthor(pubkey: userId),
        ).thenAnswer((_) => restCompleter.future);
        when(() => mockVideoEventService.authorVideos(userId)).thenReturn([
          _relayVideo(
            id: 'relay-head',
            pubkey: userId,
            stableId: 'relay-head',
            createdAt: DateTime(2026, 3, 30, 12, 0, 30),
          ),
        ]);

        final container = createContainer();
        await container.read(funnelcakeAvailableProvider.future);

        final initialState = await container
            .read(profileFeedProvider(userId).future)
            .timeout(const Duration(milliseconds: 100));
        expect(initialState.videos.map((v) => v.id), ['relay-head']);

        final merged = Completer<VideoFeedState>();
        final subscription = container.listen<AsyncValue<VideoFeedState>>(
          profileFeedProvider(userId),
          (previous, next) {
            final value = next.asData?.value;
            if (value != null &&
                value.videos.length == 3 &&
                value.totalVideoCount == 12 &&
                !merged.isCompleted) {
              merged.complete(value);
            }
          },
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        restCompleter.complete(
          _videoStats(count: 2, pubkey: userId, startIndex: 1, totalCount: 12),
        );

        final mergedState = await merged.future.timeout(
          const Duration(milliseconds: 200),
        );
        expect(mergedState.videos.map((v) => v.id), [
          'relay-head',
          'video-1',
          'video-2',
        ]);
        expect(mergedState.hasMoreContent, isFalse);
        expect(mergedState.totalVideoCount, 12);
      },
    );

    test(
      'nostr fallback resolves initial state even when subscribe startup hangs',
      () async {
        final subscribeCompleter = Completer<void>();
        addTearDown(() {
          if (!subscribeCompleter.isCompleted) {
            subscribeCompleter.complete();
          }
        });

        when(
          () => mockVideoEventService.subscribeToUserVideos(userId),
        ).thenAnswer((_) => subscribeCompleter.future);
        when(() => mockVideoEventService.authorVideos(userId)).thenReturn([]);

        final container = createContainer(funnelcakeAvailable: false);

        final state = await container
            .read(profileFeedProvider(userId).future)
            .timeout(const Duration(milliseconds: 100));

        expect(state.videos, isEmpty);
        expect(state.hasMoreContent, isFalse);
      },
    );

    test(
      'REST refreshFromService marks hasMoreContent false when response is shorter than a page',
      () async {
        final responses = Queue<VideosByAuthorResponse>()
          ..add(_videoStats(count: 50, pubkey: userId))
          ..add(_videoStats(count: 12, pubkey: userId));

        when(
          () => mockFunnelcakeApiClient.getVideosByAuthor(pubkey: userId),
        ).thenAnswer((_) async => responses.removeFirst());

        final container = createContainer();
        await container.read(funnelcakeAvailableProvider.future);
        final notifier = container.read(profileFeedProvider(userId).notifier);

        await container.read(profileFeedProvider(userId).future);

        final initialHydrated = Completer<void>();
        final initialSubscription = container
            .listen<AsyncValue<VideoFeedState>>(profileFeedProvider(userId), (
              previous,
              next,
            ) {
              final value = next.asData?.value;
              if (value != null &&
                  value.videos.length == 50 &&
                  !initialHydrated.isCompleted) {
                initialHydrated.complete();
              }
            }, fireImmediately: true);
        addTearDown(initialSubscription.close);
        await initialHydrated.future.timeout(const Duration(milliseconds: 200));

        final completer = Completer<void>();
        final subscription = container.listen<AsyncValue<VideoFeedState>>(
          profileFeedProvider(userId),
          (previous, next) {
            final value = next.asData?.value;
            if (value != null &&
                value.videos.length == 12 &&
                !completer.isCompleted) {
              completer.complete();
            }
          },
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        notifier.refreshFromService();
        await completer.future;

        final refreshedState = container
            .read(profileFeedProvider(userId))
            .requireValue;
        expect(refreshedState.videos.length, 12);
        expect(refreshedState.hasMoreContent, isFalse);
      },
    );

    test(
      'REST loadMore requests the next author page via offset and appends videos',
      () async {
        when(
          () => mockFunnelcakeApiClient.getVideosByAuthor(pubkey: userId),
        ).thenAnswer((_) async => _videoStats(count: 50, pubkey: userId));
        when(
          () => mockFunnelcakeApiClient.getVideosByAuthor(
            pubkey: userId,
            offset: 50,
          ),
        ).thenAnswer(
          (_) async => _videoStats(count: 17, pubkey: userId, startIndex: 50),
        );

        final container = createContainer();
        await container.read(funnelcakeAvailableProvider.future);
        final notifier = container.read(profileFeedProvider(userId).notifier);

        await container.read(profileFeedProvider(userId).future);

        final hydrated = Completer<VideoFeedState>();
        final subscription = container.listen<AsyncValue<VideoFeedState>>(
          profileFeedProvider(userId),
          (previous, next) {
            final value = next.asData?.value;
            if (value != null &&
                value.videos.length == 50 &&
                value.hasMoreContent &&
                !hydrated.isCompleted) {
              hydrated.complete(value);
            }
          },
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        final initialState = await hydrated.future.timeout(
          const Duration(milliseconds: 200),
        );
        expect(initialState.videos.length, 50);
        expect(initialState.hasMoreContent, isTrue);

        await notifier.loadMore();

        final updatedState = container
            .read(profileFeedProvider(userId))
            .requireValue;
        expect(updatedState.videos.length, 67);
        expect(updatedState.hasMoreContent, isFalse);

        verify(
          () => mockFunnelcakeApiClient.getVideosByAuthor(
            pubkey: userId,
            offset: 50,
          ),
        ).called(1);
      },
    );

    test(
      'REST loadMore uses server nextOffset from v2 pagination envelope',
      () async {
        when(
          () => mockFunnelcakeApiClient.getVideosByAuthor(pubkey: userId),
        ).thenAnswer(
          (_) async => _videoStats(
            count: 12,
            pubkey: userId,
            nextOffset: 50,
            hasMore: true,
          ),
        );
        when(
          () => mockFunnelcakeApiClient.getVideosByAuthor(
            pubkey: userId,
            offset: 50,
          ),
        ).thenAnswer(
          (_) async => _videoStats(
            count: 4,
            pubkey: userId,
            startIndex: 50,
            nextOffset: 54,
            hasMore: false,
          ),
        );

        final container = createContainer();
        await container.read(funnelcakeAvailableProvider.future);
        final notifier = container.read(profileFeedProvider(userId).notifier);

        await container.read(profileFeedProvider(userId).future);

        final hydrated = Completer<void>();
        final subscription = container.listen<AsyncValue<VideoFeedState>>(
          profileFeedProvider(userId),
          (previous, next) {
            final value = next.asData?.value;
            if (value != null &&
                value.videos.length == 12 &&
                value.hasMoreContent &&
                !hydrated.isCompleted) {
              hydrated.complete();
            }
          },
          fireImmediately: true,
        );
        addTearDown(subscription.close);
        await hydrated.future.timeout(const Duration(milliseconds: 200));

        await notifier.loadMore();

        verifyNever(
          () => mockFunnelcakeApiClient.getVideosByAuthor(
            pubkey: userId,
            offset: 12,
          ),
        );
        verify(
          () => mockFunnelcakeApiClient.getVideosByAuthor(
            pubkey: userId,
            offset: 50,
          ),
        ).called(1);
      },
    );

    test(
      'REST loadMore dedupes replaceable videos by stable identity',
      () async {
        when(
          () => mockFunnelcakeApiClient.getVideosByAuthor(pubkey: userId),
        ).thenAnswer((_) async => _videoStats(count: 50, pubkey: userId));
        when(
          () => mockFunnelcakeApiClient.getVideosByAuthor(
            pubkey: userId,
            offset: 50,
          ),
        ).thenAnswer(
          (_) async => VideosByAuthorResponse(
            videos: [
              _videoStat(
                id: 'video-0-replacement',
                pubkey: userId,
                stableId: 'video-0',
                createdAt: DateTime(2026, 3, 30, 12, 1),
              ),
              _videoStat(
                id: 'video-50',
                pubkey: userId,
                stableId: 'video-50',
                createdAt: DateTime(2026, 3, 30, 11, 10),
              ),
            ],
            totalCount: 51,
          ),
        );

        final container = createContainer();
        await container.read(funnelcakeAvailableProvider.future);
        final notifier = container.read(profileFeedProvider(userId).notifier);

        await container.read(profileFeedProvider(userId).future);

        final hydrated = Completer<void>();
        final subscription = container.listen<AsyncValue<VideoFeedState>>(
          profileFeedProvider(userId),
          (previous, next) {
            final value = next.asData?.value;
            if (value != null &&
                value.videos.length == 50 &&
                value.hasMoreContent &&
                !hydrated.isCompleted) {
              hydrated.complete();
            }
          },
          fireImmediately: true,
        );
        addTearDown(subscription.close);
        await hydrated.future.timeout(const Duration(milliseconds: 200));

        await notifier.loadMore();

        final updatedState = container
            .read(profileFeedProvider(userId))
            .requireValue;
        expect(updatedState.videos.length, 51);
        expect(
          updatedState.videos.where((video) => video.stableId == 'video-0'),
          hasLength(1),
        );
        expect(
          updatedState.videos.any((video) => video.id == 'video-50'),
          isTrue,
        );
      },
    );

    // Pins the per-call funnelcake-availability contract from #3849: a
    // transient REST failure during build must NOT prevent a subsequent
    // refresh() from re-attempting REST. Will fail loudly if a future
    // change ever reintroduces a sticky-disable shape that gates
    // _refreshFromRestApi on previous-call success.
    test(
      'refresh after a build-time REST failure re-attempts REST and recovers',
      () async {
        var restCallCount = 0;
        when(
          () => mockFunnelcakeApiClient.getVideosByAuthor(pubkey: userId),
        ).thenAnswer((_) async {
          restCallCount++;
          if (restCallCount == 1) {
            throw const FunnelcakeApiException(
              message: 'transient server error',
              statusCode: 500,
            );
          }
          return _videoStats(count: 3, pubkey: userId);
        });

        final container = createContainer();
        await container.read(funnelcakeAvailableProvider.future);
        final notifier = container.read(profileFeedProvider(userId).notifier);

        // Initial build: REST throws on the first call → falls back to relay
        // (empty in this test setup).
        final initialState = await container.read(
          profileFeedProvider(userId).future,
        );
        expect(initialState.videos, isEmpty);

        // Wait for the background _refreshFromRestApi triggered by build to
        // settle so the failure is observed before we trigger refresh().
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // refresh() must re-attempt REST instead of skipping it.
        await notifier.refresh();

        // Allow the parallel _refreshFromRestApi inside refresh() to complete.
        final hydrated = Completer<VideoFeedState>();
        final subscription = container.listen<AsyncValue<VideoFeedState>>(
          profileFeedProvider(userId),
          (previous, next) {
            final value = next.asData?.value;
            if (value != null &&
                value.videos.length == 3 &&
                !hydrated.isCompleted) {
              hydrated.complete(value);
            }
          },
          fireImmediately: true,
        );
        addTearDown(subscription.close);

        final recoveredState = await hydrated.future.timeout(
          const Duration(milliseconds: 300),
        );
        expect(recoveredState.videos, hasLength(3));
        expect(restCallCount, greaterThanOrEqualTo(2));
      },
    );

    // Pins the per-call funnelcake-availability contract from #3849: a REST
    // failure on loadMore must not poison the pagination state. The next
    // loadMore should still attempt REST when funnelcake remains available
    // and the REST cursor (_nextOffset) is set.
    test(
      'loadMore retries REST after a transient pagination failure',
      () async {
        var nextPageCallCount = 0;
        when(
          () => mockFunnelcakeApiClient.getVideosByAuthor(pubkey: userId),
        ).thenAnswer((_) async => _videoStats(count: 50, pubkey: userId));
        when(
          () => mockFunnelcakeApiClient.getVideosByAuthor(
            pubkey: userId,
            offset: 50,
          ),
        ).thenAnswer((_) async {
          nextPageCallCount++;
          if (nextPageCallCount == 1) {
            throw const FunnelcakeApiException(
              message: 'service unavailable',
              statusCode: 503,
            );
          }
          return _videoStats(count: 5, pubkey: userId, startIndex: 50);
        });

        final container = createContainer();
        await container.read(funnelcakeAvailableProvider.future);
        final notifier = container.read(profileFeedProvider(userId).notifier);

        await container.read(profileFeedProvider(userId).future);

        final hydrated = Completer<VideoFeedState>();
        final subscription = container.listen<AsyncValue<VideoFeedState>>(
          profileFeedProvider(userId),
          (previous, next) {
            final value = next.asData?.value;
            if (value != null &&
                value.videos.length == 50 &&
                value.hasMoreContent &&
                !hydrated.isCompleted) {
              hydrated.complete(value);
            }
          },
          fireImmediately: true,
        );
        addTearDown(subscription.close);
        await hydrated.future.timeout(const Duration(milliseconds: 200));

        // First loadMore: REST fails. Pagination state must NOT be wiped.
        await notifier.loadMore();

        // Second loadMore: REST should be retried (was previously skipped).
        await notifier.loadMore();

        expect(nextPageCallCount, 2);
        final updatedState = container
            .read(profileFeedProvider(userId))
            .requireValue;
        expect(updatedState.videos.length, 55);
      },
    );
  });
}

VideosByAuthorResponse _videoStats({
  required int count,
  required String pubkey,
  int startIndex = 0,
  int? totalCount,
  int? nextOffset,
  bool? hasMore,
}) {
  final now = DateTime(2026, 3, 30, 12);

  final videos = List.generate(count, (index) {
    final videoIndex = startIndex + index;
    final createdAt = now.subtract(Duration(minutes: videoIndex));
    return VideoStats(
      id: 'video-$videoIndex',
      pubkey: pubkey,
      createdAt: createdAt,
      kind: 22,
      dTag: 'video-$videoIndex',
      title: 'Video $videoIndex',
      thumbnail: 'https://example.com/thumb-$videoIndex.jpg',
      videoUrl: 'https://example.com/video-$videoIndex.mp4',
      reactions: videoIndex,
      comments: videoIndex,
      reposts: videoIndex,
      engagementScore: videoIndex,
    );
  });
  return VideosByAuthorResponse(
    videos: videos,
    totalCount: totalCount,
    nextOffset: nextOffset,
    hasMore: hasMore,
  );
}

VideoStats _videoStat({
  required String id,
  required String pubkey,
  required String stableId,
  required DateTime createdAt,
}) {
  return VideoStats(
    id: id,
    pubkey: pubkey,
    createdAt: createdAt,
    kind: 22,
    dTag: stableId,
    title: 'Video $id',
    thumbnail: 'https://example.com/$id.jpg',
    videoUrl: 'https://example.com/$id.mp4',
    reactions: 1,
    comments: 1,
    reposts: 1,
    engagementScore: 1,
  );
}

VideoEvent _relayVideo({
  required String id,
  required String pubkey,
  required String stableId,
  required DateTime createdAt,
}) {
  return VideoEvent(
    id: id,
    pubkey: pubkey,
    createdAt: createdAt.millisecondsSinceEpoch ~/ 1000,
    content: 'Relay video $id',
    timestamp: createdAt,
    title: 'Relay video $id',
    videoUrl: 'https://example.com/$id.mp4',
    vineId: stableId,
    rawTags: {'d': stableId},
  );
}
