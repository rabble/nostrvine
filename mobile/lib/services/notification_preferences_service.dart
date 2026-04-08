// ABOUTME: Persists push notification preferences and syncs them to the push service
// ABOUTME: Keeps storage and remote update logic out of the settings UI

import 'dart:convert';

import 'package:hive_ce/hive.dart';
import 'package:openvine/models/notification_preferences.dart';
import 'package:openvine/utils/unified_logger.dart';

class NotificationPreferencesService {
  NotificationPreferencesService({
    required Future<Box<dynamic>> Function() openBox,
    required Future<void> Function(NotificationPreferences prefs)
    publishPreferences,
  }) : _openBox = openBox,
       _publishPreferences = publishPreferences;

  final Future<Box<dynamic>> Function() _openBox;
  final Future<void> Function(NotificationPreferences prefs)
  _publishPreferences;

  static const _boxName = 'notifications';
  static const _prefsKey = 'push_preferences';

  Future<NotificationPreferences> loadPreferences() async {
    try {
      final box = await _openBox();
      final stored = box.get(_prefsKey) as String?;
      if (stored == null) {
        return const NotificationPreferences();
      }

      final json = jsonDecode(stored) as Map<String, dynamic>;
      return NotificationPreferences.fromJson(json);
    } on FormatException catch (error) {
      Log.warning(
        'Failed to decode push notification preferences: $error',
        name: 'NotificationPreferencesService',
        category: LogCategory.system,
      );
      return const NotificationPreferences();
    } on Object catch (error) {
      Log.warning(
        'Failed to load push notification preferences from Hive: $error',
        name: 'NotificationPreferencesService',
        category: LogCategory.system,
      );
      return const NotificationPreferences();
    }
  }

  Future<void> updatePreferences(NotificationPreferences prefs) async {
    try {
      final box = await _openBox();
      await box.put(_prefsKey, jsonEncode(prefs.toJson()));
    } on Object catch (error) {
      Log.warning(
        'Failed to persist push notification preferences: $error',
        name: 'NotificationPreferencesService',
        category: LogCategory.system,
      );
    }

    await _publishPreferences(prefs);
  }

  static Future<Box<dynamic>> openBox() => Hive.openBox<dynamic>(_boxName);
}
