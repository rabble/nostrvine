import 'package:test/test.dart';
import 'package:text_sanitizer/text_sanitizer.dart';

void main() {
  group(sanitizeUtf16, () {
    test('replaces unpaired UTF-16 surrogates', () {
      final malformed = String.fromCharCodes([0xD800, 0x61, 0xDC00]);

      expect(sanitizeUtf16(malformed), equals('\uFFFDa\uFFFD'));
    });

    test('preserves valid surrogate pairs', () {
      final emoji = String.fromCharCodes([0xD83D, 0xDE00]);

      expect(sanitizeUtf16(emoji), equals('😀'));
    });

    test('preserves valid surrogate pairs after malformed code units', () {
      final mixed = String.fromCharCodes([0xD800, 0xD83D, 0xDE00, 0x61]);

      expect(sanitizeUtf16(mixed), equals('\uFFFD😀a'));
    });
  });

  group(stripZalgo, () {
    test('returns empty string unchanged', () {
      expect(stripZalgo(''), equals(''));
    });

    test('returns plain ASCII unchanged', () {
      expect(stripZalgo('hello'), equals('hello'));
    });

    test('preserves NFC precomposed accented characters', () {
      // U+00E9 é — single codepoint, no combining chars
      expect(stripZalgo('\u00E9'), equals('\u00E9'));
    });

    test('preserves NFD accented character with one combining char', () {
      // e + U+0301 (combining acute) — legitimate single accent
      expect(stripZalgo('e\u0301'), equals('e\u0301'));
    });

    test('preserves two combining chars per base (Vietnamese ổ)', () {
      // o + U+0302 (circumflex) + U+0309 (hook above) — 2 combining chars
      expect(stripZalgo('o\u0302\u0309'), equals('o\u0302\u0309'));
    });

    test('strips combining chars beyond the default cap of 2', () {
      // o + 5 combining chars — only first 2 kept
      const zalgo = 'o\u0300\u0301\u0302\u0303\u0304';
      expect(stripZalgo(zalgo), equals('o\u0300\u0301'));
    });

    test('strips combining chars from all Unicode combining blocks', () {
      // Each assertion hits a distinct branch of _isCombining.
      // U+0300–U+036F: Combining Diacritical Marks
      expect(stripZalgo('a\u0300\u0301\u0302'), equals('a\u0300\u0301'));
      // U+0489: Combining Cyrillic Millions Sign
      expect(stripZalgo('а\u0489\u0489\u0489'), equals('а\u0489\u0489'));
      // U+1AB0–U+1AFF: Combining Diacritical Marks Extended
      expect(stripZalgo('a\u1AB0\u1AB1\u1AB2'), equals('a\u1AB0\u1AB1'));
      // U+1DC0–U+1DFF: Combining Diacritical Marks Supplement
      expect(stripZalgo('a\u1DC0\u1DC1\u1DC2'), equals('a\u1DC0\u1DC1'));
      // U+20D0–U+20FF: Combining Diacritical Marks for Symbols
      expect(stripZalgo('a\u20D0\u20D1\u20D2'), equals('a\u20D0\u20D1'));
      // U+FE20–U+FE2F: Combining Half Marks
      expect(stripZalgo('a\uFE20\uFE21\uFE22'), equals('a\uFE20\uFE21'));
    });

    test('respects custom maxCombining parameter', () {
      const input = 'a\u0300\u0301\u0302';
      expect(stripZalgo(input, maxCombining: 1), equals('a\u0300'));
      expect(stripZalgo(input, maxCombining: 3), equals('a\u0300\u0301\u0302'));
    });

    test('handles multi-character string with mixed content', () {
      // 'é' NFC + zalgo 'S' + plain 'i'
      const input = '\u00E9S\u0300\u0301\u0302i';
      expect(stripZalgo(input), equals('\u00E9S\u0300\u0301i'));
    });
  });

  group('$sanitizeUtf16 edge cases', () {
    test('returns empty string unchanged', () {
      expect(sanitizeUtf16(''), equals(''));
    });

    test('returns plain ASCII unchanged', () {
      expect(sanitizeUtf16('hello'), equals('hello'));
    });

    test('preserves a valid surrogate pair (emoji)', () {
      // U+1F600 grinning face = D83D DE00
      const emoji = '\u{1F600}';
      expect(sanitizeUtf16(emoji), equals(emoji));
    });

    test('replaces a lone high surrogate', () {
      final input = String.fromCharCodes([0x61, 0xD83D, 0x62]);
      expect(sanitizeUtf16(input), equals('a\uFFFDb'));
    });

    test('replaces a lone low surrogate', () {
      final input = String.fromCharCodes([0x61, 0xDE00, 0x62]);
      expect(sanitizeUtf16(input), equals('a\uFFFDb'));
    });

    test('replaces a trailing high surrogate from a truncated emoji', () {
      final input = String.fromCharCodes([0x68, 0x69, 0xD83D]);
      expect(sanitizeUtf16(input), equals('hi\uFFFD'));
    });

    test('keeps valid pairs while replacing adjacent lone surrogates', () {
      // lone low surrogate + valid pair + lone high surrogate
      final input = String.fromCharCodes([0xDE00, 0xD83D, 0xDE00, 0xD83D]);
      expect(sanitizeUtf16(input), equals('\uFFFD\u{1F600}\uFFFD'));
    });

    test('returns the identical instance when already well-formed', () {
      const input = 'well formed \u{1F600} text';
      expect(sanitizeUtf16(input), same(input));
    });
  });

  group(sanitizeUtf16OrNull, () {
    test('returns null for null input', () {
      expect(sanitizeUtf16OrNull(null), isNull);
    });

    test('delegates to sanitizeUtf16 for non-null input', () {
      final input = String.fromCharCodes([0x61, 0xD83D]);

      expect(sanitizeUtf16OrNull(input), equals('a�'));
    });
  });

  group(sanitizeForDisplay, () {
    test('replaces lone surrogates and caps combining chars', () {
      // lone high surrogate, then o + 4 combining chars
      final input = String.fromCharCodes([
        0xD83D,
        0x6F,
        0x0300,
        0x0301,
        0x0302,
        0x0303,
      ]);
      expect(sanitizeForDisplay(input), equals('\uFFFDo\u0300\u0301'));
    });

    test('returns well-formed clean text unchanged', () {
      const input = 'clean \u{1F600} text';
      expect(sanitizeForDisplay(input), equals(input));
    });

    test('forwards maxCombining to stripZalgo', () {
      const input = 'a\u0300\u0301\u0302';
      expect(sanitizeForDisplay(input, maxCombining: 1), equals('a\u0300'));
    });
  });
}
