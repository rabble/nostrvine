import 'package:test/test.dart';
import 'package:text_sanitizer/text_sanitizer.dart';

void main() {
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
}
