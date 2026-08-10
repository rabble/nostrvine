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
  List<String> fromNewestFirst(
    List<String> pubkeys, {
    required int datedCount,
  }) {
    final boundary = datedCount.clamp(0, pubkeys.length);
    return switch (this) {
      FollowSortOrder.newestFirst => pubkeys,
      FollowSortOrder.oldestFirst => [
        ...pubkeys.take(boundary).toList().reversed,
        ...pubkeys.skip(boundary),
      ],
    };
  }

  /// Arranges a following list for this order.
  ///
  /// [pubkeys] must be in follow order as `FollowRepository` returns it: the
  /// `p` tags of the user's own kind 3 contact list, verbatim. New follows are
  /// appended, so that order runs oldest to newest and needs no timestamps.
  ///
  /// The order is only as good as the last client that wrote the contact list.
  /// One that rebuilds the tag list instead of appending loses it, and this
  /// then reverses whatever order that client chose.
  List<String> fromFollowOrder(List<String> pubkeys) => switch (this) {
    FollowSortOrder.newestFirst => pubkeys.reversed.toList(),
    FollowSortOrder.oldestFirst => pubkeys,
  };
}
