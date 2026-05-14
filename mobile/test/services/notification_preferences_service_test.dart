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

  test(
    'syncs and clears matching dirty preferences after publish succeeds',
    () async {
      const pubkey =
          '1111111111111111111111111111111111111111111111111111111111111111';
      const prefs = NotificationPreferences(commentsEnabled: false);
      final store = _MemoryNotificationPreferencesStore();
      final published = <NotificationPreferences>[];
      final service = NotificationPreferencesService(
        store: store,
        currentPubkey: () => pubkey,
        publishPreferences: (publishPubkey, preferences) async {
          expect(publishPubkey, pubkey);
          published.add(preferences);
          return true;
        },
      );

      await store.markDirty(pubkey, prefs);
      final outcome = await service.syncDirtyPreferencesForPubkey(pubkey);

      expect(outcome, NotificationPreferencesSyncOutcome.publishedAndCleared);
      expect(published, [prefs]);
      expect(await store.loadDirty(pubkey), isNull);
    },
  );

  test('keeps dirty preferences after publish failure', () async {
    const pubkey =
        '1111111111111111111111111111111111111111111111111111111111111111';
    const prefs = NotificationPreferences(commentsEnabled: false);
    final store = _MemoryNotificationPreferencesStore();
    final service = NotificationPreferencesService(
      store: store,
      currentPubkey: () => pubkey,
      publishPreferences: (_, _) async => false,
    );

    await store.markDirty(pubkey, prefs);
    final outcome = await service.syncDirtyPreferencesForPubkey(pubkey);

    expect(outcome, NotificationPreferencesSyncOutcome.stillDirty);
    expect(await store.loadDirty(pubkey), prefs);
  });

  test('reports nothing to drain when no dirty preferences exist', () async {
    const pubkey =
        '1111111111111111111111111111111111111111111111111111111111111111';
    final store = _MemoryNotificationPreferencesStore();
    final service = NotificationPreferencesService(
      store: store,
      currentPubkey: () => pubkey,
      publishPreferences: (_, _) async => true,
    );

    final outcome = await service.syncDirtyPreferencesForPubkey(pubkey);

    expect(outcome, NotificationPreferencesSyncOutcome.nothingToDrain);
  });
}

class _MemoryNotificationPreferencesStore
    implements NotificationPreferencesStore {
  NotificationPreferences? preferences;
  final dirty = <String, NotificationPreferences>{};

  @override
  Future<NotificationPreferences> loadPreferences() async {
    return preferences ?? const NotificationPreferences();
  }

  @override
  Future<void> savePreferences(NotificationPreferences preferences) async {
    this.preferences = preferences;
  }

  @override
  Future<void> markDirty(
    String pubkey,
    NotificationPreferences preferences,
  ) async {
    dirty[pubkey] = preferences;
  }

  @override
  Future<NotificationPreferences?> loadDirty(String pubkey) async {
    return dirty[pubkey];
  }

  @override
  Future<void> clearDirty(String pubkey) async {
    dirty.remove(pubkey);
  }

  @override
  Future<void> clearDirtyIfMatches(
    String pubkey,
    NotificationPreferences preferences,
  ) async {
    if (dirty[pubkey] == preferences) {
      dirty.remove(pubkey);
    }
  }
}
