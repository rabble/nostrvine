// ABOUTME: Entry-point identifiers for add-to-people-list UI flows.
// ABOUTME: Lets BLoCs and UI differentiate triggers (profile, search, etc.).

/// Identifies the entry point that launched an add-to-people-list flow.
///
/// Used by screens and sheets to tailor copy or analytics based on where
/// the user opened the flow from.
enum PeopleListEntryPoint {
  /// Opened from a user profile screen.
  profile,

  /// Opened from a search result row.
  searchResult,

  /// Opened from a followers list.
  followersList,

  /// Opened from a following list.
  followingList,

  /// Opened from the share video menu.
  shareMenu,

  /// Unknown / programmatic entry point.
  unknown,
}
