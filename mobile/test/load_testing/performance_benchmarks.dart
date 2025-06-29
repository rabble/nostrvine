// ABOUTME: Performance benchmarking tools for video system load testing
// ABOUTME: Measures throughput, latency, memory usage under various load conditions

import 'dart:async';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/video_manager_interface.dart';
import 'package:openvine/services/video_manager_service.dart';
import '../helpers/test_helpers.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Performance benchmarking suite for video system
/// 
/// This suite provides comprehensive performance testing including:
/// - Throughput measurements
/// - Latency analysis
/// - Memory usage profiling
/// - Scalability testing
/// - Resource utilization monitoring
void main() {
  group('Video System Performance Benchmarks', () {
    
    group('Throughput Benchmarks', () {
      test('video addition throughput test', () async {
        final benchmark = ThroughputBenchmark(
          name: 'Video Addition Throughput',
          duration: Duration(seconds: 10),
        );
        
        final videoManager = VideoManagerService(config: VideoManagerConfig.testing());
        int videosAdded = 0;
        
        try {
          await benchmark.run(() async {
            await videoManager.addVideoEvent(TestHelpers.createVideoEvent(
              id: 'throughput-video-${videosAdded++}',
              title: 'Throughput Test Video $videosAdded',
            ));
          });
          
          final results = benchmark.getResults();
          
          Log.debug('Video Addition Throughput Results:');
          Log.debug('  Operations/second: ${results.operationsPerSecond.toStringAsFixed(2)}');
          Log.debug('  Total operations: ${results.totalOperations}');
          Log.debug('  Average latency: ${results.averageLatency.inMilliseconds}ms');
          Log.debug('  95th percentile: ${results.p95Latency.inMilliseconds}ms');
          Log.debug('  99th percentile: ${results.p99Latency.inMilliseconds}ms');
          
          // Performance targets
          expect(results.operationsPerSecond, greaterThan(100), 
              reason: 'Video addition should handle >100 ops/sec');
          expect(results.averageLatency.inMilliseconds, lessThan(50), 
              reason: 'Average video addition should be <50ms');
          
        } finally {
          videoManager.dispose();
        }
      });
      
      test('concurrent preload throughput test', () async {
        final videoManager = VideoManagerService(config: VideoManagerConfig.testing());
        const int videoCount = 100;
        
        // Add videos first
        for (int i = 0; i < videoCount; i++) {
          await videoManager.addVideoEvent(TestHelpers.createVideoEvent(
            id: 'concurrent-preload-$i',
            title: 'Concurrent Preload Video $i',
          ));
        }
        
        final benchmark = ThroughputBenchmark(
          name: 'Concurrent Preload Throughput',
          duration: Duration(seconds: 15),
        );
        
        int preloadIndex = 0;
        
        try {
          await benchmark.run(() async {
            final videoId = 'concurrent-preload-${preloadIndex % videoCount}';
            preloadIndex++;
            await videoManager.preloadVideo(videoId);
          });
          
          final results = benchmark.getResults();
          
          Log.debug('Concurrent Preload Throughput Results:');
          Log.debug('  Operations/second: ${results.operationsPerSecond.toStringAsFixed(2)}');
          Log.debug('  Total operations: ${results.totalOperations}');
          Log.debug('  Average latency: ${results.averageLatency.inMilliseconds}ms');
          
          // Preload throughput should be reasonable
          expect(results.operationsPerSecond, greaterThan(10), 
              reason: 'Preload should handle >10 ops/sec');
          
        } finally {
          videoManager.dispose();
        }
      });
    });
    
    group('Latency Benchmarks', () {
      test('video state access latency test', () async {
        final videoManager = VideoManagerService(config: VideoManagerConfig.testing());
        const int videoCount = 1000;
        
        // Add videos
        for (int i = 0; i < videoCount; i++) {
          await videoManager.addVideoEvent(TestHelpers.createVideoEvent(
            id: 'latency-test-$i',
            title: 'Latency Test Video $i',
          ));
        }
        
        final benchmark = LatencyBenchmark(name: 'Video State Access');
        final random = Random(42);
        
        try {
          // Measure latency of state access operations
          for (int i = 0; i < 10000; i++) {
            final videoId = 'latency-test-${random.nextInt(videoCount)}';
            
            await benchmark.measure(() async {
              final state = videoManager.getVideoState(videoId);
              expect(state, isNotNull);
            });
          }
          
          final results = benchmark.getResults();
          
          Log.debug('Video State Access Latency Results:');
          Log.debug('  Samples: ${results.sampleCount}');
          Log.debug('  Average: ${results.average.inMicroseconds}μs');
          Log.debug('  Median: ${results.median.inMicroseconds}μs');
          Log.debug('  95th percentile: ${results.p95.inMicroseconds}μs');
          Log.debug('  99th percentile: ${results.p99.inMicroseconds}μs');
          Log.debug('  Max: ${results.max.inMicroseconds}μs');
          
          // State access should be very fast
          expect(results.p95.inMicroseconds, lessThan(1000), 
              reason: '95% of state accesses should be <1ms');
          
        } finally {
          videoManager.dispose();
        }
      });
      
      test('preload around index latency test', () async {
        final videoManager = VideoManagerService(config: VideoManagerConfig.testing());
        const int videoCount = 500;
        
        // Add videos
        for (int i = 0; i < videoCount; i++) {
          await videoManager.addVideoEvent(TestHelpers.createVideoEvent(
            id: 'preload-latency-$i',
            title: 'Preload Latency Video $i',
          ));
        }
        
        final benchmark = LatencyBenchmark(name: 'Preload Around Index');
        final random = Random(42);
        
        try {
          // Measure preload scheduling latency
          for (int i = 0; i < 1000; i++) {
            final index = random.nextInt(videoCount - 10);
            
            await benchmark.measure(() async {
              videoManager.preloadAroundIndex(index, preloadRange: 3);
            });
            
            // Small delay to prevent overwhelming the system
            await Future.delayed(Duration(milliseconds: 1));
          }
          
          final results = benchmark.getResults();
          
          Log.debug('Preload Around Index Latency Results:');
          Log.debug('  Average: ${results.average.inMicroseconds}μs');
          Log.debug('  95th percentile: ${results.p95.inMicroseconds}μs');
          
          // Preload scheduling should be fast
          expect(results.p95.inMilliseconds, lessThan(10), 
              reason: 'Preload scheduling should be <10ms');
          
        } finally {
          videoManager.dispose();
        }
      });
    });
    
    group('Memory Usage Benchmarks', () {
      test('memory usage under sustained load', () async {
        final memoryProfiler = MemoryProfiler();
        final videoManager = VideoManagerService(config: VideoManagerConfig(
          maxVideos: 1000,
          enableMemoryManagement: true,
        ));
        
        try {
          memoryProfiler.startProfiling();
          
          // Sustained load for 30 seconds (accelerated)
          const int durationSeconds = 5; // Reduced for testing
          const int videosPerSecond = 20;
          
          for (int second = 0; second < durationSeconds; second++) {
            for (int i = 0; i < videosPerSecond; i++) {
              final videoIndex = second * videosPerSecond + i;
              await videoManager.addVideoEvent(TestHelpers.createVideoEvent(
                id: 'memory-test-$videoIndex',
                title: 'Memory Test Video $videoIndex',
              ));
              
              // Simulate user scrolling
              if (videoIndex % 10 == 0) {
                videoManager.preloadAroundIndex(videoIndex ~/ 10);
              }
              
              // Record memory usage
              final debugInfo = videoManager.getDebugInfo();
              memoryProfiler.recordMemoryUsage(debugInfo['estimatedMemoryMB'] ?? 0);
            }
            
            // Periodic memory pressure
            if (second % 2 == 1) {
              await videoManager.handleMemoryPressure();
            }
          }
          
          final profile = memoryProfiler.getProfile();
          
          Log.debug('Memory Usage Profile:');
          Log.debug('  Peak memory: ${profile.peakMemoryMB}MB');
          Log.debug('  Average memory: ${profile.averageMemoryMB.toStringAsFixed(1)}MB');
          Log.debug('  Memory growth rate: ${profile.growthRateMBPerSecond.toStringAsFixed(2)}MB/s');
          Log.debug('  Samples: ${profile.sampleCount}');
          
          // Memory should stay within bounds
          expect(profile.peakMemoryMB, lessThan(500), 
              reason: 'Peak memory should stay under 500MB');
          expect(profile.averageMemoryMB, lessThan(300), 
              reason: 'Average memory should stay under 300MB');
          
        } finally {
          memoryProfiler.stopProfiling();
          videoManager.dispose();
        }
      });
      
      test('memory cleanup effectiveness', () async {
        final videoManager = VideoManagerService(config: VideoManagerConfig.testing());
        const int videoCount = 200;
        
        try {
          // Load up system with videos
          for (int i = 0; i < videoCount; i++) {
            await videoManager.addVideoEvent(TestHelpers.createVideoEvent(
              id: 'cleanup-test-$i',
              title: 'Cleanup Test Video $i',
            ));
            
            // Preload every 3rd video
            if (i % 3 == 0) {
              videoManager.preloadVideo('cleanup-test-$i');
            }
          }
          
          // Wait for preloading
          await Future.delayed(Duration(milliseconds: 500));
          
          final beforeCleanup = videoManager.getDebugInfo();
          final memoryBefore = beforeCleanup['estimatedMemoryMB'] as int;
          final controllersBefore = beforeCleanup['activeControllers'] as int;
          
          Log.debug('Before cleanup: ${memoryBefore}MB, $controllersBefore controllers');
          
          // Trigger memory cleanup
          await videoManager.handleMemoryPressure();
          
          final afterCleanup = videoManager.getDebugInfo();
          final memoryAfter = afterCleanup['estimatedMemoryMB'] as int;
          final controllersAfter = afterCleanup['activeControllers'] as int;
          
          Log.debug('After cleanup: ${memoryAfter}MB, $controllersAfter controllers');
          
          final memoryReduction = memoryBefore - memoryAfter;
          final controllerReduction = controllersBefore - controllersAfter;
          
          Log.debug('Memory reduction: ${memoryReduction}MB');
          Log.debug('Controller reduction: $controllerReduction');
          
          // Cleanup should be effective
          expect(memoryReduction, greaterThan(0), 
              reason: 'Memory cleanup should reduce memory usage');
          expect(controllersAfter, lessThan(controllersBefore), 
              reason: 'Memory cleanup should dispose some controllers');
          
        } finally {
          videoManager.dispose();
        }
      });
    });
    
    group('Scalability Benchmarks', () {
      test('performance vs video count scaling', () async {
        final scalabilityResults = <int, ScalabilityMetrics>{};
        final videoCountLevels = [10, 50, 100, 500, 1000];
        
        for (final videoCount in videoCountLevels) {
          final videoManager = VideoManagerService(config: VideoManagerConfig.testing());
          
          try {
            final startTime = DateTime.now();
            
            // Add videos
            for (int i = 0; i < videoCount; i++) {
              await videoManager.addVideoEvent(TestHelpers.createVideoEvent(
                id: 'scale-test-$videoCount-$i',
                title: 'Scale Test Video $i',
              ));
            }
            
            final addDuration = DateTime.now().difference(startTime);
            
            // Measure state access performance
            final accessStartTime = DateTime.now();
            for (int i = 0; i < 1000; i++) {
              final randomIndex = Random().nextInt(videoCount);
              videoManager.getVideoState('scale-test-$videoCount-$randomIndex');
            }
            final accessDuration = DateTime.now().difference(accessStartTime);
            
            // Measure preload scheduling performance
            final preloadStartTime = DateTime.now();
            for (int i = 0; i < 100; i++) {
              final randomIndex = Random().nextInt(videoCount);
              videoManager.preloadAroundIndex(randomIndex);
            }
            final preloadDuration = DateTime.now().difference(preloadStartTime);
            
            final debugInfo = videoManager.getDebugInfo();
            
            scalabilityResults[videoCount] = ScalabilityMetrics(
              videoCount: videoCount,
              addTimePerVideo: Duration(milliseconds: addDuration.inMilliseconds ~/ videoCount),
              accessTimePerOperation: Duration(microseconds: accessDuration.inMicroseconds ~/ 1000),
              preloadTimePerOperation: Duration(microseconds: preloadDuration.inMicroseconds ~/ 100),
              memoryUsageMB: debugInfo['estimatedMemoryMB'] ?? 0,
            );
            
          } finally {
            videoManager.dispose();
          }
        }
        
        // Analyze scalability
        Log.debug('\nScalability Analysis:');
        Log.debug('Videos | Add(ms) | Access(μs) | Preload(μs) | Memory(MB)');
        Log.debug('-------|---------|------------|-------------|----------');
        
        for (final entry in scalabilityResults.entries) {
          final count = entry.key;
          final metrics = entry.value;
          
          Log.debug('${count.toString().padLeft(6)} | '
              '${metrics.addTimePerVideo.inMilliseconds.toString().padLeft(7)} | '
              '${metrics.accessTimePerOperation.inMicroseconds.toString().padLeft(10)} | '
              '${metrics.preloadTimePerOperation.inMicroseconds.toString().padLeft(11)} | '
              '${metrics.memoryUsageMB.toString().padLeft(9)}');
        }
        
        // Verify scalability characteristics
        final results10 = scalabilityResults[10]!;
        final results1000 = scalabilityResults[1000]!;
        
        // Performance should not degrade significantly with scale
        final accessSlowdown = results1000.accessTimePerOperation.inMicroseconds / 
                              results10.accessTimePerOperation.inMicroseconds;
        
        expect(accessSlowdown, lessThan(3.0), 
            reason: 'Access time should not slow down more than 3x with 100x more videos');
        
        // Memory should scale reasonably
        final memoryScaling = results1000.memoryUsageMB / results10.memoryUsageMB;
        expect(memoryScaling, lessThan(20.0), 
            reason: 'Memory should not scale more than 20x with 100x more videos');
      });
    });
  });
}

