// ABOUTME: Tests persistence behavior for push notification preferences.
// ABOUTME: Verifies dirty retry state survives notification cache cleanup.

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/notification_preferences.dart';
import 'package:openvine/services/notification_preferences_service.dart';

class _MockHiveBox extends Mock implements Box<dynamic> {}

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  test('dirty preferences survive notification box cleanup', () async {
    const pubkey =
        '1111111111111111111111111111111111111111111111111111111111111111';
    const prefs = NotificationPreferences(commentsEnabled: false);
    final notificationBox = _MockHiveBox();
    final dirtyBox = _MockHiveBox();
    final notificationStorage = <dynamic, dynamic>{};
    final dirtyStorage = <dynamic, dynamic>{};
    final store = HiveNotificationPreferencesStore(
      openBox: () async => notificationBox,
      openDirtyBox: () async => dirtyBox,
    );
    when(() => notificationBox.put(any(), any())).thenAnswer((invocation) {
      notificationStorage[invocation.positionalArguments[0]] =
          invocation.positionalArguments[1];
      return Future<void>.value();
    });
    when(() => dirtyBox.put(any(), any())).thenAnswer((invocation) {
      dirtyStorage[invocation.positionalArguments[0]] =
          invocation.positionalArguments[1];
      return Future<void>.value();
    });
    when(() => dirtyBox.get(any())).thenAnswer(
      (invocation) => dirtyStorage[invocation.positionalArguments[0]],
    );

    await store.markDirty(pubkey, prefs);
    await notificationBox.put('cached_notification', {
      'id': 'cached_notification',
    });

    notificationStorage.clear();

    expect(await store.loadDirty(pubkey), prefs);
    expect(notificationStorage, isEmpty);
  });
}
