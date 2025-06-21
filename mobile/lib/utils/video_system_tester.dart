// ABOUTME: Comprehensive test script to compare VideoManagerService vs VideoCacheService performance
// ABOUTME: Provides automated testing and detailed performance analysis

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../services/video_manager_service.dart';
import '../services/video_manager_interface.dart';
import '../services/video_cache_service.dart';
import '../models/video_event.dart';
import '../utils/video_system_debugger.dart';

/// Test result data
class TestResult {
  final String systemName;
  final DateTime startTime;
  final DateTime endTime;
  final List<VideoLoadMetric> loadMetrics = [];
  int videosLoaded = 0;
  int videosFailed = 0;
  double totalMemoryMB = 0;
  int memoryMeasurements = 0;

  TestResult(this.systemName, this.startTime, this.endTime);

  double get averageLoadTime {
    if (loadMetrics.isEmpty) return 0;
    return loadMetrics.map((m) => m.loadTimeMs).reduce((a, b) => a + b) / loadMetrics.length;
  }

  double get successRate {
    final total = videosLoaded + videosFailed;
    return total > 0 ? (videosLoaded / total) * 100 : 0;
  }

  double get averageMemoryMB {
    return memoryMeasurements > 0 ? totalMemoryMB / memoryMeasurements : 0;
  }

  Duration get testDuration => endTime.difference(startTime);
}

/// Individual video load metric
class VideoLoadMetric {
  final String videoId;
  final double loadTimeMs;
  final bool isSuccess;
  final String? errorMessage;
  final double memoryMB;
  final int timestamp;

  VideoLoadMetric({
    required this.videoId,
    required this.loadTimeMs,
    required this.isSuccess,
    this.errorMessage,
    required this.memoryMB,
    required this.timestamp,
  });
}

/// Comprehensive video system performance tester
class VideoSystemTester {
  static final VideoSystemTester _instance = VideoSystemTester._internal();
  factory VideoSystemTester() => _instance;
  VideoSystemTester._internal();

  /// Test configuration
  static const int testVideoCount = 10;
  static const Duration testDuration = Duration(minutes: 2);
  
  /// Test results
  final Map<String, TestResult> _results = {};
  bool _isTestRunning = false;


  /// Run comprehensive comparison test
  Future<Map<String, TestResult>> runComparisonTest({
    List<VideoEvent>? testVideos,
  }) async {
    if (_isTestRunning) {
      throw Exception('Test already running');
    }

    _isTestRunning = true;
    _results.clear();

    try {
      debugPrint('🧪 Starting comprehensive video system comparison test...');
      
      // Generate test videos if not provided
      final videos = testVideos ?? _generateTestVideos();
      debugPrint('📊 Testing with ${videos.length} videos');

      // Test VideoManagerService
      debugPrint('🔬 Testing VideoManagerService...');
      final managerResult = await _testVideoManagerService(videos);
      _results['VideoManager'] = managerResult;

      // Small delay between tests
      await Future.delayed(const Duration(seconds: 2));

      // Test VideoCacheService 
      debugPrint('🔬 Testing VideoCacheService...');
      final cacheResult = await _testVideoCacheService(videos);
      _results['VideoCache'] = cacheResult;

      debugPrint('✅ Comparison test completed!');
      _printComparisonReport();

      return Map.unmodifiable(_results);

    } finally {
      _isTestRunning = false;
    }
  }

