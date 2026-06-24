/// Crashlytics `site` identifiers for `FeedTuningRepository` error reports.
///
/// Network/relay publish failures are expected and NOT reported (see the
/// repository). These sites mark the only programming-invariant paths.
abstract class FeedTuningReportableSites {
  /// Site for failures while publishing a tuning signal.
  static const String tune = 'tune';

  /// Site for failures while publishing a tuning retraction.
  static const String undo = 'undo';
}
