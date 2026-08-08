// ABOUTME: Tests the LocalSoundStore adapter over SavedSoundsService.
// ABOUTME: Verifies id keying and SavedSound json round-tripping.

import 'package:creator_sync/creator_sync.dart';
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

      // Full-map equality, not just one field: the reconciler compares
      // syncBodyHash(readAll()[id]) against the body it just wrote, so any
      // field this adapter drops or alters would make every later pass
      // see a spurious local edit and republish.
      expect((await store.readAll())[sound.id], equals(sound.toJson()));
    });

    test(
      'upsert rejects a body whose own id disagrees with the id argument',
      () async {
        final sound = buildSavedSound(id: 'h' * 64);

        expect(
          () => store.upsert('i' * 64, sound.toJson()),
          throwsA(isA<AssertionError>()),
        );
      },
    );

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

    group('unreadable library', () {
      /// Rebuilds the service over [raw] stored at the account's key.
      Future<SavedSoundsLocalStore> storeOver(String raw) async {
        SharedPreferences.setMockInitialValues({
          SavedSoundsService.accountStorageKey(pubkey): raw,
        });
        return SavedSoundsLocalStore(
          SavedSoundsService(
            await SharedPreferences.getInstance(),
            pubkeyHex: pubkey,
          ),
        );
      }

      // loadSavedSounds() answers [] for each of these exactly as it does
      // for a genuinely empty library. Reporting that to the reconciler as
      // an empty map makes every synced sound look user-deleted, and the
      // delete-retry pass then tombstones the whole library on every
      // device the account is signed in to.
      test('throws on a payload written by a newer build', () async {
        final store = await storeOver(
          '{"schemaVersion":9999,"sounds":[{"id":"${'a' * 64}"}]}',
        );

        await expectLater(
          store.readAll(),
          throwsA(isA<LocalStoreUnreadableException>()),
        );
      });

      test('throws on a corrupt payload', () async {
        final store = await storeOver('not json at all');

        await expectLater(
          store.readAll(),
          throwsA(isA<LocalStoreUnreadableException>()),
        );
      });

      test('throws on a versioned payload with no sound list', () async {
        final store = await storeOver('{"schemaVersion":1}');

        await expectLater(
          store.readAll(),
          throwsA(isA<LocalStoreUnreadableException>()),
        );
      });

      test(
        'reads an empty versioned library as empty, not unreadable',
        () async {
          final store = await storeOver('{"schemaVersion":1,"sounds":[]}');

          expect(await store.readAll(), isEmpty);
        },
      );

      test('reads an empty legacy list as empty, not unreadable', () async {
        final store = await storeOver('[]');

        expect(await store.readAll(), isEmpty);
      });
    });
  });
}
