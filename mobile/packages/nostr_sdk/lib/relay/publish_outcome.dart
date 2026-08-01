// ABOUTME: Result type for publishing an event with relay OK confirmation.
// ABOUTME: Tracks per-relay acceptance, rejection, unreachability and silence.

import 'dart:async';

/// Outcome of a publish operation that awaits relay OK confirmations.
///
/// Per NIP-01, relays respond to `EVENT` messages with `OK` frames indicating
/// acceptance (`true`) or rejection (`false`) with an optional reason.
///
/// ## What acceptance means
///
/// `OK true` means the relay *accepted the event for writing*. It does not
/// mean the event is stored: NIP-01 defines the flag as "accepted by the
/// relay", and its own example of a valid `OK true` carries the reason
/// `duplicate: already have this event` — an acceptance that wrote nothing.
/// Divine's own relay acknowledges from an in-memory queue and commits to
/// storage on a batch interval afterwards. Treat this type as a record of
/// **how broadly a publish was accepted**, never as a durability guarantee.
///
/// ## Partition invariant
///
/// Every relay the publish targeted appears in exactly one of [acceptedBy],
/// [rejectedBy], [noResponseFrom] or [unreachableTargets], and no other relay
/// appears at all.
class PublishOutcome {
  const PublishOutcome({
    required this.eventId,
    this.eventKind,
    required this.acceptedBy,
    required this.rejectedBy,
    required this.noResponseFrom,
    this.unreachableTargets = const [],
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

  /// Relays the event reached that did not answer before the publish settled.
  final List<String> noResponseFrom;

  /// Relays the publish targeted but could not write to at all.
  ///
  /// These never received the `EVENT` frame — the socket was down, the send
  /// timed out, or the relay dropped out mid-publish. They are reported
  /// separately from [noResponseFrom] because "we never asked" and "we asked
  /// and got silence" call for different recovery.
  final List<String> unreachableTargets;

  /// Every relay this publish targeted.
  int get targetCount =>
      acceptedBy.length +
      rejectedBy.length +
      noResponseFrom.length +
      unreachableTargets.length;

  /// `true` when at least one relay confirmed acceptance.
  bool get acceptedByAny => acceptedBy.isNotEmpty;

  /// `true` when every targeted relay confirmed acceptance.
  ///
  /// Returns `false` when the publish had no targets at all — "all of zero" is
  /// a surprising success, so an empty publish is never treated as accepted.
  bool get acceptedByAll =>
      acceptedBy.isNotEmpty &&
      rejectedBy.isEmpty &&
      noResponseFrom.isEmpty &&
      unreachableTargets.isEmpty;

  /// `true` when some but not all targeted relays accepted the event.
  ///
  /// Nothing in the client republishes to the relays that did not accept, so a
  /// partial publish stays partial until the caller acts on it.
  bool get acceptedByPartial => acceptedByAny && !acceptedByAll;

  /// `true` when at least one relay confirmed acceptance.
  ///
  /// Prefer [acceptedByAny] or [acceptedByAll], which say which one they mean.
  bool get confirmed => acceptedByAny;

  /// `true` when no targeted relay accepted the event. Callers should treat
  /// this as a hard failure.
  bool get failed => acceptedBy.isEmpty;

  /// A short, human-readable summary for logs and error messages.
  String get summary {
    if (acceptedByAll) {
      return 'accepted by all ${acceptedBy.length} relay'
          '${acceptedBy.length == 1 ? '' : 's'}';
    }
    if (acceptedByAny) {
      return 'accepted by ${acceptedBy.length} of $targetCount relays';
    }
    if (rejectedBy.isNotEmpty) {
      final first = rejectedBy.entries.first;
      return 'rejected by ${first.key}: ${first.value}';
    }
    if (noResponseFrom.isNotEmpty) {
      return 'no relay responded (${noResponseFrom.length} timed out)';
    }
    if (unreachableTargets.isNotEmpty) {
      return 'no relay reachable (${unreachableTargets.length} unreachable)';
    }
    return 'no relay reached';
  }

  @override
  String toString() =>
      'PublishOutcome(eventId: $eventId, accepted: $acceptedBy, '
      'rejected: $rejectedBy, noResponse: $noResponseFrom, '
      'unreachable: $unreachableTargets)';
}

/// Internal tracker used by [RelayPool] to correlate OK frames with the
/// original publish call.
///
/// Completion waits for **every** relay the publish reached, so the outcome
/// describes what the relays actually said rather than whichever answered
/// first. It resolves when:
///  * every reached relay has answered, or
///  * [settleWindow] elapses after the first answer, or
///  * [timeout] elapses.
///
/// The settle window bounds the cost of one wedged relay: healthy relays
/// answer in single-digit milliseconds, so waiting the full [timeout] for a
/// silent sibling would stall every publish behind the slowest connection.
class PublishTracker {
  PublishTracker({
    required this.eventId,
    this.eventKind,
    this.diagnosticTag,
    this.message,
    this.deadline,
    required this.expectedRelays,
    required Duration timeout,
    this.settleWindow = defaultSettleWindow,
  }) {
    _timer = Timer(timeout, _onTimeout);
  }

  /// Grace period granted to the remaining relays after the first answer.
  ///
  /// Sized against measured relay behaviour: a healthy relay returns `OK`
  /// within a few milliseconds, so this is orders of magnitude of headroom
  /// while still capping a wedged relay far below the publish timeout. Revisit
  /// once publish telemetry gives a real latency distribution.
  static const defaultSettleWindow = Duration(seconds: 1);

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

  /// Every relay this publish intends to reach.
  ///
  /// Computed before the fan-out starts, so it covers relays the pool later
  /// fails to write to. Those are reported in
  /// [PublishOutcome.unreachableTargets] instead of vanishing from the result.
  final Set<String> expectedRelays;

  /// Grace period granted to the remaining relays after the first answer.
  final Duration settleWindow;

  /// Relays the fan-out actually wrote to, once it has reported.
  ///
  /// `null` until [setReachable] is called, which means "assume every target
  /// can answer". The fan-out narrows it, which is what lets an unreachable
  /// target stop blocking completion.
  Set<String>? _reachable;

  final Map<String, String> _rejected = {};
  final Map<String, String> _deferredRejections = {};
  final Set<String> _accepted = {};
  final Completer<PublishOutcome> _completer = Completer<PublishOutcome>();
  late final Timer _timer;
  Timer? _settleTimer;
  bool _closed = false;

  Future<PublishOutcome> get future => _completer.future;

  /// Relays that may still answer this publish.
  Set<String> get _awaitable => _reachable ?? expectedRelays;

  /// Whether [relayUrl] is allowed to speak for this publish.
  ///
  /// Frames are routed by event id alone, so without this check any connected
  /// relay could accept or reject a publish it was never sent.
  bool isTarget(String relayUrl) =>
      expectedRelays.contains(relayUrl) ||
      (_reachable?.contains(relayUrl) ?? false);

  /// Record which relays the fan-out managed to write to.
  ///
  /// Relays that were targeted but not reached stop being awaited and are
  /// reported as unreachable.
  void setReachable(Iterable<String> reachable) {
    if (_closed) return;
    _reachable = reachable.toSet();
    _maybeComplete();
  }

  /// Call when the relay returned `OK true`.
  void onAccepted(String relayUrl) {
    if (_closed) return;
    _deferredRejections.remove(relayUrl);
    _accepted.add(relayUrl);
    _onAnswered();
  }

  /// Call when the relay returned `OK false` with a reason.
  void onRejected(String relayUrl, String reason) {
    if (_closed) return;
    _deferredRejections.remove(relayUrl);
    _rejected[relayUrl] = reason;
    _onAnswered();
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
    _reachable = _awaitable.where((r) => r != relayUrl).toSet();
    _maybeComplete();
  }

  /// Start the settle window on the first answer, then re-test completion.
  void _onAnswered() {
    _settleTimer ??= Timer(settleWindow, _onSettleWindowElapsed);
    _maybeComplete();
  }

  void _maybeComplete() {
    final answered = _accepted.length + _rejected.length;
    if (answered >= _awaitable.length) {
      _complete();
    }
  }

  void _onSettleWindowElapsed() {
    if (_closed) return;
    _complete();
  }

  void _onTimeout() {
    if (_closed) return;
    _complete();
  }

  void _complete() {
    if (_closed) return;
    _closed = true;
    _timer.cancel();
    _settleTimer?.cancel();
    final effectiveRejected = Map<String, String>.from(_rejected);
    if (_accepted.isEmpty) {
      effectiveRejected.addAll(_deferredRejections);
    }
    final awaitable = _awaitable;
    bool answered(String relay) =>
        _accepted.contains(relay) || effectiveRejected.containsKey(relay);
    final noResponse = awaitable
        .where((r) => !answered(r))
        .toList(growable: false);
    // A relay that answered is never unreachable, even if the fan-out reported
    // its write as failed — the answer proves it got the frame.
    final unreachable = expectedRelays
        .where((r) => !awaitable.contains(r) && !answered(r))
        .toList(growable: false);
    _completer.complete(
      PublishOutcome(
        eventId: eventId,
        eventKind: eventKind,
        acceptedBy: _accepted.toList(growable: false),
        rejectedBy: Map<String, String>.unmodifiable(effectiveRejected),
        noResponseFrom: noResponse,
        unreachableTargets: unreachable,
      ),
    );
  }

  /// Cancel the tracker without waiting. Used when the pool is shut down.
  ///
  /// Reports whatever has arrived so far, using the same partitioning as a
  /// normal completion so a relay can never appear in two buckets.
  void cancel() => _complete();
}
