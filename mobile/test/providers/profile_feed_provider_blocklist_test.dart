// ABOUTME: Tests that ProfileFeed filters blocked/muted authors from the
// ABOUTME: Funnelcake REST author feed (anonymous endpoint = no server filter). See #4782.

import 'dart:async';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
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

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _AlwaysAvailableFunnelcake extends FunnelcakeAvailable {
  @override
  Future<bool> build() async => true;
}

class _NeverAvailableFunnelcake extends FunnelcakeAvailable {
  @override
  Future<bool> build() async => false;
}

VideosByAuthorResponse _authorVideos({
  required int count,
  required String pubkey,
}) {
  final now = DateTime(2026, 3, 30, 12);
  final videos = List.generate(count, (index) {
    return VideoStats(
      id: 'video-$index',
      pubkey: pubkey,
      createdAt: now.subtract(Duration(minutes: index)),
      kind: 22,
      dTag: 'video-$index',
      title: 'Video $index',
      thumbnail: 'https://example.com/thumb-$index.jpg',
      videoUrl: 'https://example.com/video-$index.mp4',
      reactions: 0,
      comments: 0,
      reposts: 0,
      engagementScore: 0,
    );
  });
  return VideosByAuthorResponse(videos: videos, hasMore: false);
}

void main() {
  // A profile feed contains a single author, so blocking that author should
  // empty the grid; not blocking should show all videos. The delta proves the
  // blocklist filter (kind 30000 d=block / kind 10000) is applied to the
  // anonymous Funnelcake author endpoint that performs no server-side filter.
  const userId =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  group('$ProfileFeed blocklist filtering (#4782)', () {
    late _MockFunnelcakeApiClient mockFunnelcakeApiClient;
    late _MockVideoEventService mockVideoEventService;
    late _MockNostrClient mockNostrClient;
    late _MockContentBlocklistRepository mockBlocklistRepository;

    setUp(() {
      mockFunnelcakeApiClient = _MockFunnelcakeApiClient();
      mockVideoEventService = _MockVideoEventService();
      mockNostrClient = _MockNostrClient();
      mockBlocklistRepository = _MockContentBlocklistRepository();

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
      when(
        () => mockVideoEventService.authorVideos(userId),
      ).thenReturn(<VideoEvent>[]);
      when(() => mockVideoEventService.filterVideoList(any())).thenAnswer(
        (invocation) =>
            invocation.positionalArguments.single as List<VideoEvent>,
      );
      when(
        () => mockVideoEventService.isVideoLocallyDeleted(any()),
      ).thenReturn(false);
    });

    ProviderContainer createContainer({
      ProfileFeedSessionCache? sessionCache,
      bool funnelcakeAvailable = true,
    }) {
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
          contentBlocklistRepositoryProvider.overrideWithValue(
            mockBlocklistRepository,
          ),
          profileFeedSessionCacheProvider.overrideWith(
            (ref) => sessionCache ?? ProfileFeedSessionCache(),
          ),
          contentFilterVersionProvider.overrideWith((ref) => 0),
          divineHostFilterVersionProvider.overrideWith((ref) => 0),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('keeps all author videos when the author is NOT blocked', () async {
      when(
        () => mockBlocklistRepository.shouldFilterFromFeeds(any()),
      ).thenReturn(false);
      when(
        () => mockFunnelcakeApiClient.getVideosByAuthor(pubkey: userId),
      ).thenAnswer((_) async => _authorVideos(count: 3, pubkey: userId));

      final container = createContainer();
      await container.read(funnelcakeAvailableProvider.future);
      await container.read(profileFeedProvider(userId).future);

      final loaded = Completer<VideoFeedState>();
      final sub = container.listen<AsyncValue<VideoFeedState>>(
        profileFeedProvider(userId),
        (previous, next) {
          final value = next.asData?.value;
          if (value != null &&
              value.videos.length == 3 &&
              !loaded.isCompleted) {
            loaded.complete(value);
          }
        },
        fireImmediately: true,
      );
      addTearDown(sub.close);

      final state = await loaded.future.timeout(const Duration(seconds: 5));
      expect(state.videos, hasLength(3));
      expect(state.videos.every((v) => v.pubkey == userId), isTrue);
    });

    test('removes the author videos when the author is blocked', () async {
      final filterApplied = Completer<void>();
      when(
        () => mockBlocklistRepository.shouldFilterFromFeeds(userId),
      ).thenAnswer((_) {
        if (!filterApplied.isCompleted) filterApplied.complete();
        return true;
      });
      when(
        () => mockFunnelcakeApiClient.getVideosByAuthor(pubkey: userId),
      ).thenAnswer((_) async => _authorVideos(count: 3, pubkey: userId));

      final container = createContainer();
      await container.read(funnelcakeAvailableProvider.future);
      await container.read(profileFeedProvider(userId).future);

      // Wait until the REST hydration path consults the blocklist.
      await filterApplied.future.timeout(const Duration(seconds: 5));
      // Let the post-filter merge settle.
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final state = container.read(profileFeedProvider(userId)).asData?.value;
      expect(state, isNotNull);
      expect(
        state!.videos.where((v) => v.pubkey == userId),
        isEmpty,
        reason: "A blocked author's videos must not appear in their feed",
      );
      verify(
        () => mockBlocklistRepository.shouldFilterFromFeeds(userId),
      ).called(greaterThanOrEqualTo(1));
    });

    test(
      'filters retained session-cache videos after a blocklist change',
      () async {
        final cachedVideos = _authorVideos(
          count: 2,
          pubkey: userId,
        ).videos.toVideoEvents();
        final sessionCache = ProfileFeedSessionCache()
          ..write(
            userId,
            VideoFeedState(
              videos: cachedVideos,
              hasMoreContent: false,
              lastUpdated: DateTime(2026, 3, 30, 12),
            ),
          );

        when(
          () => mockBlocklistRepository.shouldFilterFromFeeds(userId),
        ).thenReturn(true);

        final container = createContainer(
          sessionCache: sessionCache,
          funnelcakeAvailable: false,
        );
        await container.read(funnelcakeAvailableProvider.future);

        final state = await container.read(profileFeedProvider(userId).future);

        expect(
          state.videos.where((v) => v.pubkey == userId),
          isEmpty,
          reason:
              'Warm profile-feed cache must not re-show an author after they are blocked',
        );
        verify(
          () => mockBlocklistRepository.shouldFilterFromFeeds(userId),
        ).called(greaterThanOrEqualTo(1));
        verifyNever(
          () => mockFunnelcakeApiClient.getVideosByAuthor(pubkey: userId),
        );
      },
    );
  });
}
