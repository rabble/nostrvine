// ABOUTME: Crashlytics site identifiers for creator_sync error reports.
// ABOUTME: Kept per-package so feature migrations avoid a shared hot spot.

/// Call-site identifiers passed to the `CreatorSyncErrorReporter` port.
abstract final class CreatorSyncReportableSites {
  /// Full sound-library reconcile pass.
  static const String reconcileSounds = 'reconcileSounds';

  /// Publishing a single local sound change.
  static const String publishSoundChange = 'publishSoundChange';

  /// Publishing a single local sound deletion.
  static const String publishSoundDeletion = 'publishSoundDeletion';
}
