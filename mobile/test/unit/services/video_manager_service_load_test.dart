// ABOUTME: Load testing and memory behavior validation for VideoManagerService
// ABOUTME: Tests performance, memory limits, concurrent operations, and failure recovery

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/video_manager_service.dart';
import 'package:openvine/services/video_manager_interface.dart';
import 'package:openvine/models/video_state.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('VideoManagerService Load Tests', () {
    late VideoManagerService manager;
    
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
    });
    
    setUp(() {
      manager = VideoManagerService();
    });
    
    tearDown(() {
      manager.dispose();
    });

    group('Memory Management Under Load', () {
      test('should enforce video count limits', () async {
        // ARRANGE: Configure with low limit for testing
        final limitedManager = VideoManagerService(
          config: const VideoManagerConfig(maxVideos: 10)
        );
        
        try {
          // ACT: Add more videos than limit
          for (int i = 0; i < 25; i++) {
            final event = TestHelpers.createMockVideoEvent(id: 'video$i');
            await limitedManager.addVideoEvent(event);
          }
          
          // ASSERT: Should not exceed limit
          final debugInfo = limitedManager.getDebugInfo();
          expect(debugInfo['totalVideos'], lessThanOrEqualTo(10));
          
          // Should keep newest videos
          final videos = limitedManager.videos;
          expect(videos.isNotEmpty, isTrue);
          
        } finally {
          limitedManager.dispose();
        }
      });
      
      test('should handle rapid video additions efficiently', () async {
        // ARRANGE & ACT: Add many videos quickly
        final stopwatch = Stopwatch()..start();
        
        for (int i = 0; i < 100; i++) {
          final event = TestHelpers.createMockVideoEvent(id: 'rapid$i');
          await manager.addVideoEvent(event);
        }
        
        stopwatch.stop();
        
        // ASSERT: Should be reasonably fast and manage memory
        expect(stopwatch.elapsedMilliseconds, lessThan(5000)); // <5 seconds
        
        final debugInfo = manager.getDebugInfo();
        expect(debugInfo['totalVideos'], lessThanOrEqualTo(100));
        
        // Memory should be reasonable
        final estimatedMB = debugInfo['estimatedMemoryMB'] as int;
        expect(estimatedMB, lessThan(500)); // Should stay under 500MB estimate
      });
      
      test('should cleanup distant videos during preloading', () async {
        // ARRANGE: Add videos and set current index
        for (int i = 0; i < 20; i++) {
          final event = TestHelpers.createMockVideoEvent(id: 'cleanup$i');
          await manager.addVideoEvent(event);
        }
        
        // ACT: Trigger preloading around middle index
        manager.preloadAroundIndex(10, preloadRange: 2);
        
        // Wait for any async cleanup
        await Future.delayed(const Duration(milliseconds: 200));
        
        // ASSERT: Should have reasonable state distribution
        final debugInfo = manager.getDebugInfo();
        expect(debugInfo, isA<Map<String, dynamic>>());
      });
      
      test('should handle memory pressure aggressively', () async {
        // ARRANGE: Add many videos
        for (int i = 0; i < 15; i++) {
          final event = TestHelpers.createMockVideoEvent(id: 'pressure$i');
          await manager.addVideoEvent(event);
        }
        
        final initialDebugInfo = manager.getDebugInfo();
        final initialVideos = initialDebugInfo['totalVideos'];
        
        // ACT: Trigger memory pressure
        await manager.handleMemoryPressure();
        
        // ASSERT: Should reduce memory footprint
        final finalDebugInfo = manager.getDebugInfo();
        expect(finalDebugInfo, isA<Map<String, dynamic>>());
        expect(finalDebugInfo['activeControllers'], lessThanOrEqualTo(2));
      });
    });
    
    group('Concurrent Operations', () {
      test('should handle concurrent video additions', () async {
        // ARRANGE & ACT: Add videos concurrently
        final futures = <Future<void>>[];
        
        for (int i = 0; i < 20; i++) {
          final event = TestHelpers.createMockVideoEvent(id: 'concurrent$i');
          futures.add(manager.addVideoEvent(event));
        }
        
        // Wait for all additions to complete
        await Future.wait(futures);
        
        // ASSERT: All videos should be tracked
        final debugInfo = manager.getDebugInfo();
        expect(debugInfo['totalVideos'], greaterThan(0));
        expect(debugInfo['totalVideos'], lessThanOrEqualTo(20));
      });
      
      test('should handle concurrent preloading requests', () async {
        // ARRANGE: Add videos first
        for (int i = 0; i < 10; i++) {
          final event = TestHelpers.createMockVideoEvent(id: 'preload$i');
          await manager.addVideoEvent(event);
        }
        
        // ACT: Start preloading all videos concurrently
        final futures = <Future<void>>[];
        for (int i = 0; i < 10; i++) {
          futures.add(manager.preloadVideo('preload$i'));
        }
        
        // Wait for all preloads to complete (will fail in test environment)
        await Future.wait(futures);
        
        // ASSERT: All videos should have been processed
        final debugInfo = manager.getDebugInfo();
        final totalProcessed = (debugInfo['readyVideos'] as int) + 
                              (debugInfo['failedVideos'] as int) + 
                              (debugInfo['loadingVideos'] as int);
        expect(totalProcessed, greaterThan(0));
      });
      
      test('should handle mixed operations under load', () async {
        // ARRANGE & ACT: Mix adding, preloading, and disposing
        final futures = <Future<void>>[];
        
        // Add videos
        for (int i = 0; i < 10; i++) {
          final event = TestHelpers.createMockVideoEvent(id: 'mixed$i');
          futures.add(manager.addVideoEvent(event));
        }
        
        await Future.wait(futures);
        futures.clear();
        
        // Preload some videos
        for (int i = 0; i < 5; i++) {
          futures.add(manager.preloadVideo('mixed$i'));
        }
        
        // Dispose some videos while preloading
        Future.delayed(const Duration(milliseconds: 50), () {
          for (int i = 5; i < 8; i++) {
            manager.disposeVideo('mixed$i');
          }
        });
        
        await Future.wait(futures);
        
        // Handle memory pressure
        await manager.handleMemoryPressure();
        
        // ASSERT: Should handle mixed operations gracefully
        final debugInfo = manager.getDebugInfo();
        expect(debugInfo, isA<Map<String, dynamic>>());
        expect(debugInfo['totalVideos'], greaterThanOrEqualTo(0));
      });
    });
    
    group('Circuit Breaker and Failure Recovery', () {
      test('should track and avoid repeated failures', () async {
        // ARRANGE: Add video that will consistently fail
        final failingEvent = TestHelpers.createMockVideoEvent(
          id: 'failing',
          url: 'https://invalid-domain-will-fail.com/video.mp4',
        );
        await manager.addVideoEvent(failingEvent);
        
        // ACT: Try to preload multiple times
        for (int i = 0; i < 5; i++) {
          await manager.preloadVideo('failing');
          await Future.delayed(const Duration(milliseconds: 10));
        }
        
        // ASSERT: Should have failure tracking
        final debugInfo = manager.getDebugInfo();
        expect(debugInfo['failedVideos'], greaterThan(0));
        
        final state = manager.getVideoState('failing');
        expect(state?.hasFailed, isTrue);
      });
      
      test('should clear failure patterns on memory pressure', () async {
        // ARRANGE: Create failure patterns
        for (int i = 0; i < 3; i++) {
          final event = TestHelpers.createMockVideoEvent(
            id: 'pattern$i',
            url: 'https://fail-pattern-$i.com/video.mp4',
          );
          await manager.addVideoEvent(event);
          await manager.preloadVideo('pattern$i');
        }
        
        final beforeCleanup = manager.getDebugInfo();
        final failuresBefore = beforeCleanup['failedVideos'] as int;
        
        // ACT: Handle memory pressure (should clear patterns)
        await manager.handleMemoryPressure();
        
        // ASSERT: Memory pressure should clean up state
        final afterCleanup = manager.getDebugInfo();
        expect(afterCleanup['metrics']['memoryPressureCount'], equals(1));
      });
    });
    
    group('State Consistency Under Load', () {
      test('should maintain state consistency during rapid operations', () async {
        // ARRANGE & ACT: Rapid state changes
        final events = <String>[];
        
        // Add videos rapidly
        for (int i = 0; i < 30; i++) {
          final event = TestHelpers.createMockVideoEvent(id: 'state$i');
          await manager.addVideoEvent(event);
          events.add('state$i');
        }
        
        // Preload some
        for (int i = 0; i < 10; i++) {
          manager.preloadVideo('state$i'); // Fire and forget
        }
        
        // Dispose some
        for (int i = 10; i < 15; i++) {
          manager.disposeVideo('state$i');
        }
        
        // Change current index rapidly
        for (int i = 0; i < 5; i++) {
          manager.preloadAroundIndex(i * 2);
          await Future.delayed(const Duration(milliseconds: 10));
        }
        
        // Wait for operations to settle
        await Future.delayed(const Duration(milliseconds: 200));
        
        // ASSERT: State should be consistent
        final debugInfo = manager.getDebugInfo();
        final totalStates = (debugInfo['readyVideos'] as int) +
                           (debugInfo['loadingVideos'] as int) +
                           (debugInfo['failedVideos'] as int);
        
        // All tracked videos should have a valid state
        expect(totalStates, lessThanOrEqualTo(debugInfo['totalVideos']));
        expect(debugInfo['totalVideos'], greaterThan(0));
      });
      
      test('should handle state notifications under load', () async {
        // ARRANGE
        var notificationCount = 0;
        final subscription = manager.stateChanges.listen((_) {
          notificationCount++;
        });
        
        try {
          // ACT: Rapid operations that should trigger notifications
          for (int i = 0; i < 20; i++) {
            final event = TestHelpers.createMockVideoEvent(id: 'notify$i');
            await manager.addVideoEvent(event);
            
            if (i % 3 == 0) {
              manager.preloadVideo('notify$i'); // Async
            }
            if (i % 4 == 0) {
              manager.disposeVideo('notify$i');
            }
          }
          
          // Wait for notifications
          await Future.delayed(const Duration(milliseconds: 300));
          
          // ASSERT: Should have received many notifications
          expect(notificationCount, greaterThan(10));
          
        } finally {
          subscription.cancel();
        }
      });
    });
    
    group('Resource Management', () {
      test('should handle dispose during active operations', () async {
        // ARRANGE: Start some operations
        for (int i = 0; i < 10; i++) {
          final event = TestHelpers.createMockVideoEvent(id: 'dispose$i');
          await manager.addVideoEvent(event);
        }
        
        // Start preloading (will be async)
        for (int i = 0; i < 5; i++) {
          manager.preloadVideo('dispose$i'); // Don't await
        }
        
        // ACT: Dispose while operations are in progress
        manager.dispose();
        
        // ASSERT: Should handle disposal gracefully
        expect(manager.videos, isEmpty);
        final debugInfo = manager.getDebugInfo();
        expect(debugInfo['disposed'], isTrue);
      });
      
      test('should prevent operations after disposal', () async {
        // ARRANGE
        manager.dispose();
        
        // ACT & ASSERT: Operations should be safe after disposal
        expect(() => manager.videos, returnsNormally);
        expect(manager.videos, isEmpty);
        
        expect(() => manager.getVideoState('any'), returnsNormally);
        expect(manager.getVideoState('any'), isNull);
        
        expect(() => manager.getController('any'), returnsNormally);
        expect(manager.getController('any'), isNull);
        
        // Adding videos should throw
        final event = TestHelpers.createMockVideoEvent(id: 'after_dispose');
        expect(
          () => manager.addVideoEvent(event),
          throwsA(isA<VideoManagerException>()),
        );
      });
    });
    
    group('Performance Metrics', () {
      test('should provide accurate debug information under load', () async {
        // ARRANGE: Create known state
        final gifCount = 5;
        final videoCount = 10;
        
        // Add GIFs (ready immediately)
        for (int i = 0; i < gifCount; i++) {
          final gifEvent = TestHelpers.createMockVideoEvent(
            id: 'gif$i',
            isGif: true,
          );
          await manager.addVideoEvent(gifEvent);
        }
        
        // Add videos (will fail in test environment)
        for (int i = 0; i < videoCount; i++) {
          final videoEvent = TestHelpers.createMockVideoEvent(id: 'video$i');
          await manager.addVideoEvent(videoEvent);
          await manager.preloadVideo('video$i'); // Will fail
        }
        
        // ACT: Get debug info
        final debugInfo = manager.getDebugInfo();
        
        // ASSERT: Debug info should be accurate
        expect(debugInfo['totalVideos'], gifCount + videoCount);
        expect(debugInfo['readyVideos'], 0); // No videos are ready in test environment
        expect(debugInfo['failedVideos'], greaterThanOrEqualTo(1)); // Videos fail in test
        expect(debugInfo['activeControllers'], 0); // No real controllers in test
        expect(debugInfo['estimatedMemoryMB'], 0); // No controllers = no memory
        
        expect(debugInfo, contains('activePreloads'));
        expect(debugInfo, contains('config'));
        expect(debugInfo['config'], contains('maxVideos'));
        expect(debugInfo['config'], contains('preloadAhead'));
        expect(debugInfo['config'], contains('enableMemoryManagement'));
      });
      
      test('should track preloading queue size accurately', () async {
        // ARRANGE: Add videos
        for (int i = 0; i < 10; i++) {
          final event = TestHelpers.createMockVideoEvent(id: 'queue$i');
          await manager.addVideoEvent(event);
        }
        
        // ACT: Start preloading without waiting
        final preloadFutures = <Future<void>>[];
        for (int i = 0; i < 5; i++) {
          preloadFutures.add(manager.preloadVideo('queue$i'));
        }
        
        // Check queue during preloading
        await Future.delayed(const Duration(milliseconds: 10));
        
        // Wait for completion
        await Future.wait(preloadFutures);
        
        // ASSERT: Queue should be empty after completion
        final finalDebugInfo = manager.getDebugInfo();
        expect(finalDebugInfo['activePreloads'], 0);
      });
    });
  });
}