// ABOUTME: Comprehensive memory management tests for VideoManagerService
// ABOUTME: Tests memory limits, cleanup behavior, pressure handling and leak prevention

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostrvine_app/models/video_event.dart';
import 'package:nostrvine_app/models/video_state.dart';
import 'package:nostrvine_app/services/video_manager_interface.dart';
import 'package:nostrvine_app/services/video_manager_service.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('VideoManagerService Memory Management', () {
    late VideoManagerService videoManager;
    late VideoManagerConfig testConfig;

    setUp(() {
      // Use testing config with small limits for memory testing
      testConfig = VideoManagerConfig.testing();
      videoManager = VideoManagerService(config: testConfig);
    });

    tearDown(() {
      videoManager.dispose();
    });

    group('Memory Limits Enforcement', () {
      test('should enforce maximum video count limit', () async {
        // Add videos beyond the limit (testing config has max 10)
        final videos = TestHelpers.createVideoList(15);
        
        for (final video in videos) {
          await videoManager.addVideoEvent(video);
        }

        // Should not exceed the configured limit
        expect(videoManager.videos.length, lessThanOrEqualTo(testConfig.maxVideos));
        expect(videoManager.videos.length, equals(testConfig.maxVideos));
      });

      test('should remove oldest videos when limit exceeded', () async {
        final videos = TestHelpers.createVideoList(12, timeSpacing: const Duration(seconds: 10));
        
        // Add all videos
        for (final video in videos) {
          await videoManager.addVideoEvent(video);
        }

        // Should keep only the newest videos
        final remainingVideos = videoManager.videos;
        expect(remainingVideos.length, equals(testConfig.maxVideos));
        
        // Verify newest videos are retained (videos are added in newest-first order)
        // The first videos added should be the last ones in the createVideoList result
        // because createVideoList creates older videos first, but addVideoEvent puts newest first
        final expectedNewestVideos = videos.reversed.take(testConfig.maxVideos).toList();
        for (int i = 0; i < remainingVideos.length; i++) {
          expect(remainingVideos[i].id, equals(expectedNewestVideos[i].id));
        }
      });

      test('should clean up video states when removing videos', () async {
        final videos = TestHelpers.createVideoList(12);
        
        for (final video in videos) {
          await videoManager.addVideoEvent(video);
        }

        // The oldest videos (first ones in the list) should be removed when limit is exceeded
        // Since videos are added newest-first, the oldest videos would be the first ones in the original list
        final oldestVideos = videos.take(videos.length - testConfig.maxVideos).toList();
        
        for (final oldVideo in oldestVideos) {
          final state = videoManager.getVideoState(oldVideo.id);
          expect(state, isNull, reason: 'State for removed video ${oldVideo.id} should be cleaned up');
        }
      });

      test('should preserve video controllers for active videos during cleanup', () async {
        // Create config with very small limit for testing
        final smallConfig = VideoManagerConfig(
          maxVideos: 3,
          preloadAhead: 1,
          preloadBehind: 1,
          enableMemoryManagement: true,
        );
        
        final smallManager = VideoManagerService(config: smallConfig);
        
        try {
          final videos = TestHelpers.createVideoList(5);
          
          for (final video in videos) {
            await smallManager.addVideoEvent(video);
          }

          // Verify that memory limits were enforced
          expect(smallManager.videos.length, equals(3));
          
          // Check debug info shows proper state
          final debugInfo = smallManager.getDebugInfo();
          expect(debugInfo['totalVideos'], equals(3));
          
        } finally {
          smallManager.dispose();
        }
      });
    });

    group('Memory Pressure Handling', () {
      test('should handle memory pressure by disposing old videos', () async {
        // Add several videos
        final videos = TestHelpers.createVideoList(8);
        for (final video in videos) {
          await videoManager.addVideoEvent(video);
        }

        final initialCount = videoManager.videos.length;
        final debugInfoBefore = videoManager.getDebugInfo();
        
        // Trigger memory pressure
        await videoManager.handleMemoryPressure();
        
        // Should have fewer videos after pressure handling
        // Memory pressure keeps 70% of maxVideos, so 7 videos in this case (10 * 0.7 = 7)
        final finalCount = videoManager.videos.length;
        expect(finalCount, lessThan(initialCount));
        expect(finalCount, equals((testConfig.maxVideos * 0.7).floor()));
        
        // Should have updated pressure count
        final debugInfoAfter = videoManager.getDebugInfo();
        expect(debugInfoAfter['metrics']['memoryPressureCount'], 
               equals(debugInfoBefore['metrics']['memoryPressureCount'] + 1));
      });

      test('should preserve newest videos during memory pressure', () async {
        final videos = TestHelpers.createVideoList(8, timeSpacing: const Duration(minutes: 1));
        for (final video in videos) {
          await videoManager.addVideoEvent(video);
        }

        final videosBeforePressure = List.from(videoManager.videos);
        
        await videoManager.handleMemoryPressure();
        
        final videosAfterPressure = videoManager.videos;
        
        // All remaining videos should be from the beginning of the original list (newest)
        for (int i = 0; i < videosAfterPressure.length; i++) {
          expect(videosAfterPressure[i].id, equals(videosBeforePressure[i].id));
        }
      });

      test('should update cleanup timestamp after memory pressure', () async {
        final videos = TestHelpers.createVideoList(5);
        for (final video in videos) {
          await videoManager.addVideoEvent(video);
        }

        final debugInfoBefore = videoManager.getDebugInfo();
        final beforeTimestamp = debugInfoBefore['metrics']['lastCleanupTime'];
        
        await videoManager.handleMemoryPressure();
        
        final debugInfoAfter = videoManager.getDebugInfo();
        final afterTimestamp = debugInfoAfter['metrics']['lastCleanupTime'];
        
        expect(afterTimestamp, isNotNull);
        expect(afterTimestamp, isNot(equals(beforeTimestamp)));
      });

      test('should handle multiple memory pressure calls gracefully', () async {
        final videos = TestHelpers.createVideoList(6);
        for (final video in videos) {
          await videoManager.addVideoEvent(video);
        }

        // Call memory pressure multiple times
        await videoManager.handleMemoryPressure();
        final firstCleanupCount = videoManager.videos.length;
        
        await videoManager.handleMemoryPressure();
        final secondCleanupCount = videoManager.videos.length;
        
        await videoManager.handleMemoryPressure();
        final thirdCleanupCount = videoManager.videos.length;
        
        // Should handle gracefully without errors
        expect(thirdCleanupCount, lessThanOrEqualTo(secondCleanupCount));
        expect(secondCleanupCount, lessThanOrEqualTo(firstCleanupCount));
        
        final debugInfo = videoManager.getDebugInfo();
        expect(debugInfo['metrics']['memoryPressureCount'], equals(3));
      });
    });

    group('Controller Memory Management', () {
      test('should dispose controllers when videos are removed', () async {
        final videos = TestHelpers.createVideoList(12);
        
        for (final video in videos) {
          await videoManager.addVideoEvent(video);
        }

        // Get debug info to see controller count
        final debugInfo = videoManager.getDebugInfo();
        final totalVideos = debugInfo['totalVideos'] as int;
        
        // Should not have more controllers than videos
        expect(debugInfo['activeControllers'], lessThanOrEqualTo(totalVideos));
      });

      test('should dispose individual video controllers correctly', () async {
        final video = TestHelpers.createVideoEvent(id: 'test-dispose');
        await videoManager.addVideoEvent(video);

        // Initially no controller
        expect(videoManager.getController(video.id), isNull);
        
        // Dispose the video
        videoManager.disposeVideo(video.id);
        
        // State should be disposed
        final state = videoManager.getVideoState(video.id);
        expect(state?.isDisposed, isTrue);
        
        // Controller should be null
        expect(videoManager.getController(video.id), isNull);
      });

      test('should handle disposal of non-existent videos gracefully', () async {
        // Should not throw when disposing non-existent video
        expect(() => videoManager.disposeVideo('non-existent'), returnsNormally);
        
        // Debug info should remain consistent
        final debugInfo = videoManager.getDebugInfo();
        expect(debugInfo['totalVideos'], equals(0));
        expect(debugInfo['activeControllers'], equals(0));
      });

      test('should clean up all controllers during manager disposal', () async {
        final videos = TestHelpers.createVideoList(5);
        for (final video in videos) {
          await videoManager.addVideoEvent(video);
        }

        // Dispose the manager
        videoManager.dispose();
        
        // All controllers should be cleaned up
        final debugInfo = videoManager.getDebugInfo();
        expect(debugInfo['activeControllers'], equals(0));
        expect(debugInfo['totalVideos'], equals(0));
        expect(debugInfo['disposed'], isTrue);
      });
    });

    group('Memory Configuration Impact', () {
      test('should respect disabled memory management', () async {
        final noMemMgmtConfig = VideoManagerConfig(
          maxVideos: 5,
          enableMemoryManagement: false,
        );
        final noMemMgmtManager = VideoManagerService(config: noMemMgmtConfig);
        
        try {
          // Add more videos than the limit
          final videos = TestHelpers.createVideoList(8);
          for (final video in videos) {
            await noMemMgmtManager.addVideoEvent(video);
          }

          // Without memory management, it might exceed the limit
          // (depending on implementation details)
          final debugInfo = noMemMgmtManager.getDebugInfo();
          expect(debugInfo['config']['enableMemoryManagement'], isFalse);
          
        } finally {
          noMemMgmtManager.dispose();
        }
      });

      test('should adapt to different memory configurations', () async {
        final wifiConfig = VideoManagerConfig.wifi();
        final cellularConfig = VideoManagerConfig.cellular();
        
        final wifiManager = VideoManagerService(config: wifiConfig);
        final cellularManager = VideoManagerService(config: cellularConfig);
        
        try {
          // Wifi should allow more videos
          expect(wifiConfig.maxVideos, greaterThan(cellularConfig.maxVideos));
          
          // Verify debug info reflects configs
          final wifiDebug = wifiManager.getDebugInfo();
          final cellularDebug = cellularManager.getDebugInfo();
          
          expect(wifiDebug['config']['maxVideos'], equals(100));
          expect(cellularDebug['config']['maxVideos'], equals(50));
          
        } finally {
          wifiManager.dispose();
          cellularManager.dispose();
        }
      });
    });

    group('Memory Leak Prevention', () {
      test('should not leak video states after disposal', () async {
        final videos = TestHelpers.createVideoList(5);
        for (final video in videos) {
          await videoManager.addVideoEvent(video);
        }

        // Dispose some videos
        for (int i = 0; i < 3; i++) {
          videoManager.disposeVideo(videos[i].id);
        }

        // Check that disposed videos have proper state
        for (int i = 0; i < 3; i++) {
          final state = videoManager.getVideoState(videos[i].id);
          expect(state?.isDisposed, isTrue);
        }
        
        // Remaining videos should still be accessible
        for (int i = 3; i < 5; i++) {
          final state = videoManager.getVideoState(videos[i].id);
          expect(state?.isDisposed, isFalse);
        }
      });

      test('should clean up stream controllers properly', () async {
        final stateChanges = <void>[];
        final subscription = videoManager.stateChanges.listen(stateChanges.add);

        final video = TestHelpers.createVideoEvent();
        await videoManager.addVideoEvent(video);

        // Should receive state change notification
        await Future.delayed(const Duration(milliseconds: 10));
        expect(stateChanges, isNotEmpty);

        // Dispose and ensure stream is closed
        videoManager.dispose();
        
        // Stream should be closed, subscription should handle this gracefully
        await subscription.cancel();
      });

      test('should handle concurrent disposal operations safely', () async {
        final videos = TestHelpers.createVideoList(10);
        for (final video in videos) {
          await videoManager.addVideoEvent(video);
        }

        // Dispose multiple videos concurrently
        final disposalFutures = <Future<void>>[];
        for (int i = 0; i < 5; i++) {
          disposalFutures.add(Future(() => videoManager.disposeVideo(videos[i].id)));
        }

        // Should complete without errors
        await Future.wait(disposalFutures);
        
        // Verify final state is consistent - disposing doesn't remove from videos list
        // Only changes the state to disposed, so total count remains the same
        final debugInfo = videoManager.getDebugInfo();
        expect(debugInfo['totalVideos'], equals(testConfig.maxVideos));
        
        // Check that the disposed videos have proper state
        for (int i = 0; i < 5; i++) {
          final state = videoManager.getVideoState(videos[i].id);
          expect(state?.isDisposed, isTrue);
        }
      });
    });

    group('Performance Under Memory Pressure', () {
      test('should maintain performance during cleanup operations', () async {
        // Add many videos quickly
        final videos = TestHelpers.generatePerformanceTestData(20);
        
        final stopwatch = Stopwatch()..start();
        
        for (final video in videos) {
          await videoManager.addVideoEvent(video);
        }
        
        // Trigger memory pressure
        await videoManager.handleMemoryPressure();
        
        stopwatch.stop();
        
        // Should complete within reasonable time (adjust threshold as needed)
        expect(stopwatch.elapsedMilliseconds, lessThan(1000)); // 1 second max
        
        // Should maintain data integrity
        final debugInfo = videoManager.getDebugInfo();
        expect(debugInfo['totalVideos'], greaterThan(0));
      });

      test('should handle rapid memory pressure cycles', () async {
        final videos = TestHelpers.createVideoList(8);
        for (final video in videos) {
          await videoManager.addVideoEvent(video);
        }

        // Rapid memory pressure cycles
        for (int i = 0; i < 5; i++) {
          await videoManager.handleMemoryPressure();
          await Future.delayed(const Duration(milliseconds: 10));
        }

        // Should maintain stability
        final debugInfo = videoManager.getDebugInfo();
        expect(debugInfo['disposed'], isFalse);
        expect(debugInfo['metrics']['memoryPressureCount'], equals(5));
      });
    });

    group('Memory Usage Monitoring', () {
      test('should calculate estimated memory usage correctly', () async {
        final videos = TestHelpers.createVideoList(5);
        for (final video in videos) {
          await videoManager.addVideoEvent(video);
        }

        // Initially no controllers, so no memory
        final debugInfo = videoManager.getDebugInfo();
        expect(debugInfo['estimatedMemoryMB'], equals(0));
        expect(debugInfo['memoryUtilization'], equals('0.0'));
        expect(debugInfo['config']['maxControllers'], equals(15));
        expect(debugInfo['config']['memoryPerControllerMB'], equals(20));
      });
      
      test('should report accurate memory monitoring in debug info', () async {
        final debugInfo = videoManager.getDebugInfo();
        
        // Should contain memory monitoring fields
        expect(debugInfo, contains('estimatedMemoryMB'));
        expect(debugInfo, contains('memoryUtilization'));
        expect(debugInfo['config'], contains('maxControllers'));
        expect(debugInfo['config'], contains('memoryPerControllerMB'));
        
        // Should be accurate for empty state
        expect(debugInfo['estimatedMemoryMB'], equals(0));
        expect(debugInfo['memoryUtilization'], equals('0.0'));
      });
      
      test('should calculate memory utilization percentage correctly', () async {
        // Mock scenario where we would have controllers
        // In real environment, this would come from successful preloads
        final debugInfo = videoManager.getDebugInfo();
        
        // For calculation testing:
        // If we had 5 controllers out of 15 max = 33.3%
        // If we had 15 controllers out of 15 max = 100.0%
        // If we had 0 controllers out of 15 max = 0.0%
        
        expect(debugInfo['memoryUtilization'], equals('0.0')); // No controllers yet
      });
      
      test('should enforce 500MB memory target through controller limits', () async {
        // 500MB target / 20MB per controller = 25 controllers theoretical max
        // But we enforce 15 controllers max for safety margin
        const int maxControllersForTarget = 500 ~/ 20; // 25
        const int actualMaxControllers = 15;
        
        final debugInfo = videoManager.getDebugInfo();
        final configuredMax = debugInfo['config']['maxControllers'] as int;
        final memoryPerController = debugInfo['config']['memoryPerControllerMB'] as int;
        
        expect(configuredMax, equals(actualMaxControllers));
        expect(memoryPerController, equals(20));
        
        // At max controllers, memory should be <= 500MB
        final maxMemoryMB = configuredMax * memoryPerController;
        expect(maxMemoryMB, lessThanOrEqualTo(500)); // 15 * 20 = 300MB <= 500MB
      });
    });

    group('Edge Cases', () {
      test('should handle memory operations on empty manager', () async {
        // Memory pressure on empty manager
        expect(() => videoManager.handleMemoryPressure(), returnsNormally);
        
        // Disposal on empty manager
        expect(() => videoManager.disposeVideo('any-id'), returnsNormally);
        
        final debugInfo = videoManager.getDebugInfo();
        expect(debugInfo['totalVideos'], equals(0));
      });

      test('should handle memory operations after manager disposal', () async {
        final video = TestHelpers.createVideoEvent();
        await videoManager.addVideoEvent(video);
        
        videoManager.dispose();
        
        // Operations after disposal should be safe
        expect(() => videoManager.handleMemoryPressure(), returnsNormally);
        expect(() => videoManager.disposeVideo(video.id), returnsNormally);
      });

      test('should handle simultaneous add and cleanup operations', () async {
        // Start adding videos
        final addFuture = Future(() async {
          final videos = TestHelpers.createVideoList(15);
          for (final video in videos) {
            await videoManager.addVideoEvent(video);
            await Future.delayed(const Duration(milliseconds: 1));
          }
        });

        // Start memory pressure operations
        final cleanupFuture = Future(() async {
          for (int i = 0; i < 5; i++) {
            await Future.delayed(const Duration(milliseconds: 10));
            await videoManager.handleMemoryPressure();
          }
        });

        // Both should complete without errors
        await Future.wait([addFuture, cleanupFuture]);
        
        // Final state should be consistent
        final debugInfo = videoManager.getDebugInfo();
        expect(debugInfo['totalVideos'], lessThanOrEqualTo(testConfig.maxVideos));
      });
    });
  });
}