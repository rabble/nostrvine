// ABOUTME: Tests for test helpers to verify TDD infrastructure works
// ABOUTME: Validates that test utilities and mock factories function correctly

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr/nostr.dart';
import 'package:nostrvine_app/models/video_event.dart';
import 'test_helpers.dart';

void main() {
  group('TestHelpers', () {
    group('createMockVideoEvent', () {
      test('creates valid VideoEvent with default values', () {
        final videoEvent = TestHelpers.createMockVideoEvent();
        
        expect(videoEvent, isNotNull);
        expect(videoEvent.id, isNotEmpty);
        expect(videoEvent.pubkey, isNotEmpty);
        expect(videoEvent.content, equals('Mock video content for testing'));
        expect(videoEvent.videoUrl, contains('https://example.com'));
        expect(videoEvent.hashtags, contains('test'));
        expect(videoEvent.hashtags, contains('mock'));
      });

      test('creates VideoEvent with custom properties', () {
        final customVideoEvent = TestHelpers.createMockVideoEvent(
          id: 'custom_id',
          title: 'Custom Title',
          url: 'https://custom.com/video.gif',
          hashtags: ['custom', 'video'],
          isGif: true,
        );
        
        expect(customVideoEvent.id, equals('custom_id'));
        expect(customVideoEvent.title, equals('Custom Title'));
        expect(customVideoEvent.videoUrl, equals('https://custom.com/video.gif'));
        expect(customVideoEvent.hashtags, contains('custom'));
        expect(customVideoEvent.hashtags, contains('video'));
        expect(customVideoEvent.videoUrl, contains('.gif'));
      });
    });

    group('createMockNostrEvent', () {
      test('creates valid Nostr Event with default values', () {
        final event = TestHelpers.createMockNostrEvent();
        
        expect(event, isNotNull);
        expect(event.id, isNotEmpty);
        expect(event.pubkey, isNotEmpty);
        expect(event.kind, equals(1));
        expect(event.content, equals('Mock event content'));
        expect(event.tags, isEmpty);
        expect(event.sig, equals('mock_signature_for_testing'));
      });

      test('creates Event with custom properties', () {
        final customEvent = TestHelpers.createMockNostrEvent(
          id: 'custom_event_id',
          kind: 22,
          content: 'Custom content',
          tags: [['url', 'https://example.com']],
        );
        
        expect(customEvent.id, equals('custom_event_id'));
        expect(customEvent.kind, equals(22));
        expect(customEvent.content, equals('Custom content'));
        expect(customEvent.tags, hasLength(1));
        expect(customEvent.tags[0], equals(['url', 'https://example.com']));
      });
    });

    group('createMockVideoEvents', () {
      test('creates multiple video events', () {
        final events = TestHelpers.createMockVideoEvents(5);
        
        expect(events, hasLength(5));
        for (int i = 0; i < events.length; i++) {
          expect(events[i].id, equals('mock_video_$i'));
          expect(events[i].title, equals('Mock Video $i'));
        }
      });

      test('includes GIFs in batch generation', () {
        final events = TestHelpers.createMockVideoEvents(10, includeGifs: true);
        
        // Every 3rd video should be a GIF (indices 0, 3, 6, 9)
        expect(events[0].videoUrl, contains('.gif'));
        expect(events[3].videoUrl, contains('.gif'));
        expect(events[1].videoUrl, contains('.mp4'));
        expect(events[2].videoUrl, contains('.mp4'));
      });
    });

    group('generatePerformanceTestData', () {
      test('generates correct number of performance test videos', () {
        final testData = TestHelpers.generatePerformanceTestData(100);
        
        expect(testData, hasLength(100));
        expect(testData[0].id, equals('perf_test_0'));
        expect(testData[99].id, equals('perf_test_99'));
      });
    });

    group('createEdgeCaseVideoEvents', () {
      test('creates edge case test data', () {
        final edgeCases = TestHelpers.createEdgeCaseVideoEvents();
        
        expect(edgeCases, isNotEmpty);
        
        // Verify we have various edge cases
        final titles = edgeCases.map((e) => e.title).toList();
        expect(titles.any((title) => title != null && title.length > 50), isTrue, 
               reason: 'Should have long title');
        expect(titles.any((title) => title != null && title.isEmpty), isTrue,
               reason: 'Should have empty title');
        expect(titles.any((title) => title != null && title.contains('émojis')), isTrue,
               reason: 'Should have special characters');
      });
    });
  });
}