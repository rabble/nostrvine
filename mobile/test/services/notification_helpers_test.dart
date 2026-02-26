// ABOUTME: Tests for extracted notification helper functions
// ABOUTME: Pure function tests for video ID extraction and actor name resolution

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/notification_helpers.dart';

void main() {
  group('extractVideoEventId', () {
    test('returns uppercase "E" tag value for NIP-22 comments', () {
      // Arrange - NIP-22 comment with uppercase E tag (root scope)
      final event = Event(
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        1111, // NIP-22 comment kind
        [
          ['E', 'root_video_id', '', 'author_pubkey'],
          ['K', '34236'],
          ['e', 'parent_comment_id', '', 'parent_author'],
          ['k', '1111'],
        ],
        'Great video!',
      );

      // Act
      final result = extractVideoEventId(event);

      // Assert - should return uppercase E tag (root scope / video ID)
      expect(result, 'root_video_id');
    });

    test('prefers uppercase "E" over lowercase "e" tag', () {
      // Arrange
      final event = Event(
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        1111,
        [
          ['e', 'lowercase_id'],
          ['E', 'uppercase_id'],
        ],
        'Comment',
      );

      // Act
      final result = extractVideoEventId(event);

      // Assert - uppercase E should take priority
      expect(result, 'uppercase_id');
    });

    test('returns first "e" tag value from event tags', () {
      // Arrange
      final event = Event(
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        7,
        [
          ['e', 'video123'],
          ['p', 'user456'],
        ],
        '+',
      );

      // Act
      final result = extractVideoEventId(event);

      // Assert
      expect(result, 'video123');
    });

    test('returns null when no "e" tags exist', () {
      // Arrange
      final event = Event(
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        7,
        [
          ['p', 'user456'],
        ],
        '+',
      );

      // Act
      final result = extractVideoEventId(event);

      // Assert
      expect(result, isNull);
    });

    test('returns null when "e" tag has no value', () {
      // Arrange
      final event = Event(
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        7,
        [
          ['e'], // No value
        ],
        '+',
      );

      // Act
      final result = extractVideoEventId(event);

      // Assert
      expect(result, isNull);
    });

    test('returns null when event has empty tags', () {
      // Arrange
      final event = Event(
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        7,
        [],
        '+',
      );

      // Act
      final result = extractVideoEventId(event);

      // Assert
      expect(result, isNull);
    });

    test('returns first "e" tag when multiple exist', () {
      // Arrange
      final event = Event(
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        7,
        [
          ['e', 'first_video'],
          ['e', 'second_video'],
          ['e', 'third_video'],
        ],
        '+',
      );

      // Act
      final result = extractVideoEventId(event);

      // Assert
      expect(result, 'first_video');
    });

    test('handles empty tag arrays gracefully', () {
      // Arrange
      final event = Event(
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        7,
        [
          [], // Empty tag
          ['e', 'video123'],
        ],
        '+',
      );

      // Act
      final result = extractVideoEventId(event);

      // Assert
      expect(result, 'video123');
    });
  });

  group('extractAddressableId', () {
    test(
      'returns uppercase "A" tag value for NIP-22 comments on addressable events',
      () {
        final event = Event(
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          1111,
          [
            ['A', '34236:author_pubkey:my-video-d-tag', ''],
            ['K', '34236'],
            ['a', '34236:author_pubkey:my-video-d-tag', ''],
            ['k', '34236'],
          ],
          'Great video!',
        );

        final result = extractAddressableId(event);

        expect(result, '34236:author_pubkey:my-video-d-tag');
      },
    );

    test('prefers uppercase "A" over lowercase "a" tag', () {
      final event = Event(
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        1111,
        [
          ['a', '34236:pubkey:lowercase-dtag', ''],
          ['A', '34236:pubkey:uppercase-dtag', ''],
        ],
        'Comment',
      );

      final result = extractAddressableId(event);

      expect(result, '34236:pubkey:uppercase-dtag');
    });

    test('returns lowercase "a" tag when no uppercase "A" exists', () {
      final event = Event(
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        1111,
        [
          ['a', '34236:pubkey:some-dtag', ''],
          ['k', '34236'],
        ],
        'Comment',
      );

      final result = extractAddressableId(event);

      expect(result, '34236:pubkey:some-dtag');
    });

    test('returns null when no A or a tags exist', () {
      final event = Event(
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        7,
        [
          ['e', 'video123'],
          ['p', 'user456'],
        ],
        '+',
      );

      final result = extractAddressableId(event);

      expect(result, isNull);
    });

    test('returns null when "A" tag has no value', () {
      final event = Event(
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        1111,
        [
          ['A'],
        ],
        'Comment',
      );

      final result = extractAddressableId(event);

      expect(result, isNull);
    });

    test('returns null when event has empty tags', () {
      final event = Event(
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        1111,
        [],
        'Comment',
      );

      final result = extractAddressableId(event);

      expect(result, isNull);
    });
  });

  group('parseAddressableId', () {
    test('parses valid addressable ID into components', () {
      final result = parseAddressableId('34236:abc123pubkey:my-video-id');

      expect(result, isNotNull);
      expect(result!.kind, equals(34236));
      expect(result.pubkey, equals('abc123pubkey'));
      expect(result.dTag, equals('my-video-id'));
    });

    test('handles d-tag containing colons', () {
      final result = parseAddressableId('34236:pubkey123:d-tag:with:colons');

      expect(result, isNotNull);
      expect(result!.kind, equals(34236));
      expect(result.pubkey, equals('pubkey123'));
      expect(result.dTag, equals('d-tag:with:colons'));
    });

    test('returns null for invalid format with less than 3 parts', () {
      expect(parseAddressableId('34236:pubkey'), isNull);
      expect(parseAddressableId('34236'), isNull);
      expect(parseAddressableId(''), isNull);
    });

    test('returns null when kind is not a number', () {
      final result = parseAddressableId('notanumber:pubkey:dtag');

      expect(result, isNull);
    });

    test('parses kind 30023 (long-form content) correctly', () {
      final result = parseAddressableId('30023:pubkey:blog-post-slug');

      expect(result, isNotNull);
      expect(result!.kind, equals(30023));
      expect(result.pubkey, equals('pubkey'));
      expect(result.dTag, equals('blog-post-slug'));
    });

    test('handles empty d-tag', () {
      final result = parseAddressableId('34236:pubkey:');

      expect(result, isNotNull);
      expect(result!.kind, equals(34236));
      expect(result.pubkey, equals('pubkey'));
      expect(result.dTag, isEmpty);
    });
  });

  group('resolveActorName', () {
    test('returns name when available', () {
      // Arrange
      final profile = UserProfile(
        pubkey: 'test123',
        rawData: const {},
        createdAt: DateTime.now(),
        eventId: 'event1',
        name: 'Alice',
        displayName: 'Alice Wonderland',
        nip05: 'alice@nostr.com',
      );

      // Act
      final result = resolveActorName(profile);

      // Assert
      expect(result, 'Alice');
    });

    test('returns displayName when name is null', () {
      // Arrange
      final profile = UserProfile(
        pubkey: 'test123',
        rawData: const {},
        createdAt: DateTime.now(),
        eventId: 'event1',
        displayName: 'Bob Builder',
        nip05: 'bob@nostr.com',
      );

      // Act
      final result = resolveActorName(profile);

      // Assert
      expect(result, 'Bob Builder');
    });

    test('returns nip05 username when name and displayName are null', () {
      // Arrange
      final profile = UserProfile(
        pubkey: 'test123',
        rawData: const {},
        createdAt: DateTime.now(),
        eventId: 'event1',
        nip05: 'charlie@nostr.com',
      );

      // Act
      final result = resolveActorName(profile);

      // Assert
      expect(result, 'charlie');
    });

    test('extracts username from nip05 before @ symbol', () {
      // Arrange
      final profile = UserProfile(
        pubkey: 'test123',
        rawData: const {},
        createdAt: DateTime.now(),
        eventId: 'event1',
        nip05: 'username@example.org',
      );

      // Act
      final result = resolveActorName(profile);

      // Assert
      expect(result, 'username');
    });

    test('returns "Unknown user" when profile is null', () {
      // Act
      final result = resolveActorName(null);

      // Assert
      expect(result, 'Unknown user');
    });

    test('returns "Unknown user" when all name fields are null', () {
      // Arrange
      final profile = UserProfile(
        pubkey: 'test123',
        rawData: const {},
        createdAt: DateTime.now(),
        eventId: 'event1',
      );

      // Act
      final result = resolveActorName(profile);

      // Assert
      expect(result, 'Unknown user');
    });

    test('handles nip05 without @ symbol', () {
      // Arrange
      final profile = UserProfile(
        pubkey: 'test123',
        rawData: const {},
        createdAt: DateTime.now(),
        eventId: 'event1',
        nip05: 'plainname',
      );

      // Act
      final result = resolveActorName(profile);

      // Assert
      expect(result, 'plainname');
    });
  });
}
