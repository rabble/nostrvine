// ABOUTME: Custom exceptions for video-related services
// ABOUTME: Provides specific error types for subscription and network operations

/// Exception thrown when trying to subscribe without relay connections
class ConnectionException implements Exception {
  ConnectionException(this.message);
  final String message;

  @override
  String toString() => 'ConnectionException: $message';
}

/// Exception thrown when attempting duplicate subscriptions
class DuplicateSubscriptionException implements Exception {
  DuplicateSubscriptionException(this.message);
  final String message;

  @override
  String toString() => 'DuplicateSubscriptionException: $message';
}

/// Exception thrown when a video's selected sound does not grant reuse consent.
///
/// Thrown after the media has already uploaded, so it is not an upload or
/// relay failure: only the Nostr event is withheld. It exists as a distinct
/// type so the publish layer can classify it and tell the user the *sound* is
/// the blocker instead of pointing them at their relay settings.
class AudioReuseNotPermittedException implements Exception {
  AudioReuseNotPermittedException(this.audioEventId);

  /// The selected sound's Nostr event id, or `null` when the sound carries no
  /// referenceable event id.
  final String? audioEventId;

  @override
  String toString() =>
      'AudioReuseNotPermittedException: the selected sound does not grant '
      'reuse consent (audio: $audioEventId)';
}
