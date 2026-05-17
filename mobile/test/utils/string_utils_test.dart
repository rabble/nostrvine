import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/string_utils.dart';

void main() {
  group(StringUtils, () {
    group('sanitizeUtf16', () {
      test('returns identical instance when input is plain ASCII', () {
        const input = 'hello world';
        expect(identical(StringUtils.sanitizeUtf16(input), input), isTrue);
      });

      test('returns identical instance when input is empty', () {
        const input = '';
        expect(identical(StringUtils.sanitizeUtf16(input), input), isTrue);
      });

      test('preserves a well-formed surrogate pair (emoji)', () {
        // U+1F600 GRINNING FACE = D83D DE00
        const input = 'hi 😀';
        final result = StringUtils.sanitizeUtf16(input);
        expect(result, equals(input));
        expect(result.runes.last, equals(0x1F600));
      });

      test('drops an unpaired high surrogate', () {
        final input = 'a${String.fromCharCode(0xD83D)}b';
        expect(StringUtils.sanitizeUtf16(input), equals('ab'));
      });

      test('drops an unpaired low surrogate', () {
        final input = 'a${String.fromCharCode(0xDE00)}b';
        expect(StringUtils.sanitizeUtf16(input), equals('ab'));
      });

      test('drops a trailing unpaired high surrogate', () {
        final input = 'trail${String.fromCharCode(0xD83D)}';
        expect(StringUtils.sanitizeUtf16(input), equals('trail'));
      });

      test('drops a high surrogate followed by a non-surrogate', () {
        final input = '${String.fromCharCode(0xD83D)}x';
        expect(StringUtils.sanitizeUtf16(input), equals('x'));
      });

      test('preserves adjacent valid pairs separated by an unpaired one', () {
        final input = '😀${String.fromCharCode(0xD83D)}😀';
        final result = StringUtils.sanitizeUtf16(input);
        expect(result, equals('😀😀'));
      });
    });
  });
}
