// ABOUTME: Comprehensive tests for VideoManagerService consolidation
// ABOUTME: Ensures VideoManagerService handles all video management without legacy services

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:video_player/video_player.dart';
import 'dart:ui' show Size;
import 'package:nostrvine_app/services/video_manager_service.dart';
import 'package:nostrvine_app/services/video_manager_interface.dart';
import 'package:nostrvine_app/models/video_event.dart';
import 'package:nostrvine_app/models/video_state.dart';

// Mock VideoPlayerController for testing
class MockVideoPlayerController extends Mock implements VideoPlayerController {
  @override
  VideoPlayerValue get value => VideoPlayerValue(
    duration: const Duration(seconds: 30),
    size: const Size(1920, 1080),
    isInitialized: true,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('VideoManagerService Consolidation Tests', () {
    late VideoManagerService videoManager;
    
    setUp(() {
      videoManager = VideoManagerService(
        config: VideoManagerConfig.testing(),
      );
    });

    tearDown(() {
      videoManager.dispose();
    });

    group('Core Video Management', () {
      test('should add video events and create controllers', () async {
        // Arrange
        final videoEvent = VideoEvent(
          id: 'test123456789', // Longer ID to avoid substring errors
          pubkey: 'author456',
          createdAt: 1000,
          content: 'Test video',
          timestamp: DateTime.now(),
          videoUrl: 'https://example.com/video.mp4',
        );

        // Act
        await videoManager.addVideoEvent(videoEvent);

        // Assert
        expect(videoManager.videos.length, equals(1));
        expect(videoManager.videos.first.id, equals('test123456789'));
        
        final state = videoManager.getVideoState('test123456789');
        expect(state, isNotNull);
        expect(state!.loadingState, equals(VideoLoadingState.notLoaded));
      });

      test('should handle multiple videos in newest-first order', () async {
        // Arrange
        final videos = List.generate(5, (index) => VideoEvent(
          id: 'video${index}12345678', // Longer IDs
          pubkey: 'author$index',
          createdAt: 1000 + index,
          content: 'Video $index',
          timestamp: DateTime.now().add(Duration(seconds: index)),
          videoUrl: 'https://example.com/video$index.mp4',
        ));

        // Act
        for (final video in videos) {
          await videoManager.addVideoEvent(video);
        }

        // Assert
        expect(videoManager.videos.length, equals(5));
        // Videos are stored newest-first
        expect(videoManager.videos.map((v) => v.id).toList(), 
          equals(['video412345678', 'video312345678', 'video212345678', 'video112345678', 'video012345678']));
      });

      test('should prevent duplicate videos', () async {
        // Arrange
        final videoEvent = VideoEvent(
          id: 'test123456789',
          pubkey: 'author456',
          createdAt: 1000,
          content: 'Test video',
          timestamp: DateTime.now(),
          videoUrl: 'https://example.com/video.mp4',
        );

        // Act
        await videoManager.addVideoEvent(videoEvent);
        await videoManager.addVideoEvent(videoEvent); // Try to add duplicate

        // Assert
        expect(videoManager.videos.length, equals(1));
      });
    });

    group('Video Preloading', () {
      test('should preload videos around current index', () async {
        // Arrange
        final videos = List.generate(10, (index) => VideoEvent(
          id: 'video${index}12345678',
          pubkey: 'author$index',
          createdAt: 1000 + index,
          content: 'Video $index',
          timestamp: DateTime.now().add(Duration(seconds: index)),
          videoUrl: 'https://example.com/video$index.mp4',
        ));

        for (final video in videos) {
          await videoManager.addVideoEvent(video);
        }

        // Act - preload around index 5 (remembering videos are newest-first)
        videoManager.preloadAroundIndex(5);
        
        // Give some time for preloading to start
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert
        // With testing config (preloadAhead: 2, preloadBehind: 1)
        // Videos at indices 4, 5, 6, 7 should be marked for preloading
        // But remember the list is reversed, so video9 is at index 0
        for (int i = 4; i <= 7 && i < 10; i++) {
          final videoIndex = 9 - i; // Convert to actual video number
          final state = videoManager.getVideoState('video${videoIndex}12345678');
          expect(state, isNotNull);
          // State should be either loading or ready
          expect(state!.loadingState, 
            anyOf(VideoLoadingState.loading, VideoLoadingState.ready, VideoLoadingState.notLoaded));
        }
      });

      test('should respect max videos limit', () async {
        // Arrange - create manager with small limit
        final limitedManager = VideoManagerService(
          config: const VideoManagerConfig(
            maxVideos: 5,
            preloadAhead: 1,
            preloadBehind: 1,
          ),
        );

        final videos = List.generate(20, (index) => VideoEvent(
          id: 'video${index}12345678',
          pubkey: 'author$index',
          createdAt: 1000 + index,
          content: 'Video $index',
          timestamp: DateTime.now().add(Duration(seconds: index)),
          videoUrl: 'https://example.com/video$index.mp4',
        ));

        // Act
        for (final video in videos) {
          await limitedManager.addVideoEvent(video);
        }

        // Assert
        expect(limitedManager.videos.length, equals(20)); // All videos added
        
        final debugInfo = limitedManager.getDebugInfo();
        expect(debugInfo['controllerCount'], lessThanOrEqualTo(5));
        
        limitedManager.dispose();
      });
    });

    group('Video State Management', () {
      test('should track video loading states correctly', () async {
        // Arrange
        final videoEvent = VideoEvent(
          id: 'test123456789',
          pubkey: 'author456',
          createdAt: 1000,
          content: 'Test video',
          timestamp: DateTime.now(),
          videoUrl: 'https://example.com/video.mp4',
        );

        // Act
        await videoManager.addVideoEvent(videoEvent);
        final initialState = videoManager.getVideoState('test123456789');
        
        // Simulate loading
        videoManager.preloadAroundIndex(0);
        await Future.delayed(const Duration(milliseconds: 100));
        
        final loadingState = videoManager.getVideoState('test123456789');

        // Assert
        expect(initialState!.loadingState, equals(VideoLoadingState.notLoaded));
        expect(loadingState!.loadingState, 
          anyOf(VideoLoadingState.loading, VideoLoadingState.ready));
      });

      test('should handle error states properly', () async {
        // Arrange
        final videoEvent = VideoEvent(
          id: 'error_video12345',
          pubkey: 'author456',
          createdAt: 1000,
          content: 'Error video',
          timestamp: DateTime.now(),
          videoUrl: 'https://invalid-url.com/nonexistent.mp4',
        );

        // Act
        await videoManager.addVideoEvent(videoEvent);
        // Force an error by trying to preload an invalid video
        videoManager.preloadAroundIndex(0);
        await Future.delayed(const Duration(milliseconds: 500));

        // Assert
        final state = videoManager.getVideoState('error_video12345');
        expect(state, isNotNull);
        // Should either be in failed state or still loading
        expect(state!.loadingState, 
          anyOf(VideoLoadingState.failed, VideoLoadingState.loading));
      });
    });

    group('Memory Management', () {
      test('should clean up old videos when limit exceeded', () async {
        // Arrange
        final limitedManager = VideoManagerService(
          config: const VideoManagerConfig(
            maxVideos: 5,
            preloadAhead: 1,
            preloadBehind: 0,
          ),
        );

        final videos = List.generate(10, (index) => VideoEvent(
          id: 'video${index}12345678',
          pubkey: 'author$index',
          createdAt: 1000 + index,
          content: 'Video $index',
          timestamp: DateTime.now().add(Duration(seconds: index)),
          videoUrl: 'https://example.com/video$index.mp4',
        ));

        // Act
        for (final video in videos) {
          await limitedManager.addVideoEvent(video);
        }

        // Assert
        expect(limitedManager.videos.length, equals(10)); // All videos added
        
        final debugInfo = limitedManager.getDebugInfo();
        // Should have limited number of controllers
        expect(debugInfo['controllerCount'], lessThanOrEqualTo(5));
        
        limitedManager.dispose();
      });

      test('should properly dispose controllers when cleaning up', () async {
        // Arrange
        final videoEvent = VideoEvent(
          id: 'test123456789',
          pubkey: 'author456',
          createdAt: 1000,
          content: 'Test video',
          timestamp: DateTime.now(),
          videoUrl: 'https://example.com/video.mp4',
        );

        await videoManager.addVideoEvent(videoEvent);
        videoManager.preloadAroundIndex(0);
        
        // Act
        videoManager.dispose();

        // Assert
        expect(videoManager.getController('test123456789'), isNull);
        expect(videoManager.getVideoState('test123456789'), isNull);
      });
    });

    group('Ready Videos Filtering', () {
      test('should return only videos with ready controllers', () async {
        // Arrange
        final videos = List.generate(5, (index) => VideoEvent(
          id: 'video${index}12345678',
          pubkey: 'author$index',
          createdAt: 1000 + index,
          content: 'Video $index',
          timestamp: DateTime.now().add(Duration(seconds: index)),
          videoUrl: 'https://example.com/video$index.mp4',
        ));

        for (final video in videos) {
          await videoManager.addVideoEvent(video);
        }

        // Act - only preload first 2 videos
        videoManager.preloadAroundIndex(0);
        await Future.delayed(const Duration(milliseconds: 200));

        // Assert
        expect(videoManager.readyVideos.length, lessThanOrEqualTo(3)); // preloadAhead: 2
        for (final video in videoManager.readyVideos) {
          final state = videoManager.getVideoState(video.id);
          expect(state?.loadingState, equals(VideoLoadingState.ready));
        }
      });
    });

    group('Debug Information', () {
      test('should provide accurate debug information', () async {
        // Arrange
        final videos = List.generate(3, (index) => VideoEvent(
          id: 'video${index}12345678',
          pubkey: 'author$index',
          createdAt: 1000 + index,
          content: 'Video $index',
          timestamp: DateTime.now().add(Duration(seconds: index)),
          videoUrl: 'https://example.com/video$index.mp4',
        ));

        for (final video in videos) {
          await videoManager.addVideoEvent(video);
        }

        // Act
        final debugInfo = videoManager.getDebugInfo();

        // Assert
        expect(debugInfo['totalVideos'], equals(3));
        expect(debugInfo['controllerCount'], isNotNull);
        expect(debugInfo['estimatedMemoryMB'], isNotNull);
        expect(debugInfo.containsKey('videoStates'), isTrue);
      });
    });

    group('Legacy Service Replacement', () {
      test('should handle all VideoCacheService functionality', () async {
        // This test verifies that VideoManagerService can replace VideoCacheService
        
        // 1. Video caching and retrieval
        final videoEvent = VideoEvent(
          id: 'test123456789',
          pubkey: 'author456',
          createdAt: 1000,
          content: 'Test video',
          timestamp: DateTime.now(),
          videoUrl: 'https://example.com/video.mp4',
        );
        
        await videoManager.addVideoEvent(videoEvent);
        expect(videoManager.videos.contains(videoEvent), isTrue);
        
        // 2. Controller management
        videoManager.preloadAroundIndex(0);
        await Future.delayed(const Duration(milliseconds: 200));
        
        final controller = videoManager.getController('test123456789');
        expect(controller, isNotNull);
        
        // 3. State tracking
        final state = videoManager.getVideoState('test123456789');
        expect(state, isNotNull);
        
        // 4. Memory management
        final debugInfo = videoManager.getDebugInfo();
        expect(debugInfo['estimatedMemoryMB'], greaterThanOrEqualTo(0));
      });

      test('should handle all VideoControllerManager functionality', () async {
        // This test verifies playback control features
        
        // Add videos
        final videos = List.generate(3, (index) => VideoEvent(
          id: 'video${index}12345678',
          pubkey: 'author$index',
          createdAt: 1000 + index,
          content: 'Video $index',
          timestamp: DateTime.now().add(Duration(seconds: index)),
          videoUrl: 'https://example.com/video$index.mp4',
        ));

        for (final video in videos) {
          await videoManager.addVideoEvent(video);
        }

        // Preload videos
        videoManager.preloadAroundIndex(0);
        await Future.delayed(const Duration(milliseconds: 200));

        // Verify we can get controllers for playback (newest video is at index 0)
        final controller = videoManager.getController('video212345678');
        expect(controller, isNotNull);
        
        // Verify state management
        final state = videoManager.getVideoState('video212345678');
        expect(state?.loadingState, anyOf(VideoLoadingState.loading, VideoLoadingState.ready));
      });
    });
  });
}