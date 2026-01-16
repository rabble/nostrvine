/// Base exception for profile repository operations.
class ProfileRepositoryException implements Exception {
  /// Creates a profile repository exception with an optional [message].
  const ProfileRepositoryException([this.message]);

  /// Optional message describing the exception.
  final String? message;

  @override
  String toString() => 'ProfileRepositoryException: $message';
}

/// Thrown when publishing a profile to Nostr relays fails.
class ProfilePublishFailedException extends ProfileRepositoryException {
  /// Creates a profile publish failed exception with an optional [message].
  const ProfilePublishFailedException(super.message);

  @override
  String toString() => 'ProfilePublishFailedException: $message';
}
