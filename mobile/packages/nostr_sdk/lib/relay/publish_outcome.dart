// ABOUTME: Result type for publishing an event with relay OK confirmation.
// ABOUTME: Tracks per-relay acceptance, rejection, and timeout outcomes.

import 'dart:async';

/// Outcome of a publish operation that awaits relay OK confirmations.
///
/// Per NIP-20, relays respond to `EVENT` messages with `OK` frames indicating
/// acceptance (`true`) or rejection (`false`) with an optional reason.
class PublishOutcome {
  const PublishOutcome({
    required this.eventId,
    required this.acceptedBy,
    required this.rejectedBy,
    required this.noResponseFrom,
  });

  /// The id of the event that was published.
  final String eventId;

  /// Relay URLs that returned `OK true`.
  final List<String> acceptedBy;

  /// Relay URLs that returned `OK false`, mapped to the reason returned.
  final Map<String, String> rejectedBy;

  /// Relays the event was sent to that did not respond before timeout or
  /// disconnected without answering.
  final List<String> noResponseFrom;

  /// `true` when at least one relay confirmed acceptance.
  bool get confirmed => acceptedBy.isNotEmpty;

  /// `true` when every targeted relay either rejected the event or failed to
  /// respond. Callers should treat this as a hard failure.
  bool get failed => acceptedBy.isEmpty;

  /// A short, human-readable summary for logs and error messages.
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

  @override
  String toString() =>
      'PublishOutcome(eventId: $eventId, accepted: $acceptedBy, '
      'rejected: $rejectedBy, noResponse: $noResponseFrom)';
}

/// Internal tracker used by [RelayPool] to correlate OK frames with the
/// original publish call.
class PublishTracker {
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

  Future<PublishOutcome> get future => _completer.future;

  /// Call when the relay returned `OK true`.
  void onAccepted(String relayUrl) {
    if (_closed) return;
    _accepted.add(relayUrl);
    // First confirmation is enough for deletion-style operations; we still
    // collect the remaining responses but complete immediately.
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
        .toList(growable: false);
    _completer.complete(
      PublishOutcome(
        eventId: eventId,
        acceptedBy: _accepted.toList(growable: false),
        rejectedBy: Map<String, String>.unmodifiable(_rejected),
        noResponseFrom: noResponse,
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
          acceptedBy: _accepted.toList(growable: false),
          rejectedBy: Map<String, String>.unmodifiable(_rejected),
          noResponseFrom: expectedRelays.toList(growable: false),
        ),
      );
    }
  }
}
