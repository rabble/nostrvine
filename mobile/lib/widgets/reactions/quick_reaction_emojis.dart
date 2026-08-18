// ABOUTME: The shared quick-pick emoji set for reaction rows, used by DM
// ABOUTME: message reactions and comment reactions so both surfaces offer
// ABOUTME: the same six emoji.

/// Default emoji set for reaction quick-rows. Excludes 🙏 per user-memory
/// rule "Swap 🙏 → 🫶 always" — 🔥 takes its place because it reads
/// especially well on short-form video content.
const List<String> kQuickReactionEmojis = [
  '❤️',
  '😂',
  '🔥',
  '😮',
  '😢',
  '👍',
];
