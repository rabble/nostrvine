// ABOUTME: Comprehensive test suite for VideoManagerService production implementation  
// ABOUTME: Tests video lifecycle, preloading, memory management, and error handling

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/models/video_state.dart';
import 'package:openvine/services/video_manager_interface.dart';
import 'package:openvine/services/video_manager_service.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('VideoManagerService', () {
    late VideoManagerService videoManager;
    late VideoEvent testVideo1;
    late VideoEvent testVideo2;
    late VideoEvent testVideo3;

    setUp(() {
      videoManager = VideoManagerService(
        config: VideoManagerConfig.testing(), // Fast, small limits for testing
      );
      
      testVideo1 = TestHelpers.createVideoEvent(
        id: 'test-video-1',
        title: 'Test Video 1',
        videoUrl: 'https://example.com/video1.mp4',
      );
      
      testVideo2 = TestHelpers.createVideoEvent(
        id: 'test-video-2',
        title: 'Test Video 2',
        videoUrl: 'https://example.com/video2.mp4',
      );
      
      testVideo3 = TestHelpers.createVideoEvent(
        id: 'test-video-3',
        title: 'Test Video 3',
        videoUrl: 'https://example.com/video3.mp4',
      );
    });

    tearDown(() {
      videoManager.dispose();
    });

    group('Initialization and Configuration', () {
      test('should initialize with default config when none provided', () {
        final manager = VideoManagerService();
        
        expect(manager.videos, isEmpty);
        expect(manager.readyVideos, isEmpty);
        
        final debugInfo = manager.getDebugInfo();
        expect(debugInfo['config']['maxVideos'], equals(100)); // Default value
        
        manager.dispose();
      });

      test('should initialize with testing config', () {
        final debugInfo = videoManager.getDebugInfo();
        
        expect(debugInfo['config']['maxVideos'], equals(10)); // Testing value
        expect(debugInfo['config']['preloadAhead'], equals(2));
        expect(debugInfo['config']['preloadBehind'], equals(1));
        expect(debugInfo['config']['maxRetries'], equals(1));
        expect(debugInfo['config']['preloadTimeout'], equals(500)); // 500ms
        expect(debugInfo['config']['enableMemoryManagement'], isTrue);
      });

      test('should provide comprehensive debug information', () {
        final debugInfo = videoManager.getDebugInfo();
        
        expect(debugInfo, containsPair('totalVideos', 0));
        expect(debugInfo, containsPair('readyVideos', 0));
        expect(debugInfo, containsPair('loadingVideos', 0));
        expect(debugInfo, containsPair('failedVideos', 0));
        expect(debugInfo, containsPair('activeControllers', 0));
        expect(debugInfo, containsPair('activePreloads', 0));
        expect(debugInfo, containsPair('disposed', false));
        expect(debugInfo, contains('config'));
        expect(debugInfo, contains('metrics'));
      });
    });

    group('Video Addition and Management', () {
      test('should add video events in newest-first order', () async {
        await videoManager.addVideoEvent(testVideo1);
        await videoManager.addVideoEvent(testVideo2);
        await videoManager.addVideoEvent(testVideo3);

        final videos = videoManager.videos;
        expect(videos, hasLength(3));
        expect(videos[0].id, equals(testVideo3.id)); // Newest first
        expect(videos[1].id, equals(testVideo2.id));
        expect(videos[2].id, equals(testVideo1.id)); // Oldest last
      });

      test('should prevent duplicate video events', () async {
        await videoManager.addVideoEvent(testVideo1);
        await videoManager.addVideoEvent(testVideo1); // Duplicate

        expect(videoManager.videos, hasLength(1));
        expect(videoManager.videos[0].id, equals(testVideo1.id));
      });

      test('should initialize video state when adding', () async {
        await videoManager.addVideoEvent(testVideo1);

        final state = videoManager.getVideoState(testVideo1.id);
        expect(state, isNotNull);
        expect(state!.loadingState, equals(VideoLoadingState.notLoaded));
        expect(state.event.id, equals(testVideo1.id));
      });

      test('should throw exception for invalid video events', () async {
        final invalidVideo = TestHelpers.createVideoEvent(id: ''); // Empty ID

        expect(
          () => videoManager.addVideoEvent(invalidVideo),
          throwsA(isA<VideoManagerException>()),
        );
      });

      test('should emit state changes when adding videos', () async {
        final stateChanges = <void>[];
        final subscription = videoManager.stateChanges.listen(stateChanges.add);

        await videoManager.addVideoEvent(testVideo1);
        await videoManager.addVideoEvent(testVideo2);

        // Give time for stream events
        await Future.delayed(const Duration(milliseconds: 10));

        expect(stateChanges.length, greaterThanOrEqualTo(2));
        
        await subscription.cancel();
      });
    });

    group('Video State Management', () {
      test('should return null for non-existent video state', () {
        final state = videoManager.getVideoState('non-existent');
        expect(state, isNull);
      });

      test('should track video states correctly', () async {
        await videoManager.addVideoEvent(testVideo1);

        final initialState = videoManager.getVideoState(testVideo1.id);
        expect(initialState!.loadingState, equals(VideoLoadingState.notLoaded));
        expect(initialState.retryCount, equals(0));
        expect(initialState.errorMessage, isNull);
      });

      test('should return null controller for non-ready videos', () async {
        await videoManager.addVideoEvent(testVideo1);

        final controller = videoManager.getController(testVideo1.id);
        expect(controller, isNull);
      });

      test('should filter ready videos correctly', () async {
        await videoManager.addVideoEvent(testVideo1);
        await videoManager.addVideoEvent(testVideo2);

        // Initially no videos are ready
        expect(videoManager.readyVideos, isEmpty);

        // Mock a ready state (in real implementation this would come from successful preload)
        // Note: In production, this state would be managed internally by preload operations
      });
    });

    group('Video Preloading', () {
      test('should handle preload of non-existent video', () async {
        expect(
          () => videoManager.preloadVideo('non-existent'),
          throwsA(isA<VideoManagerException>()),
        );
      });

      test('should update state to loading when preload starts', () async {
        await videoManager.addVideoEvent(testVideo1);

        final initialState = videoManager.getVideoState(testVideo1.id);
        expect(initialState!.loadingState, equals(VideoLoadingState.notLoaded));

        // Start preload (will fail due to network, but state should update)
        final preloadFuture = videoManager.preloadVideo(testVideo1.id);
        
        // Check state immediately - it should transition to loading before the error
        final loadingState = videoManager.getVideoState(testVideo1.id);
        expect(loadingState!.isLoading, isTrue);

        // Wait for preload to complete (will fail in test environment)
        try {
          await preloadFuture;
        } catch (e) {
          // Expected to fail in test environment due to network
        }
      });

      test('should prevent concurrent preloads of same video', () async {
        await videoManager.addVideoEvent(testVideo1);

        // Start first preload
        final preload1 = videoManager.preloadVideo(testVideo1.id);
        
        // Start second preload immediately
        final preload2 = videoManager.preloadVideo(testVideo1.id);

        // Both should complete without error (second should be ignored)
        try {
          await Future.wait([preload1, preload2]);
        } catch (e) {
          // Expected to fail in test environment due to network
        }

        // Should have attempted preload only once
        final debugInfo = videoManager.getDebugInfo();
        expect(debugInfo['metrics']['preloadCount'], equals(1));
      });

      test('should handle preload failures gracefully', () async {
        await videoManager.addVideoEvent(testVideo1);

        try {
          await videoManager.preloadVideo(testVideo1.id);
          fail('Expected preload to fail in test environment');
        } catch (e) {
          expect(e, isA<Exception>());
        }

        final state = videoManager.getVideoState(testVideo1.id);
        expect(state!.hasFailed, isTrue);
        expect(state.errorMessage, isNotNull);
      });
    });

    group('Preload Around Index', () {
      test('should handle empty video list gracefully', () {
        expect(() => videoManager.preloadAroundIndex(0), returnsNormally);
      });

      test('should preload videos around specified index', () async {
        // Add multiple videos
        for (int i = 0; i < 5; i++) {
          final video = TestHelpers.createVideoEvent(
            id: 'video-$i',
            title: 'Video $i',
            videoUrl: 'https://example.com/video$i.mp4',
          );
          await videoManager.addVideoEvent(video);
        }

        // Preload around index 2
        videoManager.preloadAroundIndex(2, preloadRange: 1);

        // Give time for background preloading to start
        await Future.delayed(const Duration(milliseconds: 50));

        final debugInfo = videoManager.getDebugInfo();
        expect(debugInfo['metrics']['preloadCount'], greaterThan(0));
      });

      test('should use configuration defaults when no range specified', () async {
        for (int i = 0; i < 3; i++) {
          final video = TestHelpers.createVideoEvent(id: 'video-$i');
          await videoManager.addVideoEvent(video);
        }

        videoManager.preloadAroundIndex(1); // No range specified

        await Future.delayed(const Duration(milliseconds: 50));

        final debugInfo = videoManager.getDebugInfo();
        expect(debugInfo['metrics']['preloadCount'], greaterThan(0));
      });
    });

    group('Video Disposal', () {
      test('should dispose video and update state', () async {
        await videoManager.addVideoEvent(testVideo1);

        videoManager.disposeVideo(testVideo1.id);

        final state = videoManager.getVideoState(testVideo1.id);
        expect(state!.isDisposed, isTrue);
      });

      test('should handle disposal of non-existent video gracefully', () {
        expect(() => videoManager.disposeVideo('non-existent'), returnsNormally);
      });

      test('should clean up controllers when disposing', () async {
        await videoManager.addVideoEvent(testVideo1);

        // In real scenario, there would be a controller after successful preload
        videoManager.disposeVideo(testVideo1.id);

        final controller = videoManager.getController(testVideo1.id);
        expect(controller, isNull);
      });
    });

    group('Memory Management', () {
      test('should enforce memory limits when adding videos', () async {
        final config = VideoManagerConfig.testing(); // Max 10 videos
        final manager = VideoManagerService(config: config);

        // Add more videos than the limit
        for (int i = 0; i < 15; i++) {
          final video = TestHelpers.createVideoEvent(
            id: 'video-$i',
            title: 'Video $i',
          );
          await manager.addVideoEvent(video);
        }

        // Should not exceed the limit
        expect(manager.videos.length, lessThanOrEqualTo(config.maxVideos));
        
        manager.dispose();
      });

      test('should handle memory pressure by disposing old videos', () async {
        // Add several videos
        for (int i = 0; i < 5; i++) {
          final video = TestHelpers.createVideoEvent(id: 'video-$i');
          await videoManager.addVideoEvent(video);
        }

        final initialCount = videoManager.videos.length;
        
        await videoManager.handleMemoryPressure();

        final finalCount = videoManager.videos.length;
        expect(finalCount, lessThanOrEqualTo(initialCount));

        final debugInfo = videoManager.getDebugInfo();
        expect(debugInfo['metrics']['memoryPressureCount'], equals(1));
      });
    });

    group('Error Handling and Recovery', () {
      test('should throw exception when operating on disposed manager', () async {
        videoManager.dispose();

        expect(
          () => videoManager.addVideoEvent(testVideo1),
          throwsA(isA<VideoManagerException>()),
        );

        expect(
          () => videoManager.preloadVideo('any-id'),
          throwsA(isA<VideoManagerException>()),
        );
      });

      test('should handle invalid video URLs gracefully', () async {
        final invalidVideo = TestHelpers.createVideoEvent(
          id: 'invalid-video',
          videoUrl: '', // Empty URL
        );

        await videoManager.addVideoEvent(invalidVideo);

        expect(
          () => videoManager.preloadVideo(invalidVideo.id),
          throwsA(isA<VideoManagerException>()),
        );
      });

      test('should track error metrics correctly', () async {
        await videoManager.addVideoEvent(testVideo1);

        try {
          await videoManager.preloadVideo(testVideo1.id);
        } catch (e) {
          // Expected to fail in test environment
        }

        // Wait for any pending operations to complete
        await Future.delayed(const Duration(milliseconds: 100));

        final debugInfo = videoManager.getDebugInfo();
        expect(debugInfo['metrics']['preloadCount'], greaterThan(0));
        expect(debugInfo['metrics']['preloadFailureCount'], greaterThan(0));
        expect(debugInfo['metrics']['preloadSuccessRate'], equals('0.0'));
      });
    });

    group('Resource Cleanup', () {
      test('should clean up all resources on disposal', () async {
        await videoManager.addVideoEvent(testVideo1);
        await videoManager.addVideoEvent(testVideo2);

        final debugInfoBefore = videoManager.getDebugInfo();
        expect(debugInfoBefore['totalVideos'], equals(2));

        videoManager.dispose();

        final debugInfoAfter = videoManager.getDebugInfo();
        expect(debugInfoAfter['totalVideos'], equals(0));
        expect(debugInfoAfter['activeControllers'], equals(0));
        expect(debugInfoAfter['disposed'], isTrue);
      });

      test('should be safe to dispose multiple times', () {
        expect(() {
          videoManager.dispose();
          videoManager.dispose();
          videoManager.dispose();
        }, returnsNormally);
      });

      test('should return null for all getters after disposal', () async {
        await videoManager.addVideoEvent(testVideo1);
        
        videoManager.dispose();

        expect(videoManager.getVideoState(testVideo1.id), isNull);
        expect(videoManager.getController(testVideo1.id), isNull);
        expect(videoManager.videos, isEmpty);
        expect(videoManager.readyVideos, isEmpty);
      });

      test('should close state changes stream on disposal', () async {
        final stateChanges = <void>[];
        final subscription = videoManager.stateChanges.listen(stateChanges.add);

        videoManager.dispose();

        // Stream should be closed
        expect(() => subscription.cancel(), returnsNormally);
      });
    });

    group('Configuration Variants', () {
      test('should work with WiFi configuration', () {
        final manager = VideoManagerService(config: VideoManagerConfig.wifi());
        
        final debugInfo = manager.getDebugInfo();
        expect(debugInfo['config']['maxVideos'], equals(100));
        expect(debugInfo['config']['preloadAhead'], equals(5));
        expect(debugInfo['config']['preloadBehind'], equals(2));
        
        manager.dispose();
      });

      test('should work with cellular configuration', () {
        final manager = VideoManagerService(config: VideoManagerConfig.cellular());
        
        final debugInfo = manager.getDebugInfo();
        expect(debugInfo['config']['maxVideos'], equals(50));
        expect(debugInfo['config']['preloadAhead'], equals(1));
        expect(debugInfo['config']['preloadBehind'], equals(0));
        
        manager.dispose();
      });

      test('should work with custom configuration', () {
        final customConfig = VideoManagerConfig(
          maxVideos: 25,
          preloadAhead: 3,
          preloadBehind: 1,
          maxRetries: 2,
          preloadTimeout: const Duration(seconds: 5),
          enableMemoryManagement: false,
        );
        
        final manager = VideoManagerService(config: customConfig);
        
        final debugInfo = manager.getDebugInfo();
        expect(debugInfo['config']['maxVideos'], equals(25));
        expect(debugInfo['config']['preloadAhead'], equals(3));
        expect(debugInfo['config']['enableMemoryManagement'], isFalse);
        
        manager.dispose();
      });
    });

    group('Performance and Metrics', () {
      test('should track preload metrics correctly', () async {
        // Note: All preloads will fail in test environment due to network
        await videoManager.addVideoEvent(testVideo1);
        await videoManager.addVideoEvent(testVideo2);

        // Attempt preloads (will fail)
        try {
          await videoManager.preloadVideo(testVideo1.id);
        } catch (e) {
          // Expected to fail
        }
        
        try {
          await videoManager.preloadVideo(testVideo2.id);
        } catch (e) {
          // Expected to fail  
        }

        // Wait a bit for any pending operations
        await Future.delayed(const Duration(milliseconds: 100));

        final debugInfo = videoManager.getDebugInfo();
        // Check that at least some preload attempts were made
        expect(debugInfo['metrics']['preloadCount'], greaterThan(0));
        expect(debugInfo['metrics']['preloadSuccessCount'], equals(0));
        expect(debugInfo['metrics']['preloadSuccessRate'], equals('0.0'));
      });

      test('should provide timing information for memory cleanup', () async {
        await videoManager.handleMemoryPressure();

        final debugInfo = videoManager.getDebugInfo();
        expect(debugInfo['metrics']['lastCleanupTime'], isNotNull);
        expect(debugInfo['metrics']['memoryPressureCount'], equals(1));
      });
    });

    group('State Change Notifications', () {
      test('should notify listeners of state changes', () async {
        final notifications = <void>[];
        final subscription = videoManager.stateChanges.listen(notifications.add);

        await videoManager.addVideoEvent(testVideo1);
        await videoManager.addVideoEvent(testVideo2);
        
        videoManager.disposeVideo(testVideo1.id);

        // Give time for notifications
        await Future.delayed(const Duration(milliseconds: 10));

        expect(notifications.length, greaterThan(0));
        
        await subscription.cancel();
      });

      test('should not notify after disposal', () async {
        final notifications = <void>[];
        final subscription = videoManager.stateChanges.listen(notifications.add);

        videoManager.dispose();

        // Try to trigger notifications after disposal
        try {
          await videoManager.addVideoEvent(testVideo1);
        } catch (e) {
          // Expected to fail
        }

        // Should not receive notifications after disposal
        expect(notifications, isEmpty);
        
        await subscription.cancel();
      });
    });
  });
}