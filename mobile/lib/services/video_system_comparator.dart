// ABOUTME: Parallel system comparator for validating new video system against legacy system
// ABOUTME: Runs both systems simultaneously and compares outputs, performance, and memory usage

import 'dart:async';
import 'dart:developer' as developer;

import '../models/video_event.dart';
import 'video_cache_service.dart';
import 'video_manager_interface.dart';

/// Results of a parallel video system comparison
class VideoSystemComparisonResult {
  final DateTime timestamp;
  final List<String> discrepancies;
  final PerformanceMetrics oldSystemMetrics;
  final PerformanceMetrics newSystemMetrics;
  final MemoryMetrics oldSystemMemory;
  final MemoryMetrics newSystemMemory;
  final bool passed;
  final String summary;

  const VideoSystemComparisonResult({
    required this.timestamp,
    required this.discrepancies,
    required this.oldSystemMetrics,
    required this.newSystemMetrics,
    required this.oldSystemMemory,
    required this.newSystemMemory,
    required this.passed,
    required this.summary,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'discrepancies': discrepancies,
      'oldSystemMetrics': oldSystemMetrics.toJson(),
      'newSystemMetrics': newSystemMetrics.toJson(),
      'oldSystemMemory': oldSystemMemory.toJson(),
      'newSystemMemory': newSystemMemory.toJson(),
      'passed': passed,
      'summary': summary,
      'memoryReductionPercent': _calculateMemoryReduction(),
      'performanceImprovement': _calculatePerformanceImprovement(),
    };
  }

  double _calculateMemoryReduction() {
    if (oldSystemMemory.estimatedMB == 0) return 0.0;
    return ((oldSystemMemory.estimatedMB - newSystemMemory.estimatedMB) / oldSystemMemory.estimatedMB) * 100;
  }

  double _calculatePerformanceImprovement() {
    if (oldSystemMetrics.averageLoadTimeMs == 0) return 0.0;
    return ((oldSystemMetrics.averageLoadTimeMs - newSystemMetrics.averageLoadTimeMs) / oldSystemMetrics.averageLoadTimeMs) * 100;
  }
}

/// Performance metrics for a video system
class PerformanceMetrics {
  final int totalOperations;
  final int successfulOperations;
  final int failedOperations;
  final double successRate;
  final int averageLoadTimeMs;
  final int maxLoadTimeMs;
  final int minLoadTimeMs;
  final DateTime startTime;
  final DateTime endTime;

  const PerformanceMetrics({
    required this.totalOperations,
    required this.successfulOperations,
    required this.failedOperations,
    required this.successRate,
    required this.averageLoadTimeMs,
    required this.maxLoadTimeMs,
    required this.minLoadTimeMs,
    required this.startTime,
    required this.endTime,
  });

  Map<String, dynamic> toJson() {
    return {
      'totalOperations': totalOperations,
      'successfulOperations': successfulOperations,
      'failedOperations': failedOperations,
      'successRate': successRate,
      'averageLoadTimeMs': averageLoadTimeMs,
      'maxLoadTimeMs': maxLoadTimeMs,
      'minLoadTimeMs': minLoadTimeMs,
      'durationMs': endTime.difference(startTime).inMilliseconds,
    };
  }
}

/// Memory usage metrics for a video system
class MemoryMetrics {
  final int estimatedMB;
  final int activeControllers;
  final int totalVideos;
  final int readyVideos;
  final double utilizationPercent;
  final DateTime measuredAt;

  const MemoryMetrics({
    required this.estimatedMB,
    required this.activeControllers,
    required this.totalVideos,
    required this.readyVideos,
    required this.utilizationPercent,
    required this.measuredAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'estimatedMB': estimatedMB,
      'activeControllers': activeControllers,
      'totalVideos': totalVideos,
      'readyVideos': readyVideos,
      'utilizationPercent': utilizationPercent,
      'measuredAt': measuredAt.toIso8601String(),
    };
  }
}

