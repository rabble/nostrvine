// ABOUTME: Test helper utilities for creating mock data and testing video system
// ABOUTME: Provides consistent test data generation and common testing patterns

import 'package:openvine/models/video_event.dart';
import 'package:flutter_test/flutter_test.dart';

/// Test helper utilities for video system testing
class TestHelpers {
  /// Create a mock VideoEvent for testing purposes
  /// 
  /// Provides reasonable defaults for all required fields and allows
  /// customization of specific fields for test scenarios.
  static VideoEvent createVideoEvent({
    String? id,
    String? videoUrl,
    String? title,
    String? author,
    bool isGif = false,
    DateTime? timestamp,
    DateTime? createdAt,
    List<String>? hashtags,
    String? thumbnailUrl,
    int? duration,
    String? dimensions,
    int? fileSize,
    String? mimeType,
    String? sha256,
    String? content,
    String? pubkey,
  }) {
    final now = DateTime.now();
    final effectiveTimestamp = timestamp ?? now;
    final effectiveCreatedAt = createdAt ?? now;
    
    return VideoEvent(
      id: id ?? 'test_video_${now.millisecondsSinceEpoch}',
      pubkey: pubkey ?? 'test_pubkey_${now.millisecondsSinceEpoch}',
      createdAt: effectiveCreatedAt.millisecondsSinceEpoch ~/ 1000,
      content: content ?? 'Test video content',
      timestamp: effectiveTimestamp,
      videoUrl: videoUrl ?? (isGif ? 'https://example.com/test.gif' : 'https://example.com/test_video.mp4'),
      thumbnailUrl: thumbnailUrl ?? 'https://picsum.photos/640/480?random=${now.millisecondsSinceEpoch % 1000}',
      title: title ?? 'Test Video Title',
      hashtags: hashtags ?? ['test', 'video'],
      duration: duration ?? (isGif ? 0 : 30),
      dimensions: dimensions ?? '1920x1080',
      fileSize: fileSize ?? 1024000,
      mimeType: mimeType ?? (isGif ? 'image/gif' : 'video/mp4'),
      sha256: sha256 ?? 'test_sha256_hash',
    );
  }
  
  /// Create a VideoEvent that will fail to load (for testing error handling)
  /// 
  /// Uses invalid URLs and patterns that mock implementations recognize
  /// as failure conditions.
  static VideoEvent createFailingVideoEvent({
    String? id,
    String? errorType,
  }) {
    final now = DateTime.now();
    final baseId = id ?? 'failing_video_${now.millisecondsSinceEpoch}';
    
    // Use URL patterns that mock implementations recognize as failures
    final failureUrl = 'https://invalid-url-will-fail.com/video.mp4';
    
    return createVideoEvent(
      id: baseId,
      videoUrl: failureUrl,
      title: 'Failing Test Video',
      content: 'This video is designed to fail for testing purposes',
    );
  }
  
  /// Create a VideoEvent with slow loading characteristics
  /// 
  /// For testing timeout and loading behavior.
  static VideoEvent createSlowVideoEvent({
    String? id,
    Duration delay = const Duration(seconds: 5),
  }) {
    final now = DateTime.now();
    final baseId = id ?? 'slow_video_${now.millisecondsSinceEpoch}';
    
    // Use URL pattern that indicates delay
    final delayUrl = 'https://httpbin.org/delay/${delay.inSeconds}';
    
    return createVideoEvent(
      id: baseId,
      videoUrl: delayUrl,
      title: 'Slow Loading Test Video',
      content: 'This video loads slowly for testing purposes',
    );
  }
  
  /// Create a list of VideoEvents for bulk testing
  /// 
  /// Each video has a unique ID and timestamp for consistent ordering.
  static List<VideoEvent> createVideoList(int count, {
    String idPrefix = 'bulk_test',
    Duration? timeSpacing,
  }) {
    final videos = <VideoEvent>[];
    final baseTime = DateTime.now();
    final spacing = timeSpacing ?? const Duration(minutes: 1);
    
    for (int i = 0; i < count; i++) {
      final timestamp = baseTime.subtract(Duration(
        milliseconds: spacing.inMilliseconds * (count - 1 - i),
      ));
      
      videos.add(createVideoEvent(
        id: '${idPrefix}_$i',
        title: 'Bulk Test Video $i',
        timestamp: timestamp,
        createdAt: timestamp,
      ));
    }
    
    return videos;
  }
  
