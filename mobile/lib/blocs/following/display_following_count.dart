// ABOUTME: Shared following count display adjustment for following list states.
// ABOUTME: Preserves authoritative counts while accounting for hidden rows.

/// Returns the following count to display beside a filtered following list.
///
/// [authoritativeCount] may exceed [rawLoadedCount] when followed-pubkey
/// fetches are partial. Only subtract users that were definitely loaded and
/// intentionally hidden by filtering.
int displayFilteredFollowingCount({
  required int authoritativeCount,
  required int rawLoadedCount,
  required int visibleLoadedCount,
}) {
  final removedByFiltering = rawLoadedCount - visibleLoadedCount;
  final adjustedCount = authoritativeCount - removedByFiltering;
  return adjustedCount < 0 ? 0 : adjustedCount;
}
