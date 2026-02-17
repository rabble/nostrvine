// ABOUTME: Tests that feed providers preserve cached videos during background
// ABOUTME: Verifies fix for feeds going empty when app resumes from background

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/classic_vines_provider.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/popular_now_feed_provider.dart';
import 'package:openvine/providers/readiness_gate_providers.dart';
import 'package:openvine/services/analytics_api_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:riverpod/riverpod.dart';

import 'feed_background_preservation_test.mocks.dart';

/// Test override for FunnelcakeAvailable that always returns false
/// (forces Nostr fallback path for simpler mocking)
class _TestFunnelcakeUnavailable extends FunnelcakeAvailable {
  @override
  Future<bool> build() async => false;
}

@GenerateMocks([AnalyticsApiService, VideoEventService])
void main() {
  group('Feed background state preservation', () {
    late MockAnalyticsApiService mockAnalyticsService;
    late MockVideoEventService mockVideoEventService;

    // Test videos with originalLoops for ClassicVines Nostr fallback
    final testVideos = List.generate(
      5,
      (i) => VideoEvent(
        id: 'video_$i' * 8, // 64 char hex-like ID
        pubkey: 'pubkey_$i' * 7,
        createdAt:
            DateTime.now()
                .subtract(Duration(hours: i))
                .millisecondsSinceEpoch ~/
            1000,
        content: 'Test video $i',
        timestamp: DateTime.now().subtract(Duration(hours: i)),
        videoUrl: 'https://example.com/video_$i.mp4',
        thumbnailUrl: 'https://example.com/thumb_$i.jpg',
        originalLoops: 1000 - i * 100,
      ),
    );

    setUp(() {
      mockAnalyticsService = MockAnalyticsApiService();
      mockVideoEventService = MockVideoEventService();

      when(mockAnalyticsService.isAvailable).thenReturn(false);

      // Nostr fallback data: discoveryVideos for ClassicVines
      when(mockVideoEventService.discoveryVideos).thenReturn(testVideos);
      when(mockVideoEventService.popularNowVideos).thenReturn(testVideos);
      when(mockVideoEventService.addListener(any)).thenReturn(null);
      when(mockVideoEventService.removeListener(any)).thenReturn(null);
      when(mockVideoEventService.addVideoUpdateListener(any)).thenReturn(() {});
      when(
        mockVideoEventService.subscribeToVideoFeed(
          subscriptionType: anyNamed('subscriptionType'),
          limit: anyNamed('limit'),
          sortBy: anyNamed('sortBy'),
        ),
      ).thenAnswer((_) async {});
    });

    /// Helper to create a container with standard test overrides
    ProviderContainer createContainer({required bool appReady}) {
      return ProviderContainer(
        overrides: [
          appReadyProvider.overrideWithValue(appReady),
          analyticsApiServiceProvider.overrideWithValue(mockAnalyticsService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          funnelcakeAvailableProvider.overrideWith(
            _TestFunnelcakeUnavailable.new,
          ),
        ],
      );
    }

    group(ClassicVinesFeed, () {
      test(
        'returns empty state when appReady is false and no prior data',
        () async {
          final container = createContainer(appReady: false);
          addTearDown(container.dispose);

          await container.read(funnelcakeAvailableProvider.future);
          final state = await container.read(classicVinesFeedProvider.future);

          expect(state.videos, isEmpty);
        },
      );

      test('preserves cached videos when appReady becomes false', () async {
        // Start with appReady=true to load videos via Nostr fallback
        final container = createContainer(appReady: true);
        addTearDown(container.dispose);

        // Pre-resolve funnelcake, then read the feed
        await container.read(funnelcakeAvailableProvider.future);
        final initialState = await container.read(
          classicVinesFeedProvider.future,
        );
        expect(
          initialState.videos,
          hasLength(5),
          reason: 'Should load 5 videos initially via Nostr fallback',
        );

        // Simulate going to background — appReady becomes false
        container.updateOverrides([
          appReadyProvider.overrideWithValue(false),
          analyticsApiServiceProvider.overrideWithValue(mockAnalyticsService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          funnelcakeAvailableProvider.overrideWith(
            _TestFunnelcakeUnavailable.new,
          ),
        ]);

        // Allow provider to rebuild
        await container.read(funnelcakeAvailableProvider.future);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final afterBackgroundState = await container.read(
          classicVinesFeedProvider.future,
        );

        expect(
          afterBackgroundState.videos,
          hasLength(5),
          reason: 'Should preserve videos during background',
        );
      });

      test('reloads fresh data when appReady returns to true', () async {
        final container = createContainer(appReady: true);
        addTearDown(container.dispose);

        // Initial load
        await container.read(funnelcakeAvailableProvider.future);
        final initialState = await container.read(
          classicVinesFeedProvider.future,
        );
        expect(initialState.videos, hasLength(5));

        // Go to background
        container.updateOverrides([
          appReadyProvider.overrideWithValue(false),
          analyticsApiServiceProvider.overrideWithValue(mockAnalyticsService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          funnelcakeAvailableProvider.overrideWith(
            _TestFunnelcakeUnavailable.new,
          ),
        ]);
        await container.read(funnelcakeAvailableProvider.future);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        // Verify preserved
        final backgroundState = await container.read(
          classicVinesFeedProvider.future,
        );
        expect(
          backgroundState.videos,
          hasLength(5),
          reason: 'Should preserve during background',
        );

        // Return to foreground
        container.updateOverrides([
          appReadyProvider.overrideWithValue(true),
          analyticsApiServiceProvider.overrideWithValue(mockAnalyticsService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          funnelcakeAvailableProvider.overrideWith(
            _TestFunnelcakeUnavailable.new,
          ),
        ]);
        await container.read(funnelcakeAvailableProvider.future);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final resumedState = await container.read(
          classicVinesFeedProvider.future,
        );
        expect(
          resumedState.videos,
          hasLength(5),
          reason: 'Should have videos after resuming',
        );
      });
    });

    group(PopularNowFeed, () {
      test(
        'returns empty state when appReady is false and no prior data',
        () async {
          final container = createContainer(appReady: false);
          addTearDown(container.dispose);

          await container.read(funnelcakeAvailableProvider.future);
          final state = await container.read(popularNowFeedProvider.future);

          expect(state.videos, isEmpty);
          expect(state.hasMoreContent, isTrue);
        },
      );

      test('preserves cached videos when appReady becomes false', () async {
        final container = createContainer(appReady: true);
        addTearDown(container.dispose);

        // Wait for initial load via Nostr fallback
        await container.read(funnelcakeAvailableProvider.future);
        final initialState = await container.read(
          popularNowFeedProvider.future,
        );
        expect(
          initialState.videos,
          hasLength(5),
          reason: 'Should load 5 videos initially via Nostr fallback',
        );

        // Simulate going to background
        container.updateOverrides([
          appReadyProvider.overrideWithValue(false),
          analyticsApiServiceProvider.overrideWithValue(mockAnalyticsService),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          funnelcakeAvailableProvider.overrideWith(
            _TestFunnelcakeUnavailable.new,
          ),
        ]);

        await container.read(funnelcakeAvailableProvider.future);
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final afterBackgroundState = await container.read(
          popularNowFeedProvider.future,
        );

        expect(
          afterBackgroundState.videos,
          hasLength(5),
          reason: 'Should preserve videos during background',
        );
      });
    });
  });
}