  /// Alias for createVideoList to match TDD specification naming
  static List<VideoEvent> createMockVideoEvents(int count, {
    bool includeGifs = true,
    List<String>? baseHashtags,
  }) {
    final events = <VideoEvent>[];
    final hashtags = baseHashtags ?? ['test', 'mock'];
    
    for (int i = 0; i < count; i++) {
      final isGif = includeGifs && i % 3 == 0; // Every 3rd video is a GIF
      events.add(createVideoEvent(
        id: 'mock_video_$i',
        title: 'Mock Video $i',
        hashtags: [...hashtags, 'video$i'],
        isGif: isGif,
        createdAt: DateTime.now().subtract(Duration(seconds: i)),
      ));
    }
    
    return events;
  }
  
  /// Generate test data for performance testing
  static List<VideoEvent> generatePerformanceTestData(int count) {
    return List.generate(count, (index) => createVideoEvent(
      id: 'perf_test_$index',
      title: 'Performance Test Video $index',
      videoUrl: 'https://example.com/video_$index.mp4',
      createdAt: DateTime.now().subtract(Duration(seconds: index)),
    ));
  }
  
  /// Create a GIF VideoEvent for testing immediate readiness
  static VideoEvent createGifVideoEvent({
    String? id,
    String? title,
  }) {
    return createVideoEvent(
      id: id,
      title: title ?? 'Test GIF',
      isGif: true,
      videoUrl: 'https://example.com/test.gif',
      mimeType: 'image/gif',
      duration: 0, // GIFs typically don't have duration
    );
  }
  
