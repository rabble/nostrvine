// ABOUTME: Detects content that is only emoji (up to 3 grapheme clusters).
// ABOUTME: Shared by comment items and DM bubbles for display-size emoji.

import 'package:flutter/widgets.dart';

/// Returns true if [text] contains only emoji characters (up to 3 grapheme
/// clusters) with no text, mentions, or other content.
///
/// Handles compound emojis correctly: Dart's `.characters` segments ZWJ
/// sequences (e.g. \u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467} families),
/// skin-tone variants, flags, and keycap sequences as single grapheme
/// clusters. The regex then validates that each grapheme consists only of
/// emoji-related code points.
bool isEmojiOnly(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return false;
  final graphemes = trimmed.characters;
  if (graphemes.length > 3) return false;
  // Check each grapheme is emoji (no ASCII text, no nostr: mentions).
  // Includes Emoji_Component for keycap (\u20e3) and tag sequences,
  // and Regional_Indicator for flag emojis.
  final emojiRegex = RegExp(
    // Emoji component chars (ZWJ, VS-16, keycap, skin tones, digits/#/*)
    r'^[\u200d\ufe0f\u20e30-9#*\u{1F3FB}-\u{1F3FF}'
    // BMP emoji symbols and dingbats
    r'\u00a9\u00ae\u203c\u2049'
    r'\u2194-\u2199\u21a9-\u21aa\u231a-\u231b\u2328\u23cf'
    r'\u23e9-\u23f3\u23f8-\u23fa\u24c2\u25aa-\u25ab\u25b6\u25c0'
    r'\u25fb-\u25fe\u2600-\u27bf\u2934-\u2935\u2b05-\u2b07'
    r'\u2b1b-\u2b1c\u2b50\u2b55\u3030\u303d\u3297\u3299'
    // Supplementary plane emoji (plane 1: mahjong through symbols extended-a)
    r'\u{1F000}-\u{1FFFF}'
    r']+$',
    unicode: true,
  );
  // Exclude bare ASCII digits/symbols that have \p{Emoji} but aren't
  // visually emoji (e.g. "0"-"9", "#", "*").
  final asciiTextRegex = RegExp(r'^[0-9#*]$');
  return graphemes.every(
    (g) => emojiRegex.hasMatch(g) && !asciiTextRegex.hasMatch(g),
  );
}
