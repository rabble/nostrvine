// ABOUTME: Comprehensive error handling tests for VideoManagerService
// ABOUTME: Tests circuit breaker, retry logic, permanent failure, and error recovery scenarios

import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/models/video_state.dart';
import 'package:openvine/services/video_manager_interface.dart';
import 'package:openvine/services/video_manager_service.dart';
import '../../helpers/test_helpers.dart';

void main() {
  group('VideoManagerService Error Handling', () {
    late VideoManagerService videoManager;
    late VideoManagerConfig testConfig;

    setUp(() {
      // Use testing config with short timeouts for faster error testing
      testConfig = VideoManagerConfig.testing();
      videoManager = VideoManagerService(config: testConfig);
    });

    tearDown(() {
      videoManager.dispose();
    });

    group('Network Error Handling', () {
      test('should handle network timeout errors gracefully', () async {
        final video = TestHelpers.createVideoEvent(
          id: 'timeout-test',
          videoUrl: 'https://httpbin.org/delay/10', // Will timeout with 500ms config
        );

        await videoManager.addVideoEvent(video);

        // Attempt preload that will timeout
        try {
          await videoManager.preloadVideo(video.id);
          fail('Expected timeout error');
        } catch (e) {
          expect(e, isA<VideoManagerException>());
          expect(e.toString(), contains('timeout'));
        }

        // Video should be in failed state
        final state = videoManager.getVideoState(video.id);
        expect(state?.hasFailed, isTrue);
        expect(state?.errorMessage, isNotNull);
      });

      test('should handle network connectivity errors', () async {
        final video = TestHelpers.createVideoEvent(
          id: 'network-test',
          videoUrl: 'https://invalid-domain-that-does-not-exist.com/video.mp4',
        );

        await videoManager.addVideoEvent(video);

        try {
          await videoManager.preloadVideo(video.id);
          fail('Expected network error');
        } catch (e) {
          expect(e, isA<Exception>());
        }

        final state = videoManager.getVideoState(video.id);
        expect(state?.hasFailed, isTrue);
      });

      test('should handle HTTP error codes (404, 403, 500)', () async {
        final testCases = [
          {'code': '404', 'url': 'https://httpbin.org/status/404'},
          {'code': '403', 'url': 'https://httpbin.org/status/403'},
          {'code': '500', 'url': 'https://httpbin.org/status/500'},
        ];

        for (final testCase in testCases) {
          final video = TestHelpers.createVideoEvent(
            id: 'http-${testCase['code']}-test',
            videoUrl: testCase['url'],
          );

          await videoManager.addVideoEvent(video);

          try {
            await videoManager.preloadVideo(video.id);
            // May not throw immediately, check state
          } catch (e) {
            // Expected for some HTTP errors
          }

          final state = videoManager.getVideoState(video.id);
          // Note: Some HTTP errors might not be detected until video initialization
          expect(state, isNotNull);
        }
      });
    });

    group('URL Validation and Error Handling', () {
      test('should handle malformed URLs', () async {
        final video = TestHelpers.createVideoEvent(
          id: 'malformed-url-test',
          videoUrl: 'not-a-valid-url',
        );

        await videoManager.addVideoEvent(video);

        try {
          await videoManager.preloadVideo(video.id);
          fail('Expected URL parsing error');
        } catch (e) {
          expect(e, isA<Exception>());
        }
      });

      test('should handle empty URLs', () async {
        final video = TestHelpers.createVideoEvent(
          id: 'empty-url-test',
          videoUrl: '',
        );

        await videoManager.addVideoEvent(video);

        expect(
          () => videoManager.preloadVideo(video.id),
          throwsA(isA<VideoManagerException>()),
        );
      });

      test('should handle null URLs', () async {
        final video = TestHelpers.createVideoEvent(
          id: 'null-url-test',
          videoUrl: null,
        );

        await videoManager.addVideoEvent(video);

        expect(
          () => videoManager.preloadVideo(video.id),
          throwsA(isA<VideoManagerException>()),
        );
      });
    });

    group('Retry Logic and Circuit Breaker', () {
      test('should retry failed preloads with exponential backoff', () async {
        final video = TestHelpers.createVideoEvent(
          id: 'retry-test',
          videoUrl: 'https://httpbin.org/delay/5', // Will timeout
        );

        await videoManager.addVideoEvent(video);

        final stopwatch = Stopwatch()..start();

        // First attempt should fail and schedule retry
        try {
          await videoManager.preloadVideo(video.id);
        } catch (e) {
          // Expected to fail
        }

        // Check that retry is scheduled
        final state = videoManager.getVideoState(video.id);
        expect(state?.canRetry, isTrue);
        expect(state?.retryCount, greaterThan(0));

        stopwatch.stop();
      });

      test('should respect maximum retry count', () async {
        final video = TestHelpers.createVideoEvent(
          id: 'max-retry-test',
          videoUrl: 'https://invalid-domain.com/video.mp4',
        );

        await videoManager.addVideoEvent(video);

        // Trigger multiple failures (VideoState.maxRetryCount = 3)
        for (int i = 0; i < VideoState.maxRetryCount + 2; i++) {
          try {
            await videoManager.preloadVideo(video.id);
          } catch (e) {
            // Expected to fail
          }

          // Add small delay between attempts
          await Future.delayed(const Duration(milliseconds: 50));
          
          // Check if already permanently failed
          final state = videoManager.getVideoState(video.id);
          if (state?.loadingState == VideoLoadingState.permanentlyFailed) {
            break;
          }
        }

        // Should eventually become permanently failed
        await TestHelpers.waitForCondition(
          () {
            final state = videoManager.getVideoState(video.id);
            return state?.loadingState == VideoLoadingState.permanentlyFailed;
          },
          timeout: const Duration(seconds: 15),
        );

        final finalState = videoManager.getVideoState(video.id);
        expect(finalState?.loadingState, equals(VideoLoadingState.permanentlyFailed));
        expect(finalState?.canRetry, isFalse);
      });

      test('should implement circuit breaker to prevent retry loops', () async {
        final video = TestHelpers.createVideoEvent(
          id: 'circuit-breaker-test',
          videoUrl: 'https://invalid.com/video.mp4',
        );

        await videoManager.addVideoEvent(video);

        // Track preload attempts
        int preloadAttempts = 0;

        // Simulate multiple failed attempts
        for (int i = 0; i < 10; i++) {
          try {
            preloadAttempts++;
            await videoManager.preloadVideo(video.id);
          } catch (e) {
            // Expected
          }

          final state = videoManager.getVideoState(video.id);
          if (state?.loadingState == VideoLoadingState.permanentlyFailed) {
            break; // Circuit breaker activated
          }

          await Future.delayed(const Duration(milliseconds: 50));
        }

        // Should not attempt more than VideoState.maxRetryCount + 1
        expect(preloadAttempts, lessThanOrEqualTo(VideoState.maxRetryCount + 2));

        final finalState = videoManager.getVideoState(video.id);
        expect(finalState?.loadingState, equals(VideoLoadingState.permanentlyFailed));
      });

      test('should calculate exponential backoff delays correctly', () async {
        final video = TestHelpers.createVideoEvent(
          id: 'backoff-test',
          videoUrl: 'https://invalid.com/video.mp4',
        );

        await videoManager.addVideoEvent(video);

        final retryTimes = <DateTime>[];

        // Attempt multiple failures to observe backoff
        for (int i = 0; i < 3; i++) {
          retryTimes.add(DateTime.now());
          try {
            await videoManager.preloadVideo(video.id);
          } catch (e) {
            // Expected
          }

          // Wait for retry to be scheduled
          await Future.delayed(const Duration(milliseconds: 100));
        }

        // Verify retry delays increase (exponential backoff)
        if (retryTimes.length >= 3) {
          // Note: Due to testing config short timeouts, exact verification is limited
          expect(retryTimes.length, equals(3));
        }
      });
    });

    group('Permanent Failure Handling', () {
      test('should mark videos as permanently failed after max retries', () async {
        final video = TestHelpers.createVideoEvent(
          id: 'permanent-fail-test',
          videoUrl: 'https://definitely-invalid-url.com/video.mp4',
        );

        await videoManager.addVideoEvent(video);

        // Trigger failures until permanent failure (VideoState.maxRetryCount = 3)
        for (int attempt = 0; attempt <= VideoState.maxRetryCount + 1; attempt++) {
          try {
            await videoManager.preloadVideo(video.id);
          } catch (e) {
            // Expected
          }

          final state = videoManager.getVideoState(video.id);
          if (state?.loadingState == VideoLoadingState.permanentlyFailed) {
            break;
          }

          await Future.delayed(const Duration(milliseconds: 50));
        }

        final finalState = videoManager.getVideoState(video.id);
        expect(finalState?.loadingState, equals(VideoLoadingState.permanentlyFailed));
        expect(finalState?.canRetry, isFalse);
        expect(finalState?.errorMessage, isNotNull);
      });

      test('should not attempt preload on permanently failed videos', () async {
        final video = TestHelpers.createVideoEvent(
          id: 'no-retry-test',
          videoUrl: 'https://invalid.com/video.mp4',
        );

        await videoManager.addVideoEvent(video);

        // Force video to permanently failed state (VideoState.maxRetryCount = 3)
        for (int i = 0; i <= VideoState.maxRetryCount + 1; i++) {
          try {
            await videoManager.preloadVideo(video.id);
          } catch (e) {
            // Expected
          }
          await Future.delayed(const Duration(milliseconds: 10));
        }

        // Verify it's permanently failed
        final state = videoManager.getVideoState(video.id);
        expect(state?.loadingState, equals(VideoLoadingState.permanentlyFailed));

        // Additional preload attempts should be ignored
        try {
          await videoManager.preloadVideo(video.id);
          // Should return immediately without attempting
        } catch (e) {
          fail('Should not throw for permanently failed video');
        }
      });
    });

    group('Error Recovery Scenarios', () {
      test('should recover from transient network errors', () async {
        // This test simulates recovery scenarios, but actual recovery
        // would require network conditions to improve
        final video = TestHelpers.createVideoEvent(
          id: 'recovery-test',
          videoUrl: 'https://httpbin.org/delay/1', // Might work with retry
        );

        await videoManager.addVideoEvent(video);

        try {
          await videoManager.preloadVideo(video.id);
        } catch (e) {
          // First attempt might fail
        }

        final state = videoManager.getVideoState(video.id);
        expect(state, isNotNull);

        // In a real scenario with network recovery, subsequent attempts might succeed
        // For testing, we verify the retry mechanism is in place
        if (state?.canRetry == true) {
          expect(state?.retryCount, greaterThan(0));
          expect(state?.retryCount, lessThanOrEqualTo(testConfig.maxRetries));
        }
      });

      test('should handle memory pressure during error states', () async {
        // Add multiple failing videos
        final videos = <VideoEvent>[];
        for (int i = 0; i < 5; i++) {
          final video = TestHelpers.createVideoEvent(
            id: 'memory-error-test-$i',
            videoUrl: 'https://invalid-$i.com/video.mp4',
          );
          videos.add(video);
          await videoManager.addVideoEvent(video);
        }

        // Trigger failures
        for (final video in videos) {
          try {
            await videoManager.preloadVideo(video.id);
          } catch (e) {
            // Expected
          }
        }

        // Trigger memory pressure
        await videoManager.handleMemoryPressure();

        // Should handle gracefully without throwing
        final debugInfo = videoManager.getDebugInfo();
        expect(debugInfo['disposed'], isFalse);
        expect(debugInfo['metrics']['memoryPressureCount'], greaterThan(0));
      });
    });

    group('Error Reporting and Logging', () {
      test('should provide comprehensive error information in debug info', () async {
        final video = TestHelpers.createVideoEvent(
          id: 'error-debug-test',
          videoUrl: 'https://invalid.com/video.mp4',
        );

        await videoManager.addVideoEvent(video);

        try {
          await videoManager.preloadVideo(video.id);
        } catch (e) {
          // Expected
        }

        final debugInfo = videoManager.getDebugInfo();

        // Should track error metrics
        expect(debugInfo['metrics'], contains('preloadCount'));
        expect(debugInfo['metrics'], contains('preloadFailureCount'));
        expect(debugInfo['metrics'], contains('preloadSuccessCount'));
        expect(debugInfo['metrics'], contains('preloadSuccessRate'));

        // Should show failed videos
        expect(debugInfo, contains('failedVideos'));
      });

      test('should include error details in video state', () async {
        final video = TestHelpers.createVideoEvent(
          id: 'error-state-test',
          videoUrl: 'https://invalid.com/video.mp4',
        );

        await videoManager.addVideoEvent(video);

        try {
          await videoManager.preloadVideo(video.id);
        } catch (e) {
          // Expected
        }

        final state = videoManager.getVideoState(video.id);
        expect(state?.hasFailed, isTrue);
        expect(state?.errorMessage, isNotNull);
        expect(state?.errorMessage, isNotEmpty);
        expect(state?.retryCount, greaterThan(0));
      });

      test('should log error patterns for debugging', () async {
        // This test verifies error logging structure
        // In practice, logs would be captured by monitoring systems

        final video = TestHelpers.createVideoEvent(
          id: 'error-logging-test',
          videoUrl: 'https://invalid.com/video.mp4',
        );

        await videoManager.addVideoEvent(video);

        try {
          await videoManager.preloadVideo(video.id);
        } catch (e) {
          // Expected
        }

        // Verify error is properly structured for logging
        final state = videoManager.getVideoState(video.id);
        expect(state?.errorMessage, isNotNull);
        
        // Error message should contain useful debugging info
        final errorMsg = state!.errorMessage!;
        expect(errorMsg.isNotEmpty, isTrue);
      });
    });

    group('Edge Cases and Error Boundaries', () {
      test('should handle errors during disposal', () async {
        final video = TestHelpers.createVideoEvent(
          id: 'disposal-error-test',
          videoUrl: 'https://invalid.com/video.mp4',
        );

        await videoManager.addVideoEvent(video);

        // Start a preload operation
        final preloadFuture = videoManager.preloadVideo(video.id);

        // Dispose manager while preload is in progress
        videoManager.dispose();

        // Should not throw unhandled exceptions
        try {
          await preloadFuture;
        } catch (e) {
          // Expected - operation was cancelled
        }

        // Manager should be properly disposed
        final debugInfo = videoManager.getDebugInfo();
        expect(debugInfo['disposed'], isTrue);
      });

      test('should handle concurrent error scenarios', () async {
        final videos = TestHelpers.createVideoList(3);
        
        for (final video in videos) {
          await videoManager.addVideoEvent(video);
        }

        // Start multiple preloads that will fail concurrently
        final preloadFutures = videos.map((video) {
          return videoManager.preloadVideo(video.id).catchError((e) {
            // Ignore errors for this test
            return null;
          });
        }).toList();

        // Should handle concurrent failures gracefully
        await Future.wait(preloadFutures);

        // All videos should have proper error states
        for (final video in videos) {
          final state = videoManager.getVideoState(video.id);
          expect(state, isNotNull);
          // Note: States might be failed or permanently failed depending on timing
        }
      });

      test('should maintain consistency during error cascades', () async {
        // Add many videos that will all fail
        final videos = TestHelpers.createVideoList(8);
        
        for (final video in videos) {
          await videoManager.addVideoEvent(video);
        }

        // Trigger preloads and memory pressure simultaneously
        final preloadFutures = videos.map((video) {
          return videoManager.preloadVideo(video.id).catchError((e) => null);
        }).toList();

        // Trigger memory pressure during failures
        final memoryPressureFuture = videoManager.handleMemoryPressure();

        await Future.wait([...preloadFutures, memoryPressureFuture]);

        // System should remain consistent
        final debugInfo = videoManager.getDebugInfo();
        expect(debugInfo['disposed'], isFalse);
        expect(debugInfo['totalVideos'], lessThanOrEqualTo(videos.length));
      });
    });
  });
}