  /// Wait for a condition to be true or timeout
  /// 
  /// Useful for waiting for async operations in tests.
  static Future<void> waitForCondition(
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 5),
    Duration checkInterval = const Duration(milliseconds: 100),
  }) async {
    final stopwatch = Stopwatch()..start();
    
    while (!condition() && stopwatch.elapsed < timeout) {
      await Future.delayed(checkInterval);
    }
    
    if (!condition()) {
      throw TimeoutException(
        'Condition not met within ${timeout.inSeconds} seconds',
        timeout,
      );
    }
  }
  
  /// Wait for a video to reach a specific state
  /// 
  /// Useful for testing state transitions.
  static Future<void> waitForVideoState(
    dynamic manager, // IVideoManager but keeping dynamic to avoid import issues
    String videoId,
    dynamic expectedState, // VideoLoadingState
    {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    await waitForCondition(
      () {
        final state = manager.getVideoState(videoId);
        return state?.loadingState == expectedState;
      },
      timeout: timeout,
    );
  }
  
  /// Create a test configuration for specific scenarios
  static Map<String, dynamic> createTestConfig({
    int maxVideos = 100,
    int preloadAhead = 3,
    int maxRetries = 3,
    int timeoutSeconds = 10,
    bool enableMemoryManagement = true,
    int memoryKeepRange = 10,
  }) {
    return {
      'maxVideos': maxVideos,
      'preloadAhead': preloadAhead,
      'maxRetries': maxRetries,
      'preloadTimeout': Duration(seconds: timeoutSeconds),
      'enableMemoryManagement': enableMemoryManagement,
      'memoryKeepRange': memoryKeepRange,
    };
  }
  
  /// Verify video list ordering (newest first)
  static void verifyVideoOrdering(List<VideoEvent> videos) {
    for (int i = 0; i < videos.length - 1; i++) {
      final current = videos[i];
      final next = videos[i + 1];
      
      expect(
        current.timestamp.isAfter(next.timestamp) || 
        current.timestamp.isAtSameMomentAs(next.timestamp),
        isTrue,
        reason: 'Videos should be ordered newest first. '
               'Video at index $i (${current.id}) should be newer than '
               'video at index ${i + 1} (${next.id})',
      );
    }
  }
  
  /// Create a mock VideoEvent using simplified parameters for contract tests
  static VideoEvent createMockVideoEvent({
    String? id,
    String? url,
    String? title,
    bool isGif = false,
  }) {
    return createVideoEvent(
      id: id,
      videoUrl: url,
      title: title,
      isGif: isGif,
    );
  }
  
  /// Create a mock Nostr Event for testing video event processing
  static Map<String, dynamic> createMockNostrEvent({
    String? id,
    int kind = 22, // Video event kind
    String? content,
    List<List<String>>? tags,
    String? pubkey,
    int? createdAt,
  }) {
    final now = DateTime.now();
    
    return {
      'id': id ?? 'mock_nostr_${now.millisecondsSinceEpoch}',
      'kind': kind,
      'content': content ?? 'Mock video event content',
      'tags': tags ?? [
        ['url', 'https://example.com/video.mp4'],
        ['m', 'video/mp4'],
        ['size', '1024000'],
        ['title', 'Mock Video Title'],
      ],
      'pubkey': pubkey ?? 'mock_pubkey_${now.millisecondsSinceEpoch}',
      'created_at': createdAt ?? (now.millisecondsSinceEpoch ~/ 1000),
      'sig': 'mock_signature_${now.millisecondsSinceEpoch}',
    };
  }
  
  /// Extract video ID from a video event for easy assertions
  static String extractVideoId(VideoEvent event) {
    return event.id;
  }
  
  /// Extract video IDs from a list of video events
  static List<String> extractVideoIds(List<VideoEvent> events) {
    return events.map(extractVideoId).toList();
  }
  
  /// Create a matcher for checking video state properties
  static Matcher hasVideoState({
    dynamic loadingState,
    bool? isReady,
    bool? isLoading,
    bool? hasFailed,
    bool? canRetry,
    bool? isDisposed,
  }) {
    return _VideoStateMatcher(
      loadingState: loadingState,
      isReady: isReady,
      isLoading: isLoading,
      hasFailed: hasFailed,
      canRetry: canRetry,
      isDisposed: isDisposed,
    );
  }
}

/// Custom matcher for video state properties
class _VideoStateMatcher extends Matcher {
  final dynamic loadingState;
  final bool? isReady;
  final bool? isLoading;
  final bool? hasFailed;
  final bool? canRetry;
  final bool? isDisposed;
  
  const _VideoStateMatcher({
    this.loadingState,
    this.isReady,
    this.isLoading,
    this.hasFailed,
    this.canRetry,
    this.isDisposed,
  });
  
  @override
  bool matches(dynamic item, Map matchState) {
    if (item == null) return false;
    
    if (loadingState != null && item.loadingState != loadingState) return false;
    if (isReady != null && item.isReady != isReady) return false;
    if (isLoading != null && item.isLoading != isLoading) return false;
    if (hasFailed != null && item.hasFailed != hasFailed) return false;
    if (canRetry != null && item.canRetry != canRetry) return false;
    if (isDisposed != null && item.isDisposed != isDisposed) return false;
    
    return true;
  }
  
  @override
  Description describe(Description description) {
    description.add('VideoState with');
    
    if (loadingState != null) description.add(' loadingState: $loadingState');
    if (isReady != null) description.add(' isReady: $isReady');
    if (isLoading != null) description.add(' isLoading: $isLoading');
    if (hasFailed != null) description.add(' hasFailed: $hasFailed');
    if (canRetry != null) description.add(' canRetry: $canRetry');
    if (isDisposed != null) description.add(' isDisposed: $isDisposed');
    
    return description;
  }
}

/// Timeout exception for test operations
class TimeoutException implements Exception {
  final String message;
  final Duration timeout;
  
  const TimeoutException(this.message, this.timeout);
  
  @override
  String toString() => 'TimeoutException: $message';
}