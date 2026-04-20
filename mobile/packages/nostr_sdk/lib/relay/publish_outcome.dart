// ABOUTME: PublishOutcome summarizes per-relay NIP-20 OK responses
// ABOUTME: for one publish attempt. Supports retry policy decisions.

import 'dart:async';

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
/// [acceptedByAll], [acceptedByAny], [failed], [transientRelays], and the
/// legacy aliases [confirmed] / [summary] preserved for callers from
/// the initial delete-reliability rollout.
@immutable
class PublishOutcome {
  /// Creates a publish outcome from per-relay ack state. Asserts the three
  /// sets are disjoint (each relay appears in at most one bucket) — this
  /// prevents contradictory answers from [transientRelays] / [failed].
  PublishOutcome({
    required this.eventId,
    required this.acceptedBy,
    required this.rejectedBy,
    required this.noResponseFrom,
  }) {
    assert(() {
      final rejectedKeys = rejectedBy.keys.toSet();
      final overlap = acceptedBy
          .intersection(rejectedKeys)
          .union(acceptedBy.intersection(noResponseFrom))
          .union(rejectedKeys.intersection(noResponseFrom));
      return overlap.isEmpty;
    }(), 'acceptedBy, rejectedBy.keys, and noResponseFrom must be disjoint');
  }

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
  ///
  /// Returns `false` when no relays were targeted (all three sets empty) —
  /// vacuous truth is surprising in this API, so "all of zero" is treated
  /// as a non-successful outcome. Use [acceptedByAny] if you want a
  /// positive signal only when at least one relay accepted.
  bool get acceptedByAll =>
      acceptedBy.isNotEmpty && rejectedBy.isEmpty && noResponseFrom.isEmpty;

  /// True when at least one relay accepted. Same as legacy [confirmed].
  bool get acceptedByAny => acceptedBy.isNotEmpty;

  /// Legacy alias for [acceptedByAny]. Preserved for callers from the
  /// initial delete-reliability rollout before the retry-aware API landed.
  bool get confirmed => acceptedByAny;

  /// True when no relay accepted.
  bool get failed => acceptedBy.isEmpty;

  /// Relays that *could* succeed on retry — no-response plus rejections
  /// whose reason does not start with a permanent NIP-01 prefix.
  Set<String> get transientRelays {
    final transient = <String>{...noResponseFrom};
    rejectedBy.forEach((relay, reason) {
      if (!_isPermanent(reason)) transient.add(relay);
    });
    return transient;
  }

  /// A short, human-readable summary for logs and error messages. Legacy
  /// helper preserved for callers from the initial delete-reliability
  /// rollout.
  String get summary {
    if (confirmed) {
      return 'accepted by ${acceptedBy.length} relay'
          '${acceptedBy.length == 1 ? '' : 's'}';
    }
    if (rejectedBy.isNotEmpty) {
      final first = rejectedBy.entries.first;
      return 'rejected by ${first.key}: ${first.value}';
    }
    if (noResponseFrom.isNotEmpty) {
      return 'no relay responded (${noResponseFrom.length} timed out)';
    }
    return 'no relay reached';
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

/// Internal tracker used by [RelayPool] to correlate OK frames with the
/// original publish call.
///
/// Preserved from the initial delete-reliability rollout for any
/// external callers that reference this class. The in-package publish
/// flow has moved to the private `_PendingPublish` type inside
/// `relay_pool.dart` which collects every relay's response before
/// completing (rather than first-accept-wins), giving retry logic
/// the full picture. Prefer `RelayPool.sendAwaitOk` for new code.
class PublishTracker {
  /// Creates a tracker that resolves after [timeout] if not all
  /// expected relays have responded.
  PublishTracker({
    required this.eventId,
    required this.expectedRelays,
    required Duration timeout,
  }) {
    _timer = Timer(timeout, _onTimeout);
  }

  /// The event id we are waiting on.
  final String eventId;

  /// Relay URLs we expect responses from.
  final Set<String> expectedRelays;

  final Map<String, String> _rejected = {};
  final Set<String> _accepted = {};
  final Completer<PublishOutcome> _completer = Completer<PublishOutcome>();
  late final Timer _timer;
  bool _closed = false;

  /// Future that resolves with the [PublishOutcome] when the tracker
  /// completes.
  Future<PublishOutcome> get future => _completer.future;

  /// Call when the relay returned `OK true`.
  void onAccepted(String relayUrl) {
    if (_closed) return;
    _accepted.add(relayUrl);
    // First confirmation is enough for deletion-style operations; we
    // still collect the remaining responses but complete immediately.
    _complete();
  }

  /// Call when the relay returned `OK false` with a reason.
  void onRejected(String relayUrl, String reason) {
    if (_closed) return;
    _rejected[relayUrl] = reason;
    _maybeCompleteIfAllAnswered();
  }

  /// Call when a relay disconnected or otherwise cannot be awaited further.
  void onRelayUnavailable(String relayUrl) {
    if (_closed) return;
    expectedRelays.remove(relayUrl);
    _maybeCompleteIfAllAnswered();
  }

  void _maybeCompleteIfAllAnswered() {
    final responded = _accepted.length + _rejected.length;
    if (responded >= expectedRelays.length) {
      _complete();
    }
  }

  void _onTimeout() {
    if (_closed) return;
    _complete();
  }

  void _complete() {
    if (_closed) return;
    _closed = true;
    _timer.cancel();
    final noResponse = expectedRelays
        .where((r) => !_accepted.contains(r) && !_rejected.containsKey(r))
        .toSet();
    _completer.complete(
      PublishOutcome(
        eventId: eventId,
        acceptedBy: Set<String>.unmodifiable(_accepted),
        rejectedBy: Map<String, String>.unmodifiable(_rejected),
        noResponseFrom: Set<String>.unmodifiable(noResponse),
      ),
    );
  }

  /// Cancel the tracker without waiting. Used when the pool is shut down.
  void cancel() {
    if (_closed) return;
    _closed = true;
    _timer.cancel();
    if (!_completer.isCompleted) {
      _completer.complete(
        PublishOutcome(
          eventId: eventId,
          acceptedBy: Set<String>.unmodifiable(_accepted),
          rejectedBy: Map<String, String>.unmodifiable(_rejected),
          noResponseFrom: Set<String>.unmodifiable(expectedRelays),
        ),
      );
    }
  }
}
