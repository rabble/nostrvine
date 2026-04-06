import 'package:equatable/equatable.dart';

/// How urgently we should nudge the user to update.
enum UpdateUrgency {
  /// App is up to date, or check hasn't run yet.
  none,

  /// New version exists, released < 2 weeks ago.
  gentle,

  /// New version exists, released >= 2 weeks ago.
  moderate,

  /// User's version is below the minimum supported version.
  urgent,
}

/// Result of comparing the current app version against the latest release.
class UpdateCheckResult extends Equatable {
  /// Creates an [UpdateCheckResult].
  const UpdateCheckResult({
    required this.urgency,
    required this.downloadUrl,
    this.latestVersion,
    this.releaseHighlights = const [],
    this.releaseNotesUrl,
  });

  /// No update needed.
  const UpdateCheckResult.none()
    : this(urgency: UpdateUrgency.none, downloadUrl: '');

  /// The urgency level of the update.
  final UpdateUrgency urgency;

  /// The URL to open for the user to update.
  final String downloadUrl;

  /// The latest available version string.
  final String? latestVersion;

  /// Short feature names from the release body.
  final List<String> releaseHighlights;

  /// URL to the release notes page.
  final String? releaseNotesUrl;

  @override
  List<Object?> get props => [
    urgency,
    downloadUrl,
    latestVersion,
    releaseHighlights,
    releaseNotesUrl,
  ];
}
