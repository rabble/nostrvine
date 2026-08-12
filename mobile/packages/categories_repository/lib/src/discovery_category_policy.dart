// ABOUTME: Discovery category policy for moderation-adjacent category names.
// ABOUTME: Keeps blocked labels from becoming browsable discovery entry points.

/// Policy for category names that must not be exposed as discovery surfaces.
abstract final class DiscoveryCategoryPolicy {
  /// Category names that must never become discovery entry points.
  ///
  /// This mirrors Funnelcake's emitted discovery-category vocabulary. Update it
  /// when Funnelcake adds or renames moderation-adjacent category slugs.
  ///
  /// `porn` is a sibling slug of `adult`: Funnelcake tags the same videos
  /// `topic:adult` and `topic:porn`, so blocking one without the other leaves
  /// the same feed reachable at `/categories/porn`.
  static const _denied = <String>{'adult', 'porn', 'violence'};

  /// Returns `true` when [name] is blocked from discovery surfaces.
  static bool isDenied(String name) {
    return _denied.contains(name.trim().toLowerCase());
  }
}
