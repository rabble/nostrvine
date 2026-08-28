// ABOUTME: Typed outcome for social-event publishes that await relay OK frames.
// ABOUTME: Preserves relay evidence while separating terminal policy failures.

import 'package:nostr_sdk/nostr_sdk.dart';

/// Product-relevant classification of a social-event publish attempt.
enum SocialPublishStatus {
  /// At least one relay returned OK true.
  accepted,

  /// The trusted relay confirmed suspension or ban enforcement.
  accountRestricted,

  /// No relay accepted and at least one returned a rate limit.
  rateLimited,

  /// No relay accepted and a relay returned another rejection.
  rejected,

  /// The event reached a relay but no OK arrived in time.
  noResponse,

  /// No relay could be reached after reconnection.
  noRelays,

  /// Signing, serialization, or SDK dispatch failed before an OK result.
  sendFailed,
}

/// Marker for a social action that retry infrastructure must terminalize.
abstract interface class TerminalSocialActionException implements Exception {}

/// Result of publishing a social event through the await-OK path.
class SocialPublishResult {
  /// Creates a classified result while retaining the raw relay [outcome].
  const SocialPublishResult({
    required this.status,
    required this.event,
    this.outcome,
  });

  /// Product-relevant classification.
  final SocialPublishStatus status;

  /// Event whose publication was attempted.
  final Event event;

  /// Per-relay evidence, absent when no relay attempt was possible.
  final PublishOutcome? outcome;

  /// Whether at least one relay accepted the event.
  bool get accepted => status == SocialPublishStatus.accepted;

  /// Whether the trusted relay confirmed account enforcement.
  bool get accountRestricted => status == SocialPublishStatus.accountRestricted;
}

/// A social publish that no relay accepted.
class SocialPublishException implements Exception {
  /// Creates a typed failure from [result].
  const SocialPublishException(this.result);

  /// The classified publish result.
  final SocialPublishResult result;

  @override
  String toString() => 'SocialPublishException(${result.status.name})';
}
