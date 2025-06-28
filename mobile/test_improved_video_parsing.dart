// ABOUTME: Test the improved video URL parsing with various edge cases
// ABOUTME: Run with: dart test_improved_video_parsing.dart

import 'dart:convert';
import 'package:nostr_sdk/event.dart';
import 'lib/models/video_event.dart';

void main() {
  print('🚀 Testing improved video URL parsing...\n');
  
  // Test case 1: URL in content (no tags)
  test_UrlInContent();
  
  // Test case 2: URL in unknown tag
  test_UrlInUnknownTag();
  
  // Test case 3: Broken apt.openvine.co URL replacement
  test_BrokenUrlReplacement();
  
  // Test case 4: Multiple URL sources (priority handling)
  test_MultipleUrlSources();
  
  print('\n✅ All tests completed!');
}

void test_UrlInContent() {
  print('=== Test 1: URL in content (no tags) ===');
  
  final event = Event(
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    22,
    [],
    'Check out this video: https://blossom.primal.net/test.mp4',
    createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
  );
  
  try {
    final videoEvent = VideoEvent.fromNostrEvent(event);
    print('Result: hasVideo=${videoEvent.hasVideo}, videoUrl=${videoEvent.videoUrl}');
    
    if (videoEvent.hasVideo && videoEvent.videoUrl == 'https://blossom.primal.net/test.mp4') {
      print('✅ PASS: URL extracted from content');
    } else {
      print('❌ FAIL: URL not extracted from content');
    }
  } catch (e) {
    print('❌ ERROR: $e');
  }
  print('');
}

void test_UrlInUnknownTag() {
  print('=== Test 2: URL in unknown tag ===');
  
  final event = Event(
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    22,
    [['custom', 'https://nostr.build/test.mp4']],
    'Video with URL in custom tag',
    createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
  );
  
  try {
    final videoEvent = VideoEvent.fromNostrEvent(event);
    print('Result: hasVideo=${videoEvent.hasVideo}, videoUrl=${videoEvent.videoUrl}');
    
    if (videoEvent.hasVideo && videoEvent.videoUrl == 'https://nostr.build/test.mp4') {
      print('✅ PASS: URL extracted from unknown tag');
    } else {
      print('❌ FAIL: URL not extracted from unknown tag');
    }
  } catch (e) {
    print('❌ ERROR: $e');
  }
  print('');
}

void test_BrokenUrlReplacement() {
  print('=== Test 3: Broken apt.openvine.co URL replacement ===');
  
  final event = Event(
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    22,
    [['url', 'https://apt.openvine.co/broken.mp4']],
    'Video with broken URL',
    createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
  );
  
  try {
    final videoEvent = VideoEvent.fromNostrEvent(event);
    print('Result: hasVideo=${videoEvent.hasVideo}, videoUrl=${videoEvent.videoUrl}');
    
    if (videoEvent.hasVideo && !videoEvent.videoUrl!.contains('apt.openvine.co')) {
      print('✅ PASS: Broken URL replaced with fallback');
    } else {
      print('❌ FAIL: Broken URL not replaced');
    }
  } catch (e) {
    print('❌ ERROR: $e');
  }
  print('');
}

void test_MultipleUrlSources() {
  print('=== Test 4: Multiple URL sources (priority) ===');
  
  final event = Event(
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    22,
    [
      ['url', 'https://blossom.primal.net/priority.mp4'],
      ['custom', 'https://nostr.build/fallback.mp4']
    ],
    'Video with multiple URLs',
    createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
  );
  
  try {
    final videoEvent = VideoEvent.fromNostrEvent(event);
    print('Result: hasVideo=${videoEvent.hasVideo}, videoUrl=${videoEvent.videoUrl}');
    
    if (videoEvent.hasVideo && videoEvent.videoUrl == 'https://blossom.primal.net/priority.mp4') {
      print('✅ PASS: Correct URL priority handling');
    } else {
      print('❌ FAIL: Incorrect URL priority');
    }
  } catch (e) {
    print('❌ ERROR: $e');
  }
  print('');
}