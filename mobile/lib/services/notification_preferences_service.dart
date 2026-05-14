// ABOUTME: Persists push notification preferences and syncs them to the push service
// ABOUTME: Keeps storage and remote update logic out of the settings UI

import 'dart:convert';

import 'package:hive_ce/hive.dart';
import 'package:openvine/models/notification_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

abstract interface class NotificationPreferencesStore {
  Future<NotificationPreferences> loadPreferences();
  Future<void> savePreferences(NotificationPreferences preferences);
  Future<void> markDirty(
    String pubkey,
    NotificationPreferences preferences,
  );
  Future<NotificationPreferences?> loadDirty(String pubkey);
  Future<void> clearDirty(String pubkey);
  Future<void> clearDirtyIfMatches(
    String pubkey,
    NotificationPreferences preferences,
  );
}

class HiveNotificationPreferencesStore implements NotificationPreferencesStore {
  const HiveNotificationPreferencesStore({
    required Future<Box<dynamic>> Function() openBox,
    Future<Box<dynamic>> Function()? openDirtyBox,
  }) : _openBox = openBox,
       _openDirtyBox =
           openDirtyBox ?? HiveNotificationPreferencesStore.openDirtyBox;

  final Future<Box<dynamic>> Function() _openBox;
  final Future<Box<dynamic>> Function() _openDirtyBox;

  static const _boxName = 'notifications';
  static const _dirtyBoxName = 'push_notification_preferences_dirty';
  static const _prefsKey = 'push_preferences';
  static const _dirtyPrefix = 'push_preferences_dirty_';

  @override
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

  @override
  Future<void> savePreferences(NotificationPreferences preferences) async {
    try {
      final box = await _openBox();
      await box.put(_prefsKey, jsonEncode(preferences.toJson()));
    } on Object catch (error) {
      Log.warning(
        'Failed to persist push notification preferences: $error',
        name: 'NotificationPreferencesService',
        category: LogCategory.system,
      );
    }
  }

  @override
  Future<void> markDirty(
    String pubkey,
    NotificationPreferences preferences,
  ) async {
    try {
      final box = await _openDirtyBox();
      await box.put(_dirtyKey(pubkey), jsonEncode(preferences.toJson()));
    } on Object catch (error) {
      Log.warning(
        'Failed to mark push notification preferences dirty: $error',
        name: 'NotificationPreferencesService',
        category: LogCategory.system,
      );
    }
  }

  @override
  Future<NotificationPreferences?> loadDirty(String pubkey) async {
    try {
      final box = await _openDirtyBox();
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

  @override
  Future<void> clearDirty(String pubkey) async {
    try {
      final box = await _openDirtyBox();
      await box.delete(_dirtyKey(pubkey));
    } on Object catch (error) {
      Log.warning(
        'Failed to clear dirty push notification preferences: $error',
        name: 'NotificationPreferencesService',
        category: LogCategory.system,
      );
    }
  }

  @override
  Future<void> clearDirtyIfMatches(
    String pubkey,
    NotificationPreferences preferences,
  ) async {
    try {
      final box = await _openDirtyBox();
      final stored = box.get(_dirtyKey(pubkey)) as String?;
      if (stored == null) return;

      final json = jsonDecode(stored) as Map<String, dynamic>;
      final currentPreferences = NotificationPreferences.fromJson(json);
      if (currentPreferences == preferences) {
        await box.delete(_dirtyKey(pubkey));
      }
    } on Object catch (error) {
      Log.warning(
        'Failed to conditionally clear dirty push notification preferences: $error',
        name: 'NotificationPreferencesService',
        category: LogCategory.system,
      );
    }
  }

  static Future<Box<dynamic>> openBox() => Hive.openBox<dynamic>(_boxName);
  static Future<Box<dynamic>> openDirtyBox() =>
      Hive.openBox<dynamic>(_dirtyBoxName);

  static String _dirtyKey(String pubkey) => '$_dirtyPrefix$pubkey';
}

enum NotificationPreferencesSyncOutcome {
  nothingToDrain,
  publishedAndCleared,
  stillDirty,
}

class NotificationPreferencesService {
  NotificationPreferencesService({
    required NotificationPreferencesStore store,
    required String? Function() currentPubkey,
    required Future<bool> Function(String pubkey, NotificationPreferences prefs)
    publishPreferences,
    void Function(String pubkey)? onStillDirty,
  }) : _store = store,
       _currentPubkey = currentPubkey,
       _publishPreferences = publishPreferences,
       _onStillDirty = onStillDirty;

  final NotificationPreferencesStore _store;
  final String? Function() _currentPubkey;
  final Future<bool> Function(String pubkey, NotificationPreferences prefs)
  _publishPreferences;
  final void Function(String pubkey)? _onStillDirty;

  Future<NotificationPreferences> loadPreferences() async {
    return _store.loadPreferences();
  }

  Future<void> updatePreferences(NotificationPreferences prefs) async {
    await _store.savePreferences(prefs);

    final pubkey = _currentPubkey();
    if (pubkey == null) return;

    await _store.markDirty(pubkey, prefs);
    final outcome = await _publishAndClearDirtyPreferences(pubkey, prefs);
    if (outcome == NotificationPreferencesSyncOutcome.stillDirty) {
      _onStillDirty?.call(pubkey);
    }
  }

  Future<NotificationPreferencesSyncOutcome> syncDirtyPreferencesForPubkey(
    String pubkey,
  ) async {
    final prefs = await _store.loadDirty(pubkey);
    if (prefs == null) return NotificationPreferencesSyncOutcome.nothingToDrain;

    return _publishAndClearDirtyPreferences(pubkey, prefs);
  }

  Future<NotificationPreferencesSyncOutcome> _publishAndClearDirtyPreferences(
    String pubkey,
    NotificationPreferences preferences,
  ) async {
    final published = await _publishPreferences(pubkey, preferences);
    if (!published) {
      return NotificationPreferencesSyncOutcome.stillDirty;
    }

    await _store.clearDirtyIfMatches(pubkey, preferences);
    final dirty = await _store.loadDirty(pubkey);
    return dirty == null
        ? NotificationPreferencesSyncOutcome.publishedAndCleared
        : NotificationPreferencesSyncOutcome.stillDirty;
  }
}
