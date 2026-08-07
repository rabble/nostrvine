// ABOUTME: Tests the LocalSoundStore adapter over SavedSoundsService.
// ABOUTME: Verifies id keying and SavedSound json round-tripping.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/creator_sync/saved_sounds_local_store.dart';
import 'package:openvine/services/saved_sounds_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/saved_sound_fixtures.dart';

void main() {
  group(SavedSoundsLocalStore, () {
    const pubkey =
        'a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718293a4b5c6d7e8f90';

    late SavedSoundsService service;
    late SavedSoundsLocalStore store;

    setUp(() async {
      // The legacy-migration claim is a process-wide static; reset it so
      // the shared merged-isolate test run can't leak a prior test's claim
      // into this one.
      SavedSoundsService.resetLegacyMigrationClaimForTesting();
      SharedPreferences.setMockInitialValues({});
      service = SavedSoundsService(
        await SharedPreferences.getInstance(),
        pubkeyHex: pubkey,
      );
      store = SavedSoundsLocalStore(service);
    });

    test('readAll is empty for a fresh account', () async {
      expect(await store.readAll(), isEmpty);
    });

    test('readAll keys sounds by their full untruncated id', () async {
      final sound = buildSavedSound(id: 'c' * 64);
      await service.saveSavedSound(sound);

      final all = await store.readAll();

      expect(all.keys, equals({'c' * 64}));
    });

    test('upsert then readAll round-trips the body', () async {
      final sound = buildSavedSound(id: 'd' * 64, label: 'intro');

      await store.upsert(sound.id, sound.toJson());

      expect(
        (await store.readAll())[sound.id]!['personalLabel'],
        equals('intro'),
      );
    });

    test('upsert replaces an existing sound', () async {
      final original = buildSavedSound(id: 'e' * 64, label: 'first');
      await store.upsert(original.id, original.toJson());
      final updated = buildSavedSound(id: 'e' * 64, label: 'second');

      await store.upsert(updated.id, updated.toJson());

      final all = await store.readAll();
      expect(all, hasLength(1));
      expect(all[updated.id]!['personalLabel'], equals('second'));
    });

    test('remove deletes the sound', () async {
      final sound = buildSavedSound(id: 'f' * 64);
      await store.upsert(sound.id, sound.toJson());

      await store.remove(sound.id);

      expect(await store.readAll(), isEmpty);
    });

    test('remove is a no-op for an unknown id', () async {
      await store.remove('0' * 64);

      expect(await store.readAll(), isEmpty);
    });
  });
}
