// ABOUTME: Why a kind-22236 view event was not published to the relay.
// ABOUTME: Separates expected skips from defects so only defects alarm.

/// Why a kind-22236 view event was not published.
///
/// `publishViewEvent` returning `false` on its own cannot distinguish a view
/// that was correctly skipped from one the client failed to build. Both are
/// silent, but only the second is a bug — so the two must be told apart at
/// the point of the drop rather than inferred from log volume later.
enum ViewEventDropReason {
  /// The watched segment was shorter than the minimum for a view.
  belowMinimumWatchTime,

  /// No signed-in identity, so nothing could sign the event.
  notAuthenticated,

  /// The video carried no addressable `d` tag, so no `a` tag could be built.
  missingAddressableDTag,

  /// Signing returned no event.
  signingFailed,

  /// An unexpected exception interrupted event construction or publishing.
  unexpectedError,

  /// The event was built and signed but the relay publish did not succeed.
  relayRejected;

  /// Whether this drop indicates a defect rather than an expected skip.
  ///
  /// Structural drops should never occur: by the time they are reached the
  /// caller has already decided this view is worth publishing, so failing to
  /// build or sign the event means the client is broken. They are reported.
  ///
  /// Expected skips are high-volume and routine. Reporting them would bury
  /// the defects, so they stay silent — see `.claude/rules/error_handling.md`.
  /// [relayRejected] is deliberately not structural: the event was well
  /// formed and the failure is a network or relay condition, which the
  /// durable queue already retries.
  bool get isStructural => switch (this) {
    ViewEventDropReason.belowMinimumWatchTime => false,
    ViewEventDropReason.notAuthenticated => false,
    ViewEventDropReason.missingAddressableDTag => true,
    ViewEventDropReason.signingFailed => true,
    ViewEventDropReason.unexpectedError => true,
    ViewEventDropReason.relayRejected => false,
  };
}

/// A view event the client decided to publish but could not construct.
///
/// Wrap with `Reportable` at the call site so Crashlytics groups on this type
/// and the identifier sanitiser runs.
class ViewEventInvariantException implements Exception {
  /// Creates an invariant violation for [reason].
  const ViewEventInvariantException(this.reason);

  /// The structural reason the event could not be published.
  final ViewEventDropReason reason;

  @override
  String toString() => 'ViewEventInvariantException(${reason.name})';
}
