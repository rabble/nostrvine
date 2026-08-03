/// Which side of a follow relationship a list represents.
///
/// Used to pick the matching endpoint when an operation applies equally to
/// both lists, such as `FollowRepository.searchFollowList`.
enum FollowListKind {
  /// People who follow the subject.
  followers,

  /// People the subject follows.
  following,
}
