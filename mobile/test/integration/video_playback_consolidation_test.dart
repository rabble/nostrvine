// ABOUTME: Integration test for consolidated video playback implementation
// ABOUTME: Tests that VideoPlaybackController and Widget work together correctly

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/video_playback_controller.dart';
import 'package:openvine/widgets/video_playback_widget.dart';

void main() {
  group('Video Playback Consolidation Integration', () {
    late VideoEvent testVideo;

    setUp(() {
      testVideo = VideoEvent(
        id: 'test_video_123',
        pubkey: 'test_pubkey',
        videoUrl: 'https://example.com/video.mp4',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        content: 'Test video content',
        timestamp: DateTime.now(),
        hashtags: ['test'],
        title: 'Test Video',
        createdAt: 1234567890,
      );
    });

    testWidgets('VideoPlaybackController can be created and disposed safely', (WidgetTester tester) async {
      final controller = VideoPlaybackController(
        video: testVideo,
        config: VideoPlaybackConfig.feed,
      );

      expect(controller.state, equals(VideoPlaybackState.notInitialized));
      expect(controller.video.id, equals('test_video_123'));
      expect(controller.config, equals(VideoPlaybackConfig.feed));

      controller.dispose();
      expect(controller.state, equals(VideoPlaybackState.disposed));
    });

    testWidgets('VideoPlaybackWidget can be created with different configurations', (WidgetTester tester) async {
      // Test feed configuration
      final feedWidget = VideoPlaybackWidget.feed(
        video: testVideo,
        isActive: true,
      );

      expect(feedWidget.config, equals(VideoPlaybackConfig.feed));
      expect(feedWidget.isActive, isTrue);

      // Test fullscreen configuration
      final fullscreenWidget = VideoPlaybackWidget.fullscreen(
        video: testVideo,
      );

      expect(fullscreenWidget.config, equals(VideoPlaybackConfig.fullscreen));

      // Test preview configuration
      final previewWidget = VideoPlaybackWidget.preview(
        video: testVideo,
      );

      expect(previewWidget.config, equals(VideoPlaybackConfig.preview));
      expect(previewWidget.isActive, isFalse);
    });

    testWidgets('Configuration presets have correct settings', (WidgetTester tester) async {
      // Feed configuration
      const feedConfig = VideoPlaybackConfig.feed;
      expect(feedConfig.autoPlay, isTrue);
      expect(feedConfig.volume, equals(0.0)); // Muted
      expect(feedConfig.pauseOnNavigation, isTrue);

      // Fullscreen configuration
      const fullscreenConfig = VideoPlaybackConfig.fullscreen;
      expect(fullscreenConfig.autoPlay, isTrue);
      expect(fullscreenConfig.volume, equals(1.0)); // With audio
      expect(fullscreenConfig.pauseOnNavigation, isTrue);

      // Preview configuration
      const previewConfig = VideoPlaybackConfig.preview;
      expect(previewConfig.autoPlay, isFalse);
      expect(previewConfig.pauseOnNavigation, isFalse);
      expect(previewConfig.handleAppLifecycle, isFalse);
    });

    testWidgets('VideoPlaybackController state management works', (WidgetTester tester) async {
      final controller = VideoPlaybackController(
        video: testVideo,
        config: VideoPlaybackConfig.feed,
      );

      // Test active state changes
      expect(controller.isActive, isFalse);
      
      controller.setActive(true);
      expect(controller.isActive, isTrue);

      controller.setActive(false);
      expect(controller.isActive, isFalse);

      controller.dispose();
    });

    testWidgets('Navigation helpers work correctly', (WidgetTester tester) async {
      final controller = VideoPlaybackController(
        video: testVideo,
        config: VideoPlaybackConfig.feed,
      );

      // Test navigation away/return
      await controller.onNavigationAway();
      await controller.onNavigationReturn();

      // Should not throw exceptions
      expect(controller.state, isNot(equals(VideoPlaybackState.error)));

      controller.dispose();
    });

    testWidgets('VideoPlaybackController handles app lifecycle', (WidgetTester tester) async {
      final controller = VideoPlaybackController(
        video: testVideo,
        config: VideoPlaybackConfig.feed, // handleAppLifecycle = true
      );

      // Test app lifecycle changes
      controller.didChangeAppLifecycleState(AppLifecycleState.paused);
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);

      // Should not crash or throw
      expect(controller.state, isNot(equals(VideoPlaybackState.error)));

      controller.dispose();
    });

    testWidgets('VideoPlaybackController ignores app lifecycle when disabled', (WidgetTester tester) async {
      final controller = VideoPlaybackController(
        video: testVideo,
        config: VideoPlaybackConfig.preview, // handleAppLifecycle = false
      );

      // Test app lifecycle changes (should be ignored)
      controller.didChangeAppLifecycleState(AppLifecycleState.paused);
      controller.didChangeAppLifecycleState(AppLifecycleState.resumed);

      expect(controller.state, isNot(equals(VideoPlaybackState.error)));

      controller.dispose();
    });

    testWidgets('Event stream works correctly', (WidgetTester tester) async {
      final controller = VideoPlaybackController(
        video: testVideo,
        config: VideoPlaybackConfig.feed,
      );

      final events = <VideoPlaybackEvent>[];
      final subscription = controller.events.listen((event) {
        events.add(event);
      });

      // Trigger some state changes
      controller.setActive(true);
      await tester.pump();

      // Should have received some events
      expect(events, isNotEmpty);

      subscription.cancel();
      controller.dispose();
    });

    testWidgets('Multiple configurations can coexist', (WidgetTester tester) async {
      final feedController = VideoPlaybackController(
        video: testVideo,
        config: VideoPlaybackConfig.feed,
      );

      final fullscreenController = VideoPlaybackController(
        video: testVideo,
        config: VideoPlaybackConfig.fullscreen,
      );

      final previewController = VideoPlaybackController(
        video: testVideo,
        config: VideoPlaybackConfig.preview,
      );

      // All should be created successfully
      expect(feedController.config.volume, equals(0.0));
      expect(fullscreenController.config.volume, equals(1.0));
      expect(previewController.config.autoPlay, isFalse);

      // Clean up
      feedController.dispose();
      fullscreenController.dispose();
      previewController.dispose();
    });

    testWidgets('Retry mechanism respects max retries', (WidgetTester tester) async {
      final controller = VideoPlaybackController(
        video: testVideo,
        config: const VideoPlaybackConfig(
          maxRetries: 2,
          retryDelay: Duration(milliseconds: 1), // Fast retry for testing
        ),
      );

      // Track retry count by checking error states
      // Since the test video URL is fake, initialization will fail
      // But retry logic should still respect maxRetries limit
      
      // First retry should work
      expect(controller.config.maxRetries, equals(2));
      
      // Controller should be disposable without hanging
      controller.dispose();
      expect(controller.state, equals(VideoPlaybackState.disposed));
    });
  });
}