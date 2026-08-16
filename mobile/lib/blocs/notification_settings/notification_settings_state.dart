// ABOUTME: State for NotificationSettingsCubit — the persisted notification
// ABOUTME: preferences and the screen's load lifecycle.

import 'package:equatable/equatable.dart';
import 'package:openvine/models/notification_preferences.dart';

/// Load lifecycle of the notification settings screen.
enum NotificationSettingsStatus { initial, loading, ready }

/// Lifecycle of the mark-all-as-read action.
///
/// [unavailable] means there is no notification repository to call — the
/// signed-out case — and is fixed for the cubit's lifetime.
enum MarkAllAsReadStatus { unavailable, idle, inProgress, success, failure }

/// State for [NotificationSettingsCubit].
///
/// [preferences] is persisted via `NotificationPreferencesService`.
class NotificationSettingsState extends Equatable {
  const NotificationSettingsState({
    this.status = NotificationSettingsStatus.initial,
    this.preferences = const NotificationPreferences(),
    this.markAllAsReadStatus = MarkAllAsReadStatus.unavailable,
  });

  final NotificationSettingsStatus status;
  final NotificationPreferences preferences;
  final MarkAllAsReadStatus markAllAsReadStatus;

  /// Whether the mark-all-as-read action should accept a tap right now.
  bool get canMarkAllAsRead =>
      markAllAsReadStatus != MarkAllAsReadStatus.unavailable &&
      markAllAsReadStatus != MarkAllAsReadStatus.inProgress;

  NotificationSettingsState copyWith({
    NotificationSettingsStatus? status,
    NotificationPreferences? preferences,
    MarkAllAsReadStatus? markAllAsReadStatus,
  }) {
    return NotificationSettingsState(
      status: status ?? this.status,
      preferences: preferences ?? this.preferences,
      markAllAsReadStatus: markAllAsReadStatus ?? this.markAllAsReadStatus,
    );
  }

  @override
  List<Object?> get props => [status, preferences, markAllAsReadStatus];
}
