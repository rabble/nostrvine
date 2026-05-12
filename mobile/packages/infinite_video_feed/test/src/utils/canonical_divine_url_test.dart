import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/src/utils/canonical_divine_url.dart';

void main() {
  group('extractCanonicalDivineBlobHash', () {
    const validHash =
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

    test('returns hash for a canonical media.divine.video URL', () {
      const url = 'https://media.divine.video/$validHash';
      expect(extractCanonicalDivineBlobHash(url), equals(validHash));
    });

    test('returns hash for a URL with extra path segments', () {
      const url = 'https://media.divine.video/$validHash/hls/master.m3u8';
      expect(extractCanonicalDivineBlobHash(url), equals(validHash));
    });

    test('returns null for a non-divine URL', () {
      expect(
        extractCanonicalDivineBlobHash('https://example.com/$validHash'),
        isNull,
      );
    });

    test('returns null when hash is too short', () {
      expect(
        extractCanonicalDivineBlobHash('https://media.divine.video/abc123'),
        isNull,
      );
    });

    test('returns null when hash contains non-hex characters', () {
      const badHash =
          'g1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
      expect(
        extractCanonicalDivineBlobHash('https://media.divine.video/$badHash'),
        isNull,
      );
    });

    test('returns null for an empty path', () {
      expect(
        extractCanonicalDivineBlobHash('https://media.divine.video/'),
        isNull,
      );
    });

    test('returns null for a malformed URL (FormatException)', () {
      expect(extractCanonicalDivineBlobHash('not a url ://:'), isNull);
    });

    test('is case-insensitive for the host', () {
      const url = 'https://MEDIA.DIVINE.VIDEO/$validHash';
      expect(extractCanonicalDivineBlobHash(url), equals(validHash));
    });
  });

  group('canonicalDivineBlobHlsUrl', () {
    test('builds the expected HLS master URL', () {
      const hash =
          'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
      expect(
        canonicalDivineBlobHlsUrl(hash),
        equals('https://media.divine.video/$hash/hls/master.m3u8'),
      );
    });
  });

  group('canonicalDivineBlobRawUrl', () {
    test('builds the expected raw blob URL', () {
      const hash =
          'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
      expect(
        canonicalDivineBlobRawUrl(hash),
        equals('https://media.divine.video/$hash'),
      );
    });
  });

  group('orderedUniqueSources', () {
    test('deduplicates while preserving order', () {
      expect(
        orderedUniqueSources(['a', 'b', 'a', 'c']),
        equals(['a', 'b', 'c']),
      );
    });

    test('skips null entries', () {
      expect(orderedUniqueSources([null, 'a', null, 'b']), equals(['a', 'b']));
    });

    test('skips empty string entries', () {
      expect(orderedUniqueSources(['', 'a', '', 'b']), equals(['a', 'b']));
    });

    test('returns empty list for all-null input', () {
      expect(orderedUniqueSources([null, null]), isEmpty);
    });

    test('returns single element for one unique value', () {
      expect(orderedUniqueSources(['x']), equals(['x']));
    });
  });
}
