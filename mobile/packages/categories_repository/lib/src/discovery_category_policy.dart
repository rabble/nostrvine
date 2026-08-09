// ABOUTME: Discovery category policy for moderation-adjacent category names.
// ABOUTME: Keeps blocked labels from becoming browsable discovery entry points.

/// Policy for category names that must not be exposed as discovery surfaces.
abstract final class DiscoveryCategoryPolicy {
  /// Category names that must never become discovery entry points.
  static const denied = <String>{'adult', 'violence'};

  /// Returns `true` when [name] is blocked from discovery surfaces.
  static bool isDenied(String name) {
    return denied.contains(name.trim().toLowerCase());
  }
}