// Benchmarking utilities

class ThroughputBenchmark {
  final String name;
  final Duration duration;
  final List<Duration> _operationTimes = [];
  late DateTime _startTime;
  late DateTime _endTime;
  
  ThroughputBenchmark({
    required this.name,
    required this.duration,
  });
  
  Future<void> run(Future<void> Function() operation) async {
    _startTime = DateTime.now();
    final endTime = _startTime.add(duration);
    
    while (DateTime.now().isBefore(endTime)) {
      final opStartTime = DateTime.now();
      await operation();
      final opEndTime = DateTime.now();
      
      _operationTimes.add(opEndTime.difference(opStartTime));
    }
    
    _endTime = DateTime.now();
  }
  
  ThroughputResults getResults() {
    final totalDuration = _endTime.difference(_startTime);
    final operationsPerSecond = _operationTimes.length / totalDuration.inSeconds;
    
    _operationTimes.sort();
    
    return ThroughputResults(
      operationsPerSecond: operationsPerSecond,
      totalOperations: _operationTimes.length,
      averageLatency: _calculateAverage(_operationTimes),
      p95Latency: _percentile(_operationTimes, 0.95),
      p99Latency: _percentile(_operationTimes, 0.99),
    );
  }
  
  Duration _calculateAverage(List<Duration> durations) {
    if (durations.isEmpty) return Duration.zero;
    
    final totalMicroseconds = durations.fold(0, (sum, d) => sum + d.inMicroseconds);
    return Duration(microseconds: totalMicroseconds ~/ durations.length);
  }
  
