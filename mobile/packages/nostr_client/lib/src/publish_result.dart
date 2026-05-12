// ABOUTME: Typed result for publishEvent, distinguishing success from
// ABOUTME: no-relays and generic send-failure outcomes.

import 'package:nostr_sdk/nostr_sdk.dart';

/// The outcome of a `NostrClient.publishEvent` call.
///
/// Callers can switch exhaustively over the three variants rather than
/// inferring failure reason from a post-failure relay-list snapshot.
///
/// See also:
/// - [PublishSuccess] — the event was accepted and broadcast.
/// - [PublishNoRelays] — no relays were connected even after retry.
/// - [PublishFailed] — the relay pool was reachable but the send returned null.
sealed class PublishResult {
  const PublishResult();
}

/// The event was accepted and broadcast to at least one relay.
final class PublishSuccess extends PublishResult {
  /// Creates a successful publish result wrapping the sent [event].
  const PublishSuccess({required this.event});

  /// The signed and sent [Event].
  final Event event;
}

/// The publish attempt was aborted before sending because no relays were
/// connected, even after a reconnection attempt.
final class PublishNoRelays extends PublishResult {
  /// Creates a no-relays result.
  const PublishNoRelays();
}

/// The relay pool was reachable but the underlying send call returned null —
/// e.g. the SDK could not serialise or write the frame.
/// This is distinct from [PublishNoRelays]: at least one relay was
/// connected, but the send still failed.
final class PublishFailed extends PublishResult {
  /// Creates a send-failed result.
  const PublishFailed();
}
