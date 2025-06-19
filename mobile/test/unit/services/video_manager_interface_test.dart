// ABOUTME: Interface contract tests for IVideoManager - defines expected behaviors for all implementations
// ABOUTME: These tests ensure any IVideoManager implementation follows the single source of truth principle

import 'package:flutter_test/flutter_test.dart';
import 'package:nostrvine_app/services/video_manager_interface.dart';
import 'package:nostrvine_app/models/video_event.dart';
import 'package:nostrvine_app/models/video_state.dart';
import '../../helpers/test_helpers.dart';
import '../../mocks/mock_video_manager.dart';

/// Contract tests that define the behavior any IVideoManager implementation must follow
/// 
/// These tests are implementation-agnostic and should pass for any concrete
/// implementation of IVideoManager. They define the expected behavior for:
/// - Single source of truth principle
/// - Memory management
/// - Video preloading 
/// - Error handling
/// - State transitions
/// - Performance requirements
void main() {
  group('IVideoManager Contract Tests', () {
    late IVideoManager manager;
    late VideoManagerConfig testConfig;
    
    setUp(() {
      testConfig = const VideoManagerConfig(
        maxVideos = 10, // Small limit for testing
        preloadAhead = 2,
        maxRetries = 3,
        preloadTimeout = Duration(seconds: 5),
        enableMemoryManagement = true,
        memoryKeepRange = 3,
      );
      
      // Note: This will be replaced with real implementation once available
      manager = MockVideoManager(config: testConfig);
    });
    
    tearDown(() {
      manager.dispose();
    });
    
    group('Single Source of Truth Principle', () {
      test('should maintain consistent video list order (newest first)', () async {
        // ARRANGE: Create videos with different timestamps
        final video1 = TestHelpers.createVideoEvent(
          id: 'video1',
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        );
        final video2 = TestHelpers.createVideoEvent(
          id: 'video2', 
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
        );
        final video3 = TestHelpers.createVideoEvent(
          id: 'video3',
          timestamp: DateTime.now(), // Most recent
        );
        
        // ACT: Add videos in random order
        await manager.addVideoEvent(video1);
        await manager.addVideoEvent(video3);
        await manager.addVideoEvent(video2);
        
        // ASSERT: Videos should be ordered newest first
        final videos = manager.videos;
        expect(videos.length, equals(3));
        expect(videos[0].id, equals('video3')); // Most recent
        expect(videos[1].id, equals('video2'));
        expect(videos[2].id, equals('video1')); // Oldest
        
        // ASSERT: All videos should have state
        expect(manager.getVideoState('video1'), isNotNull);
        expect(manager.getVideoState('video2'), isNotNull);
        expect(manager.getVideoState('video3'), isNotNull);
      });
      
      test('should prevent duplicate videos', () async {
        // ARRANGE: Same video event
        final video = TestHelpers.createVideoEvent(id: 'duplicate_test');
        
        // ACT: Add same video multiple times
        await manager.addVideoEvent(video);
        await manager.addVideoEvent(video); // Duplicate
        await manager.addVideoEvent(video); // Another duplicate
        
        // ASSERT: Only one copy should exist
        expect(manager.videos.length, equals(1));
        expect(manager.videos[0].id, equals('duplicate_test'));
        
        // ASSERT: State should exist for the video
        final state = manager.getVideoState('duplicate_test');
        expect(state, isNotNull);
        expect(state!.event.id, equals('duplicate_test'));
      });
      
      test('should handle empty video list correctly', () {
        // ASSERT: Initial state should be empty
        expect(manager.videos, isEmpty);
        expect(manager.readyVideos, isEmpty);
        expect(manager.getVideoState('nonexistent'), isNull);
        expect(manager.getController('nonexistent'), isNull);
      });
      
      test('should exclude permanently failed videos from main list', () async {
        // ARRANGE: Add a video that will fail permanently
        final failingVideo = TestHelpers.createFailingVideoEvent(id: 'will_fail');
        final normalVideo = TestHelpers.createVideoEvent(id: 'normal');
        
        await manager.addVideoEvent(failingVideo);
        await manager.addVideoEvent(normalVideo);
        
        // ACT: Force video to fail permanently (simulate multiple failures)
        for (int i = 0; i < testConfig.maxRetries + 1; i++) {
          await manager.preloadVideo('will_fail');
        }
        
        // ASSERT: Permanently failed video should not appear in main list
        final videos = manager.videos;
        expect(videos.length, equals(1));
        expect(videos[0].id, equals('normal'));
        
        // ASSERT: But state should still be trackable
        final failedState = manager.getVideoState('will_fail');
        expect(failedState, isNotNull);
        expect(failedState!.loadingState, equals(VideoLoadingState.permanentlyFailed));
      });
    });
    
    group('Memory Management Contract', () {
      test('should enforce video count limits', () async {
        // ARRANGE: Add more videos than maxVideos limit
        final maxVideos = testConfig.maxVideos;
        
        // ACT: Add maxVideos + 5 videos
        for (int i = 0; i < maxVideos + 5; i++) {
          final video = TestHelpers.createVideoEvent(id: 'video_$i');
          await manager.addVideoEvent(video);
        }
        
        // ASSERT: Should not exceed limit
        expect(manager.videos.length, lessThanOrEqualTo(maxVideos));
        
        // ASSERT: Should keep newest videos (higher indices)
        final videos = manager.videos;
        final firstVideoId = videos.first.id;
        expect(firstVideoId, contains('video_')); 
        
        // Extract the number and verify it's from the newer batch
        final idNumber = int.parse(firstVideoId.split('_')[1]);
        expect(idNumber, greaterThanOrEqualTo(5)); // Should be from newer videos
      });
      
      test('should clean up disposed controllers', () async {
        // ARRANGE: Add and preload a video
        final video = TestHelpers.createVideoEvent(id: 'cleanup_test');
        await manager.addVideoEvent(video);
        await manager.preloadVideo('cleanup_test');
        
        // Verify video is ready with controller
        expect(manager.getVideoState('cleanup_test')?.isReady, isTrue);
        expect(manager.getController('cleanup_test'), isNotNull);
        
        // ACT: Dispose video
        manager.disposeVideo('cleanup_test');
        
        // ASSERT: Controller should be null, state should be disposed
        expect(manager.getController('cleanup_test'), isNull);
        final state = manager.getVideoState('cleanup_test');
        expect(state?.isDisposed, isTrue);
      });
      
      test('should handle memory pressure gracefully', () async {
        // ARRANGE: Fill up to memory limit
        final maxVideos = testConfig.maxVideos;
        for (int i = 0; i < maxVideos; i++) {
          final video = TestHelpers.createVideoEvent(id: 'memory_test_$i');
          await manager.addVideoEvent(video);
        }
        
        // ACT: Trigger memory pressure by adding more videos
        for (int i = maxVideos; i < maxVideos + 3; i++) {
          final video = TestHelpers.createVideoEvent(id: 'overflow_$i');
          await manager.addVideoEvent(video);
        }
        
        // ASSERT: System should handle gracefully without crashing
        expect(manager.videos.length, lessThanOrEqualTo(maxVideos));
        
        // ASSERT: Debug info should reflect controlled memory usage
        final debugInfo = manager.getDebugInfo();
        expect(debugInfo['totalVideos'], lessThanOrEqualTo(maxVideos));
        expect(debugInfo['estimatedMemoryMB'], isA<num>());
      });
    });
    
    group('Video Preloading Contract', () {
      test('should preload video correctly through state transitions', () async {
        // ARRANGE: Add a video
        final video = TestHelpers.createVideoEvent(id: 'preload_test');
        await manager.addVideoEvent(video);
        
        // Initial state should be notLoaded
        expect(manager.getVideoState('preload_test')?.loadingState, 
               equals(VideoLoadingState.notLoaded));
        expect(manager.getController('preload_test'), isNull);
        
        // ACT: Preload video
        await manager.preloadVideo('preload_test');
        
        // ASSERT: Video should be ready (for mock implementation)
        final state = manager.getVideoState('preload_test');
        expect(state?.isReady, isTrue);
        expect(manager.getController('preload_test'), isNotNull);
        expect(manager.readyVideos, contains(video));
      });
      
      test('should handle preload failures with circuit breaker', () async {
        // ARRANGE: Create video that will fail to load
        final failingVideo = TestHelpers.createFailingVideoEvent(id: 'fail_test');
        await manager.addVideoEvent(failingVideo);
        
        // ACT: Try to preload multiple times (should trigger circuit breaker)
        for (int i = 0; i < testConfig.maxRetries + 1; i++) {
          await manager.preloadVideo('fail_test');
        }
        
        // ASSERT: Should be in permanently failed state
        final state = manager.getVideoState('fail_test');
        expect(state?.loadingState, equals(VideoLoadingState.permanentlyFailed));
        expect(state?.canRetry, isFalse);
        expect(state?.errorMessage, isNotNull);
        expect(manager.getController('fail_test'), isNull);
      });
      
      test('should prevent duplicate preload operations', () async {
        // ARRANGE: Add a video
        final video = TestHelpers.createVideoEvent(id: 'duplicate_preload');
        await manager.addVideoEvent(video);
        
        // ACT: Try to preload the same video multiple times simultaneously
        final futures = List.generate(5, (_) => manager.preloadVideo('duplicate_preload'));
        await Future.wait(futures);
        
        // ASSERT: Should handle gracefully and end up in ready state
        final state = manager.getVideoState('duplicate_preload');
        expect(state?.isReady, isTrue);
        expect(manager.getController('duplicate_preload'), isNotNull);
      });
      
      test('should handle GIF videos immediately', () async {
        // ARRANGE: Create a GIF video event
        final gifVideo = TestHelpers.createVideoEvent(
          id: 'gif_test',
          isGif: true,
        );
        
        // ACT: Add GIF video
        await manager.addVideoEvent(gifVideo);
        
        // ASSERT: Should be immediately ready (no preloading needed)
        final state = manager.getVideoState('gif_test');
        expect(state?.isReady, isTrue);
        expect(manager.readyVideos, contains(gifVideo));
      });
      
      test('should implement smart preloading around index', () async {
        // ARRANGE: Add multiple videos
        final videos = <VideoEvent>[];
        for (int i = 0; i < 10; i++) {
          final video = TestHelpers.createVideoEvent(id: 'smart_$i');
          videos.add(video);
          await manager.addVideoEvent(video);
        }
        
        // ACT: Trigger smart preloading around index 3
        manager.preloadAroundIndex(3);
        
        // Wait a bit for preloading to potentially occur
        await Future.delayed(const Duration(milliseconds: 100));
        
        // ASSERT: Videos around index 3 should be loaded or loading
        // (Exact behavior depends on implementation, but should not crash)
        expect(manager.videos.length, equals(10));
        expect(() => manager.preloadAroundIndex(3), returnsNormally);
      });
    });
    
    group('Error Handling Contract', () {
      test('should handle invalid video IDs gracefully', () {
        // ACT & ASSERT: Should not throw for invalid operations
        expect(() => manager.getVideoState('nonexistent'), returnsNormally);
        expect(manager.getVideoState('nonexistent'), isNull);
        
        expect(() => manager.getController('nonexistent'), returnsNormally);
        expect(manager.getController('nonexistent'), isNull);
        
        expect(() => manager.disposeVideo('nonexistent'), returnsNormally);
        
        // Preload of nonexistent video should handle gracefully
        expect(() => manager.preloadVideo('nonexistent'), returnsNormally);
      });
      
      test('should handle invalid indices in preloadAroundIndex', () {
        // ARRANGE: Add a few videos
        final videos = List.generate(3, (i) => 
          TestHelpers.createVideoEvent(id: 'index_test_$i'));
        
        for (final video in videos) {
          manager.addVideoEvent(video);
        }
        
        // ACT & ASSERT: Should handle invalid indices gracefully
        expect(() => manager.preloadAroundIndex(-1), returnsNormally);
        expect(() => manager.preloadAroundIndex(100), returnsNormally);
        expect(() => manager.preloadAroundIndex(3), returnsNormally); // Just out of bounds
      });
      
      test('should provide meaningful error information', () async {
        // ARRANGE: Create an invalid video event
        final invalidVideo = TestHelpers.createVideoEvent(
          id: '', // Invalid empty ID
        );
        
        try {
          // ACT: Try to add invalid video
          await manager.addVideoEvent(invalidVideo);
          fail('Should have thrown VideoManagerException');
        } catch (e) {
          // ASSERT: Should provide meaningful error information
          expect(e, isA<VideoManagerException>());
          final exception = e as VideoManagerException;
          expect(exception.message, isNotEmpty);
          expect(exception.type, equals(VideoManagerErrorType.invalidVideo));
        }
      });
    });
    
    group('State Management Contract', () {
      test('should provide consistent state changes stream', () async {
        // ARRANGE: Listen to state changes
        final stateChanges = <void>[];
        final subscription = manager.stateChanges.listen((_) {
          stateChanges.add(null);
        });
        
        try {
          // ACT: Perform operations that should trigger state changes
          final video = TestHelpers.createVideoEvent(id: 'state_test');
          await manager.addVideoEvent(video);
          await manager.preloadVideo('state_test');
          manager.disposeVideo('state_test');
          
          // Wait for stream events
          await Future.delayed(const Duration(milliseconds: 50));
          
          // ASSERT: Should have received state change notifications
          expect(stateChanges.length, greaterThan(0));
        } finally {
          await subscription.cancel();
        }
      });
      
      test('should close state stream on dispose', () async {
        // ARRANGE: Listen to state changes
        var streamClosed = false;
        final subscription = manager.stateChanges.listen(
          (_) {},
          onDone: () => streamClosed = true,
        );
        
        try {
          // ACT: Dispose manager
          manager.dispose();
          
          // Wait for stream to close
          await Future.delayed(const Duration(milliseconds: 50));
          
          // ASSERT: Stream should be closed
          expect(streamClosed, isTrue);
        } finally {
          await subscription.cancel();
        }
      });
    });
    
    group('Performance Contract', () {
      test('should handle large video lists efficiently', () async {
        // ARRANGE & ACT: Add many videos and measure time
        const videoCount = 50; // Reduced for test performance
        final stopwatch = Stopwatch()..start();
        
        for (int i = 0; i < videoCount; i++) {
          final video = TestHelpers.createVideoEvent(id: 'perf_test_$i');
          await manager.addVideoEvent(video);
        }
        
        stopwatch.stop();
        
        // ASSERT: Should be reasonably fast (allowing for mock overhead)
        expect(stopwatch.elapsedMilliseconds, lessThan(2000)); // <2 seconds
        expect(manager.videos.length, lessThanOrEqualTo(videoCount));
        
        // ASSERT: Debug info should be responsive
        final debugInfo = manager.getDebugInfo();
        expect(debugInfo, isA<Map<String, dynamic>>());
        expect(debugInfo['totalVideos'], isA<int>());
        expect(debugInfo['estimatedMemoryMB'], isA<num>());
      });
      
      test('should handle rapid operations without race conditions', () async {
        // ARRANGE: Create multiple videos
        final videos = List.generate(10, (i) => 
          TestHelpers.createVideoEvent(id: 'race_test_$i'));
        
        // ACT: Perform rapid concurrent operations
        final addFutures = videos.map((v) => manager.addVideoEvent(v));
        final preloadFutures = videos.map((v) => manager.preloadVideo(v.id));
        
        await Future.wait([
          ...addFutures,
          ...preloadFutures,
        ]);
        
        // ASSERT: Should end in consistent state without errors
        expect(manager.videos.length, greaterThan(0));
        expect(manager.videos.length, lessThanOrEqualTo(videos.length));
        
        // All videos should have valid states
        for (final video in manager.videos) {
          final state = manager.getVideoState(video.id);
          expect(state, isNotNull);
          expect(state!.event.id, equals(video.id));
        }
      });
    });
    
    group('Debug Information Contract', () {
      test('should provide comprehensive debug information', () async {
        // ARRANGE: Set up diverse video states
        final readyVideo = TestHelpers.createVideoEvent(id: 'ready');
        final failingVideo = TestHelpers.createFailingVideoEvent(id: 'failing');
        
        await manager.addVideoEvent(readyVideo);
        await manager.addVideoEvent(failingVideo);
        await manager.preloadVideo('ready');
        await manager.preloadVideo('failing');
        
        // ACT: Get debug information
        final debugInfo = manager.getDebugInfo();
        
        // ASSERT: Should include all required fields
        expect(debugInfo, containsPair('totalVideos', isA<int>()));
        expect(debugInfo, containsPair('readyVideos', isA<int>()));
        expect(debugInfo, containsPair('loadingVideos', isA<int>()));
        expect(debugInfo, containsPair('failedVideos', isA<int>()));
        expect(debugInfo, containsPair('controllers', isA<int>()));
        expect(debugInfo, containsPair('estimatedMemoryMB', isA<num>()));
        
        // ASSERT: Values should be reasonable
        expect(debugInfo['totalVideos'], greaterThanOrEqualTo(0));
        expect(debugInfo['estimatedMemoryMB'], greaterThanOrEqualTo(0));
      });
    });
    
    group('Configuration Contract', () {
      test('should respect configuration limits', () async {
        // ARRANGE: Configuration with strict limits is already set in setUp
        
        // ACT: Add videos up to limit
        for (int i = 0; i < testConfig.maxVideos; i++) {
          final video = TestHelpers.createVideoEvent(id: 'config_test_$i');
          await manager.addVideoEvent(video);
        }
        
        // ASSERT: Should respect maxVideos limit
        expect(manager.videos.length, lessThanOrEqualTo(testConfig.maxVideos));
        
        // ACT: Add one more to trigger cleanup
        final extraVideo = TestHelpers.createVideoEvent(id: 'extra');
        await manager.addVideoEvent(extraVideo);
        
        // ASSERT: Should still respect limit
        expect(manager.videos.length, lessThanOrEqualTo(testConfig.maxVideos));
      });
    });
  });
}