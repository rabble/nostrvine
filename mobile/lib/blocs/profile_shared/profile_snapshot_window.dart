// ABOUTME: Persistence-window policy shared by profile video tab snapshots.
// ABOUTME: Bounds cache size and (de)serialization cost on reopen.

/// Persistence policy for profile video tab snapshots.
abstract class ProfileSnapshotWindow {
  /// Maximum number of items (videos and IDs) persisted in a snapshot.
  ///
  /// The live in-memory list is **uncapped** — this only bounds what is
  /// written to / read from `CacheSync`, so a user with tens of thousands of
  /// liked/reposted/saved items doesn't serialize a multi-megabyte blob on
  /// every page load and doesn't jank the UI thread decoding it on reopen.
  ///
  /// ~11 screens of a 3-column grid, which comfortably covers an instant
  /// restore. Pagination past this window re-resolves the full ID list via
  /// the background revalidation that runs on every reopen, so nothing is
  /// lost — the rest is simply fetched as the user scrolls.
  static const int maxItems = 200;
}
