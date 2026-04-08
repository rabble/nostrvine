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
      mockFunnelcakeApiClient = _MockFunnelcakeApiClient();
      mockVideoEventService = _MockVideoEventService();
      mockNostrClient = _MockNostrClient();

      when(
        () => mockNostrClient.queryEvents(any()),
      ).thenAnswer((_) async => []);
      when(
        () => mockVideoEventService.addVideoUpdateListener(any()),
      ).thenReturn(
        () {},
      );
      when(() => mockVideoEventService.addListener(any())).thenReturn(null);
      when(() => mockVideoEventService.removeListener(any())).thenReturn(null);
      when(() => mockVideoEventService.addNewVideoListener(any())).thenReturn(
        () {},
      );
      when(
        () => mockVideoEventService.filterVideoList(any()),
      ).thenAnswer((invocation) {
        return invocation.positionalArguments.single as List<VideoEvent>;
      });
    });

    ProviderContainer createContainer({bool funnelcakeAvailable = true}) {
      final container = ProviderContainer(
        overrides: [
          funnelcakeApiClientProvider.overrideWithValue(
            mockFunnelcakeApiClient,
          ),
          funnelcakeAvailableProvider.overrideWith(
            funnelcakeAvailable
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
      'initial REST state keeps hasMoreContent true when a full page filters down',
      () async {
        when(
          () => mockFunnelcakeApiClient.getVideosByAuthor(pubkey: userId),
        ).thenAnswer((_) async => _videoStats(count: 50, pubkey: userId));
        when(
          () => mockVideoEventService.filterVideoList(any()),
        ).thenAnswer((invocation) {
          final videos =
              invocation.positionalArguments.single as List<VideoEvent>;
          return videos.take(9).toList();
        });

        final container = createContainer();
        await container.read(funnelcakeAvailableProvider.future);

        final state = await container.read(profileFeedProvider(userId).future);

        expect(state.videos.length, 9);
        expect(state.hasMoreContent, isTrue);
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
        verify(
          () => mockVideoEventService.subscribeToUserVideos(userId),
        ).called(1);
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

        final initialState = await container.read(
          profileFeedProvider(userId).future,
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
  });
}

VideosByAuthorResponse _videoStats({
  required int count,
  required String pubkey,
  int startIndex = 0,
  int? totalCount,
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
  return VideosByAuthorResponse(videos: videos, totalCount: totalCount);
}
