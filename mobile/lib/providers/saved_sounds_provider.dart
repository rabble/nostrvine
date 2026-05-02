// ABOUTME: Riverpod providers for user-saved reusable sounds.
// ABOUTME: Exposes a synchronous saved sounds list backed by SharedPreferences.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/saved_sounds_service.dart';

final savedSoundsServiceProvider = Provider<SavedSoundsService>((ref) {
  return SavedSoundsService(ref.watch(sharedPreferencesProvider));
});

final savedSoundsProvider =
    NotifierProvider<SavedSoundsNotifier, List<AudioEvent>>(
      SavedSoundsNotifier.new,
    );

class SavedSoundsNotifier extends Notifier<List<AudioEvent>> {
  @override
  List<AudioEvent> build() {
    return ref.watch(savedSoundsServiceProvider).loadSounds();
  }

  Future<SavedSoundSaveResult> saveSound(AudioEvent sound) async {
    final result = await ref.read(savedSoundsServiceProvider).saveSound(sound);
    state = ref.read(savedSoundsServiceProvider).loadSounds();
    return result;
  }

  Future<void> removeSound(String soundId) async {
    await ref.read(savedSoundsServiceProvider).removeSound(soundId);
    state = ref.read(savedSoundsServiceProvider).loadSounds();
  }
}
