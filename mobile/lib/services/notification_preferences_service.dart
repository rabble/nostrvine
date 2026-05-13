// ABOUTME: Persists push notification preferences and syncs them to the push service
// ABOUTME: Keeps storage and remote update logic out of the settings UI

import 'dart:convert';

import 'package:hive_ce/hive.dart';
import 'package:openvine/models/notification_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

class NotificationPreferencesService {
  NotificationPreferencesService({
    required Future<Box<dynamic>> Function() openBox,
    required String? Function() currentPubkey,
    required Future<bool> Function(String pubkey, NotificationPreferences prefs)
    publishPreferences,
  }) : _openBox = openBox,
       _currentPubkey = currentPubkey,
       _publishPreferences = publishPreferences;

  final Future<Box<dynamic>> Function() _openBox;
  final String? Function() _currentPubkey;
  final Future<bool> Function(String pubkey, NotificationPreferences prefs)
  _publishPreferences;

  static const _boxName = 'notifications';
  static const _prefsKey = 'push_preferences';
  static const _dirtyPrefix = 'push_preferences_dirty_';

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

    final pubkey = _currentPubkey();
    if (pubkey == null) return;

    await _markDirty(pubkey, prefs);
    final published = await _publishPreferences(pubkey, prefs);
    if (published) {
      await _clearDirty(pubkey);
    }
  }

  Future<void> syncPendingPreferencesForPubkey(String pubkey) async {
    final prefs = await _loadDirty(pubkey);
    if (prefs == null) return;

    final published = await _publishPreferences(pubkey, prefs);
    if (published) {
      await _clearDirty(pubkey);
    }
  }

  Future<void> _markDirty(String pubkey, NotificationPreferences prefs) async {
    try {
      final box = await _openBox();
      await box.put(_dirtyKey(pubkey), jsonEncode(prefs.toJson()));
    } on Object catch (error) {
      Log.warning(
        'Failed to mark push notification preferences dirty: $error',
        name: 'NotificationPreferencesService',
        category: LogCategory.system,
      );
    }
  }

  Future<NotificationPreferences?> _loadDirty(String pubkey) async {
    try {
      final box = await _openBox();
      final stored = box.get(_dirtyKey(pubkey)) as String?;
      if (stored == null) return null;

      final json = jsonDecode(stored) as Map<String, dynamic>;
      return NotificationPreferences.fromJson(json);
    } on Object catch (error) {
      Log.warning(
        'Failed to load dirty push notification preferences: $error',
        name: 'NotificationPreferencesService',
        category: LogCategory.system,
      );
      return null;
    }
  }

  Future<void> _clearDirty(String pubkey) async {
    try {
      final box = await _openBox();
      await box.delete(_dirtyKey(pubkey));
    } on Object catch (error) {
      Log.warning(
        'Failed to clear dirty push notification preferences: $error',
        name: 'NotificationPreferencesService',
        category: LogCategory.system,
      );
    }
  }

  static String _dirtyKey(String pubkey) => '$_dirtyPrefix$pubkey';

  static Future<Box<dynamic>> openBox() => Hive.openBox<dynamic>(_boxName);
}
