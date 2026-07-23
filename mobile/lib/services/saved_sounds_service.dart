// ABOUTME: Persistence service for user-saved reusable sounds.
// ABOUTME: Stores selected AudioEvent records for the Library Sounds tab.

import 'dart:async';
import 'dart:convert';

import 'package:models/models.dart' show AudioEvent;
import 'package:shared_preferences/shared_preferences.dart';

enum SavedSoundSaveResult { saved, alreadySaved }

class SavedSoundsService {
  SavedSoundsService(this._preferences, {String? pubkeyHex})
    : _pubkeyHex = pubkeyHex;

  /// Prefix for the per-account storage keys.
  static const _keyPrefix = 'saved_reusable_sounds';

  /// The pre-namespacing device-wide key (no account suffix). Read once at
  /// upgrade to migrate existing saves into the first account that loads.
  static const String _legacyStorageKey = _keyPrefix;

  final SharedPreferences _preferences;

  /// Signed-in pubkey (hex) whose saved sounds this instance manages, or
  /// `null` when signed out.
  final String? _pubkeyHex;

  /// SharedPreferences key for the current account's saved sounds.
  ///
  /// Saved sounds are scoped per account so a sound one account adopts never
  /// leaks into another account on a shared device. The signed-out state uses
  /// a dedicated anonymous bucket.
  String get storageKey {
    final pubkey = _pubkeyHex;
    return pubkey == null || pubkey.isEmpty
        ? '${_keyPrefix}_anon'
        : '${_keyPrefix}_$pubkey';
  }

  List<AudioEvent> loadSounds() {
    _migrateLegacyBucketIfNeeded();
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
          sounds.add(
            _persistableSound(
              AudioEvent.fromJson(Map<String, dynamic>.from(entry)),
            ),
          );
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

  /// Overwrites the persisted list. Used by the notifier after backfilling
  /// missing fields (e.g. duration) on legacy entries.
  Future<void> replaceAll(List<AudioEvent> sounds) => _writeSounds(sounds);

  Future<void> _writeSounds(List<AudioEvent> sounds) async {
    await _preferences.setString(
      storageKey,
      jsonEncode(
        sounds.map((sound) => _persistableSound(sound).toJson()).toList(),
      ),
    );
  }

  AudioEvent _persistableSound(AudioEvent sound) {
    return sound.anchorClipId == null
        ? sound
        : sound.copyWith(clearAnchorClipId: true);
  }

  /// One-time upgrade migration: adopt the pre-namespacing device-wide list
  /// into the first signed-in account that loads after the update, then retire
  /// the shared key so a second account can't also inherit it.
  ///
  /// Only migrates into a real account bucket (not the signed-out anonymous
  /// one) and only when this account has no bucket yet, so it runs at most once
  /// and never overwrites existing per-account data. The legacy list is
  /// unlabeled, so whichever account loads first adopts all of it — an accepted
  /// upgrade trade-off (see PR #6330).
  void _migrateLegacyBucketIfNeeded() {
    final pubkey = _pubkeyHex;
    if (pubkey == null || pubkey.isEmpty) return;
    if (_preferences.containsKey(storageKey)) return;
    final legacy = _preferences.getString(_legacyStorageKey);
    if (legacy == null) return;

    // setString updates the in-memory cache synchronously, so the load right
    // after this call sees the migrated data; disk persistence is fire-and-
    // forget. Write the account bucket before retiring the legacy key.
    unawaited(_preferences.setString(storageKey, legacy));
    unawaited(_preferences.remove(_legacyStorageKey));
  }
}
