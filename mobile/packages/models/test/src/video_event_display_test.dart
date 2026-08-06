// ABOUTME: Tests for VideoEvent.displayTitle and displayContent zalgo-safe
// ABOUTME: getters that protect UI from combining-character overflow.

import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  VideoEvent build({
    String? title,
    String content = '',
    String? authorName,
    int createdAt = 1735689600,
    String? publishedAt,
    Map<String, String> rawTags = const {},
  }) => VideoEvent(
    id: 'a' * 64,
    pubkey: 'b' * 64,
    createdAt: createdAt,
    content: content,
    timestamp: DateTime.fromMillisecondsSinceEpoch(
      createdAt * 1000,
      isUtc: true,
    ),
    title: title,
    authorName: authorName,
    publishedAt: publishedAt,
    rawTags: rawTags,
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

    test('replaces unpaired surrogates from truncated emoji in content', () {
      // Lone high surrogate (truncated emoji) crashes Flutter's
      // paragraph builder if it reaches a Text widget (#6111).
      final content = String.fromCharCodes([0x68, 0x69, 0xD83D]);
      expect(build(content: content).displayContent, equals('hi\uFFFD'));
    });

    test('preserves valid emoji pairs in content', () {
      expect(
        build(content: 'fun \u{1F600}').displayContent,
        equals('fun \u{1F600}'),
      );
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

  group('VideoEvent.hasUnknownOriginalDate', () {
    test('is true for original Vines without a tag after shutdown', () {
      final video = build(
        createdAt: 1777489813,
        rawTags: const {'platform': 'vine'},
      );

      expect(video.hasUnknownOriginalDate, isTrue);
    });

    test('is false for original Vines with a Vine-era published_at tag', () {
      final video = build(
        createdAt: 1777489813,
        publishedAt: '1473050841',
        rawTags: const {'platform': 'vine', 'published_at': '1473050841'},
      );

      expect(video.hasUnknownOriginalDate, isFalse);
    });

    test(
      'is false for original Vines with a farewell-day published_at tag',
      () {
        final video = build(
          createdAt: 1777489813,
          publishedAt: '1484627482',
          rawTags: const {'platform': 'vine', 'published_at': '1484627482'},
        );

        expect(video.hasUnknownOriginalDate, isFalse);
      },
    );

    test('is false for no-tag original Vines before shutdown', () {
      final video = build(
        createdAt: 1473050841,
        rawTags: const {'platform': 'vine'},
      );

      expect(video.hasUnknownOriginalDate, isFalse);
    });

    test('is true for original Vines with a zero timestamp', () {
      final video = build(createdAt: 0, rawTags: const {'platform': 'vine'});

      expect(video.hasUnknownOriginalDate, isTrue);
    });

    test('is false for non-Vine videos with a post-shutdown date', () {
      final video = build(createdAt: 1777489813);

      expect(video.hasUnknownOriginalDate, isFalse);
    });
  });
}
