/// User-facing copy for update nudges.
///
/// English only for v1. Structured for future l10n extraction.
abstract class UpdateCopy {
  /// Gentle banner text.
  static const gentle = 'A fresh update just dropped. Check it out →';

  /// Moderate dialog title.
  static const moderateTitle = "There's been an update since you last checked";

  /// Urgent dialog title.
  static const urgentTitle = "You're missing important fixes";

  /// Dismiss button text.
  static const notNow = 'Not now';

  /// Update button text.
  static const update = 'Update';

  /// Returns "New in {version}:" text.
  static String newIn(String version) => 'New in $version:';
}
