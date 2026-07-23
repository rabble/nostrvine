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

    test('saveSound freezes the account bucket across the awaits', () async {
      const pubkeyA =
          'a123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      const pubkeyB =
          'b123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
      final serviceA = SavedSoundsService(
        sharedPreferences,
        pubkeyHex: pubkeyA,
      );
      final serviceB = SavedSoundsService(
        sharedPreferences,
        pubkeyHex: pubkeyB,
      );

      // Drive the "current account bucket" directly so the switch is
      // deterministic, independent of auth-state propagation.
      var current = serviceA;
      final container = ProviderContainer(
        overrides: [
          savedSoundsServiceProvider.overrideWith((ref) => current),
        ],
      );
      addTearDown(container.dispose);

      // Prime for account A; saveSound freezes serviceA before its first await.
      expect(container.read(savedSoundsProvider), isEmpty);
      final future = container
          .read(savedSoundsProvider.notifier)
          .saveSound(_sound(id: 'sound1'));

      // Switch the active bucket to B mid-save and force the rebind.
      current = serviceB;
      container.invalidate(savedSoundsServiceProvider);
      expect(container.read(savedSoundsProvider), isEmpty);

      await future;

      // The write landed in the frozen account A, never leaked into B, and the
      // stale-account state update was skipped.
      expect(serviceA.loadSounds().map((sound) => sound.id), ['sound1']);
      expect(serviceB.loadSounds(), isEmpty);
      expect(container.read(savedSoundsProvider), isEmpty);
    });
  });
}
