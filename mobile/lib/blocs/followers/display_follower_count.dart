// ABOUTME: Shared follower count display adjustment for follower list states.
// ABOUTME: Preserves authoritative counts while accounting for hidden rows.

/// Returns the follower count to display beside a filtered follower list.
///
/// [authoritativeCount] comes from the repository count query and may exceed
/// [rawLoadedCount] when follower pubkey fetches are partial. Only subtract
/// users that were definitely loaded and intentionally hidden by filtering.
int displayFilteredFollowerCount({
  required int authoritativeCount,
  required int rawLoadedCount,
  required int visibleLoadedCount,
}) {
  final removedByFiltering = rawLoadedCount - visibleLoadedCount;
  final adjustedCount = authoritativeCount - removedByFiltering;
  return adjustedCount < 0 ? 0 : adjustedCount;
}
