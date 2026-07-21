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

  /// Maximum concurrent name-server identity lookups while aggregating a
  /// video's community labels.
  ///
  /// A video farmed with many throwaway-key labels would otherwise burst one
  /// simultaneous HTTP GET per distinct author; authors are resolved in
  /// bounded chunks instead.
  static const int identityLookupConcurrency = 8;

  /// Client-side timeout for the label-events relay query, deliberately
  /// shorter than the SDK's internal 5s query timeout.
  ///
  /// The SDK swallows its own [TimeoutException] and resolves with whatever
  /// partial events arrived (often none), so a hanging/slow relay would be
  /// indistinguishable from a genuine "no warnings". Wrapping the query in a
  /// shorter outer timeout lets a hang surface as our own `TimeoutException`
  /// → a degraded (uncached, retried) result instead. Residual: a relay that
  /// fast-returns partial-empty within this window is still indistinguishable.
  static const Duration queryTimeout = Duration(seconds: 4);
}
