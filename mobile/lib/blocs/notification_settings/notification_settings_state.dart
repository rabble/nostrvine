// ABOUTME: State for NotificationSettingsCubit — the persisted notification
// ABOUTME: preferences and the screen's load lifecycle.

import 'package:equatable/equatable.dart';
import 'package:openvine/models/notification_preferences.dart';

/// Load lifecycle of the notification settings screen.
enum NotificationSettingsStatus { initial, loading, ready }

/// State for [NotificationSettingsCubit].
///
/// [preferences] is persisted via `NotificationPreferencesService`.
class NotificationSettingsState extends Equatable {
  const NotificationSettingsState({
    this.status = NotificationSettingsStatus.initial,
    this.preferences = const NotificationPreferences(),
  });

  final NotificationSettingsStatus status;
  final NotificationPreferences preferences;

  NotificationSettingsState copyWith({
    NotificationSettingsStatus? status,
    NotificationPreferences? preferences,
  }) {
    return NotificationSettingsState(
      status: status ?? this.status,
      preferences: preferences ?? this.preferences,
    );
  }

  @override
  List<Object?> get props => [status, preferences];
}
