/// How a follow list is ordered for display.
///
/// The followers list and the following list reach the UI in opposite base
/// orders, so each has its own entry point: [fromNewestFirst] for followers,
/// [fromFollowOrder] for following. Both answer the same user-facing question.
enum FollowSortOrder {
  /// Most recent first — the default for both lists.
  ///
  /// Puts whoever just followed you, or whoever you just followed, at the top,
  /// which is the whole reason the ordering exists.
  newestFirst,

  /// Least recent first.
  oldestFirst;

  /// Arranges a followers list for this order.
  ///
  /// [pubkeys] must be newest-first as `FollowRepository` returns it, with its
  /// [datedCount] dated followers leading — `FollowersSnapshot.datedCount`
  /// carries that boundary.
  ///
  /// Only the dated prefix flips: followers with no timestamp stay at the end
  /// in both directions, because "we don't know when" is not the same claim as
  /// "a long time ago".
  ///
  /// That justifies where the tail sits, not which way it runs. Undated
  /// followers come from the REST source, whose page is itself
  /// `ORDER BY rf.created_at DESC` server-side — so the tail is newest-first
  /// and stays that way under [oldestFirst], running against the label above
  /// it. Nothing in the response says so today, which is what the `sort` echo
  /// in divinevideo/divine-funnelcake#883 is for.
  ///
  /// Always returns a fresh list, so the no-op order cannot hand back an alias
  /// of the caller's own state.
  List<String> fromNewestFirst(
    List<String> pubkeys, {
    required int datedCount,
  }) {
    final boundary = datedCount.clamp(0, pubkeys.length);
    return switch (this) {
      FollowSortOrder.newestFirst => List<String>.of(pubkeys),
      FollowSortOrder.oldestFirst => [
        ...pubkeys.take(boundary).toList().reversed,
        ...pubkeys.skip(boundary),
      ],
    };
  }

  /// Arranges a following list for this order.
  ///
  /// [pubkeys] must be in follow order as `FollowRepository` returns it: the
  /// `p` tags of the user's own kind 3 contact list, verbatim.
  ///
  /// NIP-02 makes that order load-bearing rather than incidental: "Whenever
  /// new follows are added to an existing list, clients SHOULD append them to
  /// the end of the list, so they are stored in chronological order." So the
  /// tag order runs oldest to newest by spec and needs no timestamps — which
  /// is just as well, since a contact list carries one `created_at` for the
  /// whole list rather than one per entry.
  ///
  /// The order is therefore only as good as the last client that wrote the
  /// list. One that rebuilds the tag list instead of appending violates that
  /// SHOULD, and this then reverses whatever order it chose.
  ///
  /// Always returns a fresh list, for the same reason [fromNewestFirst] does.
  List<String> fromFollowOrder(List<String> pubkeys) => switch (this) {
    FollowSortOrder.newestFirst => pubkeys.reversed.toList(),
    FollowSortOrder.oldestFirst => List<String>.of(pubkeys),
  };
}
