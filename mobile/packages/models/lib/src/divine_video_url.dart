// ABOUTME: Regex + helpers for extracting divine.video URLs from text.
// ABOUTME: Shared by the conversation bubble, the long-press handler, and the
// ABOUTME: DM shared-video citation parser.

/// Detects the canonical share-link shape
/// (`https://divine.video/video/<id>`).
///
/// The capture group accepts hex event IDs (64 chars) and d-tags
/// (UUIDs, alphanumeric strings). Only word characters and hyphens are
/// matched so trailing punctuation (`.`, `,`, `)`) and query strings
/// (`?q=1`) are excluded.
final divineVideoUrlRegex = RegExp(
  r'https?://(?:www\.)?divine\.video/video/([\w-]+)',
  caseSensitive: false,
);

/// Matches a line whose entire content is a canonical divine.video share URL.
final divineVideoUrlLineRegex = RegExp(
  r'^https?://(?:www\.)?divine\.video/video/[\w-]+$',
  caseSensitive: false,
);
