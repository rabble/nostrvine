// ABOUTME: Screen-scoped Cubit for the notification settings screen.
// ABOUTME: Owns the notification preferences, persisting changes via
// ABOUTME: NotificationPreferencesService.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/notification_settings/notification_settings_state.dart';
import 'package:openvine/models/notification_preferences.dart';
import 'package:openvine/services/notification_preferences_service.dart';

/// Cubit backing `NotificationSettingsScreen`.
///
/// Holds the notification [NotificationSettingsState.preferences] and writes
/// mutations through [NotificationPreferencesService].
class NotificationSettingsCubit extends Cubit<NotificationSettingsState> {
  NotificationSettingsCubit({
    required NotificationPreferencesService preferencesService,
  }) : _preferencesService = preferencesService,
       super(const NotificationSettingsState());

  final NotificationPreferencesService _preferencesService;

  /// Loads the persisted preferences. `loadPreferences` is itself defensive
  /// (returns defaults on storage/decoding errors), so this does not throw.
  Future<void> load() async {
    emit(state.copyWith(status: NotificationSettingsStatus.loading));
    final preferences = await _preferencesService.loadPreferences();
    emit(
      state.copyWith(
        status: NotificationSettingsStatus.ready,
        preferences: preferences,
      ),
    );
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
