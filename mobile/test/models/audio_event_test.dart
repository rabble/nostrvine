// ABOUTME: Tests for AudioEvent model - Kind 1063 audio file metadata events
// ABOUTME: Validates parsing from Nostr events, tag generation, and edge cases

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/models/audio_event.dart';
import 'package:openvine/models/vine_sound.dart';

// Valid 64-character hex pubkey for testing
const testPubkey =
    'abc123def456789012345678901234567890123456789012345678901234abcd';

void main() {
  group('AudioEvent', () {
    group('fromNostrEvent', () {
      test('parses complete audio event with all fields', () {
        // Arrange
        final nostrEvent = Event(
          testPubkey,
          1063,
          [
            ['url', 'https://blossom.example/abc123.aac'],
            ['m', 'audio/aac'],
            [
              'x',
              'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
            ],
            ['size', '98765'],
            ['duration', '6.2'],
            ['title', 'Original sound - @username'],
            ['a', '34236:pubkey123:vine-id-456', 'wss://relay.example'],
          ],
          '',
          createdAt: 1700000000,
        );

        // Act
        final audioEvent = AudioEvent.fromNostrEvent(nostrEvent);

        // Assert
        expect(audioEvent.id, equals(nostrEvent.id));
        expect(audioEvent.pubkey, equals(testPubkey));
        expect(audioEvent.url, equals('https://blossom.example/abc123.aac'));
        expect(audioEvent.mimeType, equals('audio/aac'));
        expect(
          audioEvent.sha256,
          equals(
            'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
          ),
        );
        expect(audioEvent.fileSize, equals(98765));
        expect(audioEvent.duration, closeTo(6.2, 0.001));
        expect(audioEvent.title, equals('Original sound - @username'));
        expect(
          audioEvent.sourceVideoReference,
          equals('34236:pubkey123:vine-id-456'),
        );
        expect(audioEvent.sourceVideoRelay, equals('wss://relay.example'));
        expect(audioEvent.createdAt, equals(1700000000));
      });

      test('parses audio event with minimal required fields', () {
        // Arrange - only url and m are truly required per NIP-94
        final nostrEvent = Event(
          testPubkey,
          1063,
          [
            ['url', 'https://cdn.example/audio.aac'],
            ['m', 'audio/mp4'],
          ],
          '',
          createdAt: 1700000000,
        );

        // Act
        final audioEvent = AudioEvent.fromNostrEvent(nostrEvent);

        // Assert
        expect(audioEvent.url, equals('https://cdn.example/audio.aac'));
        expect(audioEvent.mimeType, equals('audio/mp4'));
        expect(audioEvent.sha256, isNull);
        expect(audioEvent.fileSize, isNull);
        expect(audioEvent.duration, isNull);
        expect(audioEvent.title, isNull);
        expect(audioEvent.sourceVideoReference, isNull);
      });

      test('throws for non-1063 event kind', () {
        // Arrange
        final nostrEvent = Event(
          testPubkey,
          34236, // Wrong kind - this is video
          [
            ['url', 'https://example.com/video.mp4'],
          ],
          '',
          createdAt: 1700000000,
        );

        // Act & Assert
        expect(
          () => AudioEvent.fromNostrEvent(nostrEvent),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('parses duration as integer seconds', () {
        // Arrange - some clients might send integer duration
        final nostrEvent = Event(
          testPubkey,
          1063,
          [
            ['url', 'https://example.com/audio.aac'],
            ['m', 'audio/aac'],
            ['duration', '6'],
          ],
          '',
          createdAt: 1700000000,
        );

        // Act
        final audioEvent = AudioEvent.fromNostrEvent(nostrEvent);

        // Assert
        expect(audioEvent.duration, equals(6.0));
      });

      test('handles malformed duration gracefully (Postel\'s law)', () {
        // Arrange
        final nostrEvent = Event(
          testPubkey,
          1063,
          [
            ['url', 'https://example.com/audio.aac'],
            ['m', 'audio/aac'],
            ['duration', 'not-a-number'],
          ],
          '',
          createdAt: 1700000000,
        );

        // Act
        final audioEvent = AudioEvent.fromNostrEvent(nostrEvent);

        // Assert - should not crash, just return null
        expect(audioEvent.duration, isNull);
      });

      test('handles malformed size gracefully (Postel\'s law)', () {
        // Arrange
        final nostrEvent = Event(
          testPubkey,
          1063,
          [
            ['url', 'https://example.com/audio.aac'],
            ['m', 'audio/aac'],
            ['size', 'invalid'],
          ],
          '',
          createdAt: 1700000000,
        );

        // Act
        final audioEvent = AudioEvent.fromNostrEvent(nostrEvent);

        // Assert
        expect(audioEvent.fileSize, isNull);
      });

      test('parses a tag without relay hint', () {
        // Arrange
        final nostrEvent = Event(
          testPubkey,
          1063,
          [
            ['url', 'https://example.com/audio.aac'],
            ['m', 'audio/aac'],
            ['a', '34236:somepubkey:some-vine-id'],
          ],
          '',
          createdAt: 1700000000,
        );

        // Act
        final audioEvent = AudioEvent.fromNostrEvent(nostrEvent);

        // Assert
        expect(
          audioEvent.sourceVideoReference,
          equals('34236:somepubkey:some-vine-id'),
        );
        expect(audioEvent.sourceVideoRelay, isNull);
      });

      test('handles empty tags array', () {
        // Arrange
        final nostrEvent = Event(
          testPubkey,
          1063,
          [],
          '',
          createdAt: 1700000000,
        );

        // Act
        final audioEvent = AudioEvent.fromNostrEvent(nostrEvent);

        // Assert
        expect(audioEvent.url, isNull);
        expect(audioEvent.mimeType, isNull);
      });
    });

    group('fromBundledSound', () {
      test('creates AudioEvent from VineSound with correct fields', () {
        // Arrange
        final vineSound = VineSound(
          id: 'bruh',
          title: 'Bruh Sound Effect',
          assetPath: 'assets/sounds/bruh-sound-effect.mp3',
          duration: const Duration(milliseconds: 1000),
          tags: ['meme', 'reaction', 'classic'],
        );

        // Act
        final audioEvent = AudioEvent.fromBundledSound(vineSound);

        // Assert
        expect(audioEvent.id, equals('bundled_bruh'));
        expect(audioEvent.pubkey, equals('bundled'));
        expect(audioEvent.createdAt, equals(0));
        expect(
          audioEvent.url,
          equals('asset://assets/sounds/bruh-sound-effect.mp3'),
        );
        expect(audioEvent.mimeType, equals('audio/mpeg'));
        expect(audioEvent.duration, equals(1.0));
        expect(audioEvent.title, equals('Bruh Sound Effect'));
      });

      test('isBundled returns true for bundled sounds', () {
        final vineSound = VineSound(
          id: 'test',
          title: 'Test Sound',
          assetPath: 'assets/sounds/test.mp3',
          duration: const Duration(seconds: 2),
        );

        final audioEvent = AudioEvent.fromBundledSound(vineSound);

        expect(audioEvent.isBundled, isTrue);
      });

      test('isBundled returns false for Nostr sounds', () {
        final audioEvent = AudioEvent(
          id: 'abc123def456789012345678901234567890123456789012345678901234abcd',
          pubkey: testPubkey,
          createdAt: 1700000000,
          url: 'https://blossom.example/audio.aac',
        );

        expect(audioEvent.isBundled, isFalse);
      });

      test('assetPath returns path for bundled sounds', () {
        final vineSound = VineSound(
          id: 'vine_boom',
          title: 'Vine Boom',
          assetPath: 'assets/sounds/vine-boom.mp3',
          duration: const Duration(seconds: 7),
        );

        final audioEvent = AudioEvent.fromBundledSound(vineSound);

        expect(audioEvent.assetPath, equals('assets/sounds/vine-boom.mp3'));
      });

      test('assetPath returns null for Nostr sounds', () {
        final audioEvent = AudioEvent(
          id: 'abc123def456789012345678901234567890123456789012345678901234abcd',
          pubkey: testPubkey,
          createdAt: 1700000000,
          url: 'https://blossom.example/audio.aac',
        );

        expect(audioEvent.assetPath, isNull);
      });

      test('converts duration correctly from milliseconds', () {
        final vineSound = VineSound(
          id: 'test',
          title: 'Test',
          assetPath: 'assets/sounds/test.mp3',
          duration: const Duration(milliseconds: 4500),
        );

        final audioEvent = AudioEvent.fromBundledSound(vineSound);

        expect(audioEvent.duration, equals(4.5));
      });
    });

    group('toTags', () {
      test('generates complete tags list', () {
        // Arrange
        final audioEvent = AudioEvent(
          id: 'test-id-123456789012345678901234567890123456789012345678901234',
          pubkey: 'test-pubkey',
          createdAt: 1700000000,
          url: 'https://blossom.example/audio.aac',
          mimeType: 'audio/aac',
          sha256: 'hash123',
          fileSize: 12345,
          duration: 5.5,
          title: 'Test Sound',
          sourceVideoReference: '34236:pubkey:vine-id',
          sourceVideoRelay: 'wss://relay.example',
        );

        // Act
        final tags = audioEvent.toTags();

        // Assert - check that specific tags exist
        expect(
          _findTag(tags, 'url'),
          equals(['url', 'https://blossom.example/audio.aac']),
        );
        expect(_findTag(tags, 'm'), equals(['m', 'audio/aac']));
        expect(_findTag(tags, 'x'), equals(['x', 'hash123']));
        expect(_findTag(tags, 'size'), equals(['size', '12345']));
        expect(_findTag(tags, 'duration'), equals(['duration', '5.5']));
        expect(_findTag(tags, 'title'), equals(['title', 'Test Sound']));
        expect(
          _findTag(tags, 'a'),
          equals(['a', '34236:pubkey:vine-id', 'wss://relay.example']),
        );
      });

      test('generates minimal tags for sparse event', () {
        // Arrange
        final audioEvent = AudioEvent(
          id: 'minimal-id-123456789012345678901234567890123456789012345678',
          pubkey: 'test-pubkey',
          createdAt: 1700000000,
          url: 'https://example.com/audio.aac',
          mimeType: 'audio/aac',
        );

        // Act
        final tags = audioEvent.toTags();

        // Assert
        expect(
          _findTag(tags, 'url'),
          equals(['url', 'https://example.com/audio.aac']),
        );
        expect(_findTag(tags, 'm'), equals(['m', 'audio/aac']));
        // Should not contain null fields
        expect(_findTag(tags, 'x'), isNull);
        expect(_findTag(tags, 'size'), isNull);
        expect(_findTag(tags, 'duration'), isNull);
        expect(_findTag(tags, 'title'), isNull);
        expect(_findTag(tags, 'a'), isNull);
      });

      test('generates a tag without relay when relay is null', () {
        // Arrange
        final audioEvent = AudioEvent(
          id: 'no-relay-id-12345678901234567890123456789012345678901234567',
          pubkey: 'test-pubkey',
          createdAt: 1700000000,
          url: 'https://example.com/audio.aac',
          mimeType: 'audio/aac',
          sourceVideoReference: '34236:pubkey:vine-id',
        );

        // Act
        final tags = audioEvent.toTags();

        // Assert
        expect(_findTag(tags, 'a'), equals(['a', '34236:pubkey:vine-id']));
      });
    });

    group('copyWith', () {
      test('creates copy with updated fields', () {
        // Arrange
        final original = AudioEvent(
          id: 'original-id-1234567890123456789012345678901234567890123456',
          pubkey: 'original-pubkey',
          createdAt: 1700000000,
          url: 'https://original.com/audio.aac',
          mimeType: 'audio/aac',
          title: 'Original Title',
        );

        // Act
        final copy = original.copyWith(title: 'New Title', duration: 6.0);

        // Assert
        expect(copy.id, equals(original.id));
        expect(copy.pubkey, equals(original.pubkey));
        expect(copy.url, equals(original.url));
        expect(copy.title, equals('New Title'));
        expect(copy.duration, equals(6.0));
        expect(original.title, equals('Original Title')); // Original unchanged
        expect(original.duration, isNull);
      });
    });

    group('equality', () {
      test('events with same id are equal', () {
        // Arrange
        final event1 = AudioEvent(
          id: 'same-id-123456789012345678901234567890123456789012345678901',
          pubkey: 'pubkey1',
          createdAt: 1700000000,
          url: 'https://example1.com/audio.aac',
          mimeType: 'audio/aac',
        );

        final event2 = AudioEvent(
          id: 'same-id-123456789012345678901234567890123456789012345678901',
          pubkey: 'pubkey2', // Different pubkey
          createdAt: 1700000001, // Different timestamp
          url: 'https://example2.com/audio.aac', // Different url
          mimeType: 'audio/mp4', // Different mime
        );

        // Assert
        expect(event1, equals(event2));
        expect(event1.hashCode, equals(event2.hashCode));
      });

      test('events with different ids are not equal', () {
        // Arrange
        final event1 = AudioEvent(
          id: 'id-one-123456789012345678901234567890123456789012345678901',
          pubkey: 'pubkey',
          createdAt: 1700000000,
          url: 'https://example.com/audio.aac',
          mimeType: 'audio/aac',
        );

        final event2 = AudioEvent(
          id: 'id-two-123456789012345678901234567890123456789012345678901',
          pubkey: 'pubkey',
          createdAt: 1700000000,
          url: 'https://example.com/audio.aac',
          mimeType: 'audio/aac',
        );

        // Assert
        expect(event1, isNot(equals(event2)));
      });
    });

    group('toString', () {
      test('returns readable debug string', () {
        // Arrange
        final audioEvent = AudioEvent(
          id: 'test-id-123456789012345678901234567890123456789012345678901234',
          pubkey: 'test-pubkey',
          createdAt: 1700000000,
          url: 'https://example.com/audio.aac',
          mimeType: 'audio/aac',
          title: 'Test Sound',
          duration: 6.2,
        );

        // Act
        final str = audioEvent.toString();

        // Assert
        expect(str, contains('AudioEvent'));
        expect(
          str,
          contains(
            'test-id-123456789012345678901234567890123456789012345678901234',
          ),
        );
        expect(str, contains('Test Sound'));
        expect(str, contains('6.2'));
      });
    });

    group('sourceVideoKind getter', () {
      test('extracts kind from sourceVideoReference', () {
        // Arrange
        final audioEvent = AudioEvent(
          id: 'test-id-123456789012345678901234567890123456789012345678901234',
          pubkey: 'test-pubkey',
          createdAt: 1700000000,
          url: 'https://example.com/audio.aac',
          mimeType: 'audio/aac',
          sourceVideoReference: '34236:pubkey:vine-id',
        );

        // Assert
        expect(audioEvent.sourceVideoKind, equals(34236));
      });

      test('returns null when sourceVideoReference is null', () {
        // Arrange
        final audioEvent = AudioEvent(
          id: 'test-id-123456789012345678901234567890123456789012345678901234',
          pubkey: 'test-pubkey',
          createdAt: 1700000000,
          url: 'https://example.com/audio.aac',
          mimeType: 'audio/aac',
        );

        // Assert
        expect(audioEvent.sourceVideoKind, isNull);
      });
    });

    group('sourceVideoPubkey getter', () {
      test('extracts pubkey from sourceVideoReference', () {
        // Arrange
        final audioEvent = AudioEvent(
          id: 'test-id-123456789012345678901234567890123456789012345678901234',
          pubkey: 'test-pubkey',
          createdAt: 1700000000,
          url: 'https://example.com/audio.aac',
          mimeType: 'audio/aac',
          sourceVideoReference: '34236:creator-pubkey-abc:vine-id',
        );

        // Assert
        expect(audioEvent.sourceVideoPubkey, equals('creator-pubkey-abc'));
      });
    });

    group('sourceVideoIdentifier getter', () {
      test('extracts d-tag identifier from sourceVideoReference', () {
        // Arrange
        final audioEvent = AudioEvent(
          id: 'test-id-123456789012345678901234567890123456789012345678901234',
          pubkey: 'test-pubkey',
          createdAt: 1700000000,
          url: 'https://example.com/audio.aac',
          mimeType: 'audio/aac',
          sourceVideoReference: '34236:creator-pubkey:my-vine-id-123',
        );

        // Assert
        expect(audioEvent.sourceVideoIdentifier, equals('my-vine-id-123'));
      });
    });

    group('formattedDuration getter', () {
      test('formats duration as mm:ss', () {
        // Arrange - 65.4 rounds to 65 seconds = 1:05
        final audioEvent = AudioEvent(
          id: 'test-id-123456789012345678901234567890123456789012345678901234',
          pubkey: 'test-pubkey',
          createdAt: 1700000000,
          url: 'https://example.com/audio.aac',
          mimeType: 'audio/aac',
          duration: 65.4,
        );

        // Assert
        expect(audioEvent.formattedDuration, equals('1:05'));
      });

      test('handles sub-minute duration', () {
        // Arrange
        final audioEvent = AudioEvent(
          id: 'test-id-123456789012345678901234567890123456789012345678901234',
          pubkey: 'test-pubkey',
          createdAt: 1700000000,
          url: 'https://example.com/audio.aac',
          mimeType: 'audio/aac',
          duration: 6.2,
        );

        // Assert
        expect(audioEvent.formattedDuration, equals('0:06'));
      });

      test('returns empty string when duration is null', () {
        // Arrange
        final audioEvent = AudioEvent(
          id: 'test-id-123456789012345678901234567890123456789012345678901234',
          pubkey: 'test-pubkey',
          createdAt: 1700000000,
          url: 'https://example.com/audio.aac',
          mimeType: 'audio/aac',
        );

        // Assert
        expect(audioEvent.formattedDuration, equals(''));
      });
    });

    group('fileSizeKB getter', () {
      test('returns file size in KB', () {
        // Arrange
        final audioEvent = AudioEvent(
          id: 'test-id-123456789012345678901234567890123456789012345678901234',
          pubkey: 'test-pubkey',
          createdAt: 1700000000,
          url: 'https://example.com/audio.aac',
          mimeType: 'audio/aac',
          fileSize: 102400, // 100 KB
        );

        // Assert
        expect(audioEvent.fileSizeKB, closeTo(100.0, 0.001));
      });
    });
  });
}

/// Helper to find a tag by its first element (tag name)
List<String>? _findTag(List<List<String>> tags, String tagName) {
  for (final tag in tags) {
    if (tag.isNotEmpty && tag[0] == tagName) {
      return tag;
    }
  }
  return null;
}
