// ABOUTME: Verification test to confirm video playback consolidation is working
// ABOUTME: Tests the unified API and factory methods without requiring real video

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/video_playback_widget.dart';
import 'package:openvine/services/video_playback_controller.dart';
import 'package:openvine/models/video_event.dart';

void main() {
  group('Video Consolidation Verification', () {
    late VideoEvent testVideo;

    setUp(() {
      testVideo = VideoEvent(
        id: 'test_video',
        pubkey: 'test_pubkey',
        videoUrl: 'https://example.com/video.mp4',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        content: 'Test video',
        timestamp: DateTime.now(),
        hashtags: ['test'],
        title: 'Test Video',
        createdAt: 1234567890,
      );
    });

    testWidgets('All factory methods create widgets successfully', (WidgetTester tester) async {
      // Test feed factory
      final feedWidget = VideoPlaybackWidget.feed(
        video: testVideo,
        isActive: true,
      );
      expect(feedWidget.config, equals(VideoPlaybackConfig.feed));
      expect(feedWidget.isActive, isTrue);
      expect(feedWidget.showPlayPauseIcon, isTrue);

      // Test fullscreen factory
      final fullscreenWidget = VideoPlaybackWidget.fullscreen(
        video: testVideo,
      );
      expect(fullscreenWidget.config, equals(VideoPlaybackConfig.fullscreen));
      expect(fullscreenWidget.isActive, isTrue); // Default for fullscreen
      expect(fullscreenWidget.showPlayPauseIcon, isTrue);

      // Test preview factory
      final previewWidget = VideoPlaybackWidget.preview(
        video: testVideo,
      );
      expect(previewWidget.config, equals(VideoPlaybackConfig.preview));
      expect(previewWidget.isActive, isFalse); // Default for preview
      expect(previewWidget.showPlayPauseIcon, isFalse);
    });

    testWidgets('Configuration presets have expected values', (WidgetTester tester) async {
      // Feed: muted, autoplay, loops
      expect(VideoPlaybackConfig.feed.volume, equals(0.0));
      expect(VideoPlaybackConfig.feed.autoPlay, isTrue);
      expect(VideoPlaybackConfig.feed.looping, isTrue);
      expect(VideoPlaybackConfig.feed.pauseOnNavigation, isTrue);

      // Fullscreen: with audio, autoplay, loops
      expect(VideoPlaybackConfig.fullscreen.volume, equals(1.0));
      expect(VideoPlaybackConfig.fullscreen.autoPlay, isTrue);
      expect(VideoPlaybackConfig.fullscreen.looping, isTrue);
      expect(VideoPlaybackConfig.fullscreen.pauseOnNavigation, isTrue);

      // Preview: no autoplay, no looping, no lifecycle
      expect(VideoPlaybackConfig.preview.volume, equals(0.0));
      expect(VideoPlaybackConfig.preview.autoPlay, isFalse);
      expect(VideoPlaybackConfig.preview.looping, isFalse);
      expect(VideoPlaybackConfig.preview.handleAppLifecycle, isFalse);
    });

    testWidgets('VideoPlaybackWidget renders loading state', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoPlaybackWidget.feed(
              video: testVideo,
              isActive: true,
            ),
          ),
        ),
      );

      // Should show loading state initially
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading...'), findsOneWidget);
    });

    testWidgets('Custom callbacks can be provided', (WidgetTester tester) async {
      bool tapCalled = false;
      bool doubleTapCalled = false;
      String? errorMessage;

      final widget = VideoPlaybackWidget.fullscreen(
        video: testVideo,
        onTap: () => tapCalled = true,
        onDoubleTap: () => doubleTapCalled = true,
        onError: (error) => errorMessage = error,
      );

      expect(widget.onTap, isNotNull);
      expect(widget.onDoubleTap, isNotNull);
      expect(widget.onError, isNotNull);

      // Verify callbacks are wired up
      widget.onTap!();
      widget.onDoubleTap!();
      widget.onError!('Test error');

      expect(tapCalled, isTrue);
      expect(doubleTapCalled, isTrue);
      expect(errorMessage, equals('Test error'));
    });

    testWidgets('Controller state transitions are defined', (WidgetTester tester) async {
      // Verify all expected states exist
      expect(VideoPlaybackState.values, contains(VideoPlaybackState.notInitialized));
      expect(VideoPlaybackState.values, contains(VideoPlaybackState.initializing));
      expect(VideoPlaybackState.values, contains(VideoPlaybackState.ready));
      expect(VideoPlaybackState.values, contains(VideoPlaybackState.playing));
      expect(VideoPlaybackState.values, contains(VideoPlaybackState.paused));
      expect(VideoPlaybackState.values, contains(VideoPlaybackState.buffering));
      expect(VideoPlaybackState.values, contains(VideoPlaybackState.error));
      expect(VideoPlaybackState.values, contains(VideoPlaybackState.disposed));
    });

    testWidgets('Event types are properly defined', (WidgetTester tester) async {
      // Create sample events to verify they're constructable
      final stateChange = VideoStateChanged(VideoPlaybackState.playing);
      expect(stateChange.state, equals(VideoPlaybackState.playing));

      final error = VideoError('Test error', Exception('Test'));
      expect(error.message, equals('Test error'));
      expect(error.error, isA<Exception>());

      final positionChange = VideoPositionChanged(
        const Duration(seconds: 5),
        const Duration(seconds: 10),
      );
      expect(positionChange.position, equals(const Duration(seconds: 5)));
      expect(positionChange.duration, equals(const Duration(seconds: 10)));
    });

    testWidgets('Consolidation provides unified API', (WidgetTester tester) async {
      // This test verifies that the consolidation provides a clean, unified API
      // for all video playback scenarios in the app

      // 1. Feed videos - muted, autoplay
      final feedWidget = VideoPlaybackWidget.feed(
        video: testVideo,
        isActive: true,
        overlayWidgets: [
          const Text('Overlay content'),
        ],
      );

      // 2. Fullscreen videos - with audio
      final fullscreenWidget = VideoPlaybackWidget.fullscreen(
        video: testVideo,
        onDoubleTap: () {
          // Like functionality
        },
      );

      // 3. Preview videos - no autoplay
      final previewWidget = VideoPlaybackWidget.preview(
        video: testVideo,
        placeholder: const Center(child: Text('Loading preview...')),
      );

      // All use the same underlying controller and widget
      expect(feedWidget, isA<VideoPlaybackWidget>());
      expect(fullscreenWidget, isA<VideoPlaybackWidget>());
      expect(previewWidget, isA<VideoPlaybackWidget>());

      // But with different configurations
      expect(feedWidget.config, isNot(equals(fullscreenWidget.config)));
      expect(fullscreenWidget.config, isNot(equals(previewWidget.config)));
    });
  });
}