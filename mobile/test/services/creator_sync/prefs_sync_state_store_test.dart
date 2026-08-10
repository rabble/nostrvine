// ABOUTME: Tests the SharedPreferences-backed SyncStateStore adapter.
// ABOUTME: Covers round-tripping, isolation, and corrupted-data recovery.

import 'package:creator_sync/creator_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/creator_sync/prefs_sync_state_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<SharedPreferences> _prefs() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

void main() {
  group(PrefsSyncStateStore, () {
    group('readApplied', () {
      test('returns an empty map when nothing was ever written', () async {
        final store = PrefsSyncStateStore(
          await _prefs(),
          pubkeyHex: 'a' * 64,
        );

        expect(await store.readApplied(SyncItemKind.sound), isEmpty);
      });

      test('round-trips a state written by writeApplied', () async {
        final store = PrefsSyncStateStore(
          await _prefs(),
          pubkeyHex: 'a' * 64,
        );
        const state = SyncItemState(createdAt: 1700000000, bodyHash: 'hash1');

        await store.writeApplied(SyncItemKind.sound, {'sound-1': state});
        final applied = await store.readApplied(SyncItemKind.sound);

        expect(applied, equals({'sound-1': state}));
      });

      test('keeps kinds isolated under the same account', () async {
        final prefs = await _prefs();
        final store = PrefsSyncStateStore(prefs, pubkeyHex: 'a' * 64);
        const soundState = SyncItemState(createdAt: 1, bodyHash: 'sound');
        const clipState = SyncItemState(createdAt: 2, bodyHash: 'clip');

        await store.writeApplied(SyncItemKind.sound, {'x': soundState});
        await store.writeApplied(SyncItemKind.clip, {'x': clipState});

        expect(
          await store.readApplied(SyncItemKind.sound),
          equals({'x': soundState}),
        );
        expect(
          await store.readApplied(SyncItemKind.clip),
          equals({'x': clipState}),
        );
      });

      test('keeps accounts isolated under the same kind', () async {
        final prefs = await _prefs();
        final storeA = PrefsSyncStateStore(prefs, pubkeyHex: 'a' * 64);
        final storeB = PrefsSyncStateStore(prefs, pubkeyHex: 'b' * 64);
        const state = SyncItemState(createdAt: 1, bodyHash: 'only-a');

        await storeA.writeApplied(SyncItemKind.sound, {'x': state});

        expect(
          await storeA.readApplied(SyncItemKind.sound),
          equals({'x': state}),
        );
        expect(await storeB.readApplied(SyncItemKind.sound), isEmpty);
      });

      test(
        'recovers to an empty map when the stored JSON is malformed',
        () async {
          final prefs = await _prefs();
          await prefs.setString(
            'creator_sync_applied_sound_${'a' * 64}',
            'not valid json{{{',
          );
          final store = PrefsSyncStateStore(prefs, pubkeyHex: 'a' * 64);

          expect(await store.readApplied(SyncItemKind.sound), isEmpty);
        },
      );

      test(
        'recovers to an empty map when the root JSON is not an object',
        () async {
          final prefs = await _prefs();
          await prefs.setString(
            'creator_sync_applied_sound_${'a' * 64}',
            '["not", "an", "object"]',
          );
          final store = PrefsSyncStateStore(prefs, pubkeyHex: 'a' * 64);

          expect(await store.readApplied(SyncItemKind.sound), isEmpty);
        },
      );

      test(
        'drops only the corrupted entry, keeping every valid sibling',
        () async {
          final prefs = await _prefs();
          await prefs.setString(
            'creator_sync_applied_sound_${'a' * 64}',
            '{"good":{"createdAt":5,"bodyHash":"h"},'
                '"bad":{"createdAt":"not-an-int","bodyHash":"h"}}',
          );
          final store = PrefsSyncStateStore(prefs, pubkeyHex: 'a' * 64);

          final applied = await store.readApplied(SyncItemKind.sound);

          expect(
            applied,
            equals({'good': const SyncItemState(createdAt: 5, bodyHash: 'h')}),
          );
        },
      );
    });

    group('writeApplied', () {
      test('replaces the previously stored map entirely', () async {
        final store = PrefsSyncStateStore(
          await _prefs(),
          pubkeyHex: 'a' * 64,
        );
        const first = SyncItemState(createdAt: 1, bodyHash: 'first');
        const second = SyncItemState(createdAt: 2, bodyHash: 'second');

        await store.writeApplied(SyncItemKind.sound, {'x': first});
        await store.writeApplied(SyncItemKind.sound, {'y': second});

        expect(
          await store.readApplied(SyncItemKind.sound),
          equals({'y': second}),
        );
      });
    });
  });
}
