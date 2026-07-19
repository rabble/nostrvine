import 'dart:typed_data';

import 'package:divine_blurhash/divine_blurhash.dart';
import 'package:test/test.dart';

Uint8List _solid(int width, int height, int r, int g, int b) {
  final rgba = Uint8List(width * height * 4);
  for (var i = 0; i < width * height; i++) {
    rgba[i * 4] = r;
    rgba[i * 4 + 1] = g;
    rgba[i * 4 + 2] = b;
    rgba[i * 4 + 3] = 255;
  }
  return rgba;
}

void main() {
  group('encodeBlurHash', () {
    test('produces a hash of the spec length for the component count', () {
      final hash = encodeBlurHash(
        _solid(8, 8, 100, 149, 237),
        8,
        8,
        numCompX: 3,
        numCompY: 4,
      );
      // length = 6 + 2 * (compX * compY - 1)
      expect(hash.length, 6 + 2 * (3 * 4 - 1));
    });

    test('encodes a 1x1-component hash with no AC terms', () {
      final hash = encodeBlurHash(
        _solid(4, 4, 10, 20, 30),
        4,
        4,
        numCompX: 1,
        numCompY: 1,
      );
      expect(hash.length, 6);
      // A 1x1 hash is decodable and carries a solid colour.
      expect(() => decodeBlurHash(hash, 2, 2), returnsNormally);
    });

    test('rejects component counts outside 1–9', () {
      final rgba = _solid(2, 2, 0, 0, 0);
      expect(
        () => encodeBlurHash(rgba, 2, 2, numCompX: 0),
        throwsArgumentError,
      );
      expect(
        () => encodeBlurHash(rgba, 2, 2, numCompX: 10),
        throwsArgumentError,
      );
      expect(
        () => encodeBlurHash(rgba, 2, 2, numCompY: 0),
        throwsArgumentError,
      );
      expect(
        () => encodeBlurHash(rgba, 2, 2, numCompY: 10),
        throwsArgumentError,
      );
    });

    test('rejects an rgba buffer that is not width*height*4', () {
      expect(
        () => encodeBlurHash(Uint8List(10), 2, 2),
        throwsArgumentError,
      );
    });
  });
}
