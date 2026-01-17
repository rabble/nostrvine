// ABOUTME: Tests for VideoEvent audio reference parsing from e-tags with "audio" marker
// ABOUTME: Verifies support for Kind 1063 audio event references in Kind 34236 video events

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/event.dart';
import 'package:models/models.dart';

void main() {
  // Valid 64-character hex string for test pubkey
  const testPubkey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  // Valid 64-character hex string for audio event ID
  const testAudioEventId =
      'abcd1234567890abcd1234567890abcd1234567890abcd1234567890abcd1234';
  // Another valid audio event ID for multi-reference test
  const testAudioEventId2 =
      'efef5678901234abcdef5678901234abcdef5678901234abcdef567890123456';

  group('VideoEvent audio reference parsing', () {
    test(
      'should parse audio reference from e-tag with relay and audio marker',
      () {
        // Arrange - video event with e-tag referencing an audio event
        // Format: ["e", "<audio-event-id>", "<relay>", "audio"]
        final nostrEvent = Event(
          testPubkey,
          34236,
          [
            ['d', 'test-vine-id'],
            ['url', 'https://example.com/video.mp4'],
            ['e', testAudioEventId, 'wss://relay.example.com', 'audio'],
          ],
          'Video using external audio',
          createdAt: 1757385263,
        );

        // Act
        final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

        // Assert
        expect(videoEvent.audioEventId, equals(testAudioEventId));
        expect(videoEvent.audioEventRelay, equals('wss://relay.example.com'));
        expect(videoEvent.hasAudioReference, isTrue);
      },
    );

    test('should parse audio reference from e-tag without relay hint', () {
      // Arrange - e-tag with audio marker but no relay
      // Format: ["e", "<audio-event-id>", "audio"]
      final nostrEvent = Event(
        testPubkey,
        34236,
        [
          ['d', 'test-vine-id'],
          ['url', 'https://example.com/video.mp4'],
          ['e', testAudioEventId, 'audio'],
        ],
        'Video using external audio',
        createdAt: 1757385263,
      );

      // Act
      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      // Assert
      expect(videoEvent.audioEventId, equals(testAudioEventId));
      expect(videoEvent.audioEventRelay, isNull);
      expect(videoEvent.hasAudioReference, isTrue);
    });

    test('should have no audio reference when e-tag has no audio marker', () {
      // Arrange - regular e-tag without audio marker
      final nostrEvent = Event(
        testPubkey,
        34236,
        [
          ['d', 'test-vine-id'],
          ['url', 'https://example.com/video.mp4'],
          ['e', testAudioEventId, 'wss://relay.example.com', 'reply'],
        ],
        'Regular video',
        createdAt: 1757385263,
      );

      // Act
      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      // Assert
      expect(videoEvent.audioEventId, isNull);
      expect(videoEvent.audioEventRelay, isNull);
      expect(videoEvent.hasAudioReference, isFalse);
    });

    test('should have no audio reference when no e-tag exists', () {
      // Arrange - video event without any e-tags
      final nostrEvent = Event(
        testPubkey,
        34236,
        [
          ['d', 'test-vine-id'],
          ['url', 'https://example.com/video.mp4'],
          ['title', 'Original video'],
        ],
        'Original video with original audio',
        createdAt: 1757385263,
      );

      // Act
      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      // Assert
      expect(videoEvent.audioEventId, isNull);
      expect(videoEvent.audioEventRelay, isNull);
      expect(videoEvent.hasAudioReference, isFalse);
    });

    test('should only use first audio reference when multiple exist', () {
      // Arrange - multiple e-tags with audio markers (edge case)
      final nostrEvent = Event(
        testPubkey,
        34236,
        [
          ['d', 'test-vine-id'],
          ['url', 'https://example.com/video.mp4'],
          ['e', testAudioEventId, 'wss://relay1.example.com', 'audio'],
          ['e', testAudioEventId2, 'wss://relay2.example.com', 'audio'],
        ],
        'Video with multiple audio refs',
        createdAt: 1757385263,
      );

      // Act
      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      // Assert - should use the first audio reference encountered
      expect(videoEvent.audioEventId, equals(testAudioEventId));
      expect(videoEvent.audioEventRelay, equals('wss://relay1.example.com'));
    });

    test('should preserve audio reference through copyWith', () {
      // Arrange
      final nostrEvent = Event(
        testPubkey,
        34236,
        [
          ['d', 'test-vine-id'],
          ['url', 'https://example.com/video.mp4'],
          ['e', testAudioEventId, 'wss://relay.example.com', 'audio'],
        ],
        'Video with audio',
        createdAt: 1757385263,
      );
      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      // Act - copy with different title but keep audio reference
      final copied = videoEvent.copyWith(title: 'New Title');

      // Assert
      expect(copied.title, equals('New Title'));
      expect(copied.audioEventId, equals(videoEvent.audioEventId));
      expect(copied.audioEventRelay, equals(videoEvent.audioEventRelay));
      expect(copied.hasAudioReference, isTrue);
    });

    test('should allow updating audio reference through copyWith', () {
      // Arrange
      final nostrEvent = Event(
        testPubkey,
        34236,
        [
          ['d', 'test-vine-id'],
          ['url', 'https://example.com/video.mp4'],
        ],
        'Video without audio',
        createdAt: 1757385263,
      );
      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      // Act - add audio reference through copyWith
      final copied = videoEvent.copyWith(
        audioEventId: testAudioEventId,
        audioEventRelay: 'wss://new-relay.example.com',
      );

      // Assert
      expect(copied.audioEventId, equals(testAudioEventId));
      expect(copied.audioEventRelay, equals('wss://new-relay.example.com'));
      expect(copied.hasAudioReference, isTrue);
      // Original should still have no audio reference
      expect(videoEvent.hasAudioReference, isFalse);
    });

    test('should coexist with other e-tag types', () {
      // Arrange - video with both reply and audio e-tags
      const replyTargetId =
          '1111222233334444555566667777888899990000aaaabbbbccccddddeeee0000';
      const mentionId =
          '2222333344445555666677778888999900001111bbbbccccddddeeeeaaaa1111';

      final nostrEvent = Event(
        testPubkey,
        34236,
        [
          ['d', 'test-vine-id'],
          ['url', 'https://example.com/video.mp4'],
          ['e', replyTargetId, 'wss://relay.example.com', 'reply'],
          ['e', testAudioEventId, 'wss://audio-relay.example.com', 'audio'],
          ['e', mentionId, 'wss://relay.example.com', 'mention'],
        ],
        'Video reply using external audio',
        createdAt: 1757385263,
      );

      // Act
      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      // Assert - should correctly identify the audio reference
      expect(videoEvent.audioEventId, equals(testAudioEventId));
      expect(
        videoEvent.audioEventRelay,
        equals('wss://audio-relay.example.com'),
      );
      expect(videoEvent.hasAudioReference, isTrue);
    });

    test('should not treat empty relay as valid relay hint', () {
      // Arrange - e-tag with empty relay string
      final nostrEvent = Event(
        testPubkey,
        34236,
        [
          ['d', 'test-vine-id'],
          ['url', 'https://example.com/video.mp4'],
          ['e', testAudioEventId, '', 'audio'],
        ],
        'Video with empty relay hint',
        createdAt: 1757385263,
      );

      // Act
      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      // Assert
      expect(videoEvent.audioEventId, equals(testAudioEventId));
      expect(videoEvent.audioEventRelay, isNull);
      expect(videoEvent.hasAudioReference, isTrue);
    });

    test('should handle e-tag with only event ID (2 elements)', () {
      // Arrange - minimal e-tag without relay or marker
      final nostrEvent = Event(
        testPubkey,
        34236,
        [
          ['d', 'test-vine-id'],
          ['url', 'https://example.com/video.mp4'],
          ['e', testAudioEventId],
        ],
        'Video with minimal e-tag',
        createdAt: 1757385263,
      );

      // Act
      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      // Assert - should NOT be treated as audio reference
      expect(videoEvent.audioEventId, isNull);
      expect(videoEvent.hasAudioReference, isFalse);
    });
  });
}
