// ABOUTME: Named constants for community-driven content-warning tagging.
// ABOUTME: Threshold + NIP-32 namespace for viewer-suggested content warnings.

/// Constants for the community content-warning tagging feature (#4771).
///
/// See
/// `docs/superpowers/specs/2026-07-01-community-content-warning-tagging-design.md`.
abstract class CommunityContentWarningConstants {
  /// Distinct Divine-identity authors required before the app surfaces a
  /// community-suggested content warning for a given label.
  ///
  /// Client-side, advisory display threshold only — authoritative
  /// aggregation is tracked as separate backend work under epic #5177.
  static const int displayThreshold = 3;

  /// NIP-32 namespace used for content-warning labels.
  ///
  /// Matches the creator self-labeling namespace used by `ContentLabel`.
  static const String namespace = 'content-warning';
}
