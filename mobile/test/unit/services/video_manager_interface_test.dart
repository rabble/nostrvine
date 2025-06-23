// ABOUTME: Unit tests for IVideoManager interface contract and expected behaviors
// ABOUTME: Tests interface contracts, error conditions, and edge cases

import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/models/video_state.dart';
import 'package:openvine/services/video_manager_interface.dart';
import '../../helpers/test_helpers.dart';
import '../../mocks/mock_video_manager.dart';


void main() {
  group('IVideoManager Interface Contract Tests', () {
    late MockVideoManager videoManager;
    late VideoEvent testVideo1;
    late VideoEvent testVideo2;
    late VideoEvent failingVideo;

    setUp(() {
      videoManager = MockVideoManager();
      testVideo1 = TestHelpers.createVideoEvent(
        id: 'test-video-1',
        title: 'Test Video 1',
      );
      testVideo2 = TestHelpers.createVideoEvent(
        id: 'test-video-2',
        title: 'Test Video 2',
      );
      failingVideo = TestHelpers.createVideoEvent(
        id: 'fail-video',
        title: 'Failing Video',
      );
    });

    tearDown(() {
      videoManager.dispose();
    });

    group('Video List Management Contract', () {
      test('should maintain videos in newest-first order', () async {
        // ARRANGE & ACT
        await videoManager.addVideoEvent(testVideo1);
        await videoManager.addVideoEvent(testVideo2);

        // ASSERT
        expect(videoManager.videos, hasLength(2));
        expect(videoManager.videos[0].id, equals(testVideo2.id)); // Newest first
        expect(videoManager.videos[1].id, equals(testVideo1.id)); // Oldest last
      });

      test('should prevent duplicate video events', () async {
        // ARRANGE & ACT
        await videoManager.addVideoEvent(testVideo1);
        await videoManager.addVideoEvent(testVideo1); // Duplicate

        // ASSERT
        expect(videoManager.videos, hasLength(1));
        expect(videoManager.videos[0].id, equals(testVideo1.id));
      });

      test('should return immutable video list', () {
        // ARRANGE
        final videosList = videoManager.videos;

        // ACT & ASSERT
        expect(() => videosList.add(testVideo1), throwsUnsupportedError);
      });

      test('should initialize video state as notLoaded when added', () async {
        // ARRANGE & ACT
        await videoManager.addVideoEvent(testVideo1);

        // ASSERT
        final state = videoManager.getVideoState(testVideo1.id);
        expect(state, isNotNull);
        expect(state!.loadingState, equals(VideoLoadingState.notLoaded));
      });
    });

    group('Video State Management Contract', () {
      test('should return null for non-existent video state', () {
        // ARRANGE & ACT
        final state = videoManager.getVideoState('non-existent');

        // ASSERT
        expect(state, isNull);
      });

      test('should track video state transitions correctly', () async {
        // ARRANGE
        await videoManager.addVideoEvent(testVideo1);
        final initialState = videoManager.getVideoState(testVideo1.id);
        expect(initialState!.loadingState, equals(VideoLoadingState.notLoaded));

        // ACT - Start preloading
        final preloadFuture = videoManager.preloadVideo(testVideo1.id);
        
        // Should be loading immediately
        final loadingState = videoManager.getVideoState(testVideo1.id);
        expect(loadingState!.isLoading, isTrue);
        
        // Wait for completion
        await preloadFuture;

        // ASSERT - Should be ready after preload
        final readyState = videoManager.getVideoState(testVideo1.id);
        expect(readyState!.isReady, isTrue);
      });

      test('should handle preload failures gracefully', () async {
        // ARRANGE
        await videoManager.addVideoEvent(failingVideo);

        // ACT
        await videoManager.preloadVideo(failingVideo.id);

        // ASSERT
        final state = videoManager.getVideoState(failingVideo.id);
        expect(state!.hasFailed, isTrue);
      });

      test('should return null controller for non-ready videos', () async {
        // ARRANGE
        await videoManager.addVideoEvent(testVideo1);

        // ACT & ASSERT
        expect(videoManager.getController(testVideo1.id), isNull);
      });
    });

    group('Video Preloading Contract', () {
      test('should preload videos around current index', () async {
        // ARRANGE - Add multiple videos
        for (int i = 0; i < 5; i++) {
          final video = TestHelpers.createVideoEvent(
            id: 'video-$i',
            title: 'Video $i',
          );
          await videoManager.addVideoEvent(video);
        }

        // ACT - Preload around index 2 with range 1
        videoManager.preloadAroundIndex(2, preloadRange: 1);
        
        // Give time for preloading
        await Future.delayed(const Duration(milliseconds: 150));

        // ASSERT - Videos 1, 2, 3 should be ready or loading
        for (int i = 1; i <= 3; i++) {
          final state = videoManager.getVideoState('video-$i');
          expect(state, isNotNull);
          expect(state!.isLoading || state.isReady, isTrue);
        }
      });

      test('should handle preload of already ready video gracefully', () async {
        // ARRANGE
        await videoManager.addVideoEvent(testVideo1);
        await videoManager.preloadVideo(testVideo1.id); // First preload
        final firstState = videoManager.getVideoState(testVideo1.id);
        expect(firstState!.isReady, isTrue);

        // ACT - Preload again
        await videoManager.preloadVideo(testVideo1.id);

        // ASSERT - Should remain ready
        final secondState = videoManager.getVideoState(testVideo1.id);
        expect(secondState!.isReady, isTrue);
      });

      test('should throw exception for preloading non-existent video', () async {
        // ACT & ASSERT
        expect(
          () => videoManager.preloadVideo('non-existent'),
          throwsA(isA<VideoManagerException>()),
        );
      });
    });

    group('Video Disposal Contract', () => {
      test('should dispose video controller and update state', () async {
        // ARRANGE
        await videoManager.addVideoEvent(testVideo1);
        await videoManager.preloadVideo(testVideo1.id);
        final readyState = videoManager.getVideoState(testVideo1.id);
        expect(readyState!.isReady, isTrue);

        // ACT
        videoManager.disposeVideo(testVideo1.id);

        // ASSERT
        final disposedState = videoManager.getVideoState(testVideo1.id);
        expect(disposedState!.isDisposed, isTrue);
        expect(videoManager.getController(testVideo1.id), isNull);
      }),

      test('should handle disposal of non-existent video gracefully', () {
        // ACT & ASSERT - Should not throw
        expect(() => videoManager.disposeVideo('non-existent'), returnsNormally);
      }),
    });

    group('Memory Management Contract', () {
      test('should provide debug information', () {
        // ACT
        final debugInfo = videoManager.getDebugInfo();

        // ASSERT
        expect(debugInfo, containsPair('totalVideos', 0));
        expect(debugInfo, containsPair('readyVideos', 0));
        expect(debugInfo, containsPair('loadingVideos', 0));
        expect(debugInfo, containsPair('failedVideos', 0));
        expect(debugInfo, containsPair('controllers', 0));
        expect(debugInfo, containsPair('disposed', false));
      });

      test('should handle memory pressure by disposing controllers', () async {
        // ARRANGE - Add and preload multiple videos
        for (int i = 0; i < 3; i++) {
          final video = TestHelpers.createVideoEvent(id: 'video-$i');
          await videoManager.addVideoEvent(video);
          await videoManager.preloadVideo(video.id);
        }

        // Verify all are ready
        expect(videoManager.readyVideos, hasLength(3));

        // ACT
        await videoManager.handleMemoryPressure();

        // ASSERT - Should keep at least one video ready
        expect(videoManager.readyVideos.length, lessThan(3));
      });
    });

    group('Error Handling Contract', () {
      test('should throw VideoManagerException for invalid video events', () async {
        // ARRANGE
        final invalidVideo = TestHelpers.createVideoEvent(id: ''); // Empty ID

        // ACT & ASSERT
        expect(
          () => videoManager.addVideoEvent(invalidVideo),
          throwsA(isA<VideoManagerException>()),
        );
      });

      test('should include video ID in error messages when available', () async {
        // ACT & ASSERT
        try {
          await videoManager.preloadVideo('non-existent');
          fail('Should have thrown VideoManagerException');
        } catch (e) {
          expect(e, isA<VideoManagerException>());
          expect(e.toString(), contains('non-existent'));
        }
      });

      test('should prevent operations after disposal', () async {
        // ARRANGE
        videoManager.dispose();

        // ACT & ASSERT
        expect(
          () => videoManager.addVideoEvent(testVideo1),
          throwsA(isA<VideoManagerException>()),
        );
        expect(
          () => videoManager.preloadVideo('any-id'),
          throwsA(isA<VideoManagerException>()),
        );
      });
    });

    group('Resource Cleanup Contract', () {
      test('should clean up all resources on disposal', () async {
        // ARRANGE
        await videoManager.addVideoEvent(testVideo1);
        await videoManager.preloadVideo(testVideo1.id);
        
        final debugInfoBefore = videoManager.getDebugInfo();
        expect(debugInfoBefore['totalVideos'], equals(1));

        // ACT
        videoManager.dispose();

        // ASSERT
        final debugInfoAfter = videoManager.getDebugInfo();
        expect(debugInfoAfter['totalVideos'], equals(0));
        expect(debugInfoAfter['controllers'], equals(0));
        expect(debugInfoAfter['disposed'], isTrue);
        expect(videoManager.videos, isEmpty);
      });

      test('should be safe to dispose multiple times', () {
        // ACT & ASSERT - Should not throw
        expect(() {
          videoManager.dispose();
          videoManager.dispose();
          videoManager.dispose();
        }, returnsNormally);
      });
    });

    group('Configuration Contract', () {
      test('should create valid default configuration', () {
        // ARRANGE & ACT
        const config = VideoManagerConfig();

        // ASSERT
        expect(config.maxVideos, equals(100));
        expect(config.preloadAhead, equals(3));
        expect(config.preloadBehind, equals(1));
        expect(config.maxRetries, equals(3));
        expect(config.preloadTimeout, equals(const Duration(seconds: 10)));
        expect(config.enableMemoryManagement, isTrue);
      });

      test('should create valid cellular configuration', () {
        // ARRANGE & ACT
        final config = VideoManagerConfig.cellular();

        // ASSERT
        expect(config.maxVideos, equals(50));
        expect(config.preloadAhead, equals(1));
        expect(config.preloadBehind, equals(0));
        expect(config.maxRetries, equals(2));
        expect(config.preloadTimeout, equals(const Duration(seconds: 15)));
        expect(config.enableMemoryManagement, isTrue);
      });

      test('should create valid wifi configuration', () {
        // ARRANGE & ACT
        final config = VideoManagerConfig.wifi();

        // ASSERT
        expect(config.maxVideos, equals(100));
        expect(config.preloadAhead, equals(5));
        expect(config.preloadBehind, equals(2));
        expect(config.maxRetries, equals(3));
        expect(config.preloadTimeout, equals(const Duration(seconds: 10)));
        expect(config.enableMemoryManagement, isTrue);
      });

      test('should create valid testing configuration', () {
        // ARRANGE & ACT
        final config = VideoManagerConfig.testing();

        // ASSERT
        expect(config.maxVideos, equals(10));
        expect(config.preloadAhead, equals(2));
        expect(config.preloadBehind, equals(1));
        expect(config.maxRetries, equals(1));
        expect(config.preloadTimeout, equals(const Duration(milliseconds: 500)));
        expect(config.enableMemoryManagement, isTrue);
      });
    });

    group('Exception Handling Contract', () {
      test('should create VideoManagerException with message', () {
        // ARRANGE & ACT
        const exception = VideoManagerException('Test error');

        // ASSERT
        expect(exception.message, equals('Test error'));
        expect(exception.videoId, isNull);
        expect(exception.originalError, isNull);
      });

      test('should create VideoManagerException with video ID', () {
        // ARRANGE & ACT
        const exception = VideoManagerException(
          'Test error',
          videoId: 'video-123',
        );

        // ASSERT
        expect(exception.message, equals('Test error'));
        expect(exception.videoId, equals('video-123'));
        expect(exception.toString(), contains('video-123'));
      });

      test('should create VideoManagerException with original error', () {
        // ARRANGE & ACT
        final originalError = Exception('Original error');
        final exception = VideoManagerException(
          'Test error',
          originalError: originalError,
        );

        // ASSERT
        expect(exception.message, equals('Test error'));
        expect(exception.originalError, equals(originalError));
        expect(exception.toString(), contains('Original error'));
      });

      test('should format exception string properly', () {
        // ARRANGE & ACT
        const exception = VideoManagerException(
          'Test error',
          videoId: 'video-123',
          originalError: 'Original error',
        );

        // ASSERT
        final exceptionString = exception.toString();
        expect(exceptionString, contains('VideoManagerException: Test error'));
        expect(exceptionString, contains('(videoId: video-123)'));
        expect(exceptionString, contains('(caused by: Original error)'));
      });
    });

    group('Priority and Strategy Enums Contract', () {
      test('should define all required PreloadPriority values', () {
        // ASSERT
        expect(PreloadPriority.values, hasLength(4));
        expect(PreloadPriority.values, contains(PreloadPriority.current));
        expect(PreloadPriority.values, contains(PreloadPriority.next));
        expect(PreloadPriority.values, contains(PreloadPriority.nearby));
        expect(PreloadPriority.values, contains(PreloadPriority.background));
      });

      test('should define all required CleanupStrategy values', () {
        // ASSERT
        expect(CleanupStrategy.values, hasLength(4));
        expect(CleanupStrategy.values, contains(CleanupStrategy.immediate));
        expect(CleanupStrategy.values, contains(CleanupStrategy.delayed));
        expect(CleanupStrategy.values, contains(CleanupStrategy.memoryPressure));
        expect(CleanupStrategy.values, contains(CleanupStrategy.limitBased));
      });
    });
  });
}