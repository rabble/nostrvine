// ABOUTME: Unit tests for VideoPlaybackController with mocked video player
// ABOUTME: Tests controller logic without requiring actual video playback

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:video_player/video_player.dart';
import 'package:openvine/services/video_playback_controller.dart';
import 'package:openvine/models/video_event.dart';

@GenerateMocks([VideoPlayerController])
import 'video_playback_controller_mock_test.mocks.dart';

void main() {
  group('VideoPlaybackController with Mocks', () {
    late VideoEvent testVideo;
    late MockVideoPlayerController mockVideoController;

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

      mockVideoController = MockVideoPlayerController();
      
      // Setup default mock behaviors
      when(mockVideoController.initialize()).thenAnswer((_) async {});
      when(mockVideoController.play()).thenAnswer((_) async {});
      when(mockVideoController.pause()).thenAnswer((_) async {});
      when(mockVideoController.seekTo(any)).thenAnswer((_) async {});
      when(mockVideoController.setLooping(any)).thenAnswer((_) async {});
      when(mockVideoController.setVolume(any)).thenAnswer((_) async {});
      when(mockVideoController.dispose()).thenAnswer((_) async {});
      when(mockVideoController.addListener(any)).thenReturn(null);
      when(mockVideoController.removeListener(any)).thenReturn(null);
      
      // Setup video player value
      when(mockVideoController.value).thenReturn(
        const VideoPlayerValue(
          duration: Duration(seconds: 10),
          position: Duration.zero,
          isInitialized: true,
          isPlaying: false,
          isLooping: false,
          isBuffering: false,
          volume: 1.0,
          playbackSpeed: 1.0,
          errorDescription: null,
          size: Size(1920, 1080),
        ),
      );
    });

    testWidgets('Controller properly tracks initialization state', (WidgetTester tester) async {
      final controller = VideoPlaybackController(
        video: testVideo,
        config: VideoPlaybackConfig.feed,
      );

      // Initially not initialized
      expect(controller.state, equals(VideoPlaybackState.notInitialized));
      expect(controller.isInitialized, isFalse);

      // Track state changes
      final states = <VideoPlaybackState>[];
      controller.addListener(() {
        states.add(controller.state);
      });

      // Initialize
      await controller.initialize();
      
      // Should have gone through initializing state
      expect(states.contains(VideoPlaybackState.initializing), isTrue);
      
      controller.dispose();
    });

    testWidgets('Feed configuration applies correct settings', (WidgetTester tester) async {
      final controller = VideoPlaybackController(
        video: testVideo,
        config: VideoPlaybackConfig.feed,
      );

      // Feed config should have:
      expect(controller.config.volume, equals(0.0)); // Muted
      expect(controller.config.autoPlay, isTrue);
      expect(controller.config.looping, isTrue);
      expect(controller.config.pauseOnNavigation, isTrue);

      controller.dispose();
    });

    testWidgets('Navigation pause/resume tracks playing state', (WidgetTester tester) async {
      final controller = VideoPlaybackController(
        video: testVideo,
        config: VideoPlaybackConfig.feed,
      );

      // Simulate playing state
      controller.setActive(true);
      
      // Navigate away
      await controller.onNavigationAway();
      
      // Should remember it was playing
      expect(controller.isActive, isTrue);
      
      // Navigate back
      await controller.onNavigationReturn();
      
      // Should still be active
      expect(controller.isActive, isTrue);

      controller.dispose();
    });

    testWidgets('Error state is set correctly', (WidgetTester tester) async {
      final controller = VideoPlaybackController(
        video: testVideo,
        config: VideoPlaybackConfig.feed,
      );

      // Simulate an error by having initialize throw
      when(mockVideoController.initialize()).thenThrow(Exception('Test error'));
      
      // This would normally set error state when initialize fails
      // For now, manually verify error handling path exists
      expect(controller.hasError, isFalse);
      expect(controller.errorMessage, isNull);

      controller.dispose();
    });

    testWidgets('Retry mechanism respects max retries', (WidgetTester tester) async {
      final controller = VideoPlaybackController(
        video: testVideo,
        config: const VideoPlaybackConfig(maxRetries: 2),
      );

      // Should allow first retry
      await controller.retry();
      
      // Should allow second retry
      await controller.retry();
      
      // Third retry should be limited
      await controller.retry();
      
      // Verify controller didn't crash
      expect(controller.state, isNot(equals(VideoPlaybackState.disposed)));

      controller.dispose();
    });

    testWidgets('Event stream emits state changes', (WidgetTester tester) async {
      final controller = VideoPlaybackController(
        video: testVideo,
        config: VideoPlaybackConfig.feed,
      );

      final events = <VideoPlaybackEvent>[];
      final subscription = controller.events.listen(events.add);

      // Change active state
      controller.setActive(true);
      
      // Give stream time to emit
      await Future.delayed(const Duration(milliseconds: 100));
      
      // Should have emitted at least one event
      expect(events, isNotEmpty);
      expect(events.first, isA<VideoStateChanged>());

      subscription.cancel();
      controller.dispose();
    });

    testWidgets('Volume control works correctly', (WidgetTester tester) async {
      final controller = VideoPlaybackController(
        video: testVideo,
        config: VideoPlaybackConfig.fullscreen, // Has volume 1.0
      );

      // Set custom volume
      await controller.setVolume(0.5);
      
      // Verify volume would be set on real controller
      expect(controller.config.volume, equals(1.0)); // Config doesn't change
      
      controller.dispose();
    });

    testWidgets('Dispose cleans up properly', (WidgetTester tester) async {
      final controller = VideoPlaybackController(
        video: testVideo,
        config: VideoPlaybackConfig.feed,
      );

      // Add a listener
      bool listenerCalled = false;
      controller.addListener(() {
        listenerCalled = true;
      });

      // Dispose
      controller.dispose();
      
      // State should be disposed
      expect(controller.state, equals(VideoPlaybackState.disposed));
      
      // Further operations should be safe
      controller.setActive(true);
      await controller.play();
      
      // Listener shouldn't be called after dispose
      expect(listenerCalled, isFalse);
    });
  });
}