/// The current user's follow relationship with another account.
///
/// Answers "which of the several people with this display name am I looking
/// at?" — the question a truncated npub was never able to answer. Derived
/// entirely from data the repository already holds in memory, so it is safe
/// to read per row while a list scrolls.
enum FollowRelationship {
  /// No known relationship, or the follower list has not been fetched yet.
  ///
  /// Deliberately conflates "no relationship" with "not yet known": claiming
  /// [followsYou] before the follower list has loaded would show a
  /// relationship that may not exist.
  none,

  /// The current user follows this account, which does not follow back.
  youFollow,

  /// This account follows the current user, who does not follow back.
  followsYou,

  /// The current user and this account follow each other.
  mutual,
}
