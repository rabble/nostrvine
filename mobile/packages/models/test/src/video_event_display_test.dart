// ABOUTME: Tests for VideoEvent.displayTitle and displayContent zalgo-safe
// ABOUTME: getters that protect UI from combining-character overflow.

import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  VideoEvent build({
    String? title,
    String content = '',
    String? authorName,
  }) => VideoEvent(
    id: 'a' * 64,
    pubkey: 'b' * 64,
    createdAt: 1735689600,
    content: content,
    timestamp: DateTime.utc(2026),
    title: title,
    authorName: authorName,
  );

  group('VideoEvent.displayTitle', () {
    test('returns null when title is null', () {
      expect(build().displayTitle, isNull);
    });

    test('returns title unchanged when no zalgo present', () {
      expect(build(title: 'Hello').displayTitle, equals('Hello'));
    });

    test('strips excessive combining marks from title', () {
      // o + 5 combining chars → only first 2 kept
      expect(
        build(title: 'o\u0300\u0301\u0302\u0303\u0304').displayTitle,
        equals('o\u0300\u0301'),
      );
    });

    test('replaces malformed UTF-16 in title', () {
      final malformed = String.fromCharCodes([0xD800, 0x61, 0xDC00]);

      expect(build(title: malformed).displayTitle, equals('\uFFFDa\uFFFD'));
    });
  });

  group('VideoEvent.displayContent', () {
    test('returns empty string for empty content', () {
      expect(build().displayContent, equals(''));
    });

    test('returns content unchanged when no zalgo present', () {
      expect(build(content: 'caption').displayContent, equals('caption'));
    });

    test('strips excessive combining marks from content', () {
      expect(
        build(content: 'a\u0300\u0301\u0302\u0303').displayContent,
        equals('a\u0300\u0301'),
      );
    });

    test('replaces malformed UTF-16 in content', () {
      final malformed = String.fromCharCodes([0xD800, 0x61, 0xDC00]);

      expect(build(content: malformed).displayContent, equals('\uFFFDa\uFFFD'));
    });
  });

  group('VideoEvent.displayAuthorName', () {
    test('returns null when authorName is null', () {
      expect(build().displayAuthorName, isNull);
    });

    test('returns author name unchanged when no sanitizer is needed', () {
      expect(build(authorName: 'Creator').displayAuthorName, equals('Creator'));
    });

    test('replaces malformed UTF-16 in author name', () {
      final malformed = String.fromCharCodes([0xD800, 0x61, 0xDC00]);

      expect(
        build(authorName: malformed).displayAuthorName,
        equals('\uFFFDa\uFFFD'),
      );
    });
  });
}
