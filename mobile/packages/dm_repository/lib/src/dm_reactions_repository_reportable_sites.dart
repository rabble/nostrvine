// ABOUTME: Stable identifiers for the swallow sites in DmReactionsRepository.
// ABOUTME: Used as the `site:` annotation on the reporter port calls. Per
// ABOUTME: the error-handling matrix, only DAO-layer invariants reach
// ABOUTME: Crashlytics — network/IO publish failures stay local.

/// Stable site identifiers for the swallow points in
/// `DmReactionsRepository`. The wiring layer forwards each call to
/// Crashlytics with `reason: 'DmReactionsRepository.<site>'` so the
/// dashboard aggregates per site.
abstract class DmReactionsRepositoryReportableSites {
  /// `persistIncoming`: DAO upsert threw despite valid event shape.
  /// Programming-invariant violation — the validator above passed.
  static const String persistIncomingDaoUpsert = 'persistIncoming.daoUpsert';

  /// `handleIncomingDeletion`: DAO soft-delete threw despite a validated
  /// matching reaction row.
  static const String handleIncomingDeletionSoftDelete =
      'handleIncomingDeletion.softDelete';

  /// `publish`: optimistic DAO insert threw before any send attempt.
  /// Programming-invariant violation — placeholder ids are uuid-shaped
  /// and the row is fresh.
  static const String publishOptimisticInsert = 'publish.optimisticInsert';

  /// `publish`: send succeeded but the placeholder-id swap threw.
  /// The row stays in `pending` state and won't refresh to `sent` until
  /// the next app start picks up the rescue sweep.
  static const String publishSwapPlaceholder = 'publish.swapPlaceholder';

  /// `removeOwn`: soft-delete update threw. The reaction was already
  /// kind-5 deleted on the wire — local state will eventually reconcile
  /// from the relay echo.
  static const String removeOwnSoftDelete = 'removeOwn.softDelete';

  /// `publish`: recording the durable `deletion_pending` row for a superseded
  /// prior reaction (cap-at-one emoji swap) threw. The new reaction still
  /// publishes; the superseded emoji's kind-5 removal is the part at risk.
  static const String publishSupersedeDeletion = 'publish.supersedeDeletion';
}
