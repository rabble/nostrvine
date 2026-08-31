// ABOUTME: Snapshots the local clock and bounds self-asserted DM `created_at`
// ABOUTME: values against it, so one forged or badly-skewed timestamp cannot
// ABOUTME: poison local ordering, cursors, or read state.

/// A snapshot of the local clock, used to bound self-asserted DM timestamps.
///
/// Nothing on either DM ingest path binds a message's `created_at` to real
/// time. A NIP-59 rumor is unsigned — only the seal and wrap are bound — so its
/// timestamp is chosen freely by whoever sent the wrap, and a kind-4's
/// `created_at`, while signed, is signed by its own author. So both are bounded
/// to local time before they reach any store.
///
/// Left unbounded, a single future-dated message pins its conversation above
/// every honest one and, because the conversation upsert only follows the
/// newest timestamp, permanently stops the thread's unread badge from flipping
/// back. See #7343 (NIP-17) and #8001 (NIP-04).
///
/// The bound is one-sided: an implausibly *old* timestamp is handled separately
/// by `DmSyncState.minPlausibleCreatedAt`, which defends a different failure (a
/// truncated history drain) and must not interact with this one.
class DmClock {
  /// Creates a clock pinned to [nowSeconds] (unix seconds).
  DmClock(this.nowSeconds);

  /// Creates a clock pinned to the current local time.
  DmClock.now() : nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  /// The pinned local time, in unix seconds.
  ///
  /// Snapshotted once so every timestamp derived from one ingested event —
  /// message row, conversation row, cursor — agrees, and so a loop over many
  /// entries does not re-read the clock per iteration.
  final int nowSeconds;

  /// Returns [createdAt] bounded above by [nowSeconds].
  int atMostNow(int createdAt) =>
      createdAt > nowSeconds ? nowSeconds : createdAt;
}
