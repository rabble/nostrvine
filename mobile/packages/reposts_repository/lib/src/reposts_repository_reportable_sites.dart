// ABOUTME: Stable identifiers for the local-storage swallow sites in
// ABOUTME: RepostsRepository, used as the `site:` annotation on reporter calls.

/// Stable site identifiers for the best-effort local-storage swallow
/// points in `RepostsRepository`. The wiring layer forwards each call to
/// Crashlytics with `reason: 'RepostsRepository.<site>'` so the dashboard
/// aggregates per site.
///
/// Only programming-invariant violations (`Error` subtypes) reach the
/// reporter; expected IO and corruption failures stay in the unified log
/// per the decision matrix in `.claude/rules/error_handling.md`.
abstract class RepostsRepositoryReportableSites {
  /// `_ensureInitialized`: reading the persisted repost records threw, so
  /// the session continues on an in-memory-only cache.
  static const String ensureInitializedLoadRecords =
      'ensureInitialized.loadRecords';

  /// `repostVideo`: persisting the optimistic placeholder record threw.
  static const String repostVideoSavePlaceholder =
      'repostVideo.savePlaceholder';

  /// `repostVideo`: persisting the confirmed record (real repost event id)
  /// threw after the Kind 16 publish landed.
  static const String repostVideoSaveConfirmed = 'repostVideo.saveConfirmed';

  /// `repostVideo`: rolling the placeholder back after a publish failure
  /// threw, leaving a stale row behind.
  static const String repostVideoRollbackPlaceholder =
      'repostVideo.rollbackPlaceholder';

  /// `unrepostVideo`: the fallback read of the repost record threw, so the
  /// caller cannot tell "not reposted" from "cannot tell".
  static const String unrepostVideoReadRecord = 'unrepostVideo.readRecord';

  /// `unrepostVideo`: deleting the record ahead of the Kind 5 publish threw.
  static const String unrepostVideoDeleteRecord = 'unrepostVideo.deleteRecord';

  /// `unrepostVideo`: restoring the record after a deletion-publish failure
  /// threw, so the optimistic removal is not undone locally.
  static const String unrepostVideoRestoreRecord =
      'unrepostVideo.restoreRecord';

  /// `toggleRepost`: the authoritative already-reposted read threw, so the
  /// toggle falls back to the in-memory cache to decide its direction.
  static const String toggleRepostReadState = 'toggleRepost.readState';

  /// `syncUserReposts`: the warm read of persisted records threw, so the
  /// sync runs on relay data alone.
  static const String syncUserRepostsLoadRecords =
      'syncUserReposts.loadRecords';

  /// `syncUserReposts`: persisting the freshly-synced relay records threw.
  static const String syncUserRepostsSaveBatch = 'syncUserReposts.saveBatch';

  /// `initialize`: the startup read of persisted records threw, so the
  /// session continues on an in-memory-only cache.
  static const String initializeLoadRecords = 'initialize.loadRecords';
}
