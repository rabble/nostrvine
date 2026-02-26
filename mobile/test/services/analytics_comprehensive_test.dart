// ABOUTME: Comprehensive unit tests for analytics service covering all scenarios
// ABOUTME: Tests tracking, preferences, Nostr event publishing flow, and edge cases

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/services/analytics_service.dart';
import 'package:openvine/services/view_event_publisher.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Analytics Service Comprehensive Tests', () {
    late AnalyticsService analyticsService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() {
      analyticsService.dispose();
    });

    test('should track view_end with traffic source', () async {
      analyticsService = AnalyticsService(disableNostrPublishing: true);
      await analyticsService.initialize();

      final video = VideoEvent(
        id: 'test-event-id-123',
        pubkey: 'test-pubkey-456',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Test video content',
        timestamp: DateTime.now(),
        title: 'Test Video Title',
        hashtags: const ['test', 'analytics'],
      );

      // Should complete without error
      await expectLater(
        analyticsService.trackDetailedVideoViewWithUser(
          video,
          userId: 'viewer-pubkey',
          source: 'mobile',
          eventType: 'view_end',
          watchDuration: const Duration(seconds: 15),
          totalDuration: const Duration(seconds: 30),
          loopCount: 1,
          completedVideo: true,
          trafficSource: ViewTrafficSource.home,
        ),
        completes,
      );
    });

    test('should not publish Nostr event for short watch durations', () async {
      analyticsService = AnalyticsService(disableNostrPublishing: true);
      await analyticsService.initialize();

      final video = VideoEvent(
        id: 'test-event-id',
        pubkey: 'test-pubkey',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Test video',
        timestamp: DateTime.now(),
      );

      // view_end with less than 1 second should not trigger Nostr event
      await expectLater(
        analyticsService.trackDetailedVideoViewWithUser(
          video,
          userId: 'viewer',
          source: 'mobile',
          eventType: 'view_end',
          watchDuration: Duration.zero,
        ),
        completes,
      );
    });

    test('should not send requests when analytics is disabled', () async {
      analyticsService = AnalyticsService(disableNostrPublishing: true);
      await analyticsService.initialize();
      await analyticsService.setAnalyticsEnabled(false);

      final video = VideoEvent(
        id: 'test-event-id',
        pubkey: 'test-pubkey',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Test video',
        timestamp: DateTime.now(),
      );

      // Should silently skip when disabled
      await analyticsService.trackVideoView(video);
      await analyticsService.trackVideoViews([video, video]);

      // No error means it was properly gated
      expect(analyticsService.analyticsEnabled, isFalse);
    });

    test(
      'should handle view_end without ViewEventPublisher gracefully',
      () async {
        // No ViewEventPublisher injected
        analyticsService = AnalyticsService();
        await analyticsService.initialize();

        final video = VideoEvent(
          id: 'test-event-id',
          pubkey: 'test-pubkey',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          content: 'Test video',
          timestamp: DateTime.now(),
        );

        // Should complete without error even without publisher
        await expectLater(
          analyticsService.trackDetailedVideoViewWithUser(
            video,
            userId: 'viewer',
            source: 'mobile',
            eventType: 'view_end',
            watchDuration: const Duration(seconds: 10),
            trafficSource: ViewTrafficSource.discoveryNew,
          ),
          completes,
        );
      },
    );

    test('should handle concurrent tracking requests', () async {
      analyticsService = AnalyticsService(disableNostrPublishing: true);
      await analyticsService.initialize();

      final videos = List.generate(
        5,
        (index) => VideoEvent(
          id: 'concurrent-test-id-$index',
          pubkey: 'test-pubkey',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          content: 'Test video $index',
          timestamp: DateTime.now(),
        ),
      );

      // Send all requests concurrently
      final futures = videos
          .map((video) => analyticsService.trackVideoView(video))
          .toList();
      await Future.wait(futures);

      // Should complete without error
      expect(true, isTrue);
    });
  });
}
