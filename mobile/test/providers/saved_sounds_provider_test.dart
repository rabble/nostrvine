// ABOUTME: Riverpod tests for the saved reusable sounds provider.
// ABOUTME: Verifies state loads from persistence and updates after mutation.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/saved_sounds_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
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
  );
}

void main() {
  group('savedSoundsProvider', () {
    late SharedPreferences sharedPreferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
    });

    ProviderContainer createContainer() {
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('loads saved sounds from persistence', () async {
      final service = SavedSoundsService(sharedPreferences);
      final sound = _sound(id: 'sound1');
      await service.saveSound(sound);
      final container = createContainer();

      expect(container.read(savedSoundsProvider), [sound]);
    });

    test('saveSound updates provider state', () async {
      final container = createContainer();
      final sound = _sound(id: 'sound1');

      final result = await container
          .read(savedSoundsProvider.notifier)
          .saveSound(sound);

      expect(result, SavedSoundSaveResult.saved);
      expect(container.read(savedSoundsProvider), [sound]);
    });

    test('removeSound removes persisted sound and updates state', () async {
      final service = SavedSoundsService(sharedPreferences);
      final sound = _sound(id: 'sound1');
      await service.saveSound(sound);
      final container = createContainer();

      await container.read(savedSoundsProvider.notifier).removeSound(sound.id);

      expect(container.read(savedSoundsProvider), isEmpty);
      expect(service.loadSounds(), isEmpty);
    });
  });
}
