/// Sealed class representing the result of a username release (burn) attempt.
sealed class UsernameReleaseResult {
  /// Creates a username release result.
  const UsernameReleaseResult();
}

/// The username was permanently burned, or the caller no longer holds an
/// active name (the server's idempotent no-op). Does not imply the requested
/// handle is inactive for everyone — it may be active under another pubkey.
class UsernameReleaseSuccess extends UsernameReleaseResult {
  /// Creates a success result.
  const UsernameReleaseSuccess();
}

/// The authenticated pubkey does not own the requested active name.
class UsernameReleaseNotOwner extends UsernameReleaseResult {
  /// Creates a not-owner result.
  const UsernameReleaseNotOwner();
}

/// The server could not be reached (network failure, timeout, or a browser
/// CORS block on web). Distinct from [UsernameReleaseError] so the UI can
/// offer a connectivity-specific retry rather than treating it like a
/// rejected release.
class UsernameReleaseNetworkError extends UsernameReleaseResult {
  /// Creates a network-error result.
  const UsernameReleaseNetworkError();
}

/// The server rejected the release, or the request could not be
/// authenticated.
class UsernameReleaseError extends UsernameReleaseResult {
  /// Creates an error result with the given [message].
  const UsernameReleaseError(this.message);

  /// Description of what went wrong.
  final String message;

  @override
  String toString() => 'UsernameReleaseError($message)';
}