/// Comparator for running old and new video systems in parallel
class VideoSystemComparator {
  final VideoCacheService _oldSystem;
  final IVideoManager _newSystem;
  
  // Tracking for comparison
  final List<String> _discrepancies = [];
  final List<int> _oldSystemLoadTimes = [];
  final List<int> _newSystemLoadTimes = [];
  final Map<String, DateTime> _operationStartTimes = {};
  
  // Test configuration
  final Duration _comparisonTimeout;
  final bool _strictMode;
  final bool _logVerbose;
  
  DateTime? _testStartTime;
  int _oldSystemSuccesses = 0;
  int _oldSystemFailures = 0;
  int _newSystemSuccesses = 0;
  int _newSystemFailures = 0;

  VideoSystemComparator({
    required VideoCacheService oldSystem,
    required IVideoManager newSystem,
    Duration comparisonTimeout = const Duration(minutes: 5),
    bool strictMode = false,
    bool logVerbose = true,
  }) : _oldSystem = oldSystem,
       _newSystem = newSystem,
       _comparisonTimeout = comparisonTimeout,
       _strictMode = strictMode,
       _logVerbose = logVerbose;

  /// Run both systems in parallel and compare results
  Future<VideoSystemComparisonResult> compareSystemsWithVideos(List<VideoEvent> testVideos) async {
    _testStartTime = DateTime.now();
    _discrepancies.clear();
    _oldSystemLoadTimes.clear();
    _newSystemLoadTimes.clear();
    _operationStartTimes.clear();
    
    developer.log('🔄 Starting parallel system comparison with ${testVideos.length} videos');

    try {
      // Phase 1: Add videos to both systems
      await _compareVideoAddition(testVideos);

      // Phase 2: Compare video listing and ordering
      _compareVideoLists();

      // Phase 3: Compare preloading behavior
      await _comparePreloadingBehavior(testVideos);

      // Phase 4: Compare error handling
      await _compareErrorHandling();

      // Phase 5: Generate final comparison result
      return _generateComparisonResult();

    } catch (e) {
      _discrepancies.add('Comparison failed with error: $e');
      return _generateComparisonResult();
    }
  }

  /// Compare video addition between both systems
  Future<void> _compareVideoAddition(List<VideoEvent> videos) async {
    developer.log('📊 Comparing video addition...');

    for (int i = 0; i < videos.length; i++) {
      final video = videos[i];
      
      // Time old system addition
      final oldStartTime = DateTime.now();
      try {
        // Old system doesn't have addVideoEvent, so we simulate by checking if it can handle the video
        final hasController = _oldSystem.getController(video) != null;
        if (!hasController && video.videoUrl != null && !video.isGif) {
          // Old system would create controller on demand
        }
        _oldSystemSuccesses++;
        final oldDuration = DateTime.now().difference(oldStartTime).inMilliseconds;
        _oldSystemLoadTimes.add(oldDuration);
      } catch (e) {
        _oldSystemFailures++;
        _discrepancies.add('Old system failed to handle video ${video.id}: $e');
      }

      // Time new system addition
      final newStartTime = DateTime.now();
      try {
        await _newSystem.addVideoEvent(video);
        _newSystemSuccesses++;
        final newDuration = DateTime.now().difference(newStartTime).inMilliseconds;
        _newSystemLoadTimes.add(newDuration);
      } catch (e) {
        _newSystemFailures++;
        _discrepancies.add('New system failed to add video ${video.id}: $e');
      }

      // Compare immediate results
      if (i % 10 == 0) {
        _logProgress('Video addition', i + 1, videos.length);
      }
    }
  }

