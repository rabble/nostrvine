// ABOUTME: Unit tests for imeta URL preservation logic during video metadata edits
// ABOUTME: Verifies all valid HTTP URLs are extracted from original Nostr event imeta tags

import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Pure-logic helpers that mirror the production code in
// _EditVideoDialogState._updateVideo(). They are declared here so we can
// verify correctness on controlled inputs without requiring a full widget pump.
// ---------------------------------------------------------------------------

/// Returns true for HTTP / HTTPS URLs, false for local paths or empty strings.
bool _isHttpUrl(String? url) {
  if (url == null || url.isEmpty) return false;
  return url.startsWith('http://') || url.startsWith('https://');
}

/// Extracts all valid HTTP video URLs from the imeta tag(s) in
/// [nostrEventTags], mirroring the logic in _EditVideoDialogState._updateVideo.
///
/// Handles both the old space-separated format
/// `['imeta', 'url https://…', 'm video/mp4', …]`
/// and the new positional format
/// `['imeta', 'url', 'https://…', 'm', 'video/mp4', …]`.
List<String> _extractImetaUrls(List<List<String>> nostrEventTags) {
  final urls = <String>[];
  for (final tag in nostrEventTags) {
    if (tag.isEmpty || tag[0] != 'imeta') continue;
    if (tag.length > 1 && tag[1].contains(' ')) {
      // Old format: each element is 'key value'
      for (var i = 1; i < tag.length; i++) {
        final spaceIdx = tag[i].indexOf(' ');
        if (spaceIdx > 0) {
          final key = tag[i].substring(0, spaceIdx);
          final value = tag[i].substring(spaceIdx + 1);
          if (key == 'url' && _isHttpUrl(value) && !urls.contains(value)) {
            urls.add(value);
          }
        }
      }
    } else {
      // New format: alternating key, value elements
      for (var i = 1; i < tag.length - 1; i += 2) {
        if (tag[i] == 'url' &&
            _isHttpUrl(tag[i + 1]) &&
            !urls.contains(tag[i + 1])) {
          urls.add(tag[i + 1]);
        }
      }
    }
  }
  return urls;
}

void main() {
  group('HTTP URL validation (_isHttpUrl)', () {
    test('accepts http:// URLs', () {
      expect(_isHttpUrl('http://example.com/video.mp4'), isTrue);
    });

    test('accepts https:// URLs', () {
      expect(_isHttpUrl('https://cdn.example.com/video.mp4'), isTrue);
    });

    test('rejects local file paths', () {
      expect(_isHttpUrl('/data/user/0/cache/video.mp4'), isFalse);
      expect(_isHttpUrl('file:///tmp/video.mp4'), isFalse);
    });

    test('rejects empty string', () {
      expect(_isHttpUrl(''), isFalse);
    });

    test('rejects null', () {
      expect(_isHttpUrl(null), isFalse);
    });

    test('rejects non-http schemes', () {
      expect(_isHttpUrl('ftp://example.com/video.mp4'), isFalse);
      expect(_isHttpUrl('rtmp://stream.example.com/live'), isFalse);
    });
  });

  group(
    'imeta URL extraction from nostrEventTags (old space-separated format)',
    () {
      test('extracts single URL', () {
        final tags = [
          ['imeta', 'url https://cdn.example.com/video.mp4', 'm video/mp4'],
        ];
        expect(
          _extractImetaUrls(tags),
          equals(['https://cdn.example.com/video.mp4']),
        );
      });

      test('extracts multiple URLs (streaming MP4 + R2 fallback + HLS)', () {
        final tags = [
          [
            'imeta',
            'url https://stream.example.com/play_360p.mp4',
            'url https://r2.example.com/fallback.mp4',
            'url https://cdn.example.com/video.m3u8',
            'm video/mp4',
          ],
        ];
        final result = _extractImetaUrls(tags);
        expect(result, hasLength(3));
        expect(result, contains('https://stream.example.com/play_360p.mp4'));
        expect(result, contains('https://r2.example.com/fallback.mp4'));
        expect(result, contains('https://cdn.example.com/video.m3u8'));
      });

      test('filters out non-HTTP URLs', () {
        final tags = [
          [
            'imeta',
            'url https://valid.example.com/video.mp4',
            'url /local/path/video.mp4',
            'm video/mp4',
          ],
        ];
        final result = _extractImetaUrls(tags);
        expect(result, hasLength(1));
        expect(result, contains('https://valid.example.com/video.mp4'));
      });

      test('deduplicates identical URLs', () {
        final tags = [
          [
            'imeta',
            'url https://cdn.example.com/video.mp4',
            'url https://cdn.example.com/video.mp4',
            'm video/mp4',
          ],
        ];
        final result = _extractImetaUrls(tags);
        expect(result, hasLength(1));
      });

      test('ignores non-imeta tags', () {
        final tags = [
          ['d', 'some-stable-id'],
          ['title', 'My Video'],
          ['t', 'hashtag'],
        ];
        expect(_extractImetaUrls(tags), isEmpty);
      });

      test('returns empty list when nostrEventTags is empty', () {
        expect(_extractImetaUrls([]), isEmpty);
      });
    },
  );

  group('imeta URL extraction from nostrEventTags (new positional format)', () {
    test('extracts single URL', () {
      final tags = [
        ['imeta', 'url', 'https://cdn.example.com/video.mp4', 'm', 'video/mp4'],
      ];
      expect(
        _extractImetaUrls(tags),
        equals(['https://cdn.example.com/video.mp4']),
      );
    });

    test('extracts multiple URLs', () {
      final tags = [
        [
          'imeta',
          'url',
          'https://mp4.example.com/video.mp4',
          'url',
          'https://hls.example.com/video.m3u8',
          'm',
          'video/mp4',
        ],
      ];
      final result = _extractImetaUrls(tags);
      expect(result, hasLength(2));
      expect(result, contains('https://mp4.example.com/video.mp4'));
      expect(result, contains('https://hls.example.com/video.m3u8'));
    });

    test('filters out non-HTTP URLs', () {
      final tags = [
        [
          'imeta',
          'url',
          'https://valid.example.com/video.mp4',
          'url',
          'file:///local/video.mp4',
          'm',
          'video/mp4',
        ],
      ];
      final result = _extractImetaUrls(tags);
      expect(result, hasLength(1));
      expect(result, contains('https://valid.example.com/video.mp4'));
    });
  });

  group('imeta URL extraction - URL order preservation', () {
    test('preserves the order URLs appear in the original tag', () {
      final tags = [
        [
          'imeta',
          'url https://stream.example.com/play_360p.mp4',
          'url https://r2.example.com/fallback.mp4',
          'url https://cdn.example.com/video.m3u8',
          'm video/mp4',
        ],
      ];
      final result = _extractImetaUrls(tags);
      expect(result[0], equals('https://stream.example.com/play_360p.mp4'));
      expect(result[1], equals('https://r2.example.com/fallback.mp4'));
      expect(result[2], equals('https://cdn.example.com/video.m3u8'));
    });
  });

  group('imeta URL extraction - no valid URLs guard', () {
    test('returns empty list when all URLs are non-HTTP', () {
      final tags = [
        ['imeta', 'url /local/path/video.mp4', 'm video/mp4'],
      ];
      expect(_extractImetaUrls(tags), isEmpty);
    });

    test('returns empty list when imeta has no url entries', () {
      final tags = [
        ['imeta', 'm video/mp4', 'dim 720x1280'],
      ];
      expect(_extractImetaUrls(tags), isEmpty);
    });
  });
}
