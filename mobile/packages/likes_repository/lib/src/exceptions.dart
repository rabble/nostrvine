// ABOUTME: Exception classes for the likes repository.
// ABOUTME: Provides typed exceptions for like/unlike operations.

/// Base exception for all likes repository errors.
class LikesRepositoryException implements Exception {
  /// Creates a new likes repository exception.
  const LikesRepositoryException(this.message);

  /// The error message describing what went wrong.
  final String message;

  @override
  String toString() => 'LikesRepositoryException: $message';
}

/// Exception thrown when a like operation fails.
///
/// This can occur when:
/// - The Nostr client fails to publish the reaction event
/// - The relay rejects the event
/// - Network connectivity issues
class LikeFailedException extends LikesRepositoryException {
  /// Creates a new like failed exception.
  const LikeFailedException(super.message);

  @override
  String toString() => 'LikeFailedException: $message';
}

/// Exception thrown when an unlike operation fails.
///
/// This can occur when:
/// - No like record found for the target event
/// - The Nostr client fails to publish the deletion event
/// - The relay rejects the deletion
/// - Network connectivity issues
class UnlikeFailedException extends LikesRepositoryException {
  /// Creates a new unlike failed exception.
  const UnlikeFailedException(super.message);

  @override
  String toString() => 'UnlikeFailedException: $message';
}

/// Exception thrown when the user is not authenticated.
///
/// Like operations require a signed-in user with a valid keypair.
class NotAuthenticatedException extends LikesRepositoryException {
  /// Creates a new not authenticated exception.
  const NotAuthenticatedException() : super('User not authenticated');

  @override
  String toString() => 'NotAuthenticatedException: $message';
}

/// Exception thrown when an event is already liked.
///
/// Attempting to like an event that is already liked will throw this exception.
class AlreadyLikedException extends LikesRepositoryException {
  /// Creates a new already liked exception.
  const AlreadyLikedException(String eventId)
    : super('Event $eventId is already liked');

  @override
  String toString() => 'AlreadyLikedException: $message';
}

/// Exception thrown when trying to unlike an event that is not liked.
///
/// Attempting to unlike an event that has no existing like will throw this.
class NotLikedException extends LikesRepositoryException {
  /// Creates a new not liked exception.
  const NotLikedException(String eventId)
    : super('Event $eventId is not liked');

  @override
  String toString() => 'NotLikedException: $message';
}

/// Exception thrown when syncing reactions from relays fails.
class SyncFailedException extends LikesRepositoryException {
  /// Creates a new sync failed exception.
  const SyncFailedException(super.message);

  @override
  String toString() => 'SyncFailedException: $message';
}

/// Exception thrown when fetching another user's likes from relays fails.
class FetchLikesFailedException extends LikesRepositoryException {
  /// Creates a new fetch likes failed exception.
  const FetchLikesFailedException(super.message);

  @override
  String toString() => 'FetchLikesFailedException: $message';
}
