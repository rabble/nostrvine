// ABOUTME: Performance-focused integration tests for video system scalability
// ABOUTME: Tests memory usage, loading times, and system stability under load

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:nostrvine_app/models/video_event.dart';
import 'package:nostrvine_app/models/video_state.dart';
import 'package:nostrvine_app/services/video_manager_interface.dart';
import 'package:nostrvine_app/services/video_manager_service.dart';
import 'package:nostrvine_app/screens/feed_screen_v2.dart';
import 'package:nostrvine_app/widgets/video_feed_item_v2.dart';

import '../helpers/test_helpers.dart';
import '../mocks/mock_video_manager.dart';

void main() {
  group('Performance Integration Tests', () {
    group('Memory Performance Tests', () {
      late VideoManagerService videoManager;

      setUp(() {
        videoManager = VideoManagerService(
          config: VideoManagerConfig.testing(),
        );
      });

      tearDown(() {
        videoManager.dispose();
      });

      testWidgets('Memory usage with 100+ videos', (tester) async {
        const targetVideoCount = 120; // Exceeds typical usage
        
        await tester.pumpWidget(
          Provider<IVideoManager>(
            create: (_) => videoManager,
            child: MaterialApp(
              home: const FeedScreenV2(),
            ),
          ),
        );

        // Create large dataset
        final largeVideoSet = TestHelpers.generatePerformanceTestData(targetVideoCount);
        
        final memoryStopwatch = Stopwatch()..start();

        // Add videos in chunks to monitor memory progression
        const chunkSize = 25;
        final memoryReadings = <int, int>{}; // videoCount -> memoryMB

        for (int i = 0; i < targetVideoCount; i += chunkSize) {
          final chunk = largeVideoSet.skip(i).take(chunkSize);
          
          for (final video in chunk) {
            await videoManager.addVideoEvent(video);
          }
          
          await tester.pump();
          
          // Record memory usage at intervals
          final videoCount = i + chunkSize;
          final debugInfo = videoManager.getDebugInfo();
          memoryReadings[videoCount] = debugInfo['estimatedMemoryMB'] as int;
          
          // Trigger preloading occasionally to simulate real usage
          if (videoCount % 50 == 0) {
            videoManager.preloadAroundIndex(videoCount ~/ 2);
            await tester.pump();
          }
        }

        await tester.pumpAndSettle();
        memoryStopwatch.stop();

        // Performance assertions
        expect(memoryStopwatch.elapsedMilliseconds, lessThan(15000), 
               reason: 'Adding 120 videos should complete within 15 seconds');

        final finalDebugInfo = videoManager.getDebugInfo();
        final finalMemoryMB = finalDebugInfo['estimatedMemoryMB'] as int;
        final activeControllers = finalDebugInfo['activeControllers'] as int;

        // Memory constraints
        expect(finalMemoryMB, lessThan(600), 
               reason: 'Memory usage should stay under 600MB with 120 videos');
        
        expect(activeControllers, lessThanOrEqualTo(VideoManagerService.maxControllers),
               reason: 'Should not exceed maximum controller limit');

        // Memory growth should be reasonable
        expect(memoryReadings[25]! <= memoryReadings[50]!, isTrue,
               reason: 'Memory should grow predictably');
        expect(finalMemoryMB, lessThan(memoryReadings[25]! * 5),
               reason: 'Memory growth should not be exponential');

        // System should remain functional
        expect(videoManager.videos.length, equals(targetVideoCount));
        expect(find.byType(PageView), findsOneWidget);

        debugPrint('Performance Test Results:');
        debugPrint('- Videos added: $targetVideoCount');
        debugPrint('- Time taken: ${memoryStopwatch.elapsedMilliseconds}ms');
        debugPrint('- Final memory: ${finalMemoryMB}MB');
        debugPrint('- Active controllers: $activeControllers');
        debugPrint('- Memory progression: $memoryReadings');
      });

      testWidgets('Memory pressure handling at scale', (tester) async {
        await tester.pumpWidget(
          Provider<IVideoManager>(
            create: (_) => videoManager,
            child: MaterialApp(
              home: const FeedScreenV2(),
            ),
          ),
        );

        // Add large number of videos
        const videoCount = 80;
        final videos = TestHelpers.generatePerformanceTestData(videoCount);
        
        for (final video in videos) {
          await videoManager.addVideoEvent(video);
        }

        await tester.pumpAndSettle();

        // Measure initial memory
        var debugInfo = videoManager.getDebugInfo();
        final initialMemory = debugInfo['estimatedMemoryMB'] as int;

        // Trigger memory pressure multiple times
        final pressureStopwatch = Stopwatch()..start();
        
        for (int i = 0; i < 5; i++) {
          await videoManager.handleMemoryPressure();
          await tester.pump();
          
          debugInfo = videoManager.getDebugInfo();
          final currentMemory = debugInfo['estimatedMemoryMB'] as int;
          
          // Memory should decrease or stay controlled
          expect(currentMemory, lessThan(600),
                 reason: 'Memory should stay controlled after pressure handling');
        }
        
        pressureStopwatch.stop();

        // Memory pressure should be fast
        expect(pressureStopwatch.elapsedMilliseconds, lessThan(3000),
               reason: 'Memory pressure handling should complete quickly');

        // System should remain stable
        expect(videoManager.videos.length, lessThanOrEqualTo(videoCount));
        expect(find.byType(PageView), findsOneWidget);

        final finalDebugInfo = videoManager.getDebugInfo();
        expect(finalDebugInfo['memoryPressureCount'], greaterThan(0));
      });

      testWidgets('Memory leak detection', (tester) async {
        await tester.pumpWidget(
          Provider<IVideoManager>(
            create: (_) => videoManager,
            child: MaterialApp(
              home: const FeedScreenV2(),
            ),
          ),
        );

        // Cycle through adding and removing videos
        const cycleCount = 10;
        const videosPerCycle = 15;
        
        final baselineMemory = videoManager.getDebugInfo()['estimatedMemoryMB'] as int;
        
        for (int cycle = 0; cycle < cycleCount; cycle++) {
          // Add videos
          final cycleVideos = TestHelpers.createVideoList(
            videosPerCycle, 
            idPrefix: 'cycle_${cycle}_'
          );
          
          for (final video in cycleVideos) {
            await videoManager.addVideoEvent(video);
          }
          
          // Simulate usage
          videoManager.preloadAroundIndex(cycle % videosPerCycle);
          await tester.pump();
          
          // Force cleanup
          await videoManager.handleMemoryPressure();
          await tester.pump();
        }

        await tester.pumpAndSettle();

        // Check for memory leaks
        final finalMemory = videoManager.getDebugInfo()['estimatedMemoryMB'] as int;
        
        // Memory should not grow significantly from baseline
        expect(finalMemory, lessThan(baselineMemory + 200),
               reason: 'Memory should not leak significantly over cycles');

        debugPrint('Memory Leak Test Results:');
        debugPrint('- Baseline memory: ${baselineMemory}MB');
        debugPrint('- Final memory: ${finalMemory}MB');
        debugPrint('- Memory growth: ${finalMemory - baselineMemory}MB');
      });
    });

    group('Loading Performance Tests', () {
      late MockVideoManager mockVideoManager;

      setUp(() {
        mockVideoManager = MockVideoManager();
        // Configure for optimal performance testing
        mockVideoManager.setPreloadDelay(const Duration(milliseconds: 10));
      });

      tearDown() {
        mockVideoManager.dispose();
      });

      testWidgets('Rapid video addition performance', (tester) async {
        await tester.pumpWidget(
          Provider<IVideoManager>(
            create: (_) => mockVideoManager,
            child: MaterialApp(
              home: const FeedScreenV2(),
            ),
          ),
        );

        // Rapid video addition test
        const rapidAddCount = 200;
        final rapidVideos = TestHelpers.generatePerformanceTestData(rapidAddCount);
        
        final rapidStopwatch = Stopwatch()..start();

        // Add videos as fast as possible
        for (final video in rapidVideos) {
          await mockVideoManager.addVideoEvent(video);
          // Minimal pump to allow framework processing
          if (rapidVideos.indexOf(video) % 20 == 0) {
            await tester.pump(const Duration(microseconds: 100));
          }
        }

        await tester.pumpAndSettle();
        rapidStopwatch.stop();

        // Performance expectations
        expect(rapidStopwatch.elapsedMilliseconds, lessThan(8000),
               reason: '200 rapid video additions should complete in under 8 seconds');

        expect(mockVideoManager.videos.length, equals(rapidAddCount));
        expect(find.byType(PageView), findsOneWidget);

        debugPrint('Rapid Addition Results: ${rapidStopwatch.elapsedMilliseconds}ms for $rapidAddCount videos');
      });

      testWidgets('Preloading performance at scale', (tester) async {
        // Set up for successful preloads
        mockVideoManager.setPreloadBehavior(PreloadBehavior.normal);
        mockVideoManager.setPreloadDelay(const Duration(milliseconds: 5));

        await tester.pumpWidget(
          Provider<IVideoManager>(
            create: (_) => mockVideoManager,
            child: MaterialApp(
              home: const FeedScreenV2(),
            ),
          ),
        );

        // Add moderate number of videos
        const preloadTestCount = 60;
        final preloadVideos = TestHelpers.createVideoList(preloadTestCount);
        
        for (final video in preloadVideos) {
          await mockVideoManager.addVideoEvent(video);
        }

        await tester.pumpAndSettle();

        // Test preloading performance
        final preloadStopwatch = Stopwatch()..start();

        // Simulate user scrolling through content
        for (int i = 0; i < preloadTestCount; i += 3) {
          mockVideoManager.preloadAroundIndex(i);
          await tester.pump(const Duration(milliseconds: 20));
        }

        await tester.pumpAndSettle();
        preloadStopwatch.stop();

        // Preloading should be efficient
        expect(preloadStopwatch.elapsedMilliseconds, lessThan(5000),
               reason: 'Preloading operations should complete quickly');

        // Check preload statistics
        final stats = mockVideoManager.getStatistics();
        expect(stats['preloadCallCount'], greaterThan(0));

        debugPrint('Preloading Performance: ${preloadStopwatch.elapsedMilliseconds}ms');
        debugPrint('Preload calls: ${stats['preloadCallCount']}');
      });

      testWidgets('UI responsiveness under load', (tester) async {
        await tester.pumpWidget(
          Provider<IVideoManager>(
            create: (_) => mockVideoManager,
            child: MaterialApp(
              home: const FeedScreenV2(),
            ),
          ),
        );

        // Add large dataset
        const responsiveTestCount = 100;
        final responsiveVideos = TestHelpers.generatePerformanceTestData(responsiveTestCount);
        
        for (final video in responsiveVideos) {
          await mockVideoManager.addVideoEvent(video);
        }

        await tester.pumpAndSettle();

        // Test UI responsiveness with rapid interactions
        final pageViewFinder = find.byType(PageView);
        expect(pageViewFinder, findsOneWidget);

        final interactionStopwatch = Stopwatch()..start();

        // Perform rapid scrolling and interactions
        for (int i = 0; i < 20; i++) {
          await tester.drag(pageViewFinder, Offset(0, -200 - (i % 3) * 50));
          await tester.pump(const Duration(milliseconds: 50));
          
          // Trigger preloading during interaction
          mockVideoManager.preloadAroundIndex(i % responsiveTestCount);
        }

        await tester.pumpAndSettle();
        interactionStopwatch.stop();

        // UI should remain responsive
        expect(interactionStopwatch.elapsedMilliseconds, lessThan(6000),
               reason: 'UI interactions should remain responsive under load');

        // UI should still be functional
        expect(find.byType(PageView), findsOneWidget);

        debugPrint('UI Responsiveness: ${interactionStopwatch.elapsedMilliseconds}ms for 20 interactions');
      });
    });

    group('Scalability Stress Tests', () {
      late VideoManagerService videoManager;

      setUp() {
        videoManager = VideoManagerService(
          config: const VideoManagerConfig(
            maxVideos: 200, // Higher limit for stress testing
            preloadAhead: 5,
            preloadBehind: 2,
            maxRetries: 2,
            preloadTimeout: Duration(seconds: 5),
            enableMemoryManagement: true,
          ),
        );
      });

      tearDown() {
        videoManager.dispose();
      });

      testWidgets('Extreme load stress test', (tester) async {
        await tester.pumpWidget(
          Provider<IVideoManager>(
            create: (_) => videoManager,
            child: MaterialApp(
              home: const FeedScreenV2(),
            ),
          ),
        );

        // Extreme stress test parameters
        const extremeVideoCount = 250;
        const stressOperations = 100;
        
        final stressVideos = TestHelpers.generatePerformanceTestData(extremeVideoCount);
        
        final stressStopwatch = Stopwatch()..start();

        // Phase 1: Mass video addition
        for (int i = 0; i < stressVideos.length; i += 10) {
          final batch = stressVideos.skip(i).take(10);
          for (final video in batch) {
            await videoManager.addVideoEvent(video);
          }
          
          // Occasional memory pressure during loading
          if (i % 50 == 0 && i > 0) {
            await videoManager.handleMemoryPressure();
          }
          
          await tester.pump(const Duration(milliseconds: 10));
        }

        // Phase 2: Stress operations
        for (int op = 0; op < stressOperations; op++) {
          final randomIndex = Random().nextInt(extremeVideoCount);
          
          // Mix of operations
          switch (op % 4) {
            case 0:
              videoManager.preloadAroundIndex(randomIndex);
              break;
            case 1:
              if (op % 10 == 0) {
                await videoManager.handleMemoryPressure();
              }
              break;
            case 2:
              // Simulate UI scroll
              await tester.pump(const Duration(milliseconds: 1));
              break;
            case 3:
              // Check system state
              final debugInfo = videoManager.getDebugInfo();
              expect(debugInfo['disposed'], isFalse);
              break;
          }
          
          if (op % 25 == 0) {
            await tester.pump(const Duration(milliseconds: 20));
          }
        }

        await tester.pumpAndSettle();
        stressStopwatch.stop();

        // Stress test validation
        expect(stressStopwatch.elapsedMilliseconds, lessThan(30000),
               reason: 'Extreme stress test should complete within 30 seconds');

        final finalDebugInfo = videoManager.getDebugInfo();
        expect(finalDebugInfo['disposed'], isFalse,
               reason: 'System should remain stable under extreme load');

        expect(finalDebugInfo['estimatedMemoryMB'], lessThan(800),
               reason: 'Memory should stay controlled even under extreme load');

        expect(find.byType(PageView), findsOneWidget,
               reason: 'UI should remain functional after stress test');

        debugPrint('Extreme Stress Test Results:');
        debugPrint('- Videos: $extremeVideoCount, Operations: $stressOperations');
        debugPrint('- Duration: ${stressStopwatch.elapsedMilliseconds}ms');
        debugPrint('- Final memory: ${finalDebugInfo['estimatedMemoryMB']}MB');
        debugPrint('- Memory pressure events: ${finalDebugInfo['memoryPressureCount']}');
      });

      testWidgets('Concurrent operations stress test', (tester) async {
        await tester.pumpWidget(
          Provider<IVideoManager>(
            create: (_) => videoManager,
            child: MaterialApp(
              home: const FeedScreenV2(),
            ),
          ),
        );

        // Set up base videos
        const baseVideoCount = 50;
        final baseVideos = TestHelpers.createVideoList(baseVideoCount);
        
        for (final video in baseVideos) {
          await videoManager.addVideoEvent(video);
        }

        await tester.pumpAndSettle();

        // Simulate concurrent operations
        final concurrentStopwatch = Stopwatch()..start();

        final futures = <Future>[];

        // Concurrent preloading
        for (int i = 0; i < 20; i++) {
          futures.add(
            Future(() async {
              for (int j = 0; j < 5; j++) {
                final randomIndex = Random().nextInt(baseVideoCount);
                videoManager.preloadAroundIndex(randomIndex);
                await Future.delayed(const Duration(milliseconds: 50));
              }
            })
          );
        }

        // Concurrent video additions
        for (int i = 0; i < 10; i++) {
          futures.add(
            Future(() async {
              final newVideo = TestHelpers.createVideoEvent(id: 'concurrent_$i');
              await videoManager.addVideoEvent(newVideo);
            })
          );
        }

        // Concurrent memory pressure
        futures.add(
          Future(() async {
            for (int i = 0; i < 3; i++) {
              await Future.delayed(const Duration(milliseconds: 200));
              await videoManager.handleMemoryPressure();
            }
          })
        );

        // Wait for all concurrent operations
        await Future.wait(futures);
        await tester.pumpAndSettle();

        concurrentStopwatch.stop();

        // Concurrency validation
        expect(concurrentStopwatch.elapsedMilliseconds, lessThan(15000),
               reason: 'Concurrent operations should complete within reasonable time');

        final debugInfo = videoManager.getDebugInfo();
        expect(debugInfo['disposed'], isFalse,
               reason: 'System should handle concurrent operations gracefully');

        expect(videoManager.videos.length, greaterThanOrEqualTo(baseVideoCount),
               reason: 'Videos should be added successfully despite concurrency');

        debugPrint('Concurrent Operations Test: ${concurrentStopwatch.elapsedMilliseconds}ms');
      });
    });

    group('Performance Regression Tests', () {
      testWidgets('Performance regression detection', (tester) async {
        // Baseline performance test to detect regressions
        final videoManager = VideoManagerService(
          config: VideoManagerConfig.testing(),
        );

        await tester.pumpWidget(
          Provider<IVideoManager>(
            create: (_) => videoManager,
            child: MaterialApp(
              home: const FeedScreenV2(),
            ),
          ),
        );

        // Standard test scenario
        const standardVideoCount = 50;
        const standardOperations = 25;

        final regressionVideos = TestHelpers.generatePerformanceTestData(standardVideoCount);
        
        final regressionStopwatch = Stopwatch()..start();

        // Add videos
        for (final video in regressionVideos) {
          await videoManager.addVideoEvent(video);
        }

        // Standard operations
        for (int i = 0; i < standardOperations; i++) {
          videoManager.preloadAroundIndex(i % standardVideoCount);
          await tester.pump(const Duration(milliseconds: 40));
        }

        await tester.pumpAndSettle();
        regressionStopwatch.stop();

        // Performance regression thresholds
        expect(regressionStopwatch.elapsedMilliseconds, lessThan(8000),
               reason: 'Standard performance test should complete within 8 seconds');

        final debugInfo = videoManager.getDebugInfo();
        expect(debugInfo['estimatedMemoryMB'], lessThan(400),
               reason: 'Memory usage should stay under 400MB for standard test');

        videoManager.dispose();

        debugPrint('Performance Regression Baseline: ${regressionStopwatch.elapsedMilliseconds}ms');
      });
    });
  });
}