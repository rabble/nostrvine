// ABOUTME: Exception classes for the reposts repository.
// ABOUTME: Provides typed exceptions for repost/unrepost operations.

/// Base exception for all reposts repository errors.
class RepostsRepositoryException implements Exception {
  /// Creates a new reposts repository exception.
  const RepostsRepositoryException(this.message);

  /// The error message describing what went wrong.
  final String message;

  @override
  String toString() => 'RepostsRepositoryException: $message';
}

/// Exception thrown when a repost operation fails.
///
/// This can occur when:
/// - The video event is missing required d-tag
/// - The Nostr client fails to publish the repost event
/// - The relay rejects the event
/// - Network connectivity issues
class RepostFailedException extends RepostsRepositoryException {
  /// Creates a new repost failed exception.
  const RepostFailedException(super.message);

  @override
  String toString() => 'RepostFailedException: $message';
}

/// Exception thrown when an unrepost operation fails.
///
/// This can occur when:
/// - No repost record found for the addressable ID
/// - The Nostr client fails to publish the deletion event
/// - The relay rejects the deletion
/// - Network connectivity issues
class UnrepostFailedException extends RepostsRepositoryException {
  /// Creates a new unrepost failed exception.
  const UnrepostFailedException(super.message);

  @override
  String toString() => 'UnrepostFailedException: $message';
}

/// Exception thrown when the user is not authenticated.
///
/// Repost operations require a signed-in user with a valid keypair.
class NotAuthenticatedException extends RepostsRepositoryException {
  /// Creates a new not authenticated exception.
  const NotAuthenticatedException() : super('User not authenticated');

  @override
  String toString() => 'NotAuthenticatedException: $message';
}

/// Exception thrown when a video is already reposted.
///
/// Attempting to repost a video that is already reposted will throw this.
class AlreadyRepostedException extends RepostsRepositoryException {
  /// Creates a new already reposted exception.
  const AlreadyRepostedException(String addressableId)
    : super('Video $addressableId is already reposted');

  @override
  String toString() => 'AlreadyRepostedException: $message';
}

/// Exception thrown when trying to unrepost a video that is not reposted.
///
/// Attempting to unrepost a video that has no existing repost will throw this.
class NotRepostedException extends RepostsRepositoryException {
  /// Creates a new not reposted exception.
  const NotRepostedException(String addressableId)
    : super('Video $addressableId is not reposted');

  @override
  String toString() => 'NotRepostedException: $message';
}

/// Exception thrown when syncing reposts from relays fails.
class SyncFailedException extends RepostsRepositoryException {
  /// Creates a new sync failed exception.
  const SyncFailedException(super.message);

  @override
  String toString() => 'SyncFailedException: $message';
}

/// Exception thrown when fetching another user's reposts from relays fails.
class FetchRepostsFailedException extends RepostsRepositoryException {
  /// Creates a new fetch reposts failed exception.
  const FetchRepostsFailedException(super.message);

  @override
  String toString() => 'FetchRepostsFailedException: $message';
}

/// Exception thrown when the video is missing a required d-tag.
///
/// NIP-71 addressable video events require a d-tag for addressing.
class MissingDTagException extends RepostsRepositoryException {
  /// Creates a new missing d-tag exception.
  const MissingDTagException()
    : super('Cannot repost: Video event missing required d-tag');

  @override
  String toString() => 'MissingDTagException: $message';
}
