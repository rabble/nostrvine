// ABOUTME: Normalized hashtag label strings for storage, routes, and display.

/// Normalizes a hashtag label: trims whitespace, strips one or more leading
/// `#` characters, then lowercases the remainder.
String normalizeHashtagLabel(String hashtag) {
  return hashtag.trim().replaceFirst(RegExp('^#+'), '').toLowerCase();
}

/// Formats a canonical label for display with a single `#` prefix.
String formatHashtagForDisplay(String normalizedLabel) {
  if (normalizedLabel.isEmpty) return '#';
  final body = normalizedLabel.replaceFirst(RegExp('^#+'), '');
  return '#$body';
}
