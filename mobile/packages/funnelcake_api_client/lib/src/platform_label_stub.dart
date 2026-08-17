// ABOUTME: Platform label for the shared User-Agent on non-io, non-web builds.

/// Fallback platform label; throws on platforms with no linked implementation.
String get divinePlatformLabel => throw UnsupportedError(
  'No platform label implementation linked for this build',
);
