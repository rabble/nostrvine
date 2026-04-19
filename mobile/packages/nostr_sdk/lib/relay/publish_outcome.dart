// ABOUTME: PublishOutcome summarizes per-relay NIP-20 OK responses for a single publish.
// ABOUTME: Returned by RelayPool.sendAwaitOk, Nostr.sendEventAwaitOk, and NostrClient.publishEventAwaitOk.

import 'package:meta/meta.dart';

/// Permanent rejection prefixes per NIP-01. Relays emit these in the fourth
/// element of an `["OK", id, false, reason]` frame to hint at whether a retry
/// could succeed. We treat these as permanent — retry would be wasted work.
const Set<String> _permanentRejectionPrefixes = {
  'blocked:',
  'invalid:',
  'pow:',
  'restricted:',
  'auth-required:',
  'rate-limited:',
};

/// Result of publishing a single Nostr event to one or more relays.
///
/// A publish can have three outcomes per relay:
/// - Accepted: relay sent `["OK", id, true, _]`
/// - Rejected: relay sent `["OK", id, false, reason]`
/// - No response: timeout elapsed without any OK frame
///
/// Callers decide user-facing behavior based on the combined result. See
/// [acceptedByAll], [acceptedByAny], [failed], and [transientRelays].
@immutable
class PublishOutcome {
  const PublishOutcome({
    required this.eventId,
    required this.acceptedBy,
    required this.rejectedBy,
    required this.noResponseFrom,
  });

  /// Full 64-hex-char event id — never truncated.
  final String eventId;

  /// Relay URLs that responded with `["OK", id, true, _]`.
  final Set<String> acceptedBy;

  /// Relay URLs that responded with `["OK", id, false, reason]`, mapped to
  /// the reason string (may be empty).
  final Map<String, String> rejectedBy;

  /// Relay URLs that were targeted but did not respond within the timeout.
  final Set<String> noResponseFrom;

  /// True when every targeted relay accepted.
  bool get acceptedByAll =>
      acceptedBy.isNotEmpty && rejectedBy.isEmpty && noResponseFrom.isEmpty;

  /// True when at least one relay accepted.
  bool get acceptedByAny => acceptedBy.isNotEmpty;

  /// True when no relay accepted.
  bool get failed => acceptedBy.isEmpty;

  /// Relays that *could* succeed on retry — no-response plus rejections whose
  /// reason does not start with a permanent NIP-01 prefix.
  Set<String> get transientRelays {
    final transient = <String>{...noResponseFrom};
    rejectedBy.forEach((relay, reason) {
      if (!_isPermanent(reason)) transient.add(relay);
    });
    return transient;
  }

  static bool _isPermanent(String reason) {
    for (final prefix in _permanentRejectionPrefixes) {
      if (reason.startsWith(prefix)) return true;
    }
    return false;
  }

  @override
  String toString() =>
      'PublishOutcome(eventId: $eventId, '
      'acceptedBy: $acceptedBy, '
      'rejectedBy: $rejectedBy, '
      'noResponseFrom: $noResponseFrom)';
}
