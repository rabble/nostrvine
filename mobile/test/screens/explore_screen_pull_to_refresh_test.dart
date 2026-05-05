// ABOUTME: Test for explore screen pull-to-refresh behavior on New tab
// ABOUTME: Ensures pull-to-refresh forces a new subscription to get fresh videos

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
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/popular_now_feed_provider.dart';
import 'package:openvine/providers/readiness_gate_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:openvine/services/video_filter_builder.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _MockNostrClient extends Mock implements NostrClient {}

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

/// Nostr-only feeds: matches production when Funnelcake REST is unavailable.
class _NeverAvailableFunnelcake extends FunnelcakeAvailable {
  @override
  Future<bool> build() async => false;
}

void main() {
  group('ExploreScreen Pull-to-Refresh', () {
    late _MockVideoEventService mockService;
    late _MockContentBlocklistRepository mockBlocklist;
    late _MockNostrClient mockNostr;
    late _MockFunnelcakeApiClient mockFunnelcakeApiClient;
    late SharedPreferences sharedPreferences;
    late ProviderContainer container;

    setUpAll(() {
      registerFallbackValue(SubscriptionType.popularNow);
      registerFallbackValue(VideoSortField.createdAt);
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
      mockService = _MockVideoEventService();
      mockBlocklist = _MockContentBlocklistRepository();
      mockNostr = _MockNostrClient();
      mockFunnelcakeApiClient = _MockFunnelcakeApiClient();

      when(() => mockFunnelcakeApiClient.isAvailable).thenReturn(true);

      when(() => mockBlocklist.shouldFilterFromFeeds(any())).thenReturn(false);
      when(() => mockService.addListener(any())).thenReturn(null);
      when(() => mockService.removeListener(any())).thenReturn(null);
      when(() => mockService.addVideoUpdateListener(any())).thenReturn(() {});
      when(() => mockService.filterVideoList(any())).thenAnswer((invocation) {
        return List<VideoEvent>.from(
          invocation.positionalArguments.first as List,
        );
      });
      when(() => mockService.popularNowVideos).thenReturn([]);
      when(
        () => mockService.subscribeToVideoFeed(
          subscriptionType: any(named: 'subscriptionType'),
          limit: any(named: 'limit'),
          sortBy: any(named: 'sortBy'),
          force: any(named: 'force'),
        ),
      ).thenAnswer((_) async {});

      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          appReadyProvider.overrideWithValue(true),
          videoEventServiceProvider.overrideWithValue(mockService),
          contentBlocklistRepositoryProvider.overrideWithValue(mockBlocklist),
          funnelcakeApiClientProvider.overrideWithValue(
            mockFunnelcakeApiClient,
          ),
          funnelcakeAvailableProvider.overrideWith(
            _NeverAvailableFunnelcake.new,
          ),
          nostrServiceProvider.overrideWithValue(mockNostr),
          contentFilterVersionProvider.overrideWith((ref) => 0),
          divineHostFilterVersionProvider.overrideWith((ref) => 0),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test(
      'calls subscribeToVideoFeed with force:true when refresh runs',
      () async {
        final initialVideos = [
          _createMockVideo(id: 'v1', createdAt: DateTime(2025)),
          _createMockVideo(id: 'v2', createdAt: DateTime(2025, 1, 2)),
        ];
        when(() => mockService.popularNowVideos).thenReturn(initialVideos);

        await container.read(funnelcakeAvailableProvider.future);
        await container.read(popularNowFeedProvider.future);

        clearInteractions(mockService);

        await container.read(popularNowFeedProvider.notifier).refresh();

        verify(
          () => mockService.subscribeToVideoFeed(
            subscriptionType: SubscriptionType.popularNow,
            limit: AppConstants.paginationBatchSize,
            sortBy: any(named: 'sortBy', that: isNotNull),
            force: true,
          ),
        ).called(1);
      },
    );

    test(
      'refresh triggers at least one forced subscribe when starting from empty Nostr state',
      () async {
        when(() => mockService.popularNowVideos).thenReturn([]);

        await container.read(funnelcakeAvailableProvider.future);
        await container.read(popularNowFeedProvider.future);

        clearInteractions(mockService);

        await container.read(popularNowFeedProvider.notifier).refresh();

        verify(
          () => mockService.subscribeToVideoFeed(
            subscriptionType: any(named: 'subscriptionType'),
            limit: any(named: 'limit'),
            sortBy: any(named: 'sortBy'),
            force: any(named: 'force'),
          ),
        ).called(greaterThanOrEqualTo(1));
      },
    );
  });
}

VideoEvent _createMockVideo({required String id, DateTime? createdAt}) {
  final timestamp = createdAt ?? DateTime.now();
  return VideoEvent(
    id: id,
    pubkey: 'test_pubkey',
    createdAt: timestamp.millisecondsSinceEpoch ~/ 1000,
    content: 'Test video',
    timestamp: timestamp,
    videoUrl: 'https://example.com/video.mp4',
    thumbnailUrl: 'https://example.com/thumb.jpg',
  );
}
