// ABOUTME: Integration tests for video playback with real video playing
// ABOUTME: Tests actual video initialization, playback, and state transitions

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/video_playback_controller.dart';
import 'package:openvine/widgets/video_playback_widget.dart';
import 'package:video_player/video_player.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Real Video Playback Tests', () {
    // Use a real test video URL (this is a common test video)
    const testVideoUrl = 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4';
    
    late VideoEvent testVideo;

    setUp(() {
      testVideo = VideoEvent(
        id: 'test_video_real',
        pubkey: 'test_pubkey',
        videoUrl: testVideoUrl,
        thumbnailUrl: 'https://example.com/thumb.jpg',
        content: 'Real test video',
        timestamp: DateTime.now(),
        hashtags: ['test'],
        title: 'Big Buck Bunny Test',
        createdAt: 1234567890,
      );
    });

    testWidgets('VideoPlaybackController initializes and plays real video', (WidgetTester tester) async {
      final controller = VideoPlaybackController(
        video: testVideo,
        config: VideoPlaybackConfig.feed,
      );

      // Track state changes
      final states = <VideoPlaybackState>[];
      controller.addListener(() {
        states.add(controller.state);
      });

      // Initialize controller
      await controller.initialize();
      
      // Wait for initialization to complete
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Verify state progression
      expect(states.contains(VideoPlaybackState.initializing), isTrue);
      expect(controller.state, equals(VideoPlaybackState.ready));
      expect(controller.isInitialized, isTrue);
      
      // Set active and play
      controller.setActive(true);
      await tester.pumpAndSettle(const Duration(milliseconds: 500));
      
      // With feed config, it should autoplay
      expect(controller.isPlaying, isTrue);
      expect(controller.state, equals(VideoPlaybackState.playing));

      // Verify video properties
      expect(controller.duration, greaterThan(Duration.zero));
      expect(controller.aspectRatio, greaterThan(0));

      // Test pause
      await controller.pause();
      await tester.pumpAndSettle();
      expect(controller.isPlaying, isFalse);
      expect(controller.state, equals(VideoPlaybackState.paused));

      // Test play
      await controller.play();
      await tester.pumpAndSettle();
      expect(controller.isPlaying, isTrue);

      // Cleanup
      controller.dispose();
      expect(controller.state, equals(VideoPlaybackState.disposed));
    });

    testWidgets('VideoPlaybackWidget displays real video', (WidgetTester tester) async {
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

      // Initially should show loading
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading...'), findsOneWidget);

      // Wait for video to load
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Should now show video player
      expect(find.byType(VideoPlayer), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('Navigation pause/resume works with real video', (WidgetTester tester) async {
      final controller = VideoPlaybackController(
        video: testVideo,
        config: VideoPlaybackConfig.feed,
      );

      await controller.initialize();
      controller.setActive(true);
      
      // Wait for video to start playing
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(controller.isPlaying, isTrue);

      // Simulate navigation away
      await controller.onNavigationAway();
      await tester.pumpAndSettle();
      expect(controller.isPlaying, isFalse);

      // Simulate navigation return
      await controller.onNavigationReturn();
      await tester.pumpAndSettle();
      expect(controller.isPlaying, isTrue); // Should resume

      controller.dispose();
    });

    testWidgets('Event stream emits real events during playback', (WidgetTester tester) async {
      final controller = VideoPlaybackController(
        video: testVideo,
        config: VideoPlaybackConfig.feed,
      );

      final events = <VideoPlaybackEvent>[];
      final subscription = controller.events.listen(events.add);

      await controller.initialize();
      controller.setActive(true);
      
      // Wait for events
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Should have received multiple events
      expect(events, isNotEmpty);
      expect(events.any((e) => e is VideoStateChanged), isTrue);
      
      // Check for state changes indicating initialization
      final stateChanges = events.whereType<VideoStateChanged>().toList();
      expect(stateChanges.any((e) => e.state == VideoPlaybackState.ready), isTrue);

      subscription.cancel();
      controller.dispose();
    });

    testWidgets('Tap to play/pause works with real video', (WidgetTester tester) async {
      bool tapCalled = false;
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: VideoPlaybackWidget.feed(
              video: testVideo,
              isActive: true,
              onTap: () => tapCalled = true,
            ),
          ),
        ),
      );

      // Wait for video to load
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // Tap the video
      await tester.tap(find.byType(VideoPlaybackWidget));
      await tester.pumpAndSettle();

      expect(tapCalled, isTrue);
    });

    testWidgets('Error handling works with invalid video URL', (WidgetTester tester) async {
      final errorVideo = VideoEvent(
        id: 'test_error',
        pubkey: 'test_pubkey',
        videoUrl: 'https://invalid-url-that-does-not-exist.com/video.mp4',
        thumbnailUrl: 'https://example.com/thumb.jpg',
        content: 'Error test video',
        timestamp: DateTime.now(),
        hashtags: ['test'],
        title: 'Error Test',
        createdAt: 1234567890,
      );

      final controller = VideoPlaybackController(
        video: errorVideo,
        config: VideoPlaybackConfig.feed,
      );

      final events = <VideoPlaybackEvent>[];
      controller.events.listen(events.add);

      await controller.initialize();
      
      // Wait for error
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Should be in error state
      expect(controller.state, equals(VideoPlaybackState.error));
      expect(controller.hasError, isTrue);
      expect(controller.errorMessage, isNotNull);
      
      // Should have emitted error event
      expect(events.any((e) => e is VideoError), isTrue);

      controller.dispose();
    });

    testWidgets('Volume settings work correctly', (WidgetTester tester) async {
      // Test feed config (muted)
      final feedController = VideoPlaybackController(
        video: testVideo,
        config: VideoPlaybackConfig.feed,
      );

      await feedController.initialize();
      await tester.pumpAndSettle(const Duration(seconds: 2));
      
      // Should be muted for feed videos
      expect(feedController.controller?.value.volume, equals(0.0));

      feedController.dispose();

      // Test fullscreen config (with audio)
      final fullscreenController = VideoPlaybackController(
        video: testVideo,
        config: VideoPlaybackConfig.fullscreen,
      );

      await fullscreenController.initialize();
      await tester.pumpAndSettle(const Duration(seconds: 2));
      
      // Should have audio for fullscreen videos
      expect(fullscreenController.controller?.value.volume, equals(1.0));

      fullscreenController.dispose();
    });

    testWidgets('Multiple videos can play simultaneously', (WidgetTester tester) async {
      final controller1 = VideoPlaybackController(
        video: testVideo,
        config: VideoPlaybackConfig.feed,
      );

      final controller2 = VideoPlaybackController(
        video: testVideo,
        config: VideoPlaybackConfig.feed,
      );

      await controller1.initialize();
      await controller2.initialize();
      
      controller1.setActive(true);
      controller2.setActive(true);
      
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Both should be playing
      expect(controller1.isPlaying, isTrue);
      expect(controller2.isPlaying, isTrue);

      // Pause one shouldn't affect the other
      await controller1.pause();
      await tester.pumpAndSettle();
      
      expect(controller1.isPlaying, isFalse);
      expect(controller2.isPlaying, isTrue);

      controller1.dispose();
      controller2.dispose();
    });
  });
}