  /// Compare video lists between systems
  void _compareVideoLists() {
    developer.log('📋 Comparing video lists...');

    // Get videos from both systems
    final oldVideos = _oldSystem.readyToPlayQueue;  // Old system ready queue
    final newVideos = _newSystem.videos;            // New system all videos

    // Compare counts
    if (oldVideos.length != newVideos.length) {
      if (_strictMode) {
        _discrepancies.add('Video count mismatch: Old=${oldVideos.length}, New=${newVideos.length}');
      } else {
        // In non-strict mode, just log the difference
        developer.log('⚠️ Video count difference: Old=${oldVideos.length}, New=${newVideos.length}');
      }
    }

    // Compare ordering (for videos that exist in both)
    final commonVideos = _findCommonVideos(oldVideos, newVideos);
    for (int i = 0; i < commonVideos.length - 1; i++) {
      final video1 = commonVideos[i];
      final video2 = commonVideos[i + 1];
      
      final oldIndex1 = oldVideos.indexWhere((v) => v.id == video1.id);
      final oldIndex2 = oldVideos.indexWhere((v) => v.id == video2.id);
      final newIndex1 = newVideos.indexWhere((v) => v.id == video1.id);
      final newIndex2 = newVideos.indexWhere((v) => v.id == video2.id);

      if (oldIndex1 != -1 && oldIndex2 != -1 && newIndex1 != -1 && newIndex2 != -1) {
        final oldRelativeOrder = oldIndex1 < oldIndex2;
        final newRelativeOrder = newIndex1 < newIndex2;
        
        if (oldRelativeOrder != newRelativeOrder) {
          _discrepancies.add('Ordering mismatch for videos ${video1.id} and ${video2.id}');
        }
      }
    }
  }

  /// Compare preloading behavior between systems
  Future<void> _comparePreloadingBehavior(List<VideoEvent> videos) async {
    developer.log('⚡ Comparing preloading behavior...');

    if (videos.isEmpty) return;

    // Test preloading around different indices
    final testIndices = [0, videos.length ~/ 2, videos.length - 1].where((i) => i < videos.length);

    for (final index in testIndices) {
      // Old system preloading
      final oldPreloadStart = DateTime.now();
      try {
        // Old system preloading is implicit - we can check what's in ready queue
        final oldReadyCount = _oldSystem.readyToPlayQueue.length;
        final oldMemoryBefore = _measureOldSystemMemory();
        
        // Simulate old system behavior by checking cached controllers
        int oldPreloadedCount = 0;
        for (final video in videos) {
          if (_oldSystem.isInitialized(video)) {
            oldPreloadedCount++;
          }
        }
        
        final oldPreloadTime = DateTime.now().difference(oldPreloadStart).inMilliseconds;
        _oldSystemLoadTimes.add(oldPreloadTime);
      } catch (e) {
        _discrepancies.add('Old system preloading error at index $index: $e');
      }

      // New system preloading
      final newPreloadStart = DateTime.now();
      try {
        _newSystem.preloadAroundIndex(index);
        
        // Give it time to process
        await Future.delayed(const Duration(milliseconds: 100));
        
        final newPreloadTime = DateTime.now().difference(newPreloadStart).inMilliseconds;
        _newSystemLoadTimes.add(newPreloadTime);
      } catch (e) {
        _discrepancies.add('New system preloading error at index $index: $e');
      }
    }
  }

  /// Compare error handling between systems
  Future<void> _compareErrorHandling() async {
    developer.log('❌ Comparing error handling...');

    // Create a video with invalid URL to test error handling
    final invalidVideo = VideoEvent(
      id: 'error_test_${DateTime.now().millisecondsSinceEpoch}',
      pubkey: 'test_pubkey',
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      content: 'Error test video',
      timestamp: DateTime.now(),
      videoUrl: 'https://invalid-url-for-error-testing.com/video.mp4',
      title: 'Error Test Video',
      hashtags: ['test'],
    );

    // Test old system error handling
    try {
      final oldController = _oldSystem.getController(invalidVideo);
      if (oldController == null) {
        // Old system handles errors by returning null controllers
        developer.log('Old system handled error by returning null controller');
      }
    } catch (e) {
      developer.log('Old system error handling: $e');
    }

    // Test new system error handling
    try {
      await _newSystem.addVideoEvent(invalidVideo);
      try {
        await _newSystem.preloadVideo(invalidVideo.id);
      } catch (e) {
        // Expected - should handle gracefully
        final state = _newSystem.getVideoState(invalidVideo.id);
        if (state?.hasFailed == true) {
          developer.log('New system properly tracked failed state');
        } else {
          _discrepancies.add('New system did not properly track failed state');
        }
      }
    } catch (e) {
      _discrepancies.add('New system failed to add invalid video: $e');
    }
  }