  Duration _percentile(List<Duration> sortedDurations, double percentile) {
    if (sortedDurations.isEmpty) return Duration.zero;
    
    final index = ((sortedDurations.length - 1) * percentile).round();
    return sortedDurations[index];
  }
}

class LatencyBenchmark {
  final String name;
  final List<Duration> _measurements = [];
  
  LatencyBenchmark({required this.name});
  
  Future<void> measure(Future<void> Function() operation) async {
    final startTime = DateTime.now();
    await operation();
    final endTime = DateTime.now();
    
    _measurements.add(endTime.difference(startTime));
  }
  
  LatencyResults getResults() {
    if (_measurements.isEmpty) {
      return LatencyResults(
        sampleCount: 0,
        average: Duration.zero,
        median: Duration.zero,
        p95: Duration.zero,
        p99: Duration.zero,
        max: Duration.zero,
      );
    }
    
    final sorted = List<Duration>.from(_measurements)..sort();
    
    return LatencyResults(
      sampleCount: _measurements.length,
      average: _calculateAverage(_measurements),
      median: _percentile(sorted, 0.5),
      p95: _percentile(sorted, 0.95),
      p99: _percentile(sorted, 0.99),
      max: sorted.last,
    );
  }
  
  Duration _calculateAverage(List<Duration> durations) {
    final totalMicroseconds = durations.fold(0, (sum, d) => sum + d.inMicroseconds);
    return Duration(microseconds: totalMicroseconds ~/ durations.length);
  }
  
