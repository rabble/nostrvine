// ABOUTME: Result type for NIP-17 encrypted message sending operations
// ABOUTME: Sealed class — Success carries per-wrap delivery state,
// ABOUTME: Failure carries the error and never carries selfWrapPublished

import 'package:meta/meta.dart';

/// Result of NIP-17 encrypted message sending.
///
/// NIP-17 send is two independent publishes to relays:
///
/// 1. The **recipient** gift wrap (kind 1059), encrypted to the
///    recipient's pubkey. Without this, the recipient never sees the
///    message — its publish status is the headline success/failure
///    branch of this result.
/// 2. The **self-addressed** gift wrap (kind 1059), encrypted to the
///    sender's own pubkey. Without this, the sender's other devices
///    never see the message they just sent: the recipient gets it but
///    the sender's own conversation history won't have it after a
///    reinstall, account swap, or fresh login on a second device.
///
/// Use pattern matching (or the [success] / [selfWrapPublished]
/// getters) to handle each variant:
///
/// ```dart
/// switch (result) {
///   case NIP17SendSuccess(:final selfWrapPublished):
///     // recipient delivered; selfWrapPublished tells you whether
///     // the sender will see this message on other devices.
///   case NIP17SendFailure(:final error):
///     // recipient never received the message.
/// }
/// ```
///
/// Pre-existing callers that only check [success] continue to work
/// unchanged via the base-class getter. [selfWrapPublished] surfaces
/// partial delivery so a half-delivered send can be visibly
/// distinguished from a fully-delivered one. Acting on it (e.g.
/// retrying only the missing self-wrap publish without re-publishing
/// to the recipient) is left to future callers — the durable
/// outgoing-message queue tracked in #3909 is not yet on `main`.
sealed class NIP17SendResult {
  const NIP17SendResult();

  /// Build a success result. [selfWrapPublished] defaults to `true`
  /// so existing call sites that don't yet care about per-wrap status
  /// remain in the fully-delivered state. Pass `false` from the
  /// service layer when the self-addressed wrap could not be created
  /// or did not land on any relay.
  factory NIP17SendResult.success({
    required String rumorEventId,
    required String messageEventId,
    required String recipientPubkey,
    bool selfWrapPublished = true,
  }) => NIP17SendSuccess(
    rumorEventId: rumorEventId,
    messageEventId: messageEventId,
    recipientPubkey: recipientPubkey,
    selfWrapPublished: selfWrapPublished,
    timestamp: DateTime.now(),
  );

  /// Build a failure result. [NIP17SendFailure] has no
  /// `selfWrapPublished` field — the self-wrap is never attempted
  /// when the recipient publish fails.
  const factory NIP17SendResult.failure(String error) = NIP17SendFailure;

  /// Build a policy-block result (protected-minor DM restriction, #176). Unlike
  /// a transient failure, a blocked send must NOT be retried — retrying only
  /// re-hits the same policy — so the UI surfaces distinct, no-retry copy.
  const factory NIP17SendResult.blocked(String error) =
      NIP17SendFailure.blocked;

  /// Whether the recipient gift wrap (kind 1059, encrypted to the
  /// recipient) reached at least one relay. The headline send status.
  bool get success => this is NIP17SendSuccess;

  /// Whether this failure is a policy block (#176), not a transient/network
  /// error. Blocked sends are not retriable. Always `false` for success.
  bool get blocked => false;

  /// The rumor event ID (kind 14/15) — the canonical message
  /// identifier. Use this as the primary key when persisting sent
  /// messages. `null` on the failure branch.
  String? get rumorEventId;

  /// The recipient's gift wrap event ID (kind 1059). `null` on the
  /// failure branch.
  String? get messageEventId;

  /// Recipient's public key (hex). `null` on the failure branch.
  String? get recipientPubkey;

  /// Failure reason. `null` on the success branch.
  String? get error;

  /// When the result was constructed. `null` on the failure branch.
  DateTime? get timestamp;

  /// Whether the **self-addressed** gift wrap (kind 1059, encrypted
  /// to the sender's own pubkey) reached at least one relay.
  ///
  /// - `true` on [NIP17SendSuccess] when the self-wrap was published.
  ///   The recipient sees the message, and the sender's other devices
  ///   / future installs will see it after relay re-fetch.
  /// - `false` on [NIP17SendSuccess] when the self-wrap was not
  ///   published. The recipient saw the message but the sender will
  ///   not see this message after a reinstall or on a second device.
  ///   Surfaced so callers can persist enough state to act on it once
  ///   retry handling lands (see #3909). Re-publishing the recipient
  ///   wrap on retry would double-deliver, so any future retry must
  ///   target only the self-wrap.
  /// - `null` on [NIP17SendFailure] — the self-wrap is not attempted
  ///   when the recipient publish fails.
  bool? get selfWrapPublished;
}

/// Recipient gift wrap was published to at least one relay.
@immutable
final class NIP17SendSuccess extends NIP17SendResult {
  const NIP17SendSuccess({
    required this.rumorEventId,
    required this.messageEventId,
    required this.recipientPubkey,
    required this.selfWrapPublished,
    this.timestamp,
  });

  @override
  final String rumorEventId;

  @override
  final String messageEventId;

  @override
  final String recipientPubkey;

  @override
  final bool selfWrapPublished;

  @override
  final DateTime? timestamp;

  @override
  String? get error => null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NIP17SendSuccess &&
        other.rumorEventId == rumorEventId &&
        other.messageEventId == messageEventId &&
        other.recipientPubkey == recipientPubkey &&
        other.selfWrapPublished == selfWrapPublished &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode => Object.hash(
    rumorEventId,
    messageEventId,
    recipientPubkey,
    selfWrapPublished,
    timestamp,
  );

  @override
  String toString() =>
      'NIP17SendSuccess(rumorEventId: $rumorEventId, '
      'messageEventId: $messageEventId, '
      'recipient: $recipientPubkey, '
      'selfWrapPublished: $selfWrapPublished)';
}

/// Recipient gift wrap was not published — the message did not reach
/// the recipient at all. Self-wrap is not attempted on this branch.
@immutable
final class NIP17SendFailure extends NIP17SendResult {
  const NIP17SendFailure(this.error) : blocked = false;

  /// A policy block (#176): same non-delivery as a failure, but not retriable.
  const NIP17SendFailure.blocked(this.error) : blocked = true;

  @override
  final String error;

  @override
  final bool blocked;

  @override
  String? get rumorEventId => null;

  @override
  String? get messageEventId => null;

  @override
  String? get recipientPubkey => null;

  @override
  DateTime? get timestamp => null;

  @override
  bool? get selfWrapPublished => null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NIP17SendFailure &&
        other.error == error &&
        other.blocked == blocked;
  }

  @override
  int get hashCode => Object.hash(error, blocked);

  @override
  String toString() => 'NIP17SendFailure(error: $error, blocked: $blocked)';
}
