// ABOUTME: Tests persistence behavior for push notification preferences.
// ABOUTME: Verifies dirty retry state survives notification cache cleanup.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:openvine/models/notification_preferences.dart';
import 'package:openvine/services/notification_preferences_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory testDir;

  setUp(() async {
    testDir = await Directory.systemTemp.createTemp(
      'notification_preferences_service_test_',
    );
    Hive.init(testDir.path);
  });

  tearDown(() async {
    try {
      await Hive.close();
    } on PathNotFoundException catch (_) {
      // Hive may already have removed the lock file during async shutdown.
    }
    try {
      await testDir.delete(recursive: true);
    } on PathNotFoundException catch (_) {
      // Hive may already have removed the lock file during async shutdown.
    }
  });

  test('dirty preferences survive notification box cleanup', () async {
    const pubkey =
        '1111111111111111111111111111111111111111111111111111111111111111';
    const prefs = NotificationPreferences(commentsEnabled: false);
    const store = HiveNotificationPreferencesStore(
      openBox: HiveNotificationPreferencesStore.openBox,
    );

    await store.markDirty(pubkey, prefs);
    final notificationsBox = await Hive.openBox<dynamic>('notifications');
    await notificationsBox.put('cached_notification', {
      'id': 'cached_notification',
    });

    await notificationsBox.clear();

    expect(await store.loadDirty(pubkey), prefs);
  });
}
