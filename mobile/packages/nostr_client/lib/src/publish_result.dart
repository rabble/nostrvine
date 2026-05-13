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

/// Shared helpers for [PublishResult] call sites.
extension PublishResultX on PublishResult {
  /// Whether the publish succeeded.
  bool get isSuccess => this is PublishSuccess;

  /// A short, reason-specific diagnostic string for logging, or `null` when
  /// the result is [PublishSuccess].
  ///
  /// Call sites use this to emit a distinguished log message without
  /// duplicating the branch semantics:
  ///
  /// ```dart
  /// final reason = result.failureReason;
  /// if (reason != null) {
  ///   Log.error('Failed to publish X: $reason', name: 'MyService', …);
  ///   return SomeResult.failure('generic user-facing message');
  /// }
  /// ```
  String? get failureReason => switch (this) {
    PublishSuccess() => null,
    PublishNoRelays() => 'no relays connected',
    PublishFailed() => 'send error',
  };
}