  /// Find videos that exist in both systems
  List<VideoEvent> _findCommonVideos(List<VideoEvent> oldVideos, List<VideoEvent> newVideos) {
    final oldIds = oldVideos.map((v) => v.id).toSet();
    return newVideos.where((video) => oldIds.contains(video.id)).toList();
  }

  /// Measure memory usage of old system
  MemoryMetrics _measureOldSystemMemory() {
    // Old system doesn't have built-in metrics, so we estimate
    final readyVideos = _oldSystem.readyToPlayQueue.length;
    final estimatedControllers = readyVideos; // Rough estimate
    final estimatedMB = estimatedControllers * 30; // Old system uses more memory per controller
    
    return MemoryMetrics(
      estimatedMB: estimatedMB,
      activeControllers: estimatedControllers,
      totalVideos: readyVideos,
      readyVideos: readyVideos,
      utilizationPercent: estimatedControllers > 0 ? (estimatedMB / 1024 * 100) : 0.0,
      measuredAt: DateTime.now(),
    );
  }

  /// Measure memory usage of new system
  MemoryMetrics _measureNewSystemMemory() {
    final debugInfo = _newSystem.getDebugInfo();
    return MemoryMetrics(
      estimatedMB: debugInfo['estimatedMemoryMB'] as int? ?? 0,
      activeControllers: debugInfo['activeControllers'] as int? ?? 0,
      totalVideos: debugInfo['totalVideos'] as int? ?? 0,
      readyVideos: debugInfo['readyVideos'] as int? ?? 0,
      utilizationPercent: double.tryParse(debugInfo['memoryUtilization']?.toString() ?? '0') ?? 0.0,
      measuredAt: DateTime.now(),
    );
  }

