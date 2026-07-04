/// Sealed class representing the result of a username claim attempt.
sealed class UsernameClaimResult {
  /// Creates a username claim result.
  const UsernameClaimResult();
}

/// Username was successfully claimed.
class UsernameClaimSuccess extends UsernameClaimResult {
  /// Creates a success result.
  const UsernameClaimSuccess();
}

/// Username is already taken by another user.
class UsernameClaimTaken extends UsernameClaimResult {
  /// Creates a taken result.
  const UsernameClaimTaken();
}

/// Username is reserved and requires contacting support to claim.
class UsernameClaimReserved extends UsernameClaimResult {
  /// Creates a reserved result.
  const UsernameClaimReserved();
}

/// The server could not be reached (network failure, timeout, or a browser
/// CORS block on web). Distinct from [UsernameClaimError] so the UI can offer a
/// connectivity-specific retry rather than treating it like a rejected claim.
class UsernameClaimNetworkError extends UsernameClaimResult {
  /// Creates a network-error result.
  const UsernameClaimNetworkError();
}

/// An error occurred during username claiming (server rejected the claim or the
/// request could not be authenticated).
class UsernameClaimError extends UsernameClaimResult {
  /// Creates an error result with the given [message].
  const UsernameClaimError(this.message);

  /// Description of what went wrong.
  final String message;

  @override
  String toString() => 'UsernameClaimError($message)';
}
