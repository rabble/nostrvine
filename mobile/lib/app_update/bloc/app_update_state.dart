part of 'app_update_bloc.dart';

/// Status of the update check lifecycle.
enum AppUpdateStatus {
  /// Initial state, no check performed.
  initial,

  /// Currently checking for updates.
  checking,

  /// Check completed (may or may not have an update).
  resolved,

  /// Check failed.
  error,
}

/// State for [AppUpdateBloc].
class AppUpdateState extends Equatable {
  /// Creates an [AppUpdateState].
  const AppUpdateState({
    this.status = AppUpdateStatus.initial,
    this.urgency = UpdateUrgency.none,
    this.latestVersion,
    this.downloadUrl,
    this.releaseHighlights = const [],
    this.releaseNotesUrl,
  });

  /// The lifecycle status of the update check.
  final AppUpdateStatus status;

  /// How urgently the user should update.
  final UpdateUrgency urgency;

  /// The latest available version string.
  final String? latestVersion;

  /// The URL to open for the user to update.
  final String? downloadUrl;

  /// Short feature names from the release.
  final List<String> releaseHighlights;

  /// URL to the release notes page.
  final String? releaseNotesUrl;

  /// Creates a copy with the given fields replaced.
  AppUpdateState copyWith({
    AppUpdateStatus? status,
    UpdateUrgency? urgency,
    String? latestVersion,
    String? downloadUrl,
    List<String>? releaseHighlights,
    String? releaseNotesUrl,
  }) {
    return AppUpdateState(
      status: status ?? this.status,
      urgency: urgency ?? this.urgency,
      latestVersion: latestVersion ?? this.latestVersion,
      downloadUrl: downloadUrl ?? this.downloadUrl,
      releaseHighlights: releaseHighlights ?? this.releaseHighlights,
      releaseNotesUrl: releaseNotesUrl ?? this.releaseNotesUrl,
    );
  }

  @override
  List<Object?> get props => [
    status,
    urgency,
    latestVersion,
    downloadUrl,
    releaseHighlights,
    releaseNotesUrl,
  ];
}
