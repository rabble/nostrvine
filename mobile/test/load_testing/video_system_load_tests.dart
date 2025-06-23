// ABOUTME: Load testing scenarios for video system under realistic usage patterns
// ABOUTME: Tests memory limits, concurrent operations, and stress conditions

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/models/video_state.dart';
import 'package:openvine/services/video_manager_interface.dart';
import 'package:openvine/services/video_manager_service.dart';
import 'package:openvine/services/video_performance_monitor.dart';
import '../helpers/test_helpers.dart';
import '../mocks/mock_video_manager.dart';

/// Comprehensive load testing suite for video system
/// 
/// These tests simulate real-world usage patterns including:
/// - Heavy feed scrolling
/// - Concurrent video loading
/// - Memory pressure scenarios
/// - Network condition variations
/// - Long-running sessions
void main() {
  group('Video System Load Tests', () {
    late VideoManagerService videoManager;
    late VideoPerformanceMonitor performanceMonitor;
    
    setUp(() {
      videoManager = VideoManagerService(
        config: VideoManagerConfig.testing(), // Fast timeouts for testing
      );
      
      performanceMonitor = VideoPerformanceMonitor(
        videoManager: videoManager,
        samplingInterval: Duration(milliseconds: 100),
        maxSampleHistory: 500,
      );
      
      performanceMonitor.startMonitoring();
    });
    
    tearDown(() {
      performanceMonitor.dispose();
      videoManager.dispose();
    });
    
    group('Feed Scrolling Load Tests', () {
      test('should handle rapid feed scrolling with 1000 videos', () async {
        const int videoCount = 1000;
        const int scrollSpeed = 10; // Videos per second
        
        // Add videos rapidly
        final videos = <VideoEvent>[];
        for (int i = 0; i < videoCount; i++) {
          final video = TestHelpers.createVideoEvent(
            id: 'rapid-scroll-video-$i',
            title: 'Rapid Scroll Video $i',
          );
          videos.add(video);
          await videoManager.addVideoEvent(video);
          
          // Simulate scrolling - preload around current position
          if (i % 10 == 0) {
            videoManager.preloadAroundIndex(i ~/ 10, preloadRange: 2);
            await Future.delayed(Duration(milliseconds: 100)); // Scrolling delay
          }
        }
        
        // Verify system stability
        expect(videoManager.videos.length, equals(videoCount));
        
        final debugInfo = videoManager.getDebugInfo();
        expect(debugInfo['estimatedMemoryMB'], lessThan(500));
        expect(debugInfo['controllers'], lessThan(16));
        
        // Test rapid scrolling through feed
        for (int currentIndex = 0; currentIndex < videoCount; currentIndex += scrollSpeed) {
          videoManager.preloadAroundIndex(currentIndex, preloadRange: 3);
          
          // Very fast scrolling
          await Future.delayed(Duration(milliseconds: 100));
          
          // Check memory every 100 videos
          if (currentIndex % 100 == 0) {
            final memoryCheck = videoManager.getDebugInfo();
            expect(memoryCheck['estimatedMemoryMB'], lessThan(500),
                reason: 'Memory exceeded limit at video $currentIndex');
          }
        }
        
        // Final system health check
        final finalStats = performanceMonitor.getStatistics();
        expect(finalStats.currentMemoryMB, lessThan(500));
        expect(finalStats.currentControllers, lessThan(16));
      });
      
      test('should handle back-and-forth scrolling patterns', () async {
        const int videoCount = 200;
        
        // Add test videos
        for (int i = 0; i < videoCount; i++) {
          await videoManager.addVideoEvent(TestHelpers.createVideoEvent(
            id: 'scroll-pattern-$i',
            title: 'Scroll Pattern Video $i',
          ));
        }
        
        // Simulate realistic scrolling patterns
        final scrollPattern = [
          // Forward scrolling
          ...List.generate(50, (i) => i),
          // Back scrolling 
          ...List.generate(30, (i) => 49 - i),
          // Jump forward
          ...List.generate(40, (i) => 80 + i),
          // Back to beginning
          ...List.generate(20, (i) => 19 - i),
          // Random jumps
          ...List.generate(30, (i) => Random().nextInt(videoCount)),
        ];
        
        for (final index in scrollPattern) {
          videoManager.preloadAroundIndex(index, preloadRange: 2);
          await Future.delayed(Duration(milliseconds: 50));
          
          // Verify memory bounds
          final debugInfo = videoManager.getDebugInfo();
          expect(debugInfo['estimatedMemoryMB'], lessThan(500));
        }
        
        // Verify no memory leaks
        final finalMemory = videoManager.getDebugInfo()['estimatedMemoryMB'];
        expect(finalMemory, lessThan(400)); // Should be even lower after cleanup
      });
    });
    
    group('Concurrent Operation Load Tests', () {
      test('should handle 50 concurrent video preloads', () async {
        const int concurrentCount = 50;
        
        // Create videos
        final videos = <VideoEvent>[];
        for (int i = 0; i < concurrentCount; i++) {
          final video = TestHelpers.createVideoEvent(
            id: 'concurrent-$i',
            title: 'Concurrent Video $i',
          );
          videos.add(video);
          await videoManager.addVideoEvent(video);
        }
        
        // Start concurrent preloads
        final futures = <Future<void>>[];
        final startTime = DateTime.now();
        
        for (final video in videos) {
          futures.add(videoManager.preloadVideo(video.id));
        }
        
        // Wait for all preloads to complete or timeout
        try {
          await Future.wait(futures, eagerError: false);
        } catch (e) {
          // Some preloads may fail due to resource limits - that's expected
          debugPrint('Some concurrent preloads failed: $e');
        }
        
        final duration = DateTime.now().difference(startTime);
        debugPrint('Concurrent preload duration: ${duration.inMilliseconds}ms');
        
        // Verify system didn't crash and memory is bounded
        final debugInfo = videoManager.getDebugInfo();
        expect(debugInfo['estimatedMemoryMB'], lessThan(500));
        expect(debugInfo['controllers'], lessThan(16));
        
        // At least some videos should have loaded successfully
        expect(debugInfo['readyVideos'], greaterThan(5));
      });
      
      test('should handle mixed operations under load', () async {
        const int operationCount = 200;
        final random = Random(42); // Seeded for reproducibility
        
        // Mixed operations: add, preload, dispose
        final futures = <Future<void>>[];
        
        for (int i = 0; i < operationCount; i++) {
          final operation = random.nextInt(3);
          
          switch (operation) {
            case 0: // Add video
              futures.add(_addRandomVideo(videoManager, i));
              break;
            case 1: // Preload video
              futures.add(_preloadRandomVideo(videoManager, i));
              break;
            case 2: // Dispose video
              futures.add(_disposeRandomVideo(videoManager, i));
              break;
          }
          
          // Small delay to simulate realistic timing
          await Future.delayed(Duration(milliseconds: 10));
        }
        
        // Wait for operations to complete
        await Future.wait(futures, eagerError: false);
        
        // Verify system stability
        final debugInfo = videoManager.getDebugInfo();
        expect(debugInfo['totalVideos'], greaterThan(0));
        expect(debugInfo['estimatedMemoryMB'], lessThan(500));
      });
    });
    
    group('Memory Pressure Load Tests', () {
      test('should handle aggressive memory pressure scenarios', () async {
        const int videoCount = 300;
        
        // Add many videos to trigger memory pressure
        for (int i = 0; i < videoCount; i++) {
          await videoManager.addVideoEvent(TestHelpers.createVideoEvent(
            id: 'memory-pressure-$i',
            title: 'Memory Pressure Video $i',
          ));
          
          // Try to preload every video to max out memory
          videoManager.preloadVideo('memory-pressure-$i');
          
          // Trigger memory pressure every 20 videos
          if (i % 20 == 0) {
            await videoManager.handleMemoryPressure();
          }
        }
        
        // Final memory pressure cleanup
        await videoManager.handleMemoryPressure();
        
        // Verify memory is within bounds
        final debugInfo = videoManager.getDebugInfo();
        expect(debugInfo['estimatedMemoryMB'], lessThan(200)); // Should be very low after cleanup
        expect(debugInfo['controllers'], lessThan(5)); // Most should be disposed
      });
      
      test('should recover from extreme memory pressure', () async {
        // Simulate system under extreme load
        for (int round = 0; round < 5; round++) {
          // Load up the system
          for (int i = 0; i < 100; i++) {
            await videoManager.addVideoEvent(TestHelpers.createVideoEvent(
              id: 'extreme-pressure-$round-$i',
              title: 'Extreme Pressure Video $round-$i',
            ));
            videoManager.preloadVideo('extreme-pressure-$round-$i');
          }
          
          // Trigger aggressive cleanup
          await videoManager.handleMemoryPressure();
          await videoManager.handleMemoryPressure(); // Double cleanup
          
          // Verify recovery
          final debugInfo = videoManager.getDebugInfo();
          expect(debugInfo['estimatedMemoryMB'], lessThan(300));
          
          debugPrint('Round $round: Memory=${debugInfo['estimatedMemoryMB']}MB, Controllers=${debugInfo['controllers']}');
        }
      });
    });
    
    group('Network Condition Simulation', () {
      test('should handle slow network conditions', () async {
        // Use longer timeouts to simulate slow network
        final slowVideoManager = VideoManagerService(
          config: VideoManagerConfig(
            preloadTimeout: Duration(seconds: 15), // Slow network timeout
            maxRetries: 5,
          ),
        );
        
        try {
          const int videoCount = 50;
          final slowLoadingVideos = <String>[];
          
          // Add videos that will load slowly
          for (int i = 0; i < videoCount; i++) {
            final video = TestHelpers.createVideoEvent(
              id: 'slow-network-$i',
              title: 'Slow Network Video $i',
              // Use URLs that will timeout for some videos
              videoUrl: i % 3 == 0 ? 'https://slow-server/video-$i.mp4' : null,
            );
            
            await slowVideoManager.addVideoEvent(video);
            
            if (video.videoUrl != null) {
              slowLoadingVideos.add(video.id);
              // Don't await - let them load in background
              slowVideoManager.preloadVideo(video.id);
            }
          }
          
          // Wait a bit for preloading attempts
          await Future.delayed(Duration(seconds: 2));
          
          // Check that system handles slow/failing loads gracefully
          final debugInfo = slowVideoManager.getDebugInfo();
          expect(debugInfo['totalVideos'], equals(videoCount));
          expect(debugInfo['estimatedMemoryMB'], lessThan(500));
          
          // Some videos should be in loading or failed state
          final loadingCount = debugInfo['loadingVideos'] as int;
          final failedCount = debugInfo['failedVideos'] as int;
          expect(loadingCount + failedCount, greaterThan(0));
          
        } finally {
          slowVideoManager.dispose();
        }
      });
      
      test('should handle intermittent connectivity', () async {
        const int videoCount = 100;
        final connectivityPattern = [true, true, false, true, false, false, true, true, true, false];
        
        for (int i = 0; i < videoCount; i++) {
          final isConnected = connectivityPattern[i % connectivityPattern.length];
          
          await videoManager.addVideoEvent(TestHelpers.createVideoEvent(
            id: 'intermittent-$i',
            title: 'Intermittent Video $i',
            // Simulate connectivity by using failing URLs when "disconnected"
            videoUrl: isConnected ? 'https://example.com/video-$i.mp4' : 'https://unreachable/video-$i.mp4',
          ));
          
          // Try to preload
          if (isConnected) {
            videoManager.preloadVideo('intermittent-$i');
          }
        }
        
        // System should remain stable despite connectivity issues
        final debugInfo = videoManager.getDebugInfo();
        expect(debugInfo['totalVideos'], equals(videoCount));
        expect(debugInfo['estimatedMemoryMB'], lessThan(500));
      });
    });
    
    group('Long-Running Session Tests', () {
      test('should maintain stability over extended usage', () async {
        const int sessionDurationMinutes = 5; // Simulated long session
        const int videosPerMinute = 20;
        
        final sessionStartTime = DateTime.now();
        int totalVideosAdded = 0;
        int currentIndex = 0;
        
        // Simulate 5-minute session with continuous activity
        while (DateTime.now().difference(sessionStartTime).inMinutes < sessionDurationMinutes) {
          // Add new videos
          for (int i = 0; i < videosPerMinute; i++) {
            await videoManager.addVideoEvent(TestHelpers.createVideoEvent(
              id: 'session-video-${totalVideosAdded + i}',
              title: 'Session Video ${totalVideosAdded + i}',
            ));
          }
          totalVideosAdded += videosPerMinute;
          
          // Simulate user scrolling
          final scrollJump = Random().nextInt(10) + 1;
          currentIndex = (currentIndex + scrollJump) % totalVideosAdded;
          videoManager.preloadAroundIndex(currentIndex, preloadRange: 3);
          
          // Periodic memory pressure
          if (totalVideosAdded % 100 == 0) {
            await videoManager.handleMemoryPressure();
          }
          
          // Check system health
          final debugInfo = videoManager.getDebugInfo();
          expect(debugInfo['estimatedMemoryMB'], lessThan(500),
              reason: 'Memory exceeded at $totalVideosAdded videos');
          
          // Simulate time passing (1 minute)
          await Future.delayed(Duration(milliseconds: 100)); // Accelerated for testing
        }
        
        // Final verification
        final finalStats = performanceMonitor.getStatistics();
        expect(finalStats.totalVideos, equals(totalVideosAdded));
        expect(finalStats.currentMemoryMB, lessThan(500));
        
        debugPrint('Session completed: $totalVideosAdded videos, ${finalStats.currentMemoryMB}MB memory');
      });
      
      test('should handle memory cleanup cycles over time', () async {
        const int cycles = 10;
        const int videosPerCycle = 50;
        
        for (int cycle = 0; cycle < cycles; cycle++) {
          // Add videos
          for (int i = 0; i < videosPerCycle; i++) {
            await videoManager.addVideoEvent(TestHelpers.createVideoEvent(
              id: 'cycle-$cycle-video-$i',
              title: 'Cycle $cycle Video $i',
            ));
          }
          
          // Preload some videos
          for (int i = 0; i < videosPerCycle; i += 3) {
            videoManager.preloadVideo('cycle-$cycle-video-$i');
          }
          
          // Memory cleanup every other cycle
          if (cycle % 2 == 1) {
            await videoManager.handleMemoryPressure();
          }
          
          final debugInfo = videoManager.getDebugInfo();
          debugPrint('Cycle $cycle: Videos=${debugInfo['totalVideos']}, Memory=${debugInfo['estimatedMemoryMB']}MB');
          
          expect(debugInfo['estimatedMemoryMB'], lessThan(500));
        }
        
        // Verify final cleanup
        await videoManager.handleMemoryPressure();
        final finalMemory = videoManager.getDebugInfo()['estimatedMemoryMB'];
        expect(finalMemory, lessThan(200));
      });
    });
    
    group('Performance Benchmark Tests', () {
      test('should meet performance targets under load', () async {
        const int benchmarkVideoCount = 100;
        final operationTimes = <String, List<Duration>>{};
        
        // Benchmark video addition
        final addTimes = <Duration>[];
        for (int i = 0; i < benchmarkVideoCount; i++) {
          final startTime = DateTime.now();
          await videoManager.addVideoEvent(TestHelpers.createVideoEvent(
            id: 'benchmark-$i',
            title: 'Benchmark Video $i',
          ));
          addTimes.add(DateTime.now().difference(startTime));
        }
        operationTimes['add_video'] = addTimes;
        
        // Benchmark preloading
        final preloadTimes = <Duration>[];
        for (int i = 0; i < benchmarkVideoCount; i += 5) {
          final startTime = DateTime.now();
          videoManager.preloadVideo('benchmark-$i');
          preloadTimes.add(DateTime.now().difference(startTime));
        }
        operationTimes['preload_video'] = preloadTimes;
        
        // Calculate and verify performance metrics
        for (final entry in operationTimes.entries) {
          final operation = entry.key;
          final times = entry.value;
          
          final avgTime = times.fold(Duration.zero, (sum, time) => sum + time) ~/ times.length;
          final maxTime = times.reduce((a, b) => a > b ? a : b);
          
          debugPrint('$operation: avg=${avgTime.inMilliseconds}ms, max=${maxTime.inMilliseconds}ms');
          
          // Performance targets
          expect(avgTime.inMilliseconds, lessThan(100), reason: '$operation average time too slow');
          expect(maxTime.inMilliseconds, lessThan(500), reason: '$operation max time too slow');
        }
      });
      
      test('should maintain consistent performance under varying load', () async {
        final performanceData = <int, Duration>{};
        final loadLevels = [10, 50, 100, 200, 500];
        
        for (final loadLevel in loadLevels) {
          // Clear previous state
          videoManager.dispose();
          videoManager = VideoManagerService(config: VideoManagerConfig.testing());
          
          // Add videos for this load level
          for (int i = 0; i < loadLevel; i++) {
            await videoManager.addVideoEvent(TestHelpers.createVideoEvent(
              id: 'load-$loadLevel-$i',
              title: 'Load Test Video $i',
            ));
          }
          
          // Benchmark operation at this load level
          final startTime = DateTime.now();
          videoManager.preloadAroundIndex(loadLevel ~/ 2, preloadRange: 3);
          await Future.delayed(Duration(milliseconds: 100)); // Allow processing
          final operationTime = DateTime.now().difference(startTime);
          
          performanceData[loadLevel] = operationTime;
          debugPrint('Load $loadLevel: ${operationTime.inMilliseconds}ms');
        }
        
        // Verify performance doesn't degrade significantly with load
        final times = performanceData.values.toList();
        final firstTime = times.first.inMilliseconds;
        final lastTime = times.last.inMilliseconds;
        
        // Performance should not degrade more than 3x under 50x load increase
        expect(lastTime, lessThan(firstTime * 3),
            reason: 'Performance degraded too much under load');
      });
    });
  });
}

// Helper functions for load testing

Future<void> _addRandomVideo(IVideoManager videoManager, int index) async {
  try {
    await videoManager.addVideoEvent(TestHelpers.createVideoEvent(
      id: 'random-add-$index',
      title: 'Random Video $index',
    ));
  } catch (e) {
    // Ignore errors in load testing
  }
}

Future<void> _preloadRandomVideo(IVideoManager videoManager, int index) async {
  try {
    final videos = videoManager.videos;
    if (videos.isNotEmpty) {
      final randomVideo = videos[Random().nextInt(videos.length)];
      await videoManager.preloadVideo(randomVideo.id);
    }
  } catch (e) {
    // Ignore errors in load testing
  }
}

Future<void> _disposeRandomVideo(IVideoManager videoManager, int index) async {
  try {
    final videos = videoManager.videos;
    if (videos.isNotEmpty) {
      final randomVideo = videos[Random().nextInt(videos.length)];
      videoManager.disposeVideo(randomVideo.id);
    }
  } catch (e) {
    // Ignore errors in load testing
  }
}