  /// Test VideoManagerService performance
  Future<TestResult> _testVideoManagerService(List<VideoEvent> videos) async {
    final startTime = DateTime.now();
    final manager = VideoManagerService(config: VideoManagerConfig.wifi());
    late final TestResult result;

    try {
      result = TestResult('VideoManager', startTime, DateTime.now());
      
      // Add videos to manager
      for (final video in videos) {
        await manager.addVideoEvent(video);
      }

      // Test preloading performance
      for (int i = 0; i < videos.length && i < testVideoCount; i++) {
        final video = videos[i];
        final loadStart = DateTime.now();
        
        // Get memory info first
        final debugInfo = manager.getDebugInfo();
        final estimatedMemory = debugInfo['estimatedMemoryMB'] as int? ?? 0;
        
        try {
          await manager.preloadVideo(video.id);
          final loadTime = DateTime.now().difference(loadStart);
          
          result.loadMetrics.add(VideoLoadMetric(
            videoId: video.id,
            loadTimeMs: loadTime.inMilliseconds.toDouble(),
            isSuccess: true,
            memoryMB: estimatedMemory.toDouble(),
            timestamp: DateTime.now().millisecondsSinceEpoch,
          ));
          result.videosLoaded++;

        } catch (e) {
          final loadTime = DateTime.now().difference(loadStart);
          result.loadMetrics.add(VideoLoadMetric(
            videoId: video.id,
            loadTimeMs: loadTime.inMilliseconds.toDouble(),
            isSuccess: false,
            errorMessage: e.toString(),
            memoryMB: estimatedMemory.toDouble(),
            timestamp: DateTime.now().millisecondsSinceEpoch,
          ));
          result.videosFailed++;
        }

        // Track memory
        result.totalMemoryMB += estimatedMemory.toDouble();
        result.memoryMeasurements++;

        await Future.delayed(const Duration(milliseconds: 100));
      }

    } finally {
      manager.dispose();
      // Create final result with actual end time
      final endTime = DateTime.now();
      final finalResult = TestResult('VideoManager', startTime, endTime);
      finalResult.videosLoaded = result.videosLoaded;
      finalResult.videosFailed = result.videosFailed;
      finalResult.totalMemoryMB = result.totalMemoryMB;
      finalResult.memoryMeasurements = result.memoryMeasurements;
      finalResult.loadMetrics.addAll(result.loadMetrics);
      result = finalResult;
    }

    return result;
  }

  /// Test VideoCacheService performance
  Future<TestResult> _testVideoCacheService(List<VideoEvent> videos) async {
    final startTime = DateTime.now();
    final cache = VideoCacheService();
    late final TestResult result;

    try {
      result = TestResult('VideoCache', startTime, DateTime.now());
      
      // Add videos to cache for processing
      cache.processNewVideoEvents(videos);

      // Test preloading performance
      for (int i = 0; i < videos.length && i < testVideoCount; i++) {
        final video = videos[i];
        final loadStart = DateTime.now();
        
        // Get memory estimate
        final stats = cache.getCacheStats();
        final estimatedMemory = (stats['cacheSize'] as int? ?? 0) * 20; // Rough MB estimate
        
        try {
          // Use the cache service's internal test method
          await cache.preloadVideos(videos, i);
          
          // Check if video was actually loaded
          final isReady = cache.isVideoReady(video.id);
          final loadTime = DateTime.now().difference(loadStart);
          
          result.loadMetrics.add(VideoLoadMetric(
            videoId: video.id,
            loadTimeMs: loadTime.inMilliseconds.toDouble(),
            isSuccess: isReady,
            memoryMB: estimatedMemory.toDouble(),
            timestamp: DateTime.now().millisecondsSinceEpoch,
          ));
          
          if (isReady) {
            result.videosLoaded++;
          } else {
            result.videosFailed++;
          }

        } catch (e) {
          final loadTime = DateTime.now().difference(loadStart);
          result.loadMetrics.add(VideoLoadMetric(
            videoId: video.id,
            loadTimeMs: loadTime.inMilliseconds.toDouble(),
            isSuccess: false,
            errorMessage: e.toString(),
            memoryMB: estimatedMemory.toDouble(),
            timestamp: DateTime.now().millisecondsSinceEpoch,
          ));
          result.videosFailed++;
        }

        // Track memory
        result.totalMemoryMB += estimatedMemory.toDouble();
        result.memoryMeasurements++;

        await Future.delayed(const Duration(milliseconds: 100));
      }

    } finally {
      cache.dispose();
      // Create final result with actual end time
      final endTime = DateTime.now();
      final finalResult = TestResult('VideoCache', startTime, endTime);
      finalResult.videosLoaded = result.videosLoaded;
      finalResult.videosFailed = result.videosFailed;
      finalResult.totalMemoryMB = result.totalMemoryMB;
      finalResult.memoryMeasurements = result.memoryMeasurements;
      finalResult.loadMetrics.addAll(result.loadMetrics);
      result = finalResult;
    }

    return result;
  }

