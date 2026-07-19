import 'package:divine_blurhash/src/base83.dart';
import 'package:divine_blurhash/src/blurhash_exception.dart';
import 'package:test/test.dart';

void main() {
  group('base83', () {
    test('decode83 round-trips values produced by encode83', () {
      for (final value in [0, 1, 82, 83, 1000, 571786]) {
        final encoded = encode83(value, 4);
        expect(encoded.length, 4);
        expect(decode83(encoded, 0, encoded.length), value);
      }
    });

    test('encode83 pads to the requested length', () {
      expect(encode83(0, 4), '0000');
      expect(encode83(1, 1), '1');
    });

    test('decode83 reads only the requested slice', () {
      // '10' -> 1*83 + 0 across [0,2); '0' alone across [1,2).
      expect(decode83('10', 0, 2), 83);
      expect(decode83('10', 1, 2), 0);
    });

    test('decode83 throws on a non-base83 character', () {
      expect(
        () => decode83('A/', 0, 2),
        throwsA(isA<BlurHashDecodeException>()),
      );
    });
  });
}
