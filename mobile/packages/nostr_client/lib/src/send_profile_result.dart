// ABOUTME: Typed result for sendProfile, distinguishing success from
// ABOUTME: no-relays and generic send-failure outcomes.

import 'package:nostr_sdk/nostr_sdk.dart';

/// The outcome of a Kind 0 profile publish call.
///
/// Callers can switch exhaustively over the three variants rather than
/// inferring failure reason from a post-failure relay-list snapshot.
sealed class SendProfileResult {
  const SendProfileResult();
}

/// The Kind 0 event was accepted and broadcast to at least one relay.
final class SendProfileSuccess extends SendProfileResult {
  /// Creates a successful send result wrapping the sent [event].
  const SendProfileSuccess({required this.event});

  /// The signed and sent Kind 0 [Event].
  final Event event;
}

/// The publish attempt was aborted before sending because no relays were
/// connected, even after a reconnection attempt.
final class SendProfileNoRelays extends SendProfileResult {
  /// Creates a no-relays result.
  const SendProfileNoRelays();
}

/// The relay pool was reachable but the underlying send call returned null —
/// e.g. the SDK could not serialise or write the frame.
/// This is distinct from [SendProfileNoRelays]: at least one relay was
/// connected, but the send still failed.
final class SendProfileFailed extends SendProfileResult {
  /// Creates a send-failed result.
  const SendProfileFailed();
}
