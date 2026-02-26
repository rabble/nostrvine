// ABOUTME: Tests for analytics service batch tracking
// ABOUTME: Validates batch tracking respects user preferences

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/services/analytics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('AnalyticsService Batch Tracking', () {
    late AnalyticsService analyticsService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({'analytics_enabled': true});
      analyticsService = AnalyticsService(disableNostrPublishing: true);
      await analyticsService.initialize();
    });

    tearDown(() {
      analyticsService.dispose();
    });

    test('should handle empty video list', () async {
      await expectLater(analyticsService.trackVideoViews([]), completes);
    });

    test('should batch track multiple videos', () async {
      final now = DateTime.now();
      final videos = List.generate(
        5,
        (i) => VideoEvent(
          id: 'video_$i',
          pubkey: 'pubkey_$i',
          content: '{"url": "https://example.com/video_$i.mp4"}',
          createdAt:
              now.subtract(Duration(hours: i)).millisecondsSinceEpoch ~/ 1000,
          timestamp: now.subtract(Duration(hours: i)),
          videoUrl: 'https://example.com/video_$i.mp4',
        ),
      );

      // Should complete without error
      await expectLater(analyticsService.trackVideoViews(videos), completes);
    });

    test('should respect analytics disabled setting', () async {
      await analyticsService.setAnalyticsEnabled(false);

      final now = DateTime.now();
      final videos = List.generate(
        3,
        (i) => VideoEvent(
          id: 'video_$i',
          pubkey: 'pubkey_$i',
          content: '{"url": "https://example.com/video_$i.mp4"}',
          createdAt: now.millisecondsSinceEpoch ~/ 1000,
          timestamp: now,
          videoUrl: 'https://example.com/video_$i.mp4',
        ),
      );

      // Should complete without error (silently skips when disabled)
      await expectLater(analyticsService.trackVideoViews(videos), completes);
    });
  });
}
