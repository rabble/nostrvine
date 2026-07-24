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
    this.eventKind,
    required this.acceptedBy,
    required this.rejectedBy,
    required this.noResponseFrom,
  });

  /// The id of the event that was published.
  final String eventId;

  /// The event kind that was published, when known.
  ///
  /// Set by `RelayPool.sendEventAwaitOk` callers or inferred from the `EVENT`
  /// message envelope. Null when callers do not provide a kind and it cannot be
  /// inferred from the message.
  final int? eventKind;

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
    this.eventKind,
    this.diagnosticTag,
    this.message,
    this.deadline,
    required this.expectedRelays,
    required Duration timeout,
  }) {
    _timer = Timer(timeout, _onTimeout);
  }

  /// The event id we are waiting on.
  final String eventId;

  /// The event kind we are waiting on, when known.
  final int? eventKind;

  /// Caller-supplied tag for temporary publish diagnostics, when enabled.
  final String? diagnosticTag;

  /// Original EVENT frame for SDK-internal retry paths.
  final List<dynamic>? message;

  /// Hard publish deadline shared with SDK-internal retry paths.
  final DateTime? deadline;

  /// Relay URLs we expect responses from.
  final Set<String> expectedRelays;

  final Map<String, String> _rejected = {};
  final Map<String, String> _deferredRejections = {};
  final Set<String> _accepted = {};
  final Completer<PublishOutcome> _completer = Completer<PublishOutcome>();
  late final Timer _timer;
  bool _closed = false;

  Future<PublishOutcome> get future => _completer.future;

  /// Call when the relay returned `OK true`.
  void onAccepted(String relayUrl) {
    if (_closed) return;
    _deferredRejections.remove(relayUrl);
    _accepted.add(relayUrl);
    // First confirmation is enough for deletion-style operations; we still
    // collect the remaining responses but complete immediately.
    _complete();
  }

  /// Call when the relay returned `OK false` with a reason.
  void onRejected(String relayUrl, String reason) {
    if (_closed) return;
    _deferredRejections.remove(relayUrl);
    _rejected[relayUrl] = reason;
    _maybeCompleteIfAllAnswered();
  }

  /// Record a relay rejection that should be reported if the publish times out,
  /// without counting the relay as answered yet.
  void deferRejection(String relayUrl, String reason) {
    if (_closed ||
        _accepted.contains(relayUrl) ||
        _rejected.containsKey(relayUrl)) {
      return;
    }
    _deferredRejections[relayUrl] = reason;
  }

  /// Clear a previously deferred rejection when the relay is retried or
  /// otherwise no longer represents the original rejection.
  void clearDeferredRejection(String relayUrl) {
    if (_closed) return;
    _deferredRejections.remove(relayUrl);
  }

  /// Call when a relay disconnected or otherwise cannot be awaited further.
  void onRelayUnavailable(String relayUrl) {
    if (_closed) return;
    _deferredRejections.remove(relayUrl);
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
    final effectiveRejected = Map<String, String>.from(_rejected);
    if (_accepted.isEmpty) {
      effectiveRejected.addAll(_deferredRejections);
    }
    final noResponse = expectedRelays
        .where(
          (r) => !_accepted.contains(r) && !effectiveRejected.containsKey(r),
        )
        .toList(growable: false);
    _completer.complete(
      PublishOutcome(
        eventId: eventId,
        eventKind: eventKind,
        acceptedBy: _accepted.toList(growable: false),
        rejectedBy: Map<String, String>.unmodifiable(effectiveRejected),
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
          eventKind: eventKind,
          acceptedBy: _accepted.toList(growable: false),
          rejectedBy: Map<String, String>.unmodifiable(_rejected),
          noResponseFrom: expectedRelays.toList(growable: false),
        ),
      );
    }
  }
}