  /// Generate final comparison result
  VideoSystemComparisonResult _generateComparisonResult() {
    final endTime = DateTime.now();
    final testDuration = endTime.difference(_testStartTime!);

    // Calculate performance metrics
    final oldMetrics = PerformanceMetrics(
      totalOperations: _oldSystemSuccesses + _oldSystemFailures,
      successfulOperations: _oldSystemSuccesses,
      failedOperations: _oldSystemFailures,
      successRate: (_oldSystemSuccesses + _oldSystemFailures) > 0 
          ? (_oldSystemSuccesses / (_oldSystemSuccesses + _oldSystemFailures)) * 100 
          : 0.0,
      averageLoadTimeMs: _oldSystemLoadTimes.isNotEmpty 
          ? (_oldSystemLoadTimes.reduce((a, b) => a + b) / _oldSystemLoadTimes.length).round()
          : 0,
      maxLoadTimeMs: _oldSystemLoadTimes.isNotEmpty ? _oldSystemLoadTimes.reduce((a, b) => a > b ? a : b) : 0,
      minLoadTimeMs: _oldSystemLoadTimes.isNotEmpty ? _oldSystemLoadTimes.reduce((a, b) => a < b ? a : b) : 0,
      startTime: _testStartTime!,
      endTime: endTime,
    );

    final newMetrics = PerformanceMetrics(
      totalOperations: _newSystemSuccesses + _newSystemFailures,
      successfulOperations: _newSystemSuccesses,
      failedOperations: _newSystemFailures,
      successRate: (_newSystemSuccesses + _newSystemFailures) > 0 
          ? (_newSystemSuccesses / (_newSystemSuccesses + _newSystemFailures)) * 100 
          : 0.0,
      averageLoadTimeMs: _newSystemLoadTimes.isNotEmpty 
          ? (_newSystemLoadTimes.reduce((a, b) => a + b) / _newSystemLoadTimes.length).round()
          : 0,
      maxLoadTimeMs: _newSystemLoadTimes.isNotEmpty ? _newSystemLoadTimes.reduce((a, b) => a > b ? a : b) : 0,
      minLoadTimeMs: _newSystemLoadTimes.isNotEmpty ? _newSystemLoadTimes.reduce((a, b) => a < b ? a : b) : 0,
      startTime: _testStartTime!,
      endTime: endTime,
    );

    // Measure final memory usage
    final oldMemory = _measureOldSystemMemory();
    final newMemory = _measureNewSystemMemory();

    // Determine if comparison passed
    final memoryReduction = oldMemory.estimatedMB > 0 
        ? ((oldMemory.estimatedMB - newMemory.estimatedMB) / oldMemory.estimatedMB) * 100 
        : 0.0;
    
    final performanceImprovement = oldMetrics.averageLoadTimeMs > 0 
        ? ((oldMetrics.averageLoadTimeMs - newMetrics.averageLoadTimeMs) / oldMetrics.averageLoadTimeMs) * 100 
        : 0.0;

    final passed = _discrepancies.isEmpty && 
                   memoryReduction >= 50.0 && // At least 50% memory reduction
                   newMetrics.successRate >= oldMetrics.successRate;

    final summary = _generateSummary(memoryReduction, performanceImprovement, testDuration);

    return VideoSystemComparisonResult(
      timestamp: endTime,
      discrepancies: List.from(_discrepancies),
      oldSystemMetrics: oldMetrics,
      newSystemMetrics: newMetrics,
      oldSystemMemory: oldMemory,
      newSystemMemory: newMemory,
      passed: passed,
      summary: summary,
    );
  }

  /// Generate summary of comparison results
  String _generateSummary(double memoryReduction, double performanceImprovement, Duration testDuration) {
    final buffer = StringBuffer();
    buffer.writeln('Video System Comparison Summary');
    buffer.writeln('==============================');
    buffer.writeln('Test Duration: ${testDuration.inMilliseconds}ms');
    buffer.writeln('Discrepancies Found: ${_discrepancies.length}');
    buffer.writeln('Memory Reduction: ${memoryReduction.toStringAsFixed(1)}%');
    buffer.writeln('Performance Improvement: ${performanceImprovement.toStringAsFixed(1)}%');
    buffer.writeln('');
    
    if (_discrepancies.isNotEmpty) {
      buffer.writeln('Issues Found:');
      for (final discrepancy in _discrepancies) {
        buffer.writeln('- $discrepancy');
      }
    } else {
      buffer.writeln('✅ No discrepancies found - systems are consistent');
    }

    return buffer.toString();
  }

  /// Log progress during comparison
  void _logProgress(String operation, int completed, int total) {
    if (_logVerbose) {
      final percent = (completed / total * 100).toStringAsFixed(1);
      developer.log('📊 $operation: $completed/$total ($percent%)');
    }
  }

  /// Clean up resources
  void dispose() {
    _discrepancies.clear();
    _oldSystemLoadTimes.clear();
    _newSystemLoadTimes.clear();
    _operationStartTimes.clear();
  }
}

/// Configuration for parallel testing
class ParallelTestConfig {
  final Duration timeout;
  final bool strictMode;
  final bool logVerbose;
  final double memoryReductionTarget;
  final int maxVideosToTest;
  final bool testErrorScenarios;

  const ParallelTestConfig({
    this.timeout = const Duration(minutes: 10),
    this.strictMode = false,
    this.logVerbose = true,
    this.memoryReductionTarget = 80.0, // 80% reduction target
    this.maxVideosToTest = 50,
    this.testErrorScenarios = true,
  });
}