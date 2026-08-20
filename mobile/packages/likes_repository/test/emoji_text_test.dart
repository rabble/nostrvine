// ABOUTME: Table-driven tests for the shared emoji-only text classifier
// ABOUTME: and the reaction-content wrapper built on top of it.

import 'package:likes_repository/likes_repository.dart';
import 'package:test/test.dart';

void main() {
  group('isEmojiOnlyText', () {
    const accepted = <String, String>{
      '😂': 'single pictograph',
      '❤️': 'pictograph with VS-16',
      '™️': 'BMP symbol with VS-16 exposed by the full picker (U+2122)',
      'ℹ️': 'BMP symbol with VS-16 exposed by the full picker (U+2139)',
      '©️': 'copyright with VS-16',
      '®️': 'registered with VS-16',
      '™': 'bare BMP pictograph without VS-16',
      '👍🏽': 'skin-tone modified pictograph',
      '👨‍👩‍👧‍👦': 'family ZWJ sequence',
      '🇺🇸': 'regional-indicator flag',
      '🏴󠁧󠁢󠁥󠁮󠁧󠁿': 'tag-sequence subdivision flag',
      '1️⃣': 'keycap sequence',
      '#️⃣': 'hash keycap sequence',
      '😂😂': 'multiple emoji graphemes',
      ' 🔥 ': 'emoji with surrounding whitespace',
    };
    for (final MapEntry(key: input, value: why) in accepted.entries) {
      test('accepts $why', () {
        expect(isEmojiOnlyText(input), isTrue, reason: input);
      });
    }

    const rejected = <String, String>{
      '': 'empty string',
      '   ': 'whitespace only',
      '+': 'NIP-25 like content',
      '-': 'NIP-25 dislike content',
      'abc': 'plain text',
      '123': 'bare ASCII keycap bases',
      '1': 'single bare digit',
      '#': 'single bare hash',
      'hi😂': 'text mixed with emoji',
      '❤23': 'emoji followed by bare digits',
      ':joy:': 'unrendered shortcode',
      'nostr:npub1example': 'nostr mention',
    };
    for (final MapEntry(key: input, value: why) in rejected.entries) {
      test('rejects $why', () {
        expect(isEmojiOnlyText(input), isFalse, reason: input);
      });
    }
  });

  group('emojiReactionContentOf', () {
    test('returns the trimmed emoji for valid reaction content', () {
      expect(emojiReactionContentOf(' 😂 '), equals('😂'));
      expect(emojiReactionContentOf('™️'), equals('™️'));
      expect(emojiReactionContentOf('ℹ️'), equals('ℹ️'));
      expect(emojiReactionContentOf('👨‍👩‍👧‍👦'), equals('👨‍👩‍👧‍👦'));
    });

    test('returns null for votes, prose, and empty content', () {
      expect(emojiReactionContentOf('+'), isNull);
      expect(emojiReactionContentOf('-'), isNull);
      expect(emojiReactionContentOf(''), isNull);
      expect(emojiReactionContentOf('great video!'), isNull);
    });

    test('caps reaction content at 16 UTF-16 code units', () {
      const elevenUnits = '👨‍👩‍👧‍👦';
      expect(elevenUnits.length, equals(11));
      expect(emojiReactionContentOf(elevenUnits), isNotNull);
      final overCap = '😂' * 9;
      expect(overCap.length, greaterThan(16));
      expect(emojiReactionContentOf(overCap), isNull);
    });
  });
}
