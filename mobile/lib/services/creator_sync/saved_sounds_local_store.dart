// ABOUTME: Adapts SavedSoundsService to the creator_sync LocalSoundStore.
// ABOUTME: Translates between SavedSound objects and json bodies.

import 'package:creator_sync/creator_sync.dart';
import 'package:openvine/models/saved_sound.dart';
import 'package:openvine/services/saved_sounds_service.dart';

/// Exposes the account's saved sounds to the sync reconciler.
class SavedSoundsLocalStore implements LocalSoundStore {
  /// Creates a [SavedSoundsLocalStore] over [_service].
  SavedSoundsLocalStore(this._service);

  final SavedSoundsService _service;

  @override
  Future<Map<String, Map<String, dynamic>>> readAll() async {
    return {
      for (final sound in _service.loadSavedSounds()) sound.id: sound.toJson(),
    };
  }

  @override
  Future<void> upsert(String id, Map<String, dynamic> body) =>
      _service.replaceSavedSound(SavedSound.fromJson(body));

  @override
  Future<void> remove(String id) => _service.removeSound(id);
}
