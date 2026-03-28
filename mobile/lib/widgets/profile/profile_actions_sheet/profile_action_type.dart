// ABOUTME: Enum representing pending profile actions (secure account,
// ABOUTME: complete profile) with a static helper to compute which are active.

/// Actions a new user can take to finish setting up their profile.
///
/// The [pending] factory returns the ordered list of actions that still
/// need attention. "Secure account" always appears before "complete profile"
/// so that account recovery is prioritised.
enum ProfileActionType {
  /// The user has no email/password and should register to secure their
  /// identity.
  secureAccount,

  /// The user has not yet set a custom display name, bio, or picture.
  completeProfile
  ;

  /// Returns the list of pending actions based on the current profile and
  /// auth state.
  ///
  /// [isOwnProfile] — whether we are looking at the logged-in user's profile.
  /// [isAnonymous] — the user signed in with an auto-generated key (no email).
  /// [hasExpiredSession] — an OAuth session that failed to refresh (handled
  ///   separately by [_SessionExpiredBanner]).
  /// [hasProfile] — a Kind 0 profile event has been loaded.
  /// [hasCustomName] — the user set a display name or name field.
  static List<ProfileActionType> pending({
    required bool isOwnProfile,
    required bool isAnonymous,
    required bool hasExpiredSession,
    required bool hasProfile,
    required bool hasCustomName,
  }) {
    if (!isOwnProfile) return const [];

    return [
      if (isAnonymous && !hasExpiredSession) secureAccount,
      if (hasProfile && !hasCustomName) completeProfile,
    ];
  }
}
