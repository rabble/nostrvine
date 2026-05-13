import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/divine_video_url.dart';

void main() {
  group('divineVideoUrlLineRegex', () {
    test('matches a standalone canonical divine.video URL line', () {
      expect(
        divineVideoUrlLineRegex.hasMatch('https://divine.video/video/abc123'),
        isTrue,
      );
    });

    test('rejects surrounding non-URL text on the same line', () {
      expect(
        divineVideoUrlLineRegex.hasMatch(
          'watch https://divine.video/video/abc123 now',
        ),
        isFalse,
      );
    });
  });

  group('tryExtractDivineVideoUrl', () {
    const validId = 'abc123def456';

    test('returns null when content has no URL', () {
      expect(tryExtractDivineVideoUrl('just plain text'), isNull);
    });

    test('extracts canonical https URL', () {
      expect(
        tryExtractDivineVideoUrl('see https://divine.video/video/$validId'),
        equals('https://divine.video/video/$validId'),
      );
    });

    test('extracts http URL (no scheme upgrade)', () {
      expect(
        tryExtractDivineVideoUrl('http://divine.video/video/$validId here'),
        equals('http://divine.video/video/$validId'),
      );
    });

    test('extracts URL with www subdomain', () {
      expect(
        tryExtractDivineVideoUrl(
          'check https://www.divine.video/video/$validId',
        ),
        equals('https://www.divine.video/video/$validId'),
      );
    });

    group('casing', () {
      test('matches HTTPS in uppercase', () {
        expect(
          tryExtractDivineVideoUrl('HTTPS://DIVINE.VIDEO/VIDEO/$validId'),
          equals('HTTPS://DIVINE.VIDEO/VIDEO/$validId'),
        );
      });

      test('matches mixed-case host and path', () {
        expect(
          tryExtractDivineVideoUrl('https://Divine.Video/Video/$validId'),
          equals('https://Divine.Video/Video/$validId'),
        );
      });
    });

    group('trailing punctuation', () {
      test('strips trailing period', () {
        expect(
          tryExtractDivineVideoUrl(
            'watch this: https://divine.video/video/$validId.',
          ),
          equals('https://divine.video/video/$validId'),
        );
      });

      test('strips trailing comma', () {
        expect(
          tryExtractDivineVideoUrl(
            'see https://divine.video/video/$validId, nice right?',
          ),
          equals('https://divine.video/video/$validId'),
        );
      });

      test('strips trailing closing paren', () {
        expect(
          tryExtractDivineVideoUrl(
            'parenthetical (https://divine.video/video/$validId)',
          ),
          equals('https://divine.video/video/$validId'),
        );
      });

      test('strips trailing exclamation mark', () {
        expect(
          tryExtractDivineVideoUrl('https://divine.video/video/$validId!'),
          equals('https://divine.video/video/$validId'),
        );
      });
    });

    group('query strings and fragments', () {
      test('excludes ?query=string from match', () {
        expect(
          tryExtractDivineVideoUrl(
            'https://divine.video/video/$validId?utm=share',
          ),
          equals('https://divine.video/video/$validId'),
        );
      });

      test('excludes #fragment from match', () {
        expect(
          tryExtractDivineVideoUrl(
            'https://divine.video/video/$validId#t=10',
          ),
          equals('https://divine.video/video/$validId'),
        );
      });
    });

    group('ID shapes', () {
      test('matches 64-char hex event ID', () {
        const hexId =
            'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
        expect(
          tryExtractDivineVideoUrl('https://divine.video/video/$hexId'),
          equals('https://divine.video/video/$hexId'),
        );
      });

      test('matches hyphenated d-tag', () {
        const dTag = 'my-video-d-tag-2026';
        expect(
          tryExtractDivineVideoUrl('https://divine.video/video/$dTag'),
          equals('https://divine.video/video/$dTag'),
        );
      });

      test('matches alphanumeric d-tag with underscore', () {
        const dTag = 'abc_123_xyz';
        expect(
          tryExtractDivineVideoUrl('https://divine.video/video/$dTag'),
          equals('https://divine.video/video/$dTag'),
        );
      });
    });

    group('rejects non-canonical shapes', () {
      test('rejects non-divine domain', () {
        expect(
          tryExtractDivineVideoUrl('https://example.com/video/$validId'),
          isNull,
        );
      });

      test('rejects /video/ path missing the id', () {
        expect(
          tryExtractDivineVideoUrl('https://divine.video/video/'),
          isNull,
        );
      });

      test('rejects non-/video/ path on divine.video', () {
        expect(
          tryExtractDivineVideoUrl('https://divine.video/profile/$validId'),
          isNull,
        );
      });
    });

    test('extracts first URL when content has multiple', () {
      expect(
        tryExtractDivineVideoUrl(
          'a https://divine.video/video/aaa111 b https://divine.video/video/bbb222',
        ),
        equals('https://divine.video/video/aaa111'),
      );
    });
  });
}
