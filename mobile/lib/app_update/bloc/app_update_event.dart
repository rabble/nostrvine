part of 'app_update_bloc.dart';

/// Events for [AppUpdateBloc].
sealed class AppUpdateEvent {
  const AppUpdateEvent();
}

/// Triggers a version check against the GitHub Releases API.
final class AppUpdateCheckRequested extends AppUpdateEvent {
  /// Creates an [AppUpdateCheckRequested].
  const AppUpdateCheckRequested();
}

/// User dismissed the update nudge.
final class AppUpdateDismissed extends AppUpdateEvent {
  /// Creates an [AppUpdateDismissed].
  const AppUpdateDismissed();
}