  Duration _percentile(List<Duration> sortedDurations, double percentile) {
    final index = ((sortedDurations.length - 1) * percentile).round();
    return sortedDurations[index];
  }
}

class MemoryProfiler {
  final List<MemorySample> _samples = [];
  Timer? _samplingTimer;
  bool _profiling = false;
  
  void startProfiling({Duration interval = const Duration(milliseconds: 100)}) {
    _profiling = true;
    _samples.clear();
    
    _samplingTimer = Timer.periodic(interval, (_) {
      if (_profiling) {
        _samples.add(MemorySample(
          timestamp: DateTime.now(),
          memoryMB: 0, // Will be set by recordMemoryUsage
        ));
      }
    });
  }
  
  void stopProfiling() {
    _profiling = false;
    _samplingTimer?.cancel();
    _samplingTimer = null;
  }
  
  void recordMemoryUsage(int memoryMB) {
    if (_profiling && _samples.isNotEmpty) {
      final lastSample = _samples.last;
      if (lastSample.memoryMB == 0) {
        _samples[_samples.length - 1] = MemorySample(
          timestamp: lastSample.timestamp,
          memoryMB: memoryMB,
        );
      }
    }
  }
  
  MemoryProfile getProfile() {
    if (_samples.isEmpty) {
      return MemoryProfile(
        sampleCount: 0,
        peakMemoryMB: 0,
        averageMemoryMB: 0.0,
        growthRateMBPerSecond: 0.0,
      );
    }
    
    final validSamples = _samples.where((s) => s.memoryMB > 0).toList();
    
    if (validSamples.isEmpty) {
      return MemoryProfile(
        sampleCount: 0,
        peakMemoryMB: 0,
        averageMemoryMB: 0.0,
        growthRateMBPerSecond: 0.0,
      );
    }
    
    final peakMemory = validSamples.map((s) => s.memoryMB).reduce(max);
    final averageMemory = validSamples.fold(0, (sum, s) => sum + s.memoryMB) / validSamples.length;
    
    // Calculate growth rate
    double growthRate = 0.0;
    if (validSamples.length > 1) {
      final firstSample = validSamples.first;
      final lastSample = validSamples.last;
      final timeDiff = lastSample.timestamp.difference(firstSample.timestamp).inSeconds;
      if (timeDiff > 0) {
        growthRate = (lastSample.memoryMB - firstSample.memoryMB) / timeDiff;
      }
    }
    
    return MemoryProfile(
      sampleCount: validSamples.length,
      peakMemoryMB: peakMemory,
      averageMemoryMB: averageMemory,
      growthRateMBPerSecond: growthRate,
    );
  }
}

