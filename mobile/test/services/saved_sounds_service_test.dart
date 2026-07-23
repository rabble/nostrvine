// ABOUTME: Tests for the persisted reusable sounds library service.
// ABOUTME: Covers saving, dedupe, ordering, and corrupt storage fallback.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/services/saved_sounds_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockSharedPreferences extends Mock implements SharedPreferences {}

AudioEvent _sound({
  required String id,
  String? title,
  int createdAt = 1700000000,
  String? anchorClipId,
}) {
  return AudioEvent(
    id: id,
    pubkey:
        'test_pubkey_0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
    createdAt: createdAt,
    title: title ?? 'Test Sound $id',
    duration: 6,
    url: 'https://example.com/audio/$id.m4a',
    mimeType: 'audio/mp4',
    source: 'Original Sound',
    sourceVideoReference:
        '34236:test_pubkey_0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef:$id',
    anchorClipId: anchorClipId,
  );
}

void main() {
  group(SavedSoundsService, () {
    late SharedPreferences sharedPreferences;

    setUp(() async {
      // The migration claim is a process-wide static; reset it so the shared
      // test isolate can't leak a prior test's claim into this one.
      SavedSoundsService.resetLegacyMigrationClaimForTesting();
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
    });

    test('saves and reloads a reusable sound', () async {
      final service = SavedSoundsService(sharedPreferences);
      final sound = _sound(id: 'sound1', title: 'Original sound - rabble');

      final result = await service.saveSound(sound);

      expect(result, SavedSoundSaveResult.saved);
      expect(service.loadSounds(), [sound]);
    });

    test('clears local editor anchors before persisting sounds', () async {
      final service = SavedSoundsService(sharedPreferences);
      final sound = _sound(id: 'sound1', anchorClipId: 'clip-1');

      final result = await service.saveSound(sound);

      expect(result, SavedSoundSaveResult.saved);
      final savedSound = service.loadSounds().single;
      expect(savedSound.id, sound.id);
      expect(savedSound.anchorClipId, isNull);
    });

    test(
      'returns alreadySaved and does not duplicate existing sound',
      () async {
        final service = SavedSoundsService(sharedPreferences);
        final sound = _sound(id: 'sound1');

        await service.saveSound(sound);
        final result = await service.saveSound(sound);

        expect(result, SavedSoundSaveResult.alreadySaved);
        expect(service.loadSounds(), [sound]);
      },
    );

    test('keeps newest saved sound first', () async {
      final service = SavedSoundsService(sharedPreferences);
      final olderSound = _sound(id: 'sound1', title: 'Older Sound');
      final newerSound = _sound(id: 'sound2', title: 'Newer Sound');

      await service.saveSound(olderSound);
      await service.saveSound(newerSound);

      expect(service.loadSounds().map((sound) => sound.id), [
        'sound2',
        'sound1',
      ]);
    });

    test('dedupes by full sound id without truncation', () async {
      final service = SavedSoundsService(sharedPreferences);
      final firstSound = _sound(
        id: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      );
      final secondSound = _sound(
        id: '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdee',
      );

      await service.saveSound(firstSound);
      await service.saveSound(secondSound);

      expect(service.loadSounds().map((sound) => sound.id), [
        secondSound.id,
        firstSound.id,
      ]);
    });

    test('returns empty list when persisted JSON is corrupt', () {
      final service = SavedSoundsService(sharedPreferences);
      sharedPreferences.setString(service.storageKey, 'not json');

      expect(service.loadSounds(), isEmpty);
    });

    test('skips invalid persisted entries without dropping valid sounds', () {
      final service = SavedSoundsService(sharedPreferences);
      final validSound = _sound(id: 'sound1', title: 'Valid Sound');
      sharedPreferences.setString(
        service.storageKey,
        jsonEncode([
          validSound.toJson(),
          {'id': 123},
        ]),
      );

      expect(service.loadSounds(), [validSound]);
    });

    group('per-account isolation', () {
      const pubkeyA =
          'a123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      const pubkeyB =
          'b123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

      test('a sound saved under one account is invisible to another', () async {
        await SavedSoundsService(
          sharedPreferences,
          pubkeyHex: pubkeyA,
        ).saveSound(_sound(id: 'sound1'));

        final accountB = SavedSoundsService(
          sharedPreferences,
          pubkeyHex: pubkeyB,
        );
        expect(accountB.loadSounds(), isEmpty);

        final accountA = SavedSoundsService(
          sharedPreferences,
          pubkeyHex: pubkeyA,
        );
        expect(accountA.loadSounds().map((sound) => sound.id), ['sound1']);
      });

      test('the signed-out bucket is separate from any account', () async {
        await SavedSoundsService(
          sharedPreferences,
        ).saveSound(_sound(id: 'sound1'));

        final account = SavedSoundsService(
          sharedPreferences,
          pubkeyHex: pubkeyA,
        );
        expect(account.loadSounds(), isEmpty);
      });

      test(
        'migrates the legacy device-wide list into the first account',
        () async {
          sharedPreferences.setString(
            'saved_reusable_sounds',
            jsonEncode([_sound(id: 'legacy').toJson()]),
          );

          final accountA = SavedSoundsService(
            sharedPreferences,
            pubkeyHex: pubkeyA,
          );
          expect(accountA.loadSounds().map((sound) => sound.id), ['legacy']);

          // The legacy key is retired only after the account bucket is durably
          // written, so let the ordered migration finish first.
          await Future<void>.delayed(Duration.zero);
          expect(sharedPreferences.getString('saved_reusable_sounds'), isNull);
          expect(sharedPreferences.getString(accountA.storageKey), isNotNull);
        },
      );

      test('drops legacy video_* original sounds during migration', () {
        // A pre-fix save of another creator's original sound (reuse consent
        // unknown) must not become reusable after the upgrade.
        sharedPreferences.setString(
          'saved_reusable_sounds',
          jsonEncode([
            _sound(id: 'shared').toJson(),
            _sound(id: 'video_original').toJson(),
          ]),
        );

        final accountA = SavedSoundsService(
          sharedPreferences,
          pubkeyHex: pubkeyA,
        );
        expect(accountA.loadSounds().map((sound) => sound.id), ['shared']);
      });

      test(
        'a second account does not inherit the migrated legacy list',
        () async {
          sharedPreferences.setString(
            'saved_reusable_sounds',
            jsonEncode([_sound(id: 'legacy').toJson()]),
          );

          SavedSoundsService(
            sharedPreferences,
            pubkeyHex: pubkeyA,
          ).loadSounds();
          // Let the first account's migration retire the legacy key.
          await Future<void>.delayed(Duration.zero);

          final accountB = SavedSoundsService(
            sharedPreferences,
            pubkeyHex: pubkeyB,
          );
          expect(accountB.loadSounds(), isEmpty);
        },
      );

      test('keeps the legacy key when the migration write fails', () async {
        final mockPrefs = _MockSharedPreferences();
        const legacyKey = 'saved_reusable_sounds';
        final service = SavedSoundsService(mockPrefs, pubkeyHex: pubkeyA);
        final accountKey = service.storageKey;

        when(() => mockPrefs.containsKey(accountKey)).thenReturn(false);
        when(
          () => mockPrefs.getString(legacyKey),
        ).thenReturn(jsonEncode([_sound(id: 'legacy').toJson()]));
        when(() => mockPrefs.getString(accountKey)).thenReturn(null);
        // The durable write fails.
        when(
          () => mockPrefs.setString(accountKey, any()),
        ).thenAnswer((_) async => false);
        when(() => mockPrefs.remove(any())).thenAnswer((_) async => true);

        service.loadSounds();
        await Future<void>.delayed(Duration.zero);

        // Legacy key must survive so the migration retries — never removed
        // after a failed write.
        verifyNever(() => mockPrefs.remove(legacyKey));
      });

      test(
        'a second account cannot re-adopt the legacy list mid-migration',
        () async {
          final mockPrefs = _MockSharedPreferences();
          const legacyKey = 'saved_reusable_sounds';
          final legacyJson = jsonEncode([_sound(id: 'shared').toJson()]);

          final serviceA = SavedSoundsService(mockPrefs, pubkeyHex: pubkeyA);
          final serviceB = SavedSoundsService(mockPrefs, pubkeyHex: pubkeyB);
          final keyA = serviceA.storageKey;
          final keyB = serviceB.storageKey;

          when(() => mockPrefs.containsKey(keyA)).thenReturn(false);
          when(() => mockPrefs.containsKey(keyB)).thenReturn(false);
          when(() => mockPrefs.getString(legacyKey)).thenReturn(legacyJson);
          when(() => mockPrefs.getString(keyA)).thenReturn(null);
          when(() => mockPrefs.getString(keyB)).thenReturn(null);
          // Hold A's migration write open so B loads inside the migration
          // window while the legacy key is still present.
          final blockedWrite = Completer<bool>();
          when(
            () => mockPrefs.setString(keyA, any()),
          ).thenAnswer((_) => blockedWrite.future);
          when(
            () => mockPrefs.setString(keyB, any()),
          ).thenAnswer((_) async => true);
          when(() => mockPrefs.remove(any())).thenAnswer((_) async => true);

          // A claims the migration synchronously; its write stays pending.
          serviceA.loadSounds();
          // B loads while A's write is unresolved and the legacy key survives.
          serviceB.loadSounds();

          // Only A ever tried to adopt the legacy list; B was blocked by the
          // claim and never wrote its own bucket.
          verify(() => mockPrefs.setString(keyA, any())).called(1);
          verifyNever(() => mockPrefs.setString(keyB, any()));

          // Let A finish so no pending future outlives the test.
          blockedWrite.complete(true);
          await Future<void>.delayed(Duration.zero);
        },
      );

      test('does not migrate the legacy list into the signed-out bucket', () {
        sharedPreferences.setString(
          'saved_reusable_sounds',
          jsonEncode([_sound(id: 'legacy').toJson()]),
        );

        final anon = SavedSoundsService(sharedPreferences);
        expect(anon.loadSounds(), isEmpty);
        // Legacy stays untouched for a real account to adopt later.
        expect(sharedPreferences.getString('saved_reusable_sounds'), isNotNull);
      });

      test(
        'does not migrate when the account already has saved sounds',
        () async {
          final accountA = SavedSoundsService(
            sharedPreferences,
            pubkeyHex: pubkeyA,
          );
          await accountA.saveSound(_sound(id: 'own'));
          sharedPreferences.setString(
            'saved_reusable_sounds',
            jsonEncode([_sound(id: 'legacy').toJson()]),
          );

          expect(accountA.loadSounds().map((sound) => sound.id), ['own']);
          expect(
            sharedPreferences.getString('saved_reusable_sounds'),
            isNotNull,
          );
        },
      );
    });
  });
}
