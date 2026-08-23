// ABOUTME: Tests for isEmojiOnly — the shared emoji-only content detector
// ABOUTME: behind display-size emoji in comments and DM bubbles.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/emoji_only.dart';

void main() {
  group('isEmojiOnly', () {
    test('accepts a single emoji', () {
      expect(isEmojiOnly('🥲'), isTrue);
    });

    test('accepts up to three emoji', () {
      expect(isEmojiOnly('🥲🫶🎉'), isTrue);
    });

    test('rejects four or more emoji', () {
      expect(isEmojiOnly('🥲🥲🥲🥲'), isFalse);
    });

    test('accepts surrounding whitespace', () {
      expect(isEmojiOnly('  🥲  '), isTrue);
    });

    test('accepts VS-16 presentation sequences', () {
      expect(isEmojiOnly('❤️'), isTrue);
    });

    test('accepts skin-tone modified emoji as one grapheme', () {
      expect(isEmojiOnly('🫶🏽'), isTrue);
    });

    test('accepts ZWJ family sequences as one grapheme', () {
      expect(isEmojiOnly('👨‍👩‍👧‍👦'), isTrue);
    });

    test('accepts flag emoji', () {
      expect(isEmojiOnly('🇺🇸'), isTrue);
    });

    test('accepts keycap sequences', () {
      expect(isEmojiOnly('1️⃣'), isTrue);
    });

    test('rejects plain text', () {
      expect(isEmojiOnly('hello'), isFalse);
    });

    test('rejects mixed emoji and text', () {
      expect(isEmojiOnly('🥲 hi'), isFalse);
    });

    test('rejects bare ASCII digits and symbols', () {
      expect(isEmojiOnly('3'), isFalse);
      expect(isEmojiOnly('#'), isFalse);
      expect(isEmojiOnly('*'), isFalse);
    });

    test('rejects the empty string', () {
      expect(isEmojiOnly(''), isFalse);
      expect(isEmojiOnly('   '), isFalse);
    });

    test('rejects nostr references', () {
      // Synthetic, full-length npub — not a real account.
      expect(
        isEmojiOnly(
          'nostr:npub1qqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqqq',
        ),
        isFalse,
      );
    });
  });
}
