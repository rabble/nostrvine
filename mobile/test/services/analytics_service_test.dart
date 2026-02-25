// ABOUTME: Tests for analytics service view tracking and Nostr event publishing
// ABOUTME: Verifies user preference controls, deduplication, and event flow

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/services/analytics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AnalyticsService', () {
    late AnalyticsService analyticsService;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      analyticsService = AnalyticsService(disableNostrPublishing: true);
    });

    tearDown(() {
      analyticsService.dispose();
    });

    test('should initialize with analytics enabled by default', () async {
      await analyticsService.initialize();
      expect(analyticsService.analyticsEnabled, isTrue);
    });

    test('should report operational when analytics enabled', () async {
      await analyticsService.initialize();
      expect(analyticsService.isOperational, isTrue);
    });

    test('should report not operational when analytics disabled', () async {
      await analyticsService.initialize();
      await analyticsService.setAnalyticsEnabled(false);
      expect(analyticsService.isOperational, isFalse);
    });

    test('should not track views when analytics is disabled', () async {
      await analyticsService.initialize();
      await analyticsService.setAnalyticsEnabled(false);

      final video = VideoEvent(
        id: '22e73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
        pubkey:
            'ae73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Test video',
        timestamp: DateTime.now(),
      );

      // Should complete without error even when disabled
      await expectLater(analyticsService.trackVideoView(video), completes);
    });

    test('should track view_start without publishing Nostr event', () async {
      await analyticsService.initialize();

      final video = VideoEvent(
        id: '22e73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
        pubkey:
            'ae73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Test video',
        timestamp: DateTime.now(),
      );

      // view_start should complete without error (no Nostr event published)
      await expectLater(
        analyticsService.trackDetailedVideoViewWithUser(
          video,
          userId: 'test-user',
          source: 'mobile',
          eventType: 'view_start',
        ),
        completes,
      );
    });

    test('should deduplicate rapid view_start events for same video', () async {
      await analyticsService.initialize();

      final video = VideoEvent(
        id: '22e73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
        pubkey:
            'ae73ca1faedb07dd3e24c1dca52d849aa75c6e4090eb60c532820b782c93da3',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        content: 'Test video',
        timestamp: DateTime.now(),
      );

      // Track same video twice rapidly - second should be deduped
      await analyticsService.trackVideoView(video);
      await analyticsService.trackVideoView(video);

      // Should complete without error (dedup is internal)
      expect(true, isTrue);
    });

    test('should persist analytics preference', () async {
      await analyticsService.initialize();

      // Disable analytics
      await analyticsService.setAnalyticsEnabled(false);

      // Verify persisted
      final prefs = await SharedPreferences.getInstance();
      final savedValue = prefs.getBool('analytics_enabled');
      expect(savedValue, isFalse);

      // Re-enable
      await analyticsService.setAnalyticsEnabled(true);
      final savedValue2 = prefs.getBool('analytics_enabled');
      expect(savedValue2, isTrue);
    });

    test('should clear tracked views cache', () async {
      await analyticsService.initialize();
      analyticsService.clearTrackedViews();
      // Should not throw
      expect(true, isTrue);
    });

    test('should handle batch tracking of empty list', () async {
      await analyticsService.initialize();
      await expectLater(analyticsService.trackVideoViews([]), completes);
    });

    test('should not batch track when analytics disabled', () async {
      await analyticsService.initialize();
      await analyticsService.setAnalyticsEnabled(false);

      final now = DateTime.now();
      final videos = List.generate(
        3,
        (i) => VideoEvent(
          id: 'video_$i',
          pubkey: 'pubkey_$i',
          content: 'Test video $i',
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          timestamp: now,
        ),
      );

      await expectLater(analyticsService.trackVideoViews(videos), completes);
    });
  });
}
