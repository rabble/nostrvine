// ABOUTME: State for NotificationSettingsCubit — the persisted notification
// ABOUTME: preferences plus the local-only push/sound/vibration UI toggles.

import 'package:equatable/equatable.dart';
import 'package:openvine/models/notification_preferences.dart';

/// Load lifecycle of the notification settings screen.
enum NotificationSettingsStatus { initial, loading, ready }

/// State for [NotificationSettingsCubit].
///
/// [preferences] is persisted via `NotificationPreferencesService`. The four
/// booleans are local-only UI toggles with no service backing (they mirror the
/// pre-migration `setState`-only fields).
class NotificationSettingsState extends Equatable {
  const NotificationSettingsState({
    this.status = NotificationSettingsStatus.initial,
    this.preferences = const NotificationPreferences(),
    this.systemEnabled = true,
    this.pushNotificationsEnabled = true,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
  });

  final NotificationSettingsStatus status;
  final NotificationPreferences preferences;
  final bool systemEnabled;
  final bool pushNotificationsEnabled;
  final bool soundEnabled;
  final bool vibrationEnabled;

  NotificationSettingsState copyWith({
    NotificationSettingsStatus? status,
    NotificationPreferences? preferences,
    bool? systemEnabled,
    bool? pushNotificationsEnabled,
    bool? soundEnabled,
    bool? vibrationEnabled,
  }) {
    return NotificationSettingsState(
      status: status ?? this.status,
      preferences: preferences ?? this.preferences,
      systemEnabled: systemEnabled ?? this.systemEnabled,
      pushNotificationsEnabled:
          pushNotificationsEnabled ?? this.pushNotificationsEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
    );
  }

  @override
  List<Object?> get props => [
    status,
    preferences,
    systemEnabled,
    pushNotificationsEnabled,
    soundEnabled,
    vibrationEnabled,
  ];
}
