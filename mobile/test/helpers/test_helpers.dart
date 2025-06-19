// ABOUTME: Comprehensive test helpers for TDD video system rebuild
// ABOUTME: Provides factory methods for creating mock objects and test utilities

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:nostr/nostr.dart';
import 'package:nostrvine_app/models/video_event.dart';

/// Comprehensive test helpers for video system TDD rebuild
class TestHelpers {
  /// Create a mock VideoEvent with customizable properties
  static VideoEvent createMockVideoEvent({
    String? id,
    String? pubkey,
    String? content,
    String? url,
    String? title,
    List<String>? hashtags,
    int? createdAt,
    bool isGif = false,
  }) {
    final eventId = id ?? 'mock_video_${DateTime.now().millisecondsSinceEpoch}';
    final authorPubkey = pubkey ?? 'mock_pubkey_${DateTime.now().millisecondsSinceEpoch}';
    final videoContent = content ?? 'Mock video content for testing';
    final videoUrl = url ?? (isGif 
        ? 'https://example.com/mock_video.gif' 
        : 'https://example.com/mock_video.mp4');
    final videoTitle = title ?? 'Mock Video Title';
    final videoHashtags = hashtags ?? ['test', 'mock'];
    final timestamp = createdAt ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000);
    
    // Create mock Nostr event
    final event = Event(
      eventId,
      authorPubkey,
      timestamp,
      22, // NIP-71 video event kind
      [
        ['url', videoUrl],
        ['title', videoTitle],
        if (isGif) ['gif', 'true'],
        ...videoHashtags.map((tag) => ['t', tag]),
      ],
      videoContent,
      'mock_signature_for_testing',
      verify: false, // Disable validation for test events
    );
    
    return VideoEvent.fromNostrEvent(event);
  }
  
  /// Create a mock Nostr Event with customizable properties
  static Event createMockNostrEvent({
    String? id,
    String? pubkey,
    int? kind,
    String? content,
    List<List<String>>? tags,
    int? createdAt,
  }) {
    return Event(
      id ?? 'mock_event_${DateTime.now().millisecondsSinceEpoch}',
      pubkey ?? 'mock_pubkey_${DateTime.now().millisecondsSinceEpoch}',
      createdAt ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000),
      kind ?? 1,
      tags ?? [],
      content ?? 'Mock event content',
      'mock_signature_for_testing',
      verify: false, // Disable validation for test events
    );
  }
  
  /// Create multiple mock video events for batch testing
  static List<VideoEvent> createMockVideoEvents(int count, {
    bool includeGifs = true,
    List<String>? baseHashtags,
  }) {
    final events = <VideoEvent>[];
    final hashtags = baseHashtags ?? ['test', 'mock'];
    
    for (int i = 0; i < count; i++) {
      final isGif = includeGifs && i % 3 == 0; // Every 3rd video is a GIF
      events.add(createMockVideoEvent(
        id: 'mock_video_$i',
        title: 'Mock Video $i',
        hashtags: [...hashtags, 'video$i'],
        isGif: isGif,
        createdAt: (DateTime.now().millisecondsSinceEpoch ~/ 1000) - i,
      ));
    }
    
    return events;
  }
  
  /// Wait for a widget to appear during testing
  static Future<void> pumpUntilFound(
    WidgetTester tester, 
    Finder finder, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final endTime = DateTime.now().add(timeout);
    
    while (DateTime.now().isBefore(endTime)) {
      await tester.pump();
      
      if (finder.evaluate().isNotEmpty) {
        return;
      }
      
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    throw TimeoutException(
      'Widget not found within timeout period',
      timeout,
    );
  }
  
  /// Wait for a condition to become true during testing
  static Future<void> pumpUntilCondition(
    WidgetTester tester,
    bool Function() condition, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final endTime = DateTime.now().add(timeout);
    
    while (DateTime.now().isBefore(endTime)) {
      await tester.pump();
      
      if (condition()) {
        return;
      }
      
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    throw TimeoutException(
      'Condition not met within timeout period',
      timeout,
    );
  }
  
  /// Create a test widget tree with necessary providers
  static Widget createTestApp({
    required Widget child,
    List<ChangeNotifierProvider>? providers,
  }) {
    return MaterialApp(
      home: providers != null
          ? MultiProvider(
              providers: providers,
              child: child,
            )
          : child,
    );
  }
  
  /// Wait for async operations to complete
  static Future<void> waitForAsync([Duration? delay]) async {
    await Future.delayed(delay ?? const Duration(milliseconds: 100));
  }
  
  /// Assert that a list contains exactly the expected items in order
  static void assertListEquals<T>(List<T> actual, List<T> expected, String message) {
    expect(actual.length, equals(expected.length), reason: '$message: Length mismatch');
    
    for (int i = 0; i < actual.length; i++) {
      expect(actual[i], equals(expected[i]), 
             reason: '$message: Item at index $i differs');
    }
  }
  
  /// Generate test data for performance testing
  static List<VideoEvent> generatePerformanceTestData(int count) {
    return List.generate(count, (index) => createMockVideoEvent(
      id: 'perf_test_$index',
      title: 'Performance Test Video $index',
      url: 'https://example.com/video_$index.mp4',
      createdAt: (DateTime.now().millisecondsSinceEpoch ~/ 1000) - index,
    ));
  }
  
  /// Create mock video events with specific characteristics for edge case testing
  static List<VideoEvent> createEdgeCaseVideoEvents() {
    return [
      // Very long title
      createMockVideoEvent(
        id: 'long_title',
        title: 'This is a very long video title that should test how the system handles lengthy titles that might cause display issues or performance problems',
      ),
      
      // Many hashtags
      createMockVideoEvent(
        id: 'many_hashtags',
        hashtags: List.generate(20, (i) => 'hashtag$i'),
      ),
      
      // Empty content
      createMockVideoEvent(
        id: 'empty_content',
        content: '',
        title: '',
      ),
      
      // Special characters
      createMockVideoEvent(
        id: 'special_chars',
        title: 'Video with émojis 🎥🎬 and spëciäl chars!@#\$%',
        content: 'Content with special characters: àáâãäåæçèéêë',
      ),
      
      // Old timestamp
      createMockVideoEvent(
        id: 'old_video',
        createdAt: 946684800, // Year 2000
      ),
      
      // Future timestamp
      createMockVideoEvent(
        id: 'future_video',
        createdAt: (DateTime.now().millisecondsSinceEpoch ~/ 1000) + 86400, // Tomorrow
      ),
    ];
  }
}