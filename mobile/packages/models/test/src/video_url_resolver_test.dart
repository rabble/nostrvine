import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group('VideoUrlResolver', () {
    group('fixOpenvineTypo', () {
      test('corrects the apt.openvine.co typo when present', () {
        expect(
          VideoUrlResolver.fixOpenvineTypo('https://apt.openvine.co/v.mp4'),
          equals('https://api.openvine.co/v.mp4'),
        );
      });

      test('returns the original URL when no typo is present', () {
        expect(
          VideoUrlResolver.fixOpenvineTypo('https://api.openvine.co/v.mp4'),
          equals('https://api.openvine.co/v.mp4'),
        );
      });
    });

    group('isValidVideoUrl', () {
      test('accepts well-formed http and https URLs with a host', () {
        expect(
          VideoUrlResolver.isValidVideoUrl('https://cdn.divine.video/v.mp4'),
          isTrue,
        );
        expect(
          VideoUrlResolver.isValidVideoUrl('http://example.com/v.mp4'),
          isTrue,
        );
      });

      test('rejects an empty string', () {
        expect(VideoUrlResolver.isValidVideoUrl(''), isFalse);
      });

      test('rejects non-http(s) schemes', () {
        expect(
          VideoUrlResolver.isValidVideoUrl('ftp://example.com/v.mp4'),
          isFalse,
        );
        expect(VideoUrlResolver.isValidVideoUrl('file:///tmp/v.mp4'), isFalse);
      });

      test('rejects a string with no host', () {
        expect(VideoUrlResolver.isValidVideoUrl('https://'), isFalse);
        expect(VideoUrlResolver.isValidVideoUrl('not-a-url'), isFalse);
      });

      test('rejects a malformed URI (FormatException path)', () {
        expect(VideoUrlResolver.isValidVideoUrl('http://[::1'), isFalse);
      });

      test('corrects the apt.openvine.co typo before validating', () {
        expect(
          VideoUrlResolver.isValidVideoUrl('https://apt.openvine.co/v.mp4'),
          isTrue,
        );
      });
    });

    group('scoreVideoUrl', () {
      test('ranks MP4 on cdn.divine.video highest', () {
        expect(
          VideoUrlResolver.scoreVideoUrl('https://cdn.divine.video/v.mp4'),
          equals(115),
        );
      });

      test('ranks generic MP4 above HLS', () {
        expect(
          VideoUrlResolver.scoreVideoUrl('https://example.com/v.mp4'),
          equals(110),
        );
      });

      test('ranks stream.divine.video HLS above generic HLS', () {
        expect(
          VideoUrlResolver.scoreVideoUrl('https://stream.divine.video/v.m3u8'),
          equals(105),
        );
        expect(
          VideoUrlResolver.scoreVideoUrl('https://example.com/v.m3u8'),
          equals(100),
        );
      });

      test('deprioritizes the broken cdn.divine.video /manifest/ pattern', () {
        expect(
          VideoUrlResolver.scoreVideoUrl(
            'https://cdn.divine.video/abc/manifest/video.m3u8',
          ),
          equals(5),
        );
      });

      test('rejects dead vine.co URLs with a negative score', () {
        expect(
          VideoUrlResolver.scoreVideoUrl('https://vine.co/v/abc'),
          equals(-1),
        );
        expect(
          VideoUrlResolver.scoreVideoUrl('https://www.vine.co/v/abc'),
          equals(-1),
        );
      });

      test('does not reject openvine.co (only dead vine.co)', () {
        expect(
          VideoUrlResolver.scoreVideoUrl('https://openvine.co/v'),
          equals(50),
        );
      });

      test('scores other formats by preference', () {
        expect(
          VideoUrlResolver.scoreVideoUrl('https://e.com/v.webm'),
          equals(90),
        );
        expect(
          VideoUrlResolver.scoreVideoUrl('https://e.com/v.mov'),
          equals(70),
        );
        expect(
          VideoUrlResolver.scoreVideoUrl('https://e.com/v.avi'),
          equals(60),
        );
        expect(
          VideoUrlResolver.scoreVideoUrl('https://e.com/v.mpd'),
          equals(10),
        );
        expect(VideoUrlResolver.scoreVideoUrl('https://e.com/v'), equals(50));
      });
    });

    group('selectBestVideoUrl', () {
      test('returns null for an empty candidate list', () {
        expect(VideoUrlResolver.selectBestVideoUrl([]), isNull);
      });

      test('picks the highest-scoring valid candidate', () {
        final best = VideoUrlResolver.selectBestVideoUrl([
          'https://example.com/v.m3u8', // 100
          'https://cdn.divine.video/v.mp4', // 115
          'https://example.com/v.webm', // 90
        ]);
        expect(best, equals('https://cdn.divine.video/v.mp4'));
      });

      test('returns null when every candidate is invalid', () {
        expect(
          VideoUrlResolver.selectBestVideoUrl(['', 'ftp://x/v.mp4']),
          isNull,
        );
      });

      test('does not select dead vine.co URLs (negative score)', () {
        expect(
          VideoUrlResolver.selectBestVideoUrl(['https://vine.co/v/abc']),
          isNull,
        );
      });

      test('skips invalid candidates and selects the valid one', () {
        final best = VideoUrlResolver.selectBestVideoUrl([
          'not-a-url',
          'https://example.com/v.mp4',
        ]);
        expect(best, equals('https://example.com/v.mp4'));
      });
    });

    group('extractVideoUrlFromContent', () {
      test('returns the first valid URL found in free text', () {
        expect(
          VideoUrlResolver.extractVideoUrlFromContent(
            'watch this https://example.com/v.mp4 now',
          ),
          equals('https://example.com/v.mp4'),
        );
      });

      test('corrects the apt.openvine.co typo in the returned URL', () {
        expect(
          VideoUrlResolver.extractVideoUrlFromContent(
            'see https://apt.openvine.co/v.mp4',
          ),
          equals('https://api.openvine.co/v.mp4'),
        );
      });

      test('returns null when there is no URL', () {
        expect(
          VideoUrlResolver.extractVideoUrlFromContent('no links here'),
          isNull,
        );
      });
    });

    group('findAnyVideoUrlInTags', () {
      test('returns a valid URL from a tag value', () {
        expect(
          VideoUrlResolver.findAnyVideoUrlInTags([
            ['url', 'https://example.com/v.mp4'],
          ]),
          equals('https://example.com/v.mp4'),
        );
      });

      test('ignores the tag name at index 0', () {
        expect(
          VideoUrlResolver.findAnyVideoUrlInTags([
            ['https://example.com/v.mp4'],
          ]),
          isNull,
        );
      });

      test('skips non-list and empty tags', () {
        expect(
          VideoUrlResolver.findAnyVideoUrlInTags([
            'not-a-list',
            <dynamic>[],
            ['x', 'https://example.com/v.mp4'],
          ]),
          equals('https://example.com/v.mp4'),
        );
      });

      test('corrects the apt.openvine.co typo in the returned URL', () {
        expect(
          VideoUrlResolver.findAnyVideoUrlInTags([
            ['x', 'https://apt.openvine.co/v.mp4'],
          ]),
          equals('https://api.openvine.co/v.mp4'),
        );
      });

      test('returns null when no tag holds a valid URL', () {
        expect(
          VideoUrlResolver.findAnyVideoUrlInTags([
            ['x', 'not-a-url'],
          ]),
          isNull,
        );
      });
    });
  });
}
