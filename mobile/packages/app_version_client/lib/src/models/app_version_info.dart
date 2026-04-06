import 'package:equatable/equatable.dart';

/// Version information parsed from the GitHub Releases API.
class AppVersionInfo extends Equatable {
  /// Creates an [AppVersionInfo].
  const AppVersionInfo({
    required this.latestVersion,
    required this.publishedAt,
    required this.releaseNotesUrl,
    required this.releaseHighlights,
    this.minimumVersion,
  });

  /// The latest release version tag (e.g. "1.0.8").
  final String latestVersion;

  /// When the latest release was published.
  final DateTime publishedAt;

  /// URL to the release notes page on GitHub.
  final String releaseNotesUrl;

  /// Short feature names extracted from the release body.
  final List<String> releaseHighlights;

  /// Optional minimum supported version, parsed from
  /// `<!-- minimum_version: X.Y.Z -->` in the release body.
  final String? minimumVersion;

  @override
  List<Object?> get props => [
    latestVersion,
    publishedAt,
    releaseNotesUrl,
    releaseHighlights,
    minimumVersion,
  ];
}
