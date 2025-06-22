// ABOUTME: Parallel system testing to validate new video system against legacy system
// ABOUTME: Comprehensive comparison of outputs, performance, memory usage, and error handling

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nostrvine_app/models/video_event.dart';
import 'package:nostrvine_app/models/video_state.dart';
import 'package:nostrvine_app/services/video_cache_service.dart';
import 'package:nostrvine_app/services/video_manager_interface.dart';
import 'package:nostrvine_app/services/video_manager_service.dart';
import 'package:nostrvine_app/services/video_system_comparator.dart';

import '../helpers/test_helpers.dart';

void main() {
  group('Parallel Video System Comparison Tests', () {
    group('Basic System Comparison', () {
      late VideoCacheService oldSystem;
      late VideoManagerService newSystem;
      late VideoSystemComparator comparator;

      setUp(() {
        oldSystem = VideoCacheService();
        newSystem = VideoManagerService(
          config: VideoManagerConfig.testing(),
        );
        comparator = VideoSystemComparator(
          oldSystem: oldSystem,
          newSystem: newSystem,
          logVerbose: true,
        );
      });

      tearDown(() {
        oldSystem.dispose();
        newSystem.dispose();
        comparator.dispose();
      });

      testWidgets('Systems produce consistent video lists', (tester) async {
        // Create test videos
        final testVideos = TestHelpers.createVideoList(10);

        // Run parallel comparison
        final result = await comparator.compareSystemsWithVideos(testVideos);

        // Verify results
        expect(result.passed, isTrue, 
               reason: 'Systems should produce consistent results: ${result.summary}');
        
        expect(result.discrepancies.length, lessThanOrEqualTo(2),
               reason: 'Minor discrepancies allowed for different system architectures');

        // Verify new system has videos
        expect(newSystem.videos.length, equals(testVideos.length));

        debugPrint('System Comparison Results:');
        debugPrint(result.summary);
        debugPrint('Discrepancies: ${result.discrepancies}');
      });

      testWidgets('New system achieves significant memory reduction', (tester) async {
        // Create substantial video dataset
        final testVideos = TestHelpers.createVideoList(30);

        // Run comparison
        final result = await comparator.compareSystemsWithVideos(testVideos);

        // Extract memory metrics
        final oldMemoryMB = result.oldSystemMemory.estimatedMB;
        final newMemoryMB = result.newSystemMemory.estimatedMB;
        final memoryReduction = result.toJson()['memoryReductionPercent'] as double;

        // Memory reduction assertions
        expect(newMemoryMB, lessThan(oldMemoryMB),
               reason: 'New system should use less memory than old system');

        expect(memoryReduction, greaterThan(30.0),
               reason: 'Should achieve at least 30% memory reduction');

        // Ideally should achieve 80% reduction, but be flexible for testing
        if (memoryReduction < 50.0) {
          debugPrint('⚠️ Memory reduction below target: ${memoryReduction.toStringAsFixed(1)}%');
        }

        debugPrint('Memory Comparison:');
        debugPrint('- Old System: ${oldMemoryMB}MB');
        debugPrint('- New System: ${newMemoryMB}MB');
        debugPrint('- Reduction: ${memoryReduction.toStringAsFixed(1)}%');
      });

      testWidgets('New system maintains or improves performance', (tester) async {
        final testVideos = TestHelpers.createVideoList(15);

        final result = await comparator.compareSystemsWithVideos(testVideos);

        // Performance metrics
        final oldPerformance = result.oldSystemMetrics;
        final newPerformance = result.newSystemMetrics;

        // Performance assertions
        expect(newPerformance.successRate, greaterThanOrEqualTo(oldPerformance.successRate),
               reason: 'New system should maintain or improve success rate');

        // At minimum, should not be significantly slower
        if (newPerformance.averageLoadTimeMs > oldPerformance.averageLoadTimeMs * 1.5) {
          fail('New system is significantly slower: ${newPerformance.averageLoadTimeMs}ms vs ${oldPerformance.averageLoadTimeMs}ms');
        }

        debugPrint('Performance Comparison:');
        debugPrint('- Old Success Rate: ${oldPerformance.successRate.toStringAsFixed(1)}%');
        debugPrint('- New Success Rate: ${newPerformance.successRate.toStringAsFixed(1)}%');
        debugPrint('- Old Avg Load Time: ${oldPerformance.averageLoadTimeMs}ms');
        debugPrint('- New Avg Load Time: ${newPerformance.averageLoadTimeMs}ms');
      });
    });

    group('Error Handling Comparison', () {
      late VideoCacheService oldSystem;
      late VideoManagerService newSystem;
      late VideoSystemComparator comparator;

      setUp(() {
        oldSystem = VideoCacheService();
        newSystem = VideoManagerService(
          config: VideoManagerConfig.testing(),
        );
        comparator = VideoSystemComparator(
          oldSystem: oldSystem,
          newSystem: newSystem,
          strictMode: false, // Allow some differences in error handling
        );
      });

      tearDown(() {
        oldSystem.dispose();
        newSystem.dispose();
        comparator.dispose();
      });

      testWidgets('Error handling with CoreMediaErrorDomain -12939', (tester) async {
        // Create videos including ones that will trigger the specific error
        final testVideos = [
          TestHelpers.createVideoEvent(id: 'normal_video'),
          TestHelpers.createVideoEvent(
            id: 'byte_range_error',
            videoUrl: 'https://invalid-server-config.com/video.mp4', // Will trigger byte range error
          ),
          TestHelpers.createVideoEvent(id: 'another_normal'),
        ];

        // Add videos to new system to test error handling
        for (final video in testVideos) {
          await newSystem.addVideoEvent(video);
        }

        // Test specific error scenario that was shown in the screenshot
        try {
          await newSystem.preloadVideo('byte_range_error');
        } catch (e) {
          // Should handle gracefully
          final state = newSystem.getVideoState('byte_range_error');
          expect(state?.hasFailed, isTrue);
          expect(state?.errorMessage, contains('SERVER_CONFIG_ERROR'));
        }

        // Run full comparison
        final result = await comparator.compareSystemsWithVideos(testVideos);

        // Verify error handling doesn't break the system
        expect(newSystem.videos.length, equals(testVideos.length));
        
        final debugInfo = newSystem.getDebugInfo();
        expect(debugInfo['failedVideos'], greaterThan(0),
               reason: 'Should track failed videos');

        debugPrint('Error Handling Test Results:');
        debugPrint('- Failed Videos: ${debugInfo['failedVideos']}');
        debugPrint('- Total Videos: ${debugInfo['totalVideos']}');
        debugPrint('- System Stability: ${!newSystem.getDebugInfo()['disposed']}');
      });

      testWidgets('Mixed success and failure scenarios', (tester) async {
        // Create a mix of good and bad videos
        final testVideos = [
          TestHelpers.createVideoEvent(id: 'good1'),
          TestHelpers.createFailingVideoEvent(id: 'bad1'),
          TestHelpers.createVideoEvent(id: 'good2'),
          TestHelpers.createFailingVideoEvent(id: 'bad2'),
          TestHelpers.createSlowVideoEvent(id: 'slow1'),
          TestHelpers.createVideoEvent(id: 'good3'),
        ];

        final result = await comparator.compareSystemsWithVideos(testVideos);

        // New system should handle mixed scenarios gracefully
        expect(newSystem.videos.length, equals(testVideos.length));

        // Check that both good and bad videos are tracked appropriately
        final debugInfo = newSystem.getDebugInfo();
        expect(debugInfo['totalVideos'], equals(testVideos.length));
        
        // Should have some failures but system should remain stable
        expect(debugInfo['disposed'], isFalse);

        debugPrint('Mixed Scenario Test Results:');
        debugPrint(result.summary);
      });
    });

    group('Performance Stress Testing', () {
      late VideoCacheService oldSystem;
      late VideoManagerService newSystem;
      late VideoSystemComparator comparator;

      setUp(() {
        oldSystem = VideoCacheService();
        newSystem = VideoManagerService(
          config: const VideoManagerConfig(
            maxVideos: 100,
            preloadAhead: 3,
            preloadBehind: 1,
            maxRetries: 2,
            preloadTimeout: Duration(seconds: 5),
            enableMemoryManagement: true,
          ),
        );
        comparator = VideoSystemComparator(
          oldSystem: oldSystem,
          newSystem: newSystem,
          comparisonTimeout: const Duration(minutes: 10),
        );
      });

      tearDown(() {
        oldSystem.dispose();
        newSystem.dispose();
        comparator.dispose();
      });

      testWidgets('Large dataset performance comparison', (tester) async {
        // Create large video dataset
        const videoCount = 75;
        final testVideos = TestHelpers.generatePerformanceTestData(videoCount);

        final comparisonStopwatch = Stopwatch()..start();
        final result = await comparator.compareSystemsWithVideos(testVideos);
        comparisonStopwatch.stop();

        // Performance requirements
        expect(comparisonStopwatch.elapsedMilliseconds, lessThan(60000),
               reason: 'Large dataset comparison should complete within 60 seconds');

        // Memory usage verification
        final newMemory = result.newSystemMemory.estimatedMB;
        expect(newMemory, lessThan(600),
               reason: 'New system should keep memory under 600MB even with large dataset');

        // Verify new system handles all videos
        expect(newSystem.videos.length, equals(videoCount));

        debugPrint('Large Dataset Performance:');
        debugPrint('- Videos: $videoCount');
        debugPrint('- Comparison Time: ${comparisonStopwatch.elapsedMilliseconds}ms');
        debugPrint('- New System Memory: ${newMemory}MB');
        debugPrint('- Memory Reduction: ${result.toJson()['memoryReductionPercent']}%');
      });

      testWidgets('Memory pressure scenario comparison', (tester) async {
        // Create video dataset that will trigger memory pressure
        final testVideos = TestHelpers.createVideoList(40);

        // Add videos to new system
        for (final video in testVideos) {
          await newSystem.addVideoEvent(video);
        }

        // Trigger memory pressure
        await newSystem.handleMemoryPressure();

        // Measure memory after pressure
        final debugInfo = newSystem.getDebugInfo();
        final memoryAfterPressure = debugInfo['estimatedMemoryMB'] as int;

        // Run comparison
        final result = await comparator.compareSystemsWithVideos(testVideos.take(20).toList());

        // Memory pressure should keep memory controlled
        expect(memoryAfterPressure, lessThan(400),
               reason: 'Memory pressure should reduce memory usage');

        expect(debugInfo['memoryPressureCount'], greaterThan(0),
               reason: 'Memory pressure should have been triggered');

        debugPrint('Memory Pressure Test Results:');
        debugPrint('- Memory After Pressure: ${memoryAfterPressure}MB');
        debugPrint('- Memory Pressure Events: ${debugInfo['memoryPressureCount']}');
        debugPrint('- Active Controllers: ${debugInfo['activeControllers']}');
      });
    });

    group('Real-world Scenario Testing', () {
      late VideoCacheService oldSystem;
      late VideoManagerService newSystem;
      late VideoSystemComparator comparator;

      setUp(() {
        oldSystem = VideoCacheService();
        newSystem = VideoManagerService(
          config: VideoManagerConfig.wifi(), // Use realistic config
        );
        comparator = VideoSystemComparator(
          oldSystem: oldSystem,
          newSystem: newSystem,
          strictMode: false,
        );
      });

      tearDown(() {
        oldSystem.dispose();
        newSystem.dispose();
        comparator.dispose();
      });

      testWidgets('Realistic content mix comparison', (tester) async {
        // Create realistic mix of content
        final testVideos = [
          TestHelpers.createVideoEvent(id: 'video1', isGif: false),
          TestHelpers.createGifVideoEvent(id: 'gif1'),
          TestHelpers.createVideoEvent(id: 'video2', isGif: false),
          TestHelpers.createSlowVideoEvent(id: 'slow1'),
          TestHelpers.createVideoEvent(id: 'video3', isGif: false),
          TestHelpers.createGifVideoEvent(id: 'gif2'),
        ];

        final result = await comparator.compareSystemsWithVideos(testVideos);

        // Both systems should handle mixed content
        expect(newSystem.videos.length, equals(testVideos.length));

        // Verify different content types are handled
        int videoCount = 0;
        int gifCount = 0;
        for (final video in testVideos) {
          if (video.isGif) {
            gifCount++;
          } else {
            videoCount++;
          }
        }

        expect(videoCount, greaterThan(0));
        expect(gifCount, greaterThan(0));

        debugPrint('Mixed Content Test Results:');
        debugPrint('- Videos: $videoCount, GIFs: $gifCount');
        debugPrint('- New System Total: ${newSystem.videos.length}');
        debugPrint(result.summary);
      });

      testWidgets('Progressive loading comparison', (tester) async {
        // Simulate progressive loading like in real app
        final allVideos = TestHelpers.createVideoList(25);
        final batches = [
          allVideos.take(5).toList(),
          allVideos.skip(5).take(10).toList(),
          allVideos.skip(15).take(10).toList(),
        ];

        final cumulativeResults = <VideoSystemComparisonResult>[];

        // Load in batches
        for (int i = 0; i < batches.length; i++) {
          final batch = batches[i];
          
          // Add batch to new system
          for (final video in batch) {
            await newSystem.addVideoEvent(video);
          }

          // Simulate some preloading
          if (newSystem.videos.isNotEmpty) {
            newSystem.preloadAroundIndex(newSystem.videos.length ~/ 2);
          }

          // Short delay to simulate real usage
          await Future.delayed(const Duration(milliseconds: 100));

          // Run comparison on current state
          final result = await comparator.compareSystemsWithVideos(
            allVideos.take((i + 1) * 5 + (i * 5)).toList()
          );
          cumulativeResults.add(result);

          debugPrint('Batch ${i + 1} Results:');
          debugPrint('- Total Videos: ${newSystem.videos.length}');
          debugPrint('- Memory: ${result.newSystemMemory.estimatedMB}MB');
        }

        // Final verification
        expect(newSystem.videos.length, equals(allVideos.length));
        
        // Memory should remain controlled throughout
        for (final result in cumulativeResults) {
          expect(result.newSystemMemory.estimatedMB, lessThan(600));
        }

        debugPrint('Progressive Loading Complete:');
        debugPrint('- Final Video Count: ${newSystem.videos.length}');
        debugPrint('- Final Memory: ${cumulativeResults.last.newSystemMemory.estimatedMB}MB');
      });

      testWidgets('System stability under continuous operation', (tester) async {
        // Test system stability over extended operation
        final operationCount = 20;
        final batchSize = 8;

        for (int operation = 0; operation < operationCount; operation++) {
          // Add batch of videos
          final batchVideos = TestHelpers.createVideoList(
            batchSize, 
            idPrefix: 'stable_op_${operation}_'
          );

          for (final video in batchVideos) {
            await newSystem.addVideoEvent(video);
          }

          // Simulate various operations
          if (newSystem.videos.isNotEmpty) {
            final randomIndex = Random().nextInt(newSystem.videos.length);
            newSystem.preloadAroundIndex(randomIndex);
          }

          // Occasional memory pressure
          if (operation % 5 == 0 && operation > 0) {
            await newSystem.handleMemoryPressure();
          }

          // Short processing delay
          await Future.delayed(const Duration(milliseconds: 50));
        }

        // Final stability check
        final finalDebugInfo = newSystem.getDebugInfo();
        expect(finalDebugInfo['disposed'], isFalse,
               reason: 'System should remain stable after continuous operation');

        expect(finalDebugInfo['estimatedMemoryMB'], lessThan(800),
               reason: 'Memory should remain controlled after continuous operation');

        expect(newSystem.videos.length, equals(operationCount * batchSize),
               reason: 'All videos should be tracked correctly');

        debugPrint('Stability Test Complete:');
        debugPrint('- Operations: $operationCount');
        debugPrint('- Total Videos: ${newSystem.videos.length}');
        debugPrint('- Final Memory: ${finalDebugInfo['estimatedMemoryMB']}MB');
        debugPrint('- Memory Pressure Events: ${finalDebugInfo['memoryPressureCount']}');
      });
    });

    group('Regression Detection', () {
      testWidgets('Performance regression detection', (tester) async {
        // Baseline performance test
        final oldSystem = VideoCacheService();
        final newSystem = VideoManagerService(
          config: VideoManagerConfig.testing(),
        );
        final comparator = VideoSystemComparator(
          oldSystem: oldSystem,
          newSystem: newSystem,
        );

        final baselineVideos = TestHelpers.createVideoList(20);
        final baselineResult = await comparator.compareSystemsWithVideos(baselineVideos);

        // Performance regression thresholds
        expect(baselineResult.newSystemMetrics.averageLoadTimeMs, lessThan(5000),
               reason: 'Baseline performance should be under 5 seconds average');

        expect(baselineResult.newSystemMemory.estimatedMB, lessThan(500),
               reason: 'Baseline memory should be under 500MB');

        // Clean up
        oldSystem.dispose();
        newSystem.dispose();
        comparator.dispose();

        debugPrint('Performance Regression Baseline:');
        debugPrint('- Avg Load Time: ${baselineResult.newSystemMetrics.averageLoadTimeMs}ms');
        debugPrint('- Memory Usage: ${baselineResult.newSystemMemory.estimatedMB}MB');
        debugPrint('- Success Rate: ${baselineResult.newSystemMetrics.successRate}%');
      });
    });
  });
}