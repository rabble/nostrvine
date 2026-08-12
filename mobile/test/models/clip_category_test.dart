// ABOUTME: Tests category-name validation and Unicode-safe truncation.
// ABOUTME: Prevents the 40-character limit from splitting emoji graphemes.

import 'package:characters/characters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/clip_category.dart';

void main() {
  group('ClipCategory.sanitizeName', () {
    test('trims usable names and rejects whitespace-only input', () {
      expect(ClipCategory.sanitizeName('  Travel  '), 'Travel');
      expect(ClipCategory.sanitizeName(' \n\t '), isNull);
    });

    test('preserves a valid 40-grapheme name ending in emoji', () {
      final name = '${'a' * 39}😀';

      expect(name.characters.length, ClipCategory.maxNameLength);
      expect(ClipCategory.sanitizeName(name), name);
    });

    test('truncates without splitting a compound emoji', () {
      final name = '${'a' * 40}👨‍👩‍👧‍👦';
      final sanitized = ClipCategory.sanitizeName(name)!;

      expect(sanitized, 'a' * 40);
      expect(sanitized.characters.length, ClipCategory.maxNameLength);
    });
  });
}
