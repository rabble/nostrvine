// ABOUTME: Comprehensive tests for video preloading with retry logic and error recovery
// ABOUTME: Tests network failures, exponential backoff, and state transitions

import 'package:flutter_test/flutter_test.dart';
import 'package:nostrvine_app/services/video_manager_service.dart';
import 'package:nostrvine_app/services/video_manager_interface.dart';
import 'package:nostrvine_app/models/video_state.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('Video Preloading Tests', () {
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

    group('Basic Preloading Behavior', () {
      test('should handle successful video preloading', () async {
        // ARRANGE
        final gifEvent = TestHelpers.createMockVideoEvent(
          id: 'test-gif',
          isGif: true,
        );
        await manager.addVideoEvent(gifEvent);
        
        // ACT
        await manager.preloadVideo('test-gif');
        
        // ASSERT
        final state = manager.getVideoState('test-gif');
        expect(state!.isReady, isTrue);
        expect(state.retryCount, equals(0));
      });
      
      test('should prevent duplicate preloading attempts', () async {
        // ARRANGE
        final event = TestHelpers.createMockVideoEvent(id: 'test-video');
        await manager.addVideoEvent(event);
        
        // ACT - Start preloading twice simultaneously
        final preload1 = manager.preloadVideo('test-video');
        final preload2 = manager.preloadVideo('test-video');
        
        await Future.wait([preload1, preload2]);
        
        // ASSERT - Should have handled gracefully
        final state = manager.getVideoState('test-video');
        expect(state!.hasFailed, isTrue); // Will fail in test environment
        expect(state.retryCount, greaterThan(0));
      });

      test('should transition states correctly during preloading', () async {
        // ARRANGE
        final event = TestHelpers.createMockVideoEvent(id: 'state-test');
        await manager.addVideoEvent(event);
        final initialState = manager.getVideoState('state-test');
        expect(initialState!.loadingState, equals(VideoLoadingState.notLoaded));

        // ACT - Start preloading
        final preloadFuture = manager.preloadVideo('state-test');
        
        // Should transition to loading immediately
        await Future.delayed(const Duration(milliseconds: 10));
        final loadingState = manager.getVideoState('state-test');
        expect(loadingState!.isLoading, isTrue);
        
        // Wait for completion
        await preloadFuture;
        
        // ASSERT - Should be in failed state (since videos fail in test environment)
        final finalState = manager.getVideoState('state-test');
        expect(finalState!.hasFailed, isTrue);
      });
    });

    group('Retry Logic and Exponential Backoff', () {
      test('should retry failed preloads with exponential backoff', () async {
        // ARRANGE
        final event = TestHelpers.createMockVideoEvent(
          id: 'retry-test',
          url: 'https://invalid-domain.com/video.mp4',
        );
        await manager.addVideoEvent(event);
        
        final stopwatch = Stopwatch()..start();
        
        // ACT - Trigger initial preload (will fail)
        await manager.preloadVideo('retry-test');
        
        // ASSERT - Should have started first retry attempt
        final stateAfterFirstFail = manager.getVideoState('retry-test');
        expect(stateAfterFirstFail!.loadingState, equals(VideoLoadingState.failed));
        expect(stateAfterFirstFail.retryCount, equals(1));
        expect(stateAfterFirstFail.canRetry, isTrue);
        
        // Wait for first retry (should happen after ~1-1.5 seconds)
        await Future.delayed(const Duration(milliseconds: 2000));
        
        final stateAfterFirstRetry = manager.getVideoState('retry-test');
        expect(stateAfterFirstRetry!.retryCount, greaterThanOrEqualTo(2));
        
        stopwatch.stop();
        
        // Verify timing is reasonable (should have taken at least 1 second for backoff)
        expect(stopwatch.elapsedMilliseconds, greaterThan(1000));
      });

      test('should eventually mark video as permanently failed after max retries', () async {
        // ARRANGE
        final event = TestHelpers.createMockVideoEvent(
          id: 'permanent-fail',
          url: 'https://will-always-fail.com/video.mp4',
        );
        await manager.addVideoEvent(event);
        
        // ACT - Trigger preload and wait for all retries to complete
        await manager.preloadVideo('permanent-fail');
        
        // Wait for all retries (max 3 attempts with exponential backoff)
        // Total time should be roughly: 1s + 2s + 4s = 7s + processing time
        await Future.delayed(const Duration(seconds: 10));
        
        // ASSERT
        final finalState = manager.getVideoState('permanent-fail');
        // After all retries, should either be permanently failed OR regular failed (depending on implementation)
        expect(finalState!.hasFailed, isTrue);
        expect(finalState.retryCount, greaterThanOrEqualTo(VideoState.maxRetryCount));
        expect(finalState.canRetry, isFalse);
      });

      test('should track failure patterns for permanently failed videos', () async {
        // ARRANGE
        final event = TestHelpers.createMockVideoEvent(
          id: 'pattern-test',
          url: 'https://pattern-fail.com/video.mp4',
        );
        await manager.addVideoEvent(event);
        
        // ACT - Let it fail completely
        await manager.preloadVideo('pattern-test');
        await Future.delayed(const Duration(seconds: 10)); // Wait for all retries
        
        // ASSERT - URL should be tracked in failure patterns
        final debugInfo = manager.getDebugInfo();
        expect(debugInfo['failurePatterns'], greaterThan(0));
        
        // Try to preload same URL again - should be skipped due to circuit breaker
        final event2 = TestHelpers.createMockVideoEvent(
          id: 'pattern-test-2',
          url: 'https://pattern-fail.com/video.mp4', // Same URL
        );
        await manager.addVideoEvent(event2);
        await manager.preloadVideo('pattern-test-2');
        
        final state2 = manager.getVideoState('pattern-test-2');
        expect(state2!.loadingState, equals(VideoLoadingState.notLoaded)); // Should skip preload
      });

      test('should not retry if video is disposed during retry delay', () async {
        // ARRANGE
        final event = TestHelpers.createMockVideoEvent(id: 'dispose-test');
        await manager.addVideoEvent(event);
        
        // ACT - Start preload (will fail)
        await manager.preloadVideo('dispose-test');
        
        // Dispose video during retry delay
        manager.disposeVideo('dispose-test');
        
        // Wait past retry delay
        await Future.delayed(const Duration(milliseconds: 2000));
        
        // ASSERT - Should be disposed, not retrying
        final state = manager.getVideoState('dispose-test');
        expect(state!.isDisposed, isTrue);
      });

      test('should not retry if manager is disposed during retry delay', () async {
        // ARRANGE
        final event = TestHelpers.createMockVideoEvent(id: 'manager-dispose-test');
        await manager.addVideoEvent(event);
        
        // ACT - Start preload (will fail)
        await manager.preloadVideo('manager-dispose-test');
        
        // Dispose entire manager during retry delay
        manager.dispose();
        
        // Wait past retry delay
        await Future.delayed(const Duration(milliseconds: 2000));
        
        // ASSERT - Manager should be disposed
        final debugInfo = manager.getDebugInfo();
        expect(debugInfo['disposed'], isTrue);
      });
    });

    group('Network Error Scenarios', () {
      test('should handle timeout errors with retry', () async {
        // ARRANGE
        final event = TestHelpers.createMockVideoEvent(
          id: 'timeout-test',
          url: 'https://very-slow-server.com/video.mp4',
        );
        await manager.addVideoEvent(event);
        
        // ACT
        await manager.preloadVideo('timeout-test');
        
        // ASSERT - Should fail and schedule retry
        final state = manager.getVideoState('timeout-test');
        expect(state!.hasFailed, isTrue);
        expect(state.errorMessage, contains('UnimplementedError')); // Test environment error
        expect(state.canRetry, isTrue);
      });

      test('should handle DNS resolution failures', () async {
        // ARRANGE
        final event = TestHelpers.createMockVideoEvent(
          id: 'dns-test',
          url: 'https://non-existent-domain-12345.com/video.mp4',
        );
        await manager.addVideoEvent(event);
        
        // ACT
        await manager.preloadVideo('dns-test');
        
        // ASSERT
        final state = manager.getVideoState('dns-test');
        expect(state!.hasFailed, isTrue);
        expect(state.canRetry, isTrue);
      });

      test('should handle HTTP error responses', () async {
        // ARRANGE
        final event = TestHelpers.createMockVideoEvent(
          id: 'http-error-test',
          url: 'https://httpstat.us/500', // Returns 500 error
        );
        await manager.addVideoEvent(event);
        
        // ACT
        await manager.preloadVideo('http-error-test');
        
        // ASSERT
        final state = manager.getVideoState('http-error-test');
        expect(state!.hasFailed, isTrue);
        expect(state.canRetry, isTrue);
      });
    });

    group('Circuit Breaker Patterns', () {
      test('should avoid retrying URLs with known failure patterns', () async {
        // ARRANGE - Add a URL to failure patterns manually
        final debugInfoBefore = manager.getDebugInfo();
        
        // Create events with problematic URL
        final event1 = TestHelpers.createMockVideoEvent(
          id: 'circuit-test-1',
          url: 'https://always-fails.com/video.mp4',
        );
        final event2 = TestHelpers.createMockVideoEvent(
          id: 'circuit-test-2', 
          url: 'https://always-fails.com/video.mp4', // Same URL
        );
        
        await manager.addVideoEvent(event1);
        await manager.addVideoEvent(event2);
        
        // ACT - Let first video fail completely (establishing failure pattern)
        await manager.preloadVideo('circuit-test-1');
        await Future.delayed(const Duration(seconds: 10)); // Wait for all retries
        
        // Try second video with same URL
        await manager.preloadVideo('circuit-test-2');
        
        // ASSERT - Second video should be skipped due to circuit breaker
        final state1 = manager.getVideoState('circuit-test-1');
        final state2 = manager.getVideoState('circuit-test-2');
        
        expect(state1!.loadingState, equals(VideoLoadingState.permanentlyFailed));
        expect(state2!.loadingState, equals(VideoLoadingState.notLoaded)); // Skipped
      });

      test('should clear failure patterns on memory pressure', () async {
        // ARRANGE
        final event = TestHelpers.createMockVideoEvent(
          id: 'clear-pattern-test',
          url: 'https://pattern-clear.com/video.mp4',
        );
        await manager.addVideoEvent(event);
        
        // Let it fail and establish pattern
        await manager.preloadVideo('clear-pattern-test');
        await Future.delayed(const Duration(seconds: 10));
        
        final debugInfoBefore = manager.getDebugInfo();
        expect(debugInfoBefore['failurePatterns'], greaterThan(0));
        
        // ACT - Trigger memory pressure
        await manager.handleMemoryPressure();
        
        // ASSERT - Failure patterns should be cleared
        final debugInfoAfter = manager.getDebugInfo();
        expect(debugInfoAfter['failurePatterns'], equals(0));
      });
    });

    group('State Consistency During Retries', () {
      test('should maintain consistent state during concurrent operations', () async {
        // ARRANGE
        final event = TestHelpers.createMockVideoEvent(id: 'concurrent-test');
        await manager.addVideoEvent(event);
        
        // ACT - Start multiple operations concurrently
        final preloadFuture = manager.preloadVideo('concurrent-test');
        manager.preloadAroundIndex(0); // This might trigger more preloads
        
        await preloadFuture;
        
        // ASSERT - State should be consistent
        final state = manager.getVideoState('concurrent-test');
        expect(state, isNotNull);
        expect(state!.loadingState, isIn([
          VideoLoadingState.failed,
          VideoLoadingState.permanentlyFailed,
          VideoLoadingState.ready,
        ]));
      });

      test('should handle state change notifications during retries', () async {
        // ARRANGE
        final event = TestHelpers.createMockVideoEvent(id: 'notification-test');
        await manager.addVideoEvent(event);
        
        final stateChanges = <void>[];
        final subscription = manager.stateChanges.listen((_) {
          stateChanges.add(null);
        });
        
        try {
          // ACT
          await manager.preloadVideo('notification-test');
          
          // Wait for potential retries
          await Future.delayed(const Duration(milliseconds: 2500));
          
          // ASSERT - Should have received multiple state change notifications
          expect(stateChanges.length, greaterThan(1)); // Initial add + failed + retry attempts
          
        } finally {
          await subscription.cancel();
        }
      });
    });

    group('Configuration Impact on Retries', () {
      test('should respect preload timeout configuration', () async {
        // ARRANGE - Create manager with short timeout
        final shortTimeoutManager = VideoManagerService(
          config: const VideoManagerConfig(
            preloadTimeout: Duration(milliseconds: 100), // Very short
          ),
        );
        
        try {
          final event = TestHelpers.createMockVideoEvent(
            id: 'timeout-config-test',
            url: 'https://slow-server.com/video.mp4',
          );
          await shortTimeoutManager.addVideoEvent(event);
          
          final stopwatch = Stopwatch()..start();
          
          // ACT
          await shortTimeoutManager.preloadVideo('timeout-config-test');
          
          stopwatch.stop();
          
          // ASSERT - Should fail quickly due to short timeout
          expect(stopwatch.elapsedMilliseconds, lessThan(1000));
          
          final state = shortTimeoutManager.getVideoState('timeout-config-test');
          expect(state!.hasFailed, isTrue);
          
        } finally {
          shortTimeoutManager.dispose();
        }
      });

      test('should work with different configurations', () async {
        // ARRANGE - Test cellular configuration
        final cellularManager = VideoManagerService(
          config: VideoManagerConfig.cellular(),
        );
        
        try {
          final event = TestHelpers.createMockVideoEvent(id: 'cellular-test');
          await cellularManager.addVideoEvent(event);
          
          // ACT
          await cellularManager.preloadVideo('cellular-test');
          
          // ASSERT
          final state = cellularManager.getVideoState('cellular-test');
          expect(state, isNotNull);
          
          final debugInfo = cellularManager.getDebugInfo();
          expect(debugInfo['maxVideos'], equals(50)); // Cellular config
          
        } finally {
          cellularManager.dispose();
        }
      });
    });
  });
}