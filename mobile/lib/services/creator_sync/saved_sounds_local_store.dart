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
    // loadSavedSounds() first: it is what kicks off the legacy-bucket
    // migration, and an account whose bucket that migration has not written
    // yet reads as absent rather than unreadable.
    // Stored paths, not resolved ones: a body carrying this device's current
    // container path would hash differently after every iOS app update and
    // republish itself to the relay for no change the user made.
    final sounds = _service.loadSavedSounds(resolveLocalPaths: false);
    if (_service.isLibraryUnreadable) {
      throw LocalStoreUnreadableException(
        'saved sound library is present but not decodable by this build',
      );
    }
    return {for (final sound in sounds) sound.id: sound.toJson()};
  }

  @override
  Future<void> upsert(String id, Map<String, dynamic> body) {
    final sound = SavedSound.fromJson(body);
    // replaceSavedSound keys off sound.id (== body's own "audio.id"), not
    // [id]. The reconciler's applied-state cursor is keyed by [id], so a
    // silent disagreement here would write the sound under one key while
    // recording sync progress under another.
    assert(
      sound.id == id,
      "upsert id ($id) does not match the body's own id (${sound.id})",
    );
    return _service.replaceSavedSound(sound);
  }

  @override
  Future<void> remove(String id) => _service.removeSound(id);
}
