// ABOUTME: Canonical hashtag strings aligned with divine-web for routes
// and storage.
// ABOUTME: Matches divine-web/src/lib/hashtag.ts normalizeHashtag / formatHashtag.

/// Normalizes a hashtag the same way as
/// `normalizeHashtag` in `divine-web/src/lib/hashtag.ts`:
/// trim, strip one or more leading `#`, then lower case.
///
/// Stored followed tags and deeplink paths should use this value so mobile
/// matches `https://divine.video/hashtag/...` and the web client.
String normalizeHashtagLabel(String hashtag) {
  return hashtag.trim().replaceFirst(RegExp('^#+'), '').toLowerCase();
}

/// Formats a canonical label for display with a single `#`, matching
/// `formatHashtag` in `divine-web/src/lib/hashtag.ts`.
String formatHashtagForDisplay(String normalizedLabel) {
  if (normalizedLabel.isEmpty) return '#';
  final body = normalizedLabel.replaceFirst(RegExp('^#+'), '');
  return '#$body';
}
