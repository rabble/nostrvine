// ABOUTME: Tests for MockVideoManager implementation verification and behavior
// ABOUTME: Ensures mock provides reliable, consistent behavior for other tests

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/models/video_state.dart';
import 'package:openvine/services/video_manager_interface.dart';
import '../../helpers/test_helpers.dart';
import '../../mocks/mock_video_manager.dart';

void main() {
  group('MockVideoManager Tests', () {
    late MockVideoManager mockManager;
    late VideoEvent testVideo1;
    late VideoEvent testVideo2;
    setUp(() {
      mockManager = MockVideoManager();
      testVideo1 = TestHelpers.createVideoEvent(
        id: 'test-video-1',
        title: 'Test Video 1',
      );
      testVideo2 = TestHelpers.createVideoEvent(
        id: 'test-video-2', 
        title: 'Test Video 2',
      );
    });

    tearDown(() {
      mockManager.dispose();
    });

    group('Basic Interface Compliance', () {
      test('should implement all IVideoManager methods', () {
        // ASSERT - Check that mock implements the interface
        expect(mockManager, isA<IVideoManager>());
        
        // Verify all required getters exist
        expect(() => mockManager.videos, returnsNormally);
        expect(() => mockManager.readyVideos, returnsNormally);
        expect(() => mockManager.stateChanges, returnsNormally);
        
        // Verify all required methods exist and return expected types
        expect(mockManager.getVideoState('test'), isNull);
        expect(mockManager.getController('test'), isNull);
        expect(mockManager.getDebugInfo(), isA<Map<String, dynamic>>());
        
        // Methods that don't return values
        mockManager.disposeVideo('test');
        mockManager.preloadAroundIndex(0);
        // Don't dispose here as it affects other tests
      });

      test('should pass all interface contract tests', () async {
        // ARRANGE & ACT - Run basic interface operations
        await mockManager.addVideoEvent(testVideo1);
        await mockManager.addVideoEvent(testVideo2);
        await mockManager.preloadVideo(testVideo1.id);

        // ASSERT - Verify basic contract compliance
        expect(mockManager.videos, hasLength(2));
        expect(mockManager.videos[0].id, equals(testVideo2.id)); // Newest first
        expect(mockManager.videos[1].id, equals(testVideo1.id)); // Oldest last
        
        final state1 = mockManager.getVideoState(testVideo1.id);
        expect(state1!.isReady, isTrue);
        
        final state2 = mockManager.getVideoState(testVideo2.id);
        expect(state2!.loadingState, equals(VideoLoadingState.notLoaded));
      });
    });

    group('Test Control Features', () {
      test('should control preload behavior with PreloadBehavior.alwaysFail', () async {
        // ARRANGE
        mockManager.setPreloadBehavior(PreloadBehavior.alwaysFail);
        await mockManager.addVideoEvent(testVideo1);

        // ACT
        await mockManager.preloadVideo(testVideo1.id);

        // ASSERT
        final state = mockManager.getVideoState(testVideo1.id);
        expect(state!.hasFailed, isTrue);
        expect(state.errorMessage, contains('always fail'));
      });

      test('should control preload behavior with PreloadBehavior.failOnce', () async {
        // ARRANGE
        mockManager.setPreloadBehavior(PreloadBehavior.failOnce);
        await mockManager.addVideoEvent(testVideo1);

        // ACT - First attempt should fail
        await mockManager.preloadVideo(testVideo1.id);
        final firstState = mockManager.getVideoState(testVideo1.id);
        expect(firstState!.hasFailed, isTrue);

        // ACT - Second attempt should succeed
        await mockManager.preloadVideo(testVideo1.id);
        final secondState = mockManager.getVideoState(testVideo1.id);
        expect(secondState!.isReady, isTrue);
      });

      test('should control preload delay timing', () async {
        // ARRANGE
        const testDelay = Duration(milliseconds: 200);
        mockManager.setPreloadDelay(testDelay);
        await mockManager.addVideoEvent(testVideo1);

        // ACT
        final startTime = DateTime.now();
        await mockManager.preloadVideo(testVideo1.id);
        final endTime = DateTime.now();

        // ASSERT
        final actualDelay = endTime.difference(startTime);
        expect(actualDelay.inMilliseconds, greaterThanOrEqualTo(testDelay.inMilliseconds - 50));
      });

      test('should control memory pressure threshold', () async {
        // ARRANGE
        mockManager.setMemoryPressureThreshold(1); // Set very low threshold
        await mockManager.addVideoEvent(testVideo1);

        // ACT - Adding second video should trigger memory pressure
        await mockManager.addVideoEvent(testVideo2);

        // Give time for memory pressure handling
        await Future.delayed(const Duration(milliseconds: 10));

        // ASSERT
        final stats = mockManager.getStatistics();
        expect(stats['memoryPressureCallCount'], greaterThan(0));
      });

      test('should control exception throwing behavior', () async {
        // ARRANGE
        mockManager.setThrowOnInvalidOperations(false);
        await mockManager.addVideoEvent(testVideo1);
        mockManager.dispose();

        // ACT & ASSERT - Should not throw when configured not to
        expect(() => mockManager.addVideoEvent(testVideo2), returnsNormally);
        expect(() => mockManager.preloadVideo('non-existent'), returnsNormally);
      });
    });

    group('Test Statistics and Logging', () {
      test('should track operation statistics', () async {
        // ARRANGE & ACT
        await mockManager.addVideoEvent(testVideo1);
        await mockManager.preloadVideo(testVideo1.id);
        mockManager.disposeVideo(testVideo1.id);
        await mockManager.handleMemoryPressure();

        // ASSERT
        final stats = mockManager.getStatistics();
        expect(stats['preloadCallCount'], equals(1));
        expect(stats['disposeCallCount'], greaterThanOrEqualTo(1)); // At least once direct call
        expect(stats['memoryPressureCallCount'], greaterThanOrEqualTo(1)); // At least once
      });

      test('should log operations for verification', () async {
        // ARRANGE
        mockManager.clearOperationLog();

        // ACT
        await mockManager.addVideoEvent(testVideo1);
        await mockManager.preloadVideo(testVideo1.id);
        mockManager.disposeVideo(testVideo1.id);

        // ASSERT
        final log = mockManager.getOperationLog();
        expect(log, hasLength(3));
        expect(log[0], contains('addVideoEvent(${testVideo1.id})'));
        expect(log[1], contains('preloadVideo(${testVideo1.id})'));
        expect(log[2], contains('disposeVideo(${testVideo1.id})'));
      });

      test('should track preload attempts per video', () async {
        // ARRANGE
        mockManager.setPreloadBehavior(PreloadBehavior.failOnce);
        await mockManager.addVideoEvent(testVideo1);

        // ACT
        await mockManager.preloadVideo(testVideo1.id); // Attempt 1 - fails
        await mockManager.preloadVideo(testVideo1.id); // Attempt 2 - succeeds

        // ASSERT
        expect(mockManager.getPreloadAttempts(testVideo1.id), equals(2));
        expect(mockManager.getPreloadAttempts('non-existent'), equals(0));
      });

      test('should provide enhanced debug information', () {
        // ARRANGE & ACT
        final debugInfo = mockManager.getDebugInfo();

        // ASSERT
        expect(debugInfo, containsPair('totalVideos', 0));
        expect(debugInfo, containsPair('readyVideos', 0));
        expect(debugInfo, containsPair('preloadCallCount', 0));
        expect(debugInfo, containsPair('disposeCallCount', 0));
        expect(debugInfo, containsPair('memoryPressureCallCount', 0));
        expect(debugInfo, containsPair('preloadBehavior', PreloadBehavior.normal.toString()));
        expect(debugInfo, containsPair('preloadDelay', 50));
        expect(debugInfo, containsPair('memoryPressureThreshold', 10));
        expect(debugInfo, containsPair('operationLog', isA<List>()));
      });
    });

    group('Advanced Test Scenarios', () {
      test('should handle permanently failed videos', () async {
        // ARRANGE
        await mockManager.addVideoEvent(testVideo1);
        mockManager.markVideoPermanentlyFailed(testVideo1.id);

        // ACT
        await mockManager.preloadVideo(testVideo1.id);

        // ASSERT
        final state = mockManager.getVideoState(testVideo1.id);
        expect(state!.loadingState, equals(VideoLoadingState.notLoaded)); // Unchanged
        expect(mockManager.isVideoPermanentlyFailed(testVideo1.id), isTrue);
      });

      test('should simulate random failures', () async {
        // ARRANGE
        mockManager.setPreloadBehavior(PreloadBehavior.randomFail);
        final testVideos = <VideoEvent>[];
        
        for (int i = 0; i < 10; i++) {
          final video = TestHelpers.createVideoEvent(id: 'video-$i');
          testVideos.add(video);
          await mockManager.addVideoEvent(video);
        }

        // ACT - Preload all videos
        for (final video in testVideos) {
          await mockManager.preloadVideo(video.id);
        }

        // ASSERT - Some should succeed, some should fail
        final readyCount = mockManager.readyVideos.length;
        final failedCount = mockManager.getDebugInfo()['failedVideos'] as int;
        
        expect(readyCount + failedCount, equals(testVideos.length));
        expect(readyCount, greaterThan(0)); // At least some should succeed
        expect(failedCount, greaterThan(0)); // At least some should fail
      });

      test('should handle rapid state changes gracefully', () async {
        // ARRANGE
        await mockManager.addVideoEvent(testVideo1);
        mockManager.setPreloadDelay(const Duration(milliseconds: 100));

        // ACT - Start preload, then immediately dispose
        final preloadFuture = mockManager.preloadVideo(testVideo1.id);
        mockManager.disposeVideo(testVideo1.id);
        await preloadFuture;

        // ASSERT - Should handle gracefully without errors
        final state = mockManager.getVideoState(testVideo1.id);
        expect(state!.isDisposed, isTrue);
      });

      test('should reset test settings properly', () async {
        // ARRANGE - Change all settings
        mockManager.setPreloadBehavior(PreloadBehavior.alwaysFail);
        mockManager.setPreloadDelay(const Duration(seconds: 1));
        mockManager.setMemoryPressureThreshold(100);
        mockManager.setThrowOnInvalidOperations(false);
        mockManager.markVideoPermanentlyFailed('test');

        // ACT
        mockManager.resetTestSettings();

        // ASSERT
        final debugInfo = mockManager.getDebugInfo();
        expect(debugInfo['preloadBehavior'], equals(PreloadBehavior.normal.toString()));
        expect(debugInfo['preloadDelay'], equals(50));
        expect(debugInfo['memoryPressureThreshold'], equals(10));
        expect(mockManager.isVideoPermanentlyFailed('test'), isFalse);
      });
    });

    group('State Change Notifications', () {
      test('should emit state changes on operations', () async {
        // ARRANGE
        final stateChanges = <void>[];
        final subscription = mockManager.stateChanges.listen((change) {
          stateChanges.add(change);
        });

        // ACT
        await mockManager.addVideoEvent(testVideo1);
        await mockManager.preloadVideo(testVideo1.id);
        mockManager.disposeVideo(testVideo1.id);

        // Small delay to ensure stream events are processed
        await Future.delayed(const Duration(milliseconds: 10));

        // ASSERT
        expect(stateChanges.length, greaterThanOrEqualTo(3));

        // CLEANUP
        await subscription.cancel();
      });

      test('should close state change stream on disposal', () async {
        // ARRANGE
        bool streamClosed = false;
        final subscription = mockManager.stateChanges.listen(
          (change) {},
          onDone: () => streamClosed = true,
        );

        // ACT
        mockManager.dispose();
        await Future.delayed(const Duration(milliseconds: 10));

        // ASSERT
        expect(streamClosed, isTrue);

        // CLEANUP
        await subscription.cancel();
      });
    });

    group('Edge Cases and Error Conditions', () {
      test('should handle concurrent operations safely', () async {
        // ARRANGE
        await mockManager.addVideoEvent(testVideo1);
        mockManager.setPreloadDelay(const Duration(milliseconds: 50));

        // ACT - Start multiple concurrent operations
        final futures = <Future>[];
        for (int i = 0; i < 5; i++) {
          futures.add(mockManager.preloadVideo(testVideo1.id));
        }
        await Future.wait(futures);

        // ASSERT - Should complete without errors
        final state = mockManager.getVideoState(testVideo1.id);
        expect(state!.isReady, isTrue);
      });

      test('should handle disposal during operations', () async {
        // ARRANGE
        await mockManager.addVideoEvent(testVideo1);
        mockManager.setPreloadDelay(const Duration(milliseconds: 100));

        // ACT - Start preload then dispose
        final preloadFuture = mockManager.preloadVideo(testVideo1.id);
        mockManager.dispose();
        await preloadFuture;

        // ASSERT - Should handle gracefully without throwing exceptions
      });

      test('should handle operations on non-existent videos', () async {
        // ACT & ASSERT - Should handle gracefully
        expect(() => mockManager.getVideoState('non-existent'), returnsNormally);
        expect(() => mockManager.getController('non-existent'), returnsNormally);
        expect(() => mockManager.disposeVideo('non-existent'), returnsNormally);
        
        expect(mockManager.getVideoState('non-existent'), isNull);
        expect(mockManager.getController('non-existent'), isNull);
      });

      test('should maintain operation log size limits', () async {
        // ARRANGE & ACT - Perform many operations
        for (int i = 0; i < 150; i++) {
          await mockManager.addVideoEvent(TestHelpers.createVideoEvent(id: 'video-$i'));
        }

        // ASSERT - Log should be capped at reasonable size
        final log = mockManager.getOperationLog();
        expect(log.length, lessThanOrEqualTo(100));
      });
    });

    group('Mock Reliability and Consistency', () {
      test('should provide consistent behavior across multiple runs', () async {
        // Test the same operations multiple times to ensure consistency
        for (int run = 0; run < 3; run++) {
          // ARRANGE
          final runManager = MockVideoManager();
          final video = TestHelpers.createVideoEvent(id: 'consistent-test');

          // ACT
          await runManager.addVideoEvent(video);
          await runManager.preloadVideo(video.id);

          // ASSERT
          expect(runManager.videos, hasLength(1));
          expect(runManager.getVideoState(video.id)!.isReady, isTrue);
          expect(runManager.readyVideos, hasLength(1));

          // CLEANUP
          runManager.dispose();
        }
      });

      test('should be deterministic with same inputs', () async {
        // ARRANGE - Create two identical managers
        final manager1 = MockVideoManager();
        final manager2 = MockVideoManager();
        
        const videoCount = 5;
        
        // ACT - Perform identical operations on both
        for (int i = 0; i < videoCount; i++) {
          final video = TestHelpers.createVideoEvent(id: 'deterministic-$i');
          await manager1.addVideoEvent(video);
          await manager2.addVideoEvent(video);
          await manager1.preloadVideo(video.id);
          await manager2.preloadVideo(video.id);
        }

        // ASSERT - Results should be identical
        expect(manager1.videos.length, equals(manager2.videos.length));
        expect(manager1.readyVideos.length, equals(manager2.readyVideos.length));
        
        final stats1 = manager1.getStatistics();
        final stats2 = manager2.getStatistics();
        expect(stats1['preloadCallCount'], equals(stats2['preloadCallCount']));

        // CLEANUP
        manager1.dispose();
        manager2.dispose();
      });

      test('should isolate test runs properly', () async {
        // ARRANGE - Run a test that modifies mock state
        await mockManager.addVideoEvent(testVideo1);
        mockManager.setPreloadBehavior(PreloadBehavior.alwaysFail);
        await mockManager.preloadVideo(testVideo1.id);
        
        final firstRunState = mockManager.getVideoState(testVideo1.id);
        expect(firstRunState!.hasFailed, isTrue);

        // ACT - Reset and run again
        mockManager.dispose();
        mockManager = MockVideoManager(); // Fresh instance
        await mockManager.addVideoEvent(testVideo1);
        await mockManager.preloadVideo(testVideo1.id);

        // ASSERT - Should behave differently with default settings
        final secondRunState = mockManager.getVideoState(testVideo1.id);
        expect(secondRunState!.isReady, isTrue);
      });
    });
  });
}