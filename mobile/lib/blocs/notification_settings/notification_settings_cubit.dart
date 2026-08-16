// ABOUTME: Screen-scoped Cubit for the notification settings screen.
// ABOUTME: Owns the notification preferences, persisting changes via
// ABOUTME: NotificationPreferencesService, and runs the mark-all-as-read
// ABOUTME: action against NotificationRepository.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/notification_settings/notification_settings_state.dart';
import 'package:openvine/models/notification_preferences.dart';
import 'package:openvine/services/notification_preferences_service.dart';

/// Cubit backing `NotificationSettingsScreen`.
///
/// Holds the notification [NotificationSettingsState.preferences] and writes
/// mutations through [NotificationPreferencesService]. A null
/// [NotificationRepository] — the signed-out case — leaves the
/// mark-all-as-read action permanently
/// [MarkAllAsReadStatus.unavailable].
class NotificationSettingsCubit extends Cubit<NotificationSettingsState>
    with CloseGuardedEmit<NotificationSettingsState> {
  NotificationSettingsCubit({
    required NotificationPreferencesService preferencesService,
    NotificationRepository? notificationRepository,
  }) : _preferencesService = preferencesService,
       _notificationRepository = notificationRepository,
       super(
         NotificationSettingsState(
           markAllAsReadStatus: notificationRepository == null
               ? MarkAllAsReadStatus.unavailable
               : MarkAllAsReadStatus.idle,
         ),
       );

  final NotificationPreferencesService _preferencesService;
  final NotificationRepository? _notificationRepository;

  /// Loads the persisted preferences. `loadPreferences` is itself defensive
  /// (returns defaults on storage/decoding errors), so this does not throw.
  Future<void> load() async {
    emit(state.copyWith(status: NotificationSettingsStatus.loading));
    final preferences = await _preferencesService.loadPreferences();
    emitIfOpen(
      state.copyWith(
        status: NotificationSettingsStatus.ready,
        preferences: preferences,
      ),
    );
  }

  /// Marks every notification as read, ignoring taps that arrive while a
  /// previous call is still in flight.
  Future<void> markAllAsRead() async {
    final repository = _notificationRepository;
    if (repository == null || !state.canMarkAllAsRead) return;
    emit(
      state.copyWith(markAllAsReadStatus: MarkAllAsReadStatus.inProgress),
    );
    try {
      await repository.markAllAsRead();
      emitIfOpen(
        state.copyWith(markAllAsReadStatus: MarkAllAsReadStatus.success),
      );
    } catch (error, stackTrace) {
      addError(error, stackTrace);
      emitIfOpen(
        state.copyWith(markAllAsReadStatus: MarkAllAsReadStatus.failure),
      );
    }
  }

  /// Applies [preferences] optimistically, then persists them.
  Future<void> setPreferences(NotificationPreferences preferences) async {
    emit(state.copyWith(preferences: preferences));
    await _preferencesService.updatePreferences(preferences);
  }

  /// Resets preferences to their defaults and persists them.
  Future<void> resetToDefaults() async {
    const defaults = NotificationPreferences();
    emit(state.copyWith(preferences: defaults));
    await _preferencesService.updatePreferences(defaults);
  }
}
