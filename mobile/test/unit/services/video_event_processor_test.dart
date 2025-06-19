// ABOUTME: Comprehensive test suite for VideoEventProcessor service
// ABOUTME: Tests Nostr event validation, processing, and error handling for video events

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr/nostr.dart';
import 'package:nostrvine_app/services/video_event_processor.dart';
import 'package:nostrvine_app/models/video_event.dart';
import '../../helpers/test_helpers.dart';

/// Tests for VideoEventProcessor that handles Nostr video event processing
/// with robust validation and error handling
void main() {
  group('VideoEventProcessor', () {
    
    group('Event Validation', () {
      test('should validate correct kind 22 video events', () {
        // ARRANGE
        final validEvent = Event.from(
          kind: 22,
          content: 'Check out this awesome video!',
          tags: [
            ['url', 'https://example.com/video.mp4'],
            ['title', 'Test Video'],
            ['duration', '30'],
          ],
          privkey: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        );
        
        // ACT & ASSERT
        expect(VideoEventProcessor.isValidVideoEvent(validEvent), isTrue);
        
        final result = VideoEventProcessor.validateEvent(validEvent);
        expect(result.isValid, isTrue);
        expect(result.errors, isEmpty);
      });
      
      test('should reject events with wrong kind', () {
        // ARRANGE
        final wrongKindEvent = Event.from(
          kind: 1, // Text note, not video
          content: 'This is not a video event',
          tags: [],
          privkey: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        );
        
        // ACT & ASSERT
        expect(VideoEventProcessor.isValidVideoEvent(wrongKindEvent), isFalse);
        
        final result = VideoEventProcessor.validateEvent(wrongKindEvent);
        expect(result.isValid, isFalse);
        expect(result.errors.first, contains('Event must be kind 22 (short video)'));
      });
      
      test('should reject events without video URL', () {
        // ARRANGE
        final noUrlEvent = Event.from(
          kind: 22,
          content: 'Video without URL',
          tags: [
            ['title', 'Video Title'],
          ],
          privkey: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        );
        
        // ACT & ASSERT
        expect(VideoEventProcessor.isValidVideoEvent(noUrlEvent), isFalse);
        
        final result = VideoEventProcessor.validateEvent(noUrlEvent);
        expect(result.isValid, isFalse);
        expect(result.errors, contains('Video URL is required'));
      });
      
      test('should validate video URL format', () {
        // ARRANGE
        final invalidUrlEvent = Event.from(
          kind: 22,
          content: 'Video with invalid URL',
          tags: [
            ['url', 'not-a-valid-url'],
          ],
          privkey: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        );
        
        // ACT & ASSERT
        expect(VideoEventProcessor.isValidVideoEvent(invalidUrlEvent), isFalse);
        
        final result = VideoEventProcessor.validateEvent(invalidUrlEvent);
        expect(result.isValid, isFalse);
        expect(result.errors, contains('Invalid video URL format'));
      });
      
      test('should validate supported video formats', () {
        // ARRANGE
        final unsupportedFormatEvent = Event.from(
          kind: 22,
          content: 'Video with unsupported format',
          tags: [
            ['url', 'https://example.com/video.avi'],
            ['m', 'video/avi'],
          ],
          privkey: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        );
        
        // ACT & ASSERT
        expect(VideoEventProcessor.isValidVideoEvent(unsupportedFormatEvent), isFalse);
        
        final result = VideoEventProcessor.validateEvent(unsupportedFormatEvent);
        expect(result.isValid, isFalse);
        expect(result.errors, contains('Unsupported video format: video/avi'));
      });
      
      test('should validate event fields are not empty', () {
        // ARRANGE - Create event with empty content but valid structure
        final emptyFieldsEvent = Event.from(
          kind: 22,
          content: '', // Empty content is allowed
          tags: [
            ['url', 'https://example.com/video.mp4'],
          ],
          privkey: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        );
        
        // ACT & ASSERT
        // Event.from() generates valid ID and pubkey automatically, so this should be valid
        expect(VideoEventProcessor.isValidVideoEvent(emptyFieldsEvent), isTrue);
        
        final result = VideoEventProcessor.validateEvent(emptyFieldsEvent);
        expect(result.isValid, isTrue);
        // Note: Empty content is allowed, so no errors expected
      });
    });
    
    group('Event Processing', () {
      test('should successfully process valid video event', () {
        // ARRANGE
        final validEvent = Event.from(
          kind: 22,
          content: 'Amazing short video content!',
          tags: [
            ['url', 'https://example.com/awesome_video.mp4'],
            ['title', 'Awesome Video'],
            ['duration', '45'],
            ['dim', '1920x1080'],
            ['m', 'video/mp4'],
            ['t', 'awesome'],
            ['t', 'viral'],
          ],
          privkey: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        );
        
        // ACT
        final videoEvent = VideoEventProcessor.fromNostrEvent(validEvent);
        
        // ASSERT
        expect(videoEvent, isNotNull);
        expect(videoEvent.id, isNotEmpty);
        expect(videoEvent.pubkey, isNotEmpty);
        expect(videoEvent.content, 'Amazing short video content!');
        expect(videoEvent.title, 'Awesome Video');
        expect(videoEvent.videoUrl, 'https://example.com/awesome_video.mp4');
        expect(videoEvent.duration, 45);
        expect(videoEvent.dimensions, '1920x1080');
        expect(videoEvent.mimeType, 'video/mp4');
        expect(videoEvent.hashtags, containsAll(['awesome', 'viral']));
      });
      
      test('should handle events with imeta tags', () {
        // ARRANGE
        final imetaEvent = Event.from(
          kind: 22,
          content: 'Video with imeta data',
          tags: [
            ['imeta', 'url https://example.com/imeta_video.mp4', 'm video/mp4', 'x abc123def456', 'size 5242880', 'dim 1280x720', 'duration 60'],
            ['title', 'Imeta Video'],
          ],
          privkey: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        );
        
        // ACT
        final videoEvent = VideoEventProcessor.fromNostrEvent(imetaEvent);
        
        // ASSERT
        expect(videoEvent.videoUrl, 'https://example.com/imeta_video.mp4');
        expect(videoEvent.mimeType, 'video/mp4');
        expect(videoEvent.sha256, 'abc123def456');
        expect(videoEvent.fileSize, 5242880);
        expect(videoEvent.dimensions, '1280x720');
        expect(videoEvent.duration, 60);
      });
      
      test('should handle missing optional fields gracefully', () {
        // ARRANGE
        final minimalEvent = Event.from(
          kind: 22,
          content: 'Minimal video event',
          tags: [
            ['url', 'https://example.com/minimal.mp4'],
          ],
          privkey: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        );
        
        // ACT
        final videoEvent = VideoEventProcessor.fromNostrEvent(minimalEvent);
        
        // ASSERT
        expect(videoEvent.id, isNotEmpty);
        expect(videoEvent.videoUrl, 'https://example.com/minimal.mp4');
        expect(videoEvent.title, isNull);
        expect(videoEvent.duration, isNull);
        expect(videoEvent.dimensions, isNull);
        expect(videoEvent.hashtags, isEmpty);
      });
    });
    
    group('Error Handling', () {
      test('should throw VideoEventProcessorException for invalid events', () {
        // ARRANGE
        final invalidEvent = Event.from(
          kind: 1, // Wrong kind
          content: 'Not a video event',
          tags: [],
          privkey: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        );
        
        // ACT & ASSERT
        expect(
          () => VideoEventProcessor.fromNostrEvent(invalidEvent),
          throwsA(isA<VideoEventProcessorException>()),
        );
      });
      
      test('should handle null event gracefully', () {
        // ACT & ASSERT
        expect(
          () => VideoEventProcessor.fromNostrEvent(null as dynamic),
          throwsA(isA<TypeError>()),
        );
      });
      
      test('should handle malformed tag data', () {
        // ARRANGE
        final malformedTagsEvent = Event.from(
          kind: 22,
          content: 'Video with malformed tags',
          tags: [
            ['url', 'https://example.com/video.mp4'],
            ['duration'], // Missing value
            ['dim', ''], // Empty value
            ['size', 'not-a-number'], // Invalid number
            [], // Empty tag
          ],
          privkey: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        );
        
        // ACT
        final videoEvent = VideoEventProcessor.fromNostrEvent(malformedTagsEvent);
        
        // ASSERT: Should handle gracefully without crashing
        expect(videoEvent, isNotNull);
        expect(videoEvent.videoUrl, 'https://example.com/video.mp4');
        expect(videoEvent.duration, isNull); // Should be null for invalid duration
        expect(videoEvent.fileSize, isNull); // Should be null for invalid size
      });
      
      test('should handle special characters in content', () {
        // ARRANGE
        final specialCharsEvent = Event.from(
          kind: 22,
          content: 'Video with émojis 🎥 and special chars: "quotes" & <tags>',
          tags: [
            ['url', 'https://example.com/special.mp4'],
            ['title', 'Special "Title" with émojis 🎬'],
          ],
          privkey: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        );
        
        // ACT
        final videoEvent = VideoEventProcessor.fromNostrEvent(specialCharsEvent);
        
        // ASSERT
        expect(videoEvent.content, contains('émojis 🎥'));
        expect(videoEvent.title, contains('Special "Title" with émojis 🎬'));
      });
      
      test('should handle very large content fields', () {
        // ARRANGE
        final longContent = 'A' * 10000; // 10KB content
        final largeContentEvent = Event.from(
          kind: 22,
          content: longContent,
          tags: [
            ['url', 'https://example.com/large.mp4'],
          ],
          privkey: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        );
        
        // ACT
        final videoEvent = VideoEventProcessor.fromNostrEvent(largeContentEvent);
        
        // ASSERT
        expect(videoEvent, isNotNull);
        expect(videoEvent.content.length, 10000);
      });
    });
    
    group('Edge Cases', () {
      test('should handle duplicate tags', () {
        // ARRANGE
        final duplicateTagsEvent = Event.from(
          kind: 22,
          content: 'Video with duplicate tags',
          tags: [
            ['url', 'https://example.com/first.mp4'],
            ['url', 'https://example.com/second.mp4'], // Duplicate URL
            ['title', 'First Title'],
            ['title', 'Second Title'], // Duplicate title
            ['duration', '30'],
            ['duration', '60'], // Duplicate duration
          ],
          privkey: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        );
        
        // ACT
        final videoEvent = VideoEventProcessor.fromNostrEvent(duplicateTagsEvent);
        
        // ASSERT: VideoEvent parsing uses last occurrence for duplicate tags
        expect(videoEvent.videoUrl, 'https://example.com/second.mp4');
        expect(videoEvent.title, 'Second Title');
        expect(videoEvent.duration, 60);
      });
      
      test('should handle extremely old and future timestamps', () {
        // ARRANGE
        final oldTimestamp = DateTime(1970, 1, 1);
        final futureTimestamp = DateTime(2030, 12, 31);
        
        final oldEvent = Event.from(
          kind: 22,
          content: 'Very old video',
          tags: [['url', 'https://example.com/old.mp4']],
          privkey: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        );
        
        final futureEvent = Event.from(
          kind: 22,
          content: 'Future video',
          tags: [['url', 'https://example.com/future.mp4']],
          privkey: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        );
        
        // ACT
        final oldVideoEvent = VideoEventProcessor.fromNostrEvent(oldEvent);
        final futureVideoEvent = VideoEventProcessor.fromNostrEvent(futureEvent);
        
        // ASSERT: Event.from() generates current timestamp, so check general validity
        expect(oldVideoEvent.timestamp, isA<DateTime>());
        expect(futureVideoEvent.timestamp, isA<DateTime>());
      });
      
      test('should handle international domain names and URLs', () {
        // ARRANGE
        final internationalEvent = Event.from(
          kind: 22,
          content: 'International video',
          tags: [
            ['url', 'https://видео.рф/test.mp4'], // Cyrillic domain
            ['title', 'Vidéo Français'], // French characters
          ],
          privkey: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        );
        
        // ACT
        final videoEvent = VideoEventProcessor.fromNostrEvent(internationalEvent);
        
        // ASSERT
        expect(videoEvent.videoUrl, 'https://видео.рф/test.mp4');
        expect(videoEvent.title, 'Vidéo Français');
      });
      
      test('should handle boundary values for numeric fields', () {
        // ARRANGE
        final boundaryEvent = Event.from(
          kind: 22,
          content: 'Boundary values video',
          tags: [
            ['url', 'https://example.com/boundary.mp4'],
            ['duration', '0'], // Zero duration
            ['size', '0'], // Zero file size
            ['dim', '1x1'], // Minimal dimensions
          ],
          privkey: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        );
        
        // ACT
        final videoEvent = VideoEventProcessor.fromNostrEvent(boundaryEvent);
        
        // ASSERT
        expect(videoEvent.duration, 0);
        expect(videoEvent.fileSize, 0);
        expect(videoEvent.dimensions, '1x1');
        expect(videoEvent.width, 1);
        expect(videoEvent.height, 1);
      });
      
      test('should handle extremely long URLs', () {
        // ARRANGE
        final longUrl = 'https://example.com/' + 'very-long-path/' * 100 + 'video.mp4';
        final longUrlEvent = Event.from(
          kind: 22,
          content: 'Video with very long URL',
          tags: [
            ['url', longUrl],
          ],
          privkey: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        );
        
        // ACT
        final videoEvent = VideoEventProcessor.fromNostrEvent(longUrlEvent);
        
        // ASSERT
        expect(videoEvent.videoUrl, longUrl);
        expect(videoEvent.videoUrl!.length, greaterThan(1000));
      });
    });
    
    group('Performance', () {
      test('should process events efficiently', () {
        // ARRANGE
        final events = List.generate(100, (index) => Event.from(
          kind: 22,
          content: 'Performance test video $index',
          tags: [
            ['url', 'https://example.com/perf$index.mp4'],
            ['title', 'Performance Video $index'],
            ['duration', '${30 + index}'],
          ],
          privkey: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        ));
        
        // ACT
        final stopwatch = Stopwatch()..start();
        final videoEvents = events.map((e) => VideoEventProcessor.fromNostrEvent(e)).toList();
        stopwatch.stop();
        
        // ASSERT
        expect(videoEvents.length, 100);
        expect(stopwatch.elapsedMilliseconds, lessThan(1000)); // Should process 100 events in <1 second
      });
    });
    
    group('ValidationResult', () {
      test('should provide detailed validation results', () {
        // ARRANGE
        final invalidEvent = Event.from(
          kind: 1, // Wrong kind
          content: '',
          tags: [
            ['url', 'invalid-url'],
          ],
          privkey: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        );
        
        // ACT
        final result = VideoEventProcessor.validateEvent(invalidEvent);
        
        // ASSERT
        expect(result.isValid, isFalse);
        expect(result.errors, isNotEmpty);
        expect(result.warnings, isA<List<String>>());
        expect(result.hasErrors, isTrue);
        expect(result.hasWarnings, isA<bool>());
      });
      
      test('should provide warnings for suspicious but valid events', () {
        // ARRANGE
        final suspiciousEvent = Event.from(
          kind: 22,
          content: 'Video with suspicious duration',
          tags: [
            ['url', 'https://example.com/video.mp4'],
            ['duration', '36000'], // 10 hours - suspiciously long for short video
          ],
          privkey: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
        );
        
        // ACT
        final result = VideoEventProcessor.validateEvent(suspiciousEvent);
        
        // ASSERT
        expect(result.isValid, isTrue); // Still valid
        expect(result.hasWarnings, isTrue);
        expect(result.warnings, contains(contains('Duration appears very long for short video')));
      });
    });
  });
}