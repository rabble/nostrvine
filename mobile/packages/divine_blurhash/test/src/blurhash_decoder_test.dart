import 'package:divine_blurhash/divine_blurhash.dart';
import 'package:test/test.dart';

void main() {
  group('decodeBlurHash', () {
    // A real 4x3 hash (size flag 'L' → 4 components wide, 3 tall, 28 chars).
    const validHash = 'L6Pj0^jE.AyE_3t7t7R**0o#DgR4';

    test('fills a width*height*4 RGBA buffer with opaque pixels', () {
      final pixels = decodeBlurHash(validHash, 4, 5);
      expect(pixels, hasLength(4 * 5 * 4));
      for (var i = 3; i < pixels.length; i += 4) {
        expect(pixels[i], 255, reason: 'alpha at pixel ${i ~/ 4}');
      }
    });

    test('decodes a 1x1-component hash (no AC terms)', () {
      // Size flag '0' → 1x1 components, so the hash is exactly 6 chars.
      final oneByOne = decodeBlurHash('00Fdrz', 2, 2);
      expect(oneByOne, hasLength(2 * 2 * 4));
    });

    test('throws when the hash is shorter than 6 characters', () {
      expect(
        () => decodeBlurHash('short', 4, 4),
        throwsA(isA<BlurHashDecodeException>()),
      );
    });

    test('throws when the length does not match the size flag', () {
      // validHash truncated: charset is fine, declared components need 28.
      expect(
        () => decodeBlurHash('L6Pj0^jE.AyE_3t7t7R*', 4, 4),
        throwsA(isA<BlurHashDecodeException>()),
      );
    });

    test('throws on a non-base83 character after the size flag', () {
      // '0' → 1x1 → expected length 6, so length passes; the '/' at index 1
      // is rejected while reading maxAc.
      expect(
        () => decodeBlurHash('0/0000', 2, 2),
        throwsA(isA<BlurHashDecodeException>()),
      );
    });
  });
}
