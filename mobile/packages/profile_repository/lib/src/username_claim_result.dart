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

/// An error occurred during username claiming.
class UsernameClaimError extends UsernameClaimResult {
  /// Creates an error result with the given [message].
  const UsernameClaimError(this.message);

  /// Description of what went wrong.
  final String message;

  @override
  String toString() => 'UsernameClaimError($message)';
}
