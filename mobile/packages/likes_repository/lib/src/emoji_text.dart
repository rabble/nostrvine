// ABOUTME: Shared emoji-only text classification for reaction content and
// ABOUTME: emoji-only message rendering. Property-based (UTS #51), so new
// ABOUTME: Unicode emoji classify without code-point range maintenance.

import 'package:characters/characters.dart';

/// Matches a grapheme cluster built only from emoji code points.
///
/// `Extended_Pictographic` carries every pictograph — including the BMP
/// symbols emoji pickers expose, such as ™/ℹ/©/®, which hand-maintained
/// range lists have missed. `Emoji_Component` carries the pieces sequences
/// are assembled from: ZWJ, VS-16, keycap, skin tones, regional
/// indicators, tag characters, and the ASCII digits/#/* keycap bases.
final _emojiGraphemePattern = RegExp(
  r'^[\p{Extended_Pictographic}\p{Emoji_Component}]+$',
  unicode: true,
);

/// A grapheme that is only an ASCII keycap base — a bare digit, `#`, or `*`.
///
/// These carry `Emoji=Yes` for keycap assembly but are plain text on their
/// own; without this exclusion "123" would classify as emoji.
final _asciiKeycapBasePattern = RegExp(r'^[0-9#*]+$');

/// Max reaction content length treated as an emoji, in UTF-16 code units.
///
/// A single grapheme can be many code units (family ZWJ sequences run ~11,
/// flags 4, keycaps 3); 16 admits every single emoji while rejecting
/// sentence-length content some clients put in kind 7.
const _maxEmojiReactionCodeUnits = 16;

/// True when [text] is non-empty and every grapheme cluster is an emoji.
///
/// Grapheme segmentation keeps ZWJ sequences (👨‍👩‍👧‍👦), skin tones
/// (👋🏿), flags (🇺🇸), and keycaps (1️⃣) whole, so mixed content like
/// "hi😂" or a bare "123" never classifies. Imposes no length cap —
/// callers own their use-case limits (reaction content caps at 16 UTF-16
/// code units in [emojiReactionContentOf]; the jumbo emoji-only comment
/// rendering caps at 3 graphemes at its call site).
bool isEmojiOnlyText(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) return false;
  return trimmed.characters.every(
    (grapheme) =>
        _emojiGraphemePattern.hasMatch(grapheme) &&
        !_asciiKeycapBasePattern.hasMatch(grapheme),
  );
}

/// The trimmed emoji when [content] is a displayable emoji reaction,
/// otherwise `null`.
///
/// NIP-25: emoji content SHOULD NOT be interpreted as a like or dislike —
/// clients MAY display it on the post instead. Content that is neither a
/// vote nor emoji-only (mentions, prose, `:shortcode:` without rendering
/// support) resolves to `null` and is ignored entirely. `+`/`-` are
/// neither pictographs nor components, so vote content never classifies.
String? emojiReactionContentOf(String content) {
  final trimmed = content.trim();
  if (trimmed.isEmpty || trimmed.length > _maxEmojiReactionCodeUnits) {
    return null;
  }
  if (!isEmojiOnlyText(trimmed)) return null;
  return trimmed;
}
