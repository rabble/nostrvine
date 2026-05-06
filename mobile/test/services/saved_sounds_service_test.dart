// ABOUTME: Tests for the persisted reusable sounds library service.
// ABOUTME: Covers saving, dedupe, ordering, and corrupt storage fallback.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/services/saved_sounds_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

AudioEvent _sound({
  required String id,
  String? title,
  int createdAt = 1700000000,
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
  );
}

void main() {
  group(SavedSoundsService, () {
    late SharedPreferences sharedPreferences;

    setUp(() async {
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
      sharedPreferences.setString(SavedSoundsService.storageKey, 'not json');
      final service = SavedSoundsService(sharedPreferences);

      expect(service.loadSounds(), isEmpty);
    });

    test('skips invalid persisted entries without dropping valid sounds', () {
      final validSound = _sound(id: 'sound1', title: 'Valid Sound');
      sharedPreferences.setString(
        SavedSoundsService.storageKey,
        jsonEncode([
          validSound.toJson(),
          {'id': 123},
        ]),
      );
      final service = SavedSoundsService(sharedPreferences);

      expect(service.loadSounds(), [validSound]);
    });
  });
}
