import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/blossom_blob_hash.dart';

void main() {
  group('normalizeSha256Hash', () {
    test('normalizes valid hashes', () {
      expect(
        normalizeSha256Hash(
          '  ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789  ',
        ),
        equals(
          'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789',
        ),
      );
    });

    test('rejects invalid hashes', () {
      expect(normalizeSha256Hash(null), isNull);
      expect(normalizeSha256Hash('abc123'), isNull);
      expect(
        normalizeSha256Hash(
          'zzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzzz',
        ),
        isNull,
      );
    });
  });

  group('extractSha256FromBlossomUrl', () {
    test('extracts hashes from URL path segments with extensions', () {
      const hash =
          '72d7eda61074b17e077fb9f4a8b48166cdeb65cb07e053aafa6e69d5fa165995';

      expect(
        extractSha256FromBlossomUrl('https://media.divine.video/$hash.jpg'),
        equals(hash),
      );
    });

    test('returns null when the URL has no SHA-256 path segment', () {
      expect(
        extractSha256FromBlossomUrl(
          'https://media.divine.video/not-a-hash.jpg',
        ),
        isNull,
      );
    });
  });
}
