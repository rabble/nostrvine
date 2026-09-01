// ABOUTME: The non-fatal Crashlytics signal that sizes how many installs are
// ABOUTME: in the state where a late-delivered gift wrap is lost for good.

/// Reports that an install entered the state described by #8439.
///
/// A relay has joined the set the DM subscription asks, on an install whose
/// history drain has already latched complete and whose live window already
/// has a floor. That relay was never asked about anything below `since:`, and
/// nothing ever will be — the wire boundary only rises, and the drain returns
/// before issuing a query.
///
/// **This counts exposure, not loss.** The newly-asked relay may hold nothing
/// below the band. Read the count as an upper bound on affected installs, not
/// as a number of lost messages.
///
/// It is deliberately a distinct type rather than a generic error, so it
/// groups on its own in the dashboard and can be muted without touching real
/// crash triage. `.claude/rules/error_handling.md` reserves Crashlytics for
/// programming-invariant violations, and this is not one: it is here because
/// product analytics does not reach production builds and custom keys surface
/// only on reports that already happened, so no other channel yields a count.
/// If the noise proves unacceptable the fallback is the log-only route.
///
/// Carries no pubkey and no relay URLs. A relay URL identifies the
/// infrastructure a user chose, which is identifying on its own.
class DmSyncExposure implements Exception {
  /// Creates a report for one exposure transition.
  const DmSyncExposure({
    required this.newRelayCount,
    required this.knownRelayCount,
    required this.bandSeconds,
  });

  /// How many relays entered the asked set on this subscription.
  final int newRelayCount;

  /// How many relays had already been asked before this subscription — the
  /// denominator that separates a first DM inbox relay from ordinary pool
  /// churn.
  final int knownRelayCount;

  /// Width, in seconds, of the window below `since:` that nothing will ask
  /// about again.
  final int bandSeconds;

  @override
  String toString() =>
      'DmSyncExposure(newRelays: $newRelayCount, '
      'knownRelays: $knownRelayCount, bandSeconds: $bandSeconds)';
}
