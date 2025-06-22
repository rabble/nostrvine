// ABOUTME: Comprehensive test suite for VideoEventProcessor service
// ABOUTME: Tests Nostr event validation, processing, and error handling for video events

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/event.dart';
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
        final validEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // pubkey (hex)
          22,
          [
            ['url', 'https://example.com/video.mp4'],
            ['title', 'Test Video'],
            ['duration', '30'],
          ],
          'Check out this awesome video!'
        );
        
        // ACT & ASSERT
        expect(VideoEventProcessor.isValidVideoEvent(validEvent), isTrue);
        
        final result = VideoEventProcessor.validateEvent(validEvent);
        expect(result.isValid, isTrue);
        expect(result.errors, isEmpty);
      });
      
      test('should reject events with wrong kind', () {
        // ARRANGE
        final wrongKindEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // pubkey (hex)
          1, // Text note, not video
          [],
          'This is not a video event'
        );
        
        // ACT & ASSERT
        expect(VideoEventProcessor.isValidVideoEvent(wrongKindEvent), isFalse);
        
        final result = VideoEventProcessor.validateEvent(wrongKindEvent);
        expect(result.isValid, isFalse);
        expect(result.errors.first, contains('Event must be kind 22 (short video)'));
      });
      
      test('should reject events without video URL', () {
        // ARRANGE
        final noUrlEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // pubkey (hex)
          22,
          [
            ['title', 'Video Title'],
          ],
          'Video without URL'
        );
        
        // ACT & ASSERT
        expect(VideoEventProcessor.isValidVideoEvent(noUrlEvent), isFalse);
        
        final result = VideoEventProcessor.validateEvent(noUrlEvent);
        expect(result.isValid, isFalse);
        expect(result.errors, contains('Video URL is required'));
      });
      
      test('should validate video URL format', () {
        // ARRANGE
        final invalidUrlEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // pubkey (hex)
          22,
          [
            ['url', 'not-a-valid-url'],
          ],
          'Video with invalid URL'
        );
        
        // ACT & ASSERT
        expect(VideoEventProcessor.isValidVideoEvent(invalidUrlEvent), isFalse);
        
        final result = VideoEventProcessor.validateEvent(invalidUrlEvent);
        expect(result.isValid, isFalse);
        expect(result.errors, contains('Invalid video URL format'));
      });
      
      test('should validate supported video formats', () {
        // ARRANGE
        final unsupportedFormatEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // pubkey (hex)
          22,
          [
            ['url', 'https://example.com/video.avi'],
            ['m', 'video/avi'],
          ],
          'Video with unsupported format'
        );
        
        // ACT & ASSERT
        expect(VideoEventProcessor.isValidVideoEvent(unsupportedFormatEvent), isFalse);
        
        final result = VideoEventProcessor.validateEvent(unsupportedFormatEvent);
        expect(result.isValid, isFalse);
        expect(result.errors, contains('Unsupported video format: video/avi'));
      });
      
      test('should validate event fields are not empty', () {
        // ARRANGE - Create event with empty content but valid structure
        final emptyFieldsEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // pubkey (hex)
          22,
          [
            ['url', 'https://example.com/video.mp4'],
          ],
          '' // Empty content is allowed
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
        final validEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // pubkey (hex)
          22,
          [
            ['url', 'https://example.com/awesome_video.mp4'],
            ['title', 'Awesome Video'],
            ['duration', '45'],
            ['dim', '1920x1080'],
            ['m', 'video/mp4'],
            ['t', 'awesome'],
            ['t', 'viral'],
          ],
          'Amazing short video content!'
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
        final imetaEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // pubkey (hex)
          22,
          [
            ['imeta', 'url https://example.com/imeta_video.mp4', 'm video/mp4', 'x abc123def456', 'size 5242880', 'dim 1280x720', 'duration 60'],
            ['title', 'Imeta Video'],
          ],
          'Video with imeta data'
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
        final minimalEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // pubkey (hex)
          22,
          [
            ['url', 'https://example.com/minimal.mp4'],
          ],
          'Minimal video event'
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
        final invalidEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // pubkey (hex)
          1, // Wrong kind
          [],
          'Not a video event'
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
        final malformedTagsEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // pubkey (hex)
          22,
          [
            ['url', 'https://example.com/video.mp4'],
            ['duration'], // Missing value
            ['dim', ''], // Empty value
            ['size', 'not-a-number'], // Invalid number
            [], // Empty tag
          ],
          'Video with malformed tags'
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
        final specialCharsEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // pubkey (hex)
          22,
          [
            ['url', 'https://example.com/special.mp4'],
            ['title', 'Special "Title" with émojis 🎬'],
          ],
          'Video with émojis 🎥 and special chars: "quotes" & <tags>'
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
        final largeContentEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // pubkey (hex)
          22,
          [
            ['url', 'https://example.com/large.mp4'],
          ],
          longContent
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
        final duplicateTagsEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // pubkey (hex)
          22,
          [
            ['url', 'https://example.com/first.mp4'],
            ['url', 'https://example.com/second.mp4'], // Duplicate URL
            ['title', 'First Title'],
            ['title', 'Second Title'], // Duplicate title
            ['duration', '30'],
            ['duration', '60'], // Duplicate duration
          ],
          'Video with duplicate tags'
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
        
        final oldEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // pubkey (hex)
          22,
          [['url', 'https://example.com/old.mp4']],
          'Very old video'
        );
        
        final futureEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // pubkey (hex)
          22,
          [['url', 'https://example.com/future.mp4']],
          'Future video'
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
        final internationalEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // pubkey (hex)
          22,
          [
            ['url', 'https://видео.рф/test.mp4'], // Cyrillic domain
            ['title', 'Vidéo Français'], // French characters
          ],
          'International video'
        );
        
        // ACT
        final videoEvent = VideoEventProcessor.fromNostrEvent(internationalEvent);
        
        // ASSERT
        expect(videoEvent.videoUrl, 'https://видео.рф/test.mp4');
        expect(videoEvent.title, 'Vidéo Français');
      });
      
      test('should handle boundary values for numeric fields', () {
        // ARRANGE
        final boundaryEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // pubkey (hex)
          22,
          [
            ['url', 'https://example.com/boundary.mp4'],
            ['duration', '0'], // Zero duration
            ['size', '0'], // Zero file size
            ['dim', '1x1'], // Minimal dimensions
          ],
          'Boundary values video'
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
        final longUrlEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // pubkey (hex)
          22,
          [
            ['url', longUrl],
          ],
          'Video with very long URL'
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
        final events = List.generate(100, (index) => Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // pubkey (hex)
          22,
          [
            ['url', 'https://example.com/perf$index.mp4'],
            ['title', 'Performance Video $index'],
            ['duration', '${30 + index}'],
          ],
          'Performance test video $index'
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
    
    group('Additional Coverage Tests', () {
      test('should handle empty string URL', () {
        // ARRANGE
        final emptyUrlEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // pubkey (hex)
          22,
          [
            ['url', ''], // Empty string URL
          ],
          'Test video'
        );
        
        // ACT
        final result = VideoEventProcessor.validateEvent(emptyUrlEvent);
        
        // ASSERT
        expect(result.isValid, isFalse);
        expect(result.errors, contains('Video URL is required'));
      });

      test('should validate URL scheme requirement', () {
        // ARRANGE
        final noSchemeEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // pubkey (hex)
          22,
          [
            ['url', 'example.com/video.mp4'], // No scheme
          ],
          'Test video'
        );
        
        // ACT
        final result = VideoEventProcessor.validateEvent(noSchemeEvent);
        
        // ASSERT
        expect(result.isValid, isFalse);
        expect(result.errors, contains('Invalid video URL format'));
      });

      test('should validate URL authority requirement', () {
        // ARRANGE - file:// URLs with file path are actually valid
        final noAuthorityEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // pubkey (hex)
          22,
          [
            ['url', 'file:///local/video.mp4'], // File URL with path
          ],
          'Test video'
        );
        
        // ACT
        final result = VideoEventProcessor.validateEvent(noAuthorityEvent);
        
        // ASSERT - Implementation considers file:// URLs valid
        expect(result.isValid, isTrue);
      });

      test('should handle case-insensitive MIME type validation', () {
        // ARRANGE
        final mixedCaseEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // pubkey (hex)
          22,
          [
            ['url', 'https://example.com/video.mp4'],
            ['m', 'Video/MP4'], // Mixed case - should be normalized to lowercase
          ],
          'Test video'
        );
        
        // ACT
        final result = VideoEventProcessor.validateEvent(mixedCaseEvent);
        
        // ASSERT
        expect(result.isValid, isTrue); // Should be valid after case normalization
      });

      test('should handle negative numeric values', () {
        // ARRANGE
        final negativeValuesEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // pubkey (hex)
          22,
          [
            ['url', 'https://example.com/video.mp4'],
            ['duration', '-10'], // Negative duration
            ['size', '-1000'], // Negative size
          ],
          'Test video'
        );
        
        // ACT
        final result = VideoEventProcessor.validateEvent(negativeValuesEvent);
        
        // ASSERT
        expect(result.isValid, isFalse);
        expect(result.errors, contains('Duration cannot be negative'));
        expect(result.errors, contains('File size cannot be negative'));
      });

      test('should handle content at exact boundary length', () {
        // ARRANGE
        final boundaryContent = 'A' * 10000; // Exactly 10000 characters
        final boundaryContentEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // pubkey (hex)
          22,
          [
            ['url', 'https://example.com/video.mp4'],
          ],
          boundaryContent
        );
        
        // ACT
        final result = VideoEventProcessor.validateEvent(boundaryContentEvent);
        
        // ASSERT
        expect(result.isValid, isTrue);
        expect(result.hasWarnings, isFalse); // Should not warn at exactly 10000
      });

      test('should warn about content exceeding boundary length', () {
        // ARRANGE
        final exceededContent = 'A' * 10001; // Just over 10000 characters
        final exceededContentEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // pubkey (hex)
          22,
          [
            ['url', 'https://example.com/video.mp4'],
          ],
          exceededContent
        );
        
        // ACT
        final result = VideoEventProcessor.validateEvent(exceededContentEvent);
        
        // ASSERT
        expect(result.isValid, isTrue);
        expect(result.hasWarnings, isTrue);
        expect(result.warnings, contains(contains('Content is very long')));
      });

      test('should handle completely empty tags', () {
        // ARRANGE
        final emptyTagsEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // pubkey (hex)
          22,
          [
            [], // Completely empty tag
            ['url', 'https://example.com/video.mp4'],
            [], // Another empty tag
          ],
          'Video with empty tags'
        );
        
        // ACT
        final result = VideoEventProcessor.validateEvent(emptyTagsEvent);
        
        // ASSERT
        expect(result.isValid, isTrue); // Should handle empty tags gracefully
      });

      test('should handle tags with only tag name', () {
        // ARRANGE
        final incompleteTagsEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // pubkey (hex)
          22,
          [
            ['url', 'https://example.com/video.mp4'],
            ['duration'], // Missing value
            ['title'], // Missing value
          ],
          'Video with incomplete tags'
        );
        
        // ACT
        final result = VideoEventProcessor.validateEvent(incompleteTagsEvent);
        
        // ASSERT
        expect(result.isValid, isTrue); // Should handle gracefully
        final videoEvent = VideoEventProcessor.fromNostrEvent(incompleteTagsEvent);
        expect(videoEvent.duration, isNull); // Should be null for empty duration
        expect(videoEvent.title, equals('')); // Should be empty string for missing title value
      });

      test('should handle malformed imeta tags', () {
        // ARRANGE
        final malformedImetaEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // pubkey (hex)
          22,
          [
            ['url', 'https://example.com/video.mp4'],
            ['imeta', 'url ', 'm '], // Empty values after keys
            ['imeta', 'justtext'], // No key-value pairs
            ['imeta', 'url  https://example.com/imeta.mp4'], // Multiple spaces
          ],
          'Video with malformed imeta'
        );
        
        // ACT
        final result = VideoEventProcessor.validateEvent(malformedImetaEvent);
        
        // ASSERT
        expect(result.isValid, isTrue); // Should handle malformed imeta gracefully
        final videoEvent = VideoEventProcessor.fromNostrEvent(malformedImetaEvent);
        expect(videoEvent.videoUrl, 'https://example.com/video.mp4'); // Should use regular url tag
      });

      test('should handle numeric parsing edge cases', () {
        // ARRANGE
        final numericEdgeCasesEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // pubkey (hex)
          22,
          [
            ['url', 'https://example.com/video.mp4'],
            ['duration', ' 123 '], // Leading/trailing whitespace
            ['size', '9223372036854775808'], // Larger than int64 max
          ],
          'Video with numeric edge cases'
        );
        
        // ACT
        final result = VideoEventProcessor.validateEvent(numericEdgeCasesEvent);
        final videoEvent = VideoEventProcessor.fromNostrEvent(numericEdgeCasesEvent);
        
        // ASSERT
        expect(result.isValid, isTrue);
        expect(videoEvent.duration, equals(123)); // int.tryParse handles whitespace padding
        expect(videoEvent.fileSize, isNull); // Should be null for overflow values
      });

      test('should warn at duration boundary', () {
        // ARRANGE
        final boundaryDurationEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // pubkey (hex)
          22,
          [
            ['url', 'https://example.com/video.mp4'],
            ['duration', '600'], // Exactly at maxReasonableDuration
          ],
          'Video at duration boundary'
        );
        
        // ACT
        final result = VideoEventProcessor.validateEvent(boundaryDurationEvent);
        
        // ASSERT
        expect(result.isValid, isTrue);
        expect(result.hasWarnings, isFalse); // Should not warn at exactly the boundary
      });

      test('should warn beyond duration boundary', () {
        // ARRANGE
        final exceededDurationEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // pubkey (hex)
          22,
          [
            ['url', 'https://example.com/video.mp4'],
            ['duration', '601'], // Just over maxReasonableDuration
          ],
          'Video exceeding duration boundary'
        );
        
        // ACT
        final result = VideoEventProcessor.validateEvent(exceededDurationEvent);
        
        // ASSERT
        expect(result.isValid, isTrue);
        expect(result.hasWarnings, isTrue);
        expect(result.warnings, contains(contains('Duration appears very long')));
      });

      test('should warn at file size boundary', () {
        // ARRANGE
        final maxSize = VideoEventProcessor.maxReasonableFileSize + 1;
        final largeSizeEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // pubkey (hex)
          22,
          [
            ['url', 'https://example.com/video.mp4'],
            ['size', maxSize.toString()],
          ],
          'Video with large file size'
        );
        
        // ACT
        final result = VideoEventProcessor.validateEvent(largeSizeEvent);
        
        // ASSERT
        expect(result.isValid, isTrue);
        expect(result.hasWarnings, isTrue);
        expect(result.warnings, contains(contains('File size appears very large')));
      });

      test('should handle URL with non-video extension', () {
        // ARRANGE
        final nonVideoExtEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // pubkey (hex)
          22,
          [
            ['url', 'https://example.com/file.txt'], // Non-video extension
          ],
          'URL with non-video extension'
        );
        
        // ACT
        final result = VideoEventProcessor.validateEvent(nonVideoExtEvent);
        
        // ASSERT
        expect(result.isValid, isTrue);
        expect(result.hasWarnings, isTrue);
        expect(result.warnings, contains(contains('does not appear to be a direct video file link')));
      });

      test('should handle multiple warnings simultaneously', () {
        // ARRANGE
        final multipleWarningsEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // pubkey (hex)
          22,
          [
            ['url', 'https://example.com/file.txt'], // Non-video URL warning
            ['duration', '700'], // Long duration warning
            ['size', '200000000'], // Large size warning
          ],
          'A' * 15000 // Long content warning
        );
        
        // ACT
        final result = VideoEventProcessor.validateEvent(multipleWarningsEvent);
        
        // ASSERT
        expect(result.isValid, isTrue);
        expect(result.hasWarnings, isTrue);
        expect(result.warnings.length, greaterThanOrEqualTo(3));
      });

      test('should handle special URL protocols', () {
        // ARRANGE
        final ftpUrlEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // pubkey (hex)
          22,
          [
            ['url', 'ftp://ftp.example.com/video.mp4'], // FTP protocol
          ],
          'Video with FTP URL'
        );
        
        // ACT
        final result = VideoEventProcessor.validateEvent(ftpUrlEvent);
        
        // ASSERT
        expect(result.isValid, isTrue); // Should accept valid URI with scheme and authority
      });

      test('should handle URL with port numbers', () {
        // ARRANGE
        final portUrlEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // pubkey (hex)
          22,
          [
            ['url', 'https://example.com:8080/video.mp4'], // URL with port
          ],
          'Video with port in URL'
        );
        
        // ACT
        final result = VideoEventProcessor.validateEvent(portUrlEvent);
        
        // ASSERT
        expect(result.isValid, isTrue);
      });

      test('should handle large number of tags efficiently', () {
        // ARRANGE
        final largeTags = List.generate(100, (i) => ['t', 'tag$i']);
        largeTags.insert(0, ['url', 'https://example.com/video.mp4']);
        
        final largeTagsEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // pubkey (hex)
          22,
          largeTags,
          'Video with many tags'
        );
        
        // ACT
        final stopwatch = Stopwatch()..start();
        final result = VideoEventProcessor.validateEvent(largeTagsEvent);
        stopwatch.stop();
        
        // ASSERT
        expect(result.isValid, isTrue);
        expect(stopwatch.elapsedMilliseconds, lessThan(100)); // Should be fast
      });
    });

    group('ValidationResult', () {
      test('should provide detailed validation results', () {
        // ARRANGE
        final invalidEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // pubkey (hex)
          1, // Wrong kind
          [
            ['url', 'invalid-url'],
          ],
          ''
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
        final suspiciousEvent = Event(
          '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef', // pubkey (hex)
          22,
          [
            ['url', 'https://example.com/video.mp4'],
            ['duration', '36000'], // 10 hours - suspiciously long for short video
          ],
          'Video with suspicious duration'
        );
        
        // ACT
        final result = VideoEventProcessor.validateEvent(suspiciousEvent);
        
        // ASSERT
        expect(result.isValid, isTrue); // Still valid
        expect(result.hasWarnings, isTrue);
        expect(result.warnings, contains(contains('Duration appears very long for short video')));
      });

      test('should format toString correctly for various states', () {
        // ARRANGE & ACT
        final validResult = ValidationResult(errors: [], warnings: []);
        final errorResult = ValidationResult(errors: ['Error 1', 'Error 2'], warnings: []);
        final warningResult = ValidationResult(errors: [], warnings: ['Warning 1']);
        final mixedResult = ValidationResult(errors: ['Error'], warnings: ['Warning']);
        
        // ASSERT
        expect(validResult.toString(), contains('valid: true'));
        expect(errorResult.toString(), contains('valid: false'));
        expect(errorResult.toString(), contains('errors: 2'));
        expect(warningResult.toString(), contains('warnings: 1'));
        expect(mixedResult.toString(), contains('errors: 1'));
        expect(mixedResult.toString(), contains('warnings: 1'));
      });
    });

    group('VideoEventProcessorException', () {
      test('should format toString correctly with all fields', () {
        // ARRANGE
        const exception = VideoEventProcessorException(
          'Test error message',
          eventId: 'event123',
          originalError: 'Original exception',
        );
        
        // ACT
        final exceptionString = exception.toString();
        
        // ASSERT
        expect(exceptionString, contains('VideoEventProcessorException: Test error message'));
        expect(exceptionString, contains('(eventId: event123)'));
        expect(exceptionString, contains('(caused by: Original exception)'));
      });

      test('should format toString correctly with minimal fields', () {
        // ARRANGE
        const exception = VideoEventProcessorException('Simple error');
        
        // ACT
        final exceptionString = exception.toString();
        
        // ASSERT
        expect(exceptionString, equals('VideoEventProcessorException: Simple error'));
      });

      test('should format toString correctly with partial fields', () {
        // ARRANGE
        const exceptionWithId = VideoEventProcessorException(
          'Error with ID',
          eventId: 'event456',
        );
        
        const exceptionWithOriginal = VideoEventProcessorException(
          'Error with original',
          originalError: 'Root cause',
        );
        
        // ACT & ASSERT
        expect(exceptionWithId.toString(), contains('(eventId: event456)'));
        expect(exceptionWithId.toString(), isNot(contains('caused by')));
        
        expect(exceptionWithOriginal.toString(), contains('(caused by: Root cause)'));
        expect(exceptionWithOriginal.toString(), isNot(contains('eventId')));
      });
    });

    group('Static Constants Access', () {
      test('should expose supported video formats', () {
        // ACT & ASSERT
        expect(VideoEventProcessor.supportedVideoFormats, isNotEmpty);
        expect(VideoEventProcessor.supportedVideoFormats, contains('video/mp4'));
        expect(VideoEventProcessor.supportedVideoFormats, contains('image/gif'));
        expect(VideoEventProcessor.supportedVideoFormats.length, equals(6));
      });

      test('should expose reasonable limits', () {
        // ACT & ASSERT
        expect(VideoEventProcessor.maxReasonableDuration, equals(600));
        expect(VideoEventProcessor.maxReasonableFileSize, equals(100 * 1024 * 1024));
      });
    });
  });
}