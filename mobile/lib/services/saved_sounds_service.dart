// ABOUTME: Persistence service for user-saved reusable sounds.
// ABOUTME: Stores selected AudioEvent records for the Library Sounds tab.

import 'dart:convert';

import 'package:models/models.dart' show AudioEvent;
import 'package:shared_preferences/shared_preferences.dart';

enum SavedSoundSaveResult { saved, alreadySaved }

class SavedSoundsService {
  SavedSoundsService(this._preferences);

  static const storageKey = 'saved_reusable_sounds';

  final SharedPreferences _preferences;

  List<AudioEvent> loadSounds() {
    final rawSounds = _preferences.getString(storageKey);
    if (rawSounds == null || rawSounds.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(rawSounds);
      if (decoded is! List) {
        return [];
      }

      final sounds = <AudioEvent>[];
      for (final entry in decoded.whereType<Map>()) {
        try {
          sounds.add(AudioEvent.fromJson(Map<String, dynamic>.from(entry)));
        } catch (_) {
          continue;
        }
      }
      return sounds;
    } catch (_) {
      return [];
    }
  }

  Future<SavedSoundSaveResult> saveSound(AudioEvent sound) async {
    final sounds = loadSounds();
    if (sounds.any((savedSound) => savedSound.id == sound.id)) {
      return SavedSoundSaveResult.alreadySaved;
    }

    await _writeSounds([sound, ...sounds]);
    return SavedSoundSaveResult.saved;
  }

  Future<void> removeSound(String soundId) async {
    final sounds = loadSounds()
        .where((savedSound) => savedSound.id != soundId)
        .toList();
    await _writeSounds(sounds);
  }

  Future<void> _writeSounds(List<AudioEvent> sounds) async {
    await _preferences.setString(
      storageKey,
      jsonEncode(sounds.map((sound) => sound.toJson()).toList()),
    );
  }
}
