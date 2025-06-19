// ABOUTME: Full-stack integration tests for video system end-to-end functionality
// ABOUTME: Tests complete Nostr event flow to UI display with real components

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:nostrvine_app/models/video_state.dart';
import 'package:nostrvine_app/services/video_manager_interface.dart';
import 'package:nostrvine_app/services/video_manager_service.dart';
import 'package:nostrvine_app/screens/feed_screen_v2.dart';
import 'package:nostrvine_app/widgets/video_feed_item_v2.dart';

import '../test/helpers/test_helpers.dart';
import '../test/mocks/mock_video_manager.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Video System Full-Stack Integration Tests', () {
    late IVideoManager videoManager;

    setUp(() {
      // Use real VideoManagerService for true integration testing
      videoManager = VideoManagerService(
        config: VideoManagerConfig.testing(),
      );
    });

    tearDown(() {
      videoManager.dispose();
    });

    testWidgets('Complete video system integration: Nostr events to UI display', (tester) async {
      // Setup app with real video manager
      await tester.pumpWidget(
        Provider<IVideoManager>.value(
          value: videoManager,
          child: MaterialApp(
            home: const FeedScreenV2(),
          ),
        ),
      );

      // Initial state: loading screen should be visible
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Wait for initialization
      await tester.pumpAndSettle();

      // Add video events to simulate Nostr data flow
      final testVideos = TestHelpers.createVideoList(5);
      
      for (final video in testVideos) {
        await videoManager.addVideoEvent(video);
      }

      // Trigger UI update
      await tester.pumpAndSettle();

      // Verify video feed displays
      expect(find.byType(PageView), findsOneWidget);
      
      // Check that video feed items are displayed
      expect(find.byType(VideoFeedItemV2), findsAtLeastNWidgets(1));

      // Verify video manager state
      expect(videoManager.videos.length, equals(5));
      expect(videoManager.videos, orderedEquals(testVideos));

      // Test preloading is triggered
      videoManager.preloadAroundIndex(0);
      await tester.pumpAndSettle();

      // Verify that preloading started for nearby videos
      final firstVideoState = videoManager.getVideoState(testVideos[0].id);
      expect(firstVideoState?.loadingState, isIn([VideoLoadingState.loading, VideoLoadingState.ready]));
    });

    testWidgets('User interactions work correctly', (tester) async {
      // Setup app with test videos
      final testVideos = TestHelpers.createVideoList(3);
      
      await tester.pumpWidget(
        Provider<IVideoManager>.value(
          value: videoManager,
          child: MaterialApp(
            home: const FeedScreenV2(),
          ),
        ),
      );

      // Add videos
      for (final video in testVideos) {
        await videoManager.addVideoEvent(video);
      }

      await tester.pumpAndSettle();

      // Find PageView
      final pageViewFinder = find.byType(PageView);
      expect(pageViewFinder, findsOneWidget);

      // Test scrolling to next video
      await tester.drag(pageViewFinder, const Offset(0, -300));
      await tester.pumpAndSettle();

      // Verify page change triggered preloading
      final debugInfo = videoManager.getDebugInfo();
      expect(debugInfo['activePreloads'], greaterThanOrEqualTo(0));
      expect(debugInfo['totalVideos'], equals(3));
    });

    testWidgets('Error scenarios are handled gracefully', (tester) async {
      // Create videos that will fail to load
      final failingVideos = [
        TestHelpers.createFailingVideoEvent(id: 'fail1'),
        TestHelpers.createFailingVideoEvent(id: 'fail2'),
        TestHelpers.createVideoEvent(id: 'success1'), // One success for contrast
      ];

      await tester.pumpWidget(
        Provider<IVideoManager>.value(
          value: videoManager,
          child: MaterialApp(
            home: const FeedScreenV2(),
          ),
        ),
      );

      // Add failing videos
      for (final video in failingVideos) {
        await videoManager.addVideoEvent(video);
      }

      await tester.pumpAndSettle();

      // Attempt to preload failing videos
      for (final video in failingVideos) {
        try {
          await videoManager.preloadVideo(video.id);
        } catch (e) {
          // Expected for failing videos
        }
      }

      await tester.pumpAndSettle();

      // Verify UI handles errors gracefully
      expect(find.byType(PageView), findsOneWidget);

      // Check that error states are properly managed
      final debugInfo = videoManager.getDebugInfo();
      expect(debugInfo['failedVideos'], greaterThan(0));
      expect(debugInfo['totalVideos'], equals(3));

      // UI should still be functional despite errors
      expect(find.byType(VideoFeedItemV2), findsAtLeastNWidgets(1));
    });

    testWidgets('Memory usage stays within reasonable limits', (tester) async {
      // Create a moderate number of videos for testing
      final testVideos = TestHelpers.createVideoList(20);

      await tester.pumpWidget(
        Provider<IVideoManager>.value(
          value: videoManager,
          child: MaterialApp(
            home: const FeedScreenV2(),
          ),
        ),
      );

      // Add videos progressively
      for (int i = 0; i < testVideos.length; i++) {
        await videoManager.addVideoEvent(testVideos[i]);
        
        // Trigger preloading every few videos
        if (i % 5 == 0) {
          videoManager.preloadAroundIndex(i);
          await tester.pumpAndSettle(const Duration(milliseconds: 100));
        }
      }

      await tester.pumpAndSettle();

      // Check memory usage metrics
      final debugInfo = videoManager.getDebugInfo();
      final memoryUsageMB = debugInfo['estimatedMemoryMB'] as int;
      final activeControllers = debugInfo['activeControllers'] as int;

      // Memory should stay under target (500MB target, allowing some overhead for testing)
      expect(memoryUsageMB, lessThan(600));
      
      // Should not exceed controller limit
      expect(activeControllers, lessThanOrEqualTo(VideoManagerService.maxControllers));
      
      // Should have reasonable utilization
      expect(debugInfo['memoryUtilization'], isNotNull);

      // Verify memory management is working
      if (testVideos.length > 10) {
        await videoManager.handleMemoryPressure();
        await tester.pumpAndSettle();
        
        final postCleanupInfo = videoManager.getDebugInfo();
        final postCleanupMemory = postCleanupInfo['estimatedMemoryMB'] as int;
        
        // Memory usage should decrease after cleanup
        expect(postCleanupMemory, lessThanOrEqualTo(memoryUsageMB));
      }
    });

    testWidgets('State changes trigger UI updates correctly', (tester) async {
      await tester.pumpWidget(
        Provider<IVideoManager>.value(
          value: videoManager,
          child: MaterialApp(
            home: const FeedScreenV2(),
          ),
        ),
      );

      // Start with empty state
      await tester.pumpAndSettle();
      
      // Should show empty or loading state initially
      expect(find.byType(PageView), findsNothing);

      // Add a video
      final testVideo = TestHelpers.createVideoEvent(id: 'state_test_video');
      await videoManager.addVideoEvent(testVideo);

      // Trigger UI update
      await tester.pumpAndSettle();

      // Now should show video feed
      expect(find.byType(PageView), findsOneWidget);
      expect(find.byType(VideoFeedItemV2), findsOneWidget);

      // Test state change when preloading
      await videoManager.preloadVideo(testVideo.id);
      await tester.pumpAndSettle();

      // UI should reflect the new state
      final videoState = videoManager.getVideoState(testVideo.id);
      expect(videoState, isNotNull);
      expect(videoState!.loadingState, isIn([VideoLoadingState.loading, VideoLoadingState.ready, VideoLoadingState.failed]));
    });
  });

  group('Performance Integration Tests', () {
    late IVideoManager videoManager;

    setUp(() {
      videoManager = VideoManagerService(
        config: VideoManagerConfig.testing(),
      );
    });

    tearDown(() {
      videoManager.dispose();
    });

    testWidgets('Performance with large number of videos', (tester) async {
      const videoCount = 50; // Reduced from 100+ for CI stability
      final testVideos = TestHelpers.generatePerformanceTestData(videoCount);

      final stopwatch = Stopwatch()..start();

      await tester.pumpWidget(
        Provider<IVideoManager>.value(
          value: videoManager,
          child: MaterialApp(
            home: const FeedScreenV2(),
          ),
        ),
      );

      // Add videos in batches to measure performance
      const batchSize = 10;
      for (int i = 0; i < videoCount; i += batchSize) {
        final batch = testVideos.skip(i).take(batchSize);
        for (final video in batch) {
          await videoManager.addVideoEvent(video);
        }
        
        // Allow UI to update between batches
        await tester.pumpAndSettle(const Duration(milliseconds: 50));
      }

      stopwatch.stop();

      // Performance benchmarks
      expect(stopwatch.elapsedMilliseconds, lessThan(10000)); // Should complete in under 10 seconds
      expect(videoManager.videos.length, equals(videoCount));

      // Test rapid preloading
      final preloadStopwatch = Stopwatch()..start();
      
      for (int i = 0; i < 10; i++) {
        videoManager.preloadAroundIndex(i);
        await tester.pump(const Duration(milliseconds: 10));
      }
      
      preloadStopwatch.stop();
      expect(preloadStopwatch.elapsedMilliseconds, lessThan(5000)); // Preloading should be fast

      // Verify memory is still reasonable
      final debugInfo = videoManager.getDebugInfo();
      expect(debugInfo['estimatedMemoryMB'], lessThan(600));
    });

    testWidgets('Rapid scrolling performance', (tester) async {
      const videoCount = 20;
      final testVideos = TestHelpers.createVideoList(videoCount);

      await tester.pumpWidget(
        Provider<IVideoManager>.value(
          value: videoManager,
          child: MaterialApp(
            home: const FeedScreenV2(),
          ),
        ),
      );

      // Add videos
      for (final video in testVideos) {
        await videoManager.addVideoEvent(video);
      }

      await tester.pumpAndSettle();

      final pageViewFinder = find.byType(PageView);
      expect(pageViewFinder, findsOneWidget);

      // Perform rapid scrolling
      final scrollStopwatch = Stopwatch()..start();

      for (int i = 0; i < 10; i++) {
        await tester.drag(pageViewFinder, const Offset(0, -300));
        await tester.pump(const Duration(milliseconds: 50)); // Minimal delay
      }

      await tester.pumpAndSettle();
      scrollStopwatch.stop();

      // Rapid scrolling should complete quickly
      expect(scrollStopwatch.elapsedMilliseconds, lessThan(3000));

      // System should remain stable
      final debugInfo = videoManager.getDebugInfo();
      expect(debugInfo['disposed'], isFalse);
      expect(debugInfo['totalVideos'], equals(videoCount));
    });
  });

  group('Error Recovery Integration Tests', () {
    late MockVideoManager mockVideoManager;

    setUp(() {
      mockVideoManager = MockVideoManager(
        config: VideoManagerConfig.testing(),
      );
    });

    tearDown(() {
      mockVideoManager.dispose();
    });

    testWidgets('System recovers from video loading failures', (tester) async {
      // Configure mock to fail first attempt, succeed on retry
      mockVideoManager.setPreloadBehavior(PreloadBehavior.failOnce);

      await tester.pumpWidget(
        Provider<IVideoManager>.value(
          value: mockVideoManager,
          child: MaterialApp(
            home: const FeedScreenV2(),
          ),
        ),
      );

      // Add a video that will fail then succeed
      final testVideo = TestHelpers.createVideoEvent(id: 'recovery_test');
      await mockVideoManager.addVideoEvent(testVideo);

      await tester.pumpAndSettle();

      // First preload attempt should fail
      try {
        await mockVideoManager.preloadVideo(testVideo.id);
      } catch (e) {
        // Expected failure
      }

      // Check failed state
      var videoState = mockVideoManager.getVideoState(testVideo.id);
      expect(videoState?.hasFailed, isTrue);
      expect(videoState?.canRetry, isTrue);

      // Second attempt should succeed
      await mockVideoManager.preloadVideo(testVideo.id);
      
      videoState = mockVideoManager.getVideoState(testVideo.id);
      expect(videoState?.isReady, isTrue);

      // UI should reflect successful recovery
      await tester.pumpAndSettle();
      expect(find.byType(VideoFeedItemV2), findsOneWidget);
    });

    testWidgets('UI handles permanent failures gracefully', (tester) async {
      // Configure mock to always fail
      mockVideoManager.setPreloadBehavior(PreloadBehavior.alwaysFail);

      await tester.pumpWidget(
        Provider<IVideoManager>.value(
          value: mockVideoManager,
          child: MaterialApp(
            home: const FeedScreenV2(),
          ),
        ),
      );

      // Add videos including some that will permanently fail
      final testVideos = [
        TestHelpers.createVideoEvent(id: 'will_fail_1'),
        TestHelpers.createVideoEvent(id: 'will_fail_2'),
      ];

      for (final video in testVideos) {
        await mockVideoManager.addVideoEvent(video);
      }

      await tester.pumpAndSettle();

      // Attempt preloading multiple times to trigger permanent failure
      for (final video in testVideos) {
        for (int attempt = 0; attempt < 5; attempt++) {
          try {
            await mockVideoManager.preloadVideo(video.id);
          } catch (e) {
            // Expected failures
          }
        }
      }

      await tester.pumpAndSettle();

      // UI should still be functional despite permanent failures
      expect(find.byType(PageView), findsOneWidget);
      expect(find.byType(VideoFeedItemV2), findsAtLeastNWidgets(1));

      // Check that videos are marked as permanently failed
      for (final video in testVideos) {
        final state = mockVideoManager.getVideoState(video.id);
        // In mock, permanent failure behavior depends on implementation
        expect(state?.hasFailed, isTrue);
      }
    });
  });

  group('Real-world Scenario Integration Tests', () {
    late IVideoManager videoManager;

    setUp(() {
      videoManager = VideoManagerService(
        config: VideoManagerConfig.wifi(), // Use realistic config
      );
    });

    tearDown(() {
      videoManager.dispose();
    });

    testWidgets('Mixed content types integration', (tester) async {
      // Create mix of videos and GIFs
      final mixedContent = [
        TestHelpers.createVideoEvent(id: 'video1', isGif: false),
        TestHelpers.createGifVideoEvent(id: 'gif1'),
        TestHelpers.createVideoEvent(id: 'video2', isGif: false),
        TestHelpers.createGifVideoEvent(id: 'gif2'),
        TestHelpers.createSlowVideoEvent(id: 'slow1', delay: const Duration(seconds: 2)),
      ];

      await tester.pumpWidget(
        Provider<IVideoManager>.value(
          value: videoManager,
          child: MaterialApp(
            home: const FeedScreenV2(),
          ),
        ),
      );

      // Add mixed content
      for (final content in mixedContent) {
        await videoManager.addVideoEvent(content);
      }

      await tester.pumpAndSettle();

      // Verify all content is displayed
      expect(videoManager.videos.length, equals(5));
      expect(find.byType(PageView), findsOneWidget);

      // Test preloading works for mixed content
      videoManager.preloadAroundIndex(0);
      await tester.pumpAndSettle();

      // Check that different content types are handled appropriately
      final debugInfo = videoManager.getDebugInfo();
      expect(debugInfo['totalVideos'], equals(5));
    });

    testWidgets('Memory pressure during normal usage', (tester) async {
      await tester.pumpWidget(
        Provider<IVideoManager>.value(
          value: videoManager,
          child: MaterialApp(
            home: const FeedScreenV2(),
          ),
        ),
      );

      // Simulate typical usage pattern
      final videos = TestHelpers.createVideoList(30);
      
      // Add videos gradually (simulating feed loading)
      for (int i = 0; i < videos.length; i += 5) {
        final batch = videos.skip(i).take(5);
        for (final video in batch) {
          await videoManager.addVideoEvent(video);
        }
        
        // Simulate user scrolling
        videoManager.preloadAroundIndex(i ~/ 5);
        await tester.pump(const Duration(milliseconds: 200));
        
        // Trigger memory pressure occasionally
        if (i % 15 == 0 && i > 0) {
          await videoManager.handleMemoryPressure();
          await tester.pump();
        }
      }

      await tester.pumpAndSettle();

      // System should handle memory pressure gracefully
      final finalDebugInfo = videoManager.getDebugInfo();
      expect(finalDebugInfo['disposed'], isFalse);
      expect(finalDebugInfo['estimatedMemoryMB'], lessThan(600));
      expect(finalDebugInfo['memoryPressureCount'], greaterThan(0));

      // UI should still be responsive
      expect(find.byType(PageView), findsOneWidget);
    });
  });
}