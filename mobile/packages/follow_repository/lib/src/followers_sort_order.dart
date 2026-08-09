/// How a follower list is ordered for display.
///
/// Both orders rank by the `created_at` of the follower's kind 3 contact-list
/// event. Followers the REST source reported without one are undated and sit
/// at the end either way — see [apply].
enum FollowersSortOrder {
  /// Most recently updated contact list first — the default.
  ///
  /// Puts whoever just followed at the top of the list, which is the whole
  /// reason the ordering exists.
  newestFirst,

  /// Oldest updated contact list first.
  oldestFirst;

  /// Arranges [pubkeys] for this order.
  ///
  /// [pubkeys] must be newest-first as `FollowRepository` returns it, with its
  /// [datedCount] dated followers leading — `FollowersSnapshot.datedCount`
  /// carries that boundary.
  ///
  /// Only the dated prefix flips: followers with no timestamp stay at the end
  /// in both directions, because "we don't know when" is not the same claim as
  /// "a long time ago".
  List<String> apply(List<String> pubkeys, {required int datedCount}) {
    final boundary = datedCount.clamp(0, pubkeys.length);
    return switch (this) {
      FollowersSortOrder.newestFirst => pubkeys,
      FollowersSortOrder.oldestFirst => [
        ...pubkeys.take(boundary).toList().reversed,
        ...pubkeys.skip(boundary),
      ],
    };
  }
}
