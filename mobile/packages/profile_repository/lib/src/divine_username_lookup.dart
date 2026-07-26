// ABOUTME: Typed result for looking up the active Divine username for a pubkey.
// ABOUTME: Distinguishes a confirmed missing name from an undetermined lookup.

/// Result of looking up the active Divine username for a pubkey.
sealed class DivineUsernameLookup {
  /// Creates a Divine username lookup result.
  const DivineUsernameLookup();
}

/// The pubkey owns an active Divine username.
class DivineUsernameFound extends DivineUsernameLookup {
  /// Creates a found lookup result.
  const DivineUsernameFound({required this.name, required this.canonical});

  /// Display form returned by divine-name-server.
  final String name;

  /// Canonical DNS-label form returned by divine-name-server.
  final String canonical;
}

/// divine-name-server confirmed the pubkey has no active Divine username.
class DivineUsernameNotFound extends DivineUsernameLookup {
  /// Creates a confirmed-missing lookup result.
  const DivineUsernameNotFound();
}

/// The lookup could not be determined.
class DivineUsernameUnknown extends DivineUsernameLookup {
  /// Creates an undetermined lookup result.
  const DivineUsernameUnknown();
}
