/// Sealed class representing the result of a username claim attempt.
sealed class UsernameClaimResult {
  const UsernameClaimResult();
}

/// Username was successfully claimed.
class UsernameClaimSuccess extends UsernameClaimResult {
  const UsernameClaimSuccess();
}

/// Username is already taken by another user.
class UsernameClaimTaken extends UsernameClaimResult {
  const UsernameClaimTaken();
}

/// Username is reserved and requires contacting support to claim.
class UsernameClaimReserved extends UsernameClaimResult {
  const UsernameClaimReserved();
}

/// An error occurred during username registration.
class UsernameClaimError extends UsernameClaimResult {
  /// Creates an error result with the given [message].
  const UsernameClaimError(this.message);

  /// Description of what went wrong.
  final String message;
}
