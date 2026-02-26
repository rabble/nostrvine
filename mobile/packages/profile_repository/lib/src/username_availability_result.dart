/// Sealed class representing the result of a username availability check.
sealed class UsernameAvailabilityResult {
  /// Creates a username availability result.
  const UsernameAvailabilityResult();
}

/// Username is available for registration.
class UsernameAvailable extends UsernameAvailabilityResult {
  /// Creates an available result.
  const UsernameAvailable();
}

/// Username is already taken by another user.
class UsernameTaken extends UsernameAvailabilityResult {
  /// Creates a taken result.
  const UsernameTaken();
}

/// Username has an invalid format (e.g. contains dots, underscores, etc.).
class UsernameInvalidFormat extends UsernameAvailabilityResult {
  /// Creates an invalid format result with the given [reason].
  const UsernameInvalidFormat(this.reason);

  /// Description of why the format is invalid.
  final String reason;
}

/// An error occurred during availability check.
class UsernameCheckError extends UsernameAvailabilityResult {
  /// Creates an error result with the given [message].
  const UsernameCheckError(this.message);

  /// Description of what went wrong.
  final String message;

  @override
  String toString() => 'UsernameCheckError($message)';
}