  /// Generate realistic test video events
  List<VideoEvent> _generateTestVideos() {
    final random = Random();
    final testUrls = [
      'https://video.nostr.build/test1.mp4',
      'https://video.nostr.build/test2.mp4',
      'https://video.nostr.build/test3.mp4',
      'https://cdn.discordapp.com/attachments/test4.mp4',
      'https://media.giphy.com/media/test5.mp4',
    ];

    return List.generate(testVideoCount, (index) {
      final now = DateTime.now();
      return VideoEvent(
        id: 'test-video-$index-${random.nextInt(1000)}',
        pubkey: 'test-pubkey-$index',
        createdAt: now.subtract(Duration(hours: index)).millisecondsSinceEpoch ~/ 1000,
        content: 'Test video $index for performance testing',
        timestamp: now.subtract(Duration(hours: index)),
        videoUrl: testUrls[index % testUrls.length],
        thumbnailUrl: 'https://example.com/thumb$index.jpg',
        title: 'Test Video $index',
        duration: 10 + random.nextInt(50),
        hashtags: const ['test', 'performance'],
        mimeType: 'video/mp4',
      );
    });
  }

  /// Print detailed comparison report
  void _printComparisonReport() {
    debugPrint('\n🏁 VIDEO SYSTEM PERFORMANCE COMPARISON REPORT');
    debugPrint('═' * 60);
    
    for (final entry in _results.entries) {
      final name = entry.key;
      final result = entry.value;
      
      debugPrint('\n📊 ${name.toUpperCase()} RESULTS:');
      debugPrint('  ⏱️  Test Duration: ${result.testDuration.inSeconds}s');
      debugPrint('  ✅ Videos Loaded: ${result.videosLoaded}');
      debugPrint('  ❌ Videos Failed: ${result.videosFailed}');
      debugPrint('  📈 Success Rate: ${result.successRate.toStringAsFixed(1)}%');
      debugPrint('  ⚡ Avg Load Time: ${result.averageLoadTime.toStringAsFixed(1)}ms');
      debugPrint('  🧠 Avg Memory: ${result.averageMemoryMB.toStringAsFixed(1)}MB');
      
      if (result.loadMetrics.isNotEmpty) {
        final fastest = result.loadMetrics.where((m) => m.isSuccess).map((m) => m.loadTimeMs).fold<double>(double.infinity, (a, b) => a < b ? a : b);
        final slowest = result.loadMetrics.where((m) => m.isSuccess).map((m) => m.loadTimeMs).fold<double>(0, (a, b) => a > b ? a : b);
        debugPrint('  🏃 Fastest Load: ${fastest.toStringAsFixed(1)}ms');
        debugPrint('  🐌 Slowest Load: ${slowest.toStringAsFixed(1)}ms');
      }
    }

    if (_results.length >= 2) {
      debugPrint('\n🏆 WINNER ANALYSIS:');
      final winner = _determineWinner();
      debugPrint('  Best System: ${winner.toUpperCase()}');
      debugPrint('  Recommendation: ${_getRecommendation()}');
    }
  }

  /// Determine the best performing system
  String _determineWinner() {
    String bestSystem = '';
    double bestScore = -1;

    for (final entry in _results.entries) {
      final result = entry.value;
      if (result.videosLoaded == 0) continue;

      // Composite score: 50% success rate, 30% speed, 20% memory efficiency
      final successScore = result.successRate;
      final speedScore = result.averageLoadTime > 0 ? (1000 / result.averageLoadTime) * 10 : 0;
      final memoryScore = result.averageMemoryMB > 0 ? (500 / result.averageMemoryMB) * 10 : 0;
      
      final compositeScore = (successScore * 0.5) + (speedScore * 0.3) + (memoryScore * 0.2);
      
      if (compositeScore > bestScore) {
        bestScore = compositeScore;
        bestSystem = entry.key;
      }
    }

    return bestSystem;
  }

  /// Get performance recommendation
  String _getRecommendation() {
    final winner = _determineWinner();
    
    if (winner == 'VideoManager') {
      return 'VideoManagerService provides better performance. Recommend completing the migration.';
    } else if (winner == 'VideoCache') {
      return 'VideoCacheService performs better. The new system needs optimization before migration.';
    } else {
      return 'Performance is similar. Choose based on maintainability and features.';
    }
  }

  /// Get current test status
  bool get isTestRunning => _isTestRunning;
  
  /// Get latest results
  Map<String, TestResult> get results => Map.unmodifiable(_results);
}