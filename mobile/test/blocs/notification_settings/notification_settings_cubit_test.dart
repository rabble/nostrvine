// ABOUTME: Unit tests for NotificationSettingsCubit — load, preference
// ABOUTME: persistence, and reset-to-defaults.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/notification_settings/notification_settings_cubit.dart';
import 'package:openvine/blocs/notification_settings/notification_settings_state.dart';
import 'package:openvine/models/notification_preferences.dart';
import 'package:openvine/services/notification_preferences_service.dart';

class _MockNotificationPreferencesService extends Mock
    implements NotificationPreferencesService {}

void main() {
  setUpAll(() {
    registerFallbackValue(const NotificationPreferences());
  });

  group(NotificationSettingsCubit, () {
    late _MockNotificationPreferencesService service;

    setUp(() {
      service = _MockNotificationPreferencesService();
      when(
        service.loadPreferences,
      ).thenAnswer((_) async => const NotificationPreferences());
      when(() => service.updatePreferences(any())).thenAnswer((_) async {});
    });

    NotificationSettingsCubit buildCubit() =>
        NotificationSettingsCubit(preferencesService: service);

    blocTest<NotificationSettingsCubit, NotificationSettingsState>(
      'load emits loading then ready with the loaded preferences',
      setUp: () {
        when(service.loadPreferences).thenAnswer(
          (_) async => const NotificationPreferences(likesEnabled: false),
        );
      },
      build: buildCubit,
      act: (cubit) => cubit.load(),
      expect: () => const [
        NotificationSettingsState(status: NotificationSettingsStatus.loading),
        NotificationSettingsState(
          status: NotificationSettingsStatus.ready,
          preferences: NotificationPreferences(likesEnabled: false),
        ),
      ],
    );

    blocTest<NotificationSettingsCubit, NotificationSettingsState>(
      'setPreferences emits the new preferences and persists them',
      build: buildCubit,
      act: (cubit) => cubit.setPreferences(
        const NotificationPreferences(commentsEnabled: false),
      ),
      expect: () => const [
        NotificationSettingsState(
          preferences: NotificationPreferences(commentsEnabled: false),
        ),
      ],
      verify: (_) {
        verify(
          () => service.updatePreferences(
            const NotificationPreferences(commentsEnabled: false),
          ),
        ).called(1);
      },
    );

    blocTest<NotificationSettingsCubit, NotificationSettingsState>(
      'resetToDefaults restores defaults and persists them',
      seed: () => const NotificationSettingsState(
        status: NotificationSettingsStatus.ready,
        preferences: NotificationPreferences(likesEnabled: false),
      ),
      build: buildCubit,
      act: (cubit) => cubit.resetToDefaults(),
      expect: () => const [
        NotificationSettingsState(status: NotificationSettingsStatus.ready),
      ],
      verify: (_) {
        verify(
          () => service.updatePreferences(const NotificationPreferences()),
        ).called(1);
      },
    );
  });
}