// Result classes

class ThroughputResults {
  final double operationsPerSecond;
  final int totalOperations;
  final Duration averageLatency;
  final Duration p95Latency;
  final Duration p99Latency;
  
  const ThroughputResults({
    required this.operationsPerSecond,
    required this.totalOperations,
    required this.averageLatency,
    required this.p95Latency,
    required this.p99Latency,
  });
}

class LatencyResults {
  final int sampleCount;
  final Duration average;
  final Duration median;
  final Duration p95;
  final Duration p99;
  final Duration max;
  
  const LatencyResults({
    required this.sampleCount,
    required this.average,
    required this.median,
    required this.p95,
    required this.p99,
    required this.max,
  });
}

class MemoryProfile {
  final int sampleCount;
  final int peakMemoryMB;
  final double averageMemoryMB;
  final double growthRateMBPerSecond;
  
  const MemoryProfile({
    required this.sampleCount,
    required this.peakMemoryMB,
    required this.averageMemoryMB,
    required this.growthRateMBPerSecond,
  });
}

class ScalabilityMetrics {
  final int videoCount;
  final Duration addTimePerVideo;
  final Duration accessTimePerOperation;
  final Duration preloadTimePerOperation;
  final int memoryUsageMB;
  
  const ScalabilityMetrics({
    required this.videoCount,
    required this.addTimePerVideo,
    required this.accessTimePerOperation,
    required this.preloadTimePerOperation,
    required this.memoryUsageMB,
  });
}

class MemorySample {
  final DateTime timestamp;
  final int memoryMB;
  
  const MemorySample({
    required this.timestamp,
    required this.memoryMB,
  });
}
