// ABOUTME: Persistence service for user-saved reusable sounds.
// ABOUTME: Stores selected AudioEvent records for the Library Sounds tab.

import 'dart:async';
import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/models/saved_sound.dart';
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

  /// Process-wide guard so the one-shot legacy migration is claimed by exactly
  /// one account. Set synchronously the instant an account claims it — before
  /// the async write — so a second account loading during that write can't also
  /// adopt the same device-wide list (#6330). Released only when the account
  /// write fails, so a failed migration retries on a later load.
  static bool _legacyMigrationClaimed = false;

  /// Resets the process-wide legacy-migration claim. Tests share one isolate,
  /// so each migration test must start from an unclaimed state.
  @visibleForTesting
  static void resetLegacyMigrationClaimForTesting() {
    _legacyMigrationClaimed = false;
  }

  final SharedPreferences _preferences;

  /// Signed-in pubkey (hex) whose saved sounds this instance manages, or
  /// `null` when signed out.
  final String? _pubkeyHex;

  /// SharedPreferences key for a specific account's saved sounds.
  ///
  /// Saved sounds are scoped per account so a sound one account adopts never
  /// leaks into another account on a shared device. The signed-out state uses
  /// a dedicated anonymous bucket. Exposed so account teardown can target the
  /// deleted account's bucket without duplicating the key format.
  static String accountStorageKey(String pubkeyHex) =>
      pubkeyHex.isEmpty ? '${_keyPrefix}_anon' : '${_keyPrefix}_$pubkeyHex';

  /// SharedPreferences key for the current account's saved sounds.
  String get storageKey => accountStorageKey(_pubkeyHex ?? '');

  List<AudioEvent> loadSounds() =>
      loadSavedSounds().map((sound) => sound.audio).toList(growable: false);

  List<SavedSound> loadSavedSounds() {
    _migrateLegacyBucketIfNeeded();
    final rawSounds = _preferences.getString(storageKey);
    if (rawSounds == null || rawSounds.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(rawSounds);
      if (decoded is List) {
        return _readLegacySounds(decoded);
      }
      if (decoded is Map) {
        return _readVersionedSounds(Map<String, dynamic>.from(decoded));
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  Future<SavedSoundSaveResult> saveSound(AudioEvent sound) async {
    return saveSavedSound(
      SavedSound.fromLegacy(
        _persistableSound(sound),
      ).copyWith(savedAt: DateTime.now().toUtc()),
    );
  }

  Future<SavedSoundSaveResult> saveSavedSound(SavedSound sound) async {
    final sounds = loadSavedSounds();
    if (sounds.any((savedSound) => savedSound.id == sound.id)) {
      return SavedSoundSaveResult.alreadySaved;
    }

    await _writeSavedSounds([_persistableRecord(sound), ...sounds]);
    return SavedSoundSaveResult.saved;
  }

  Future<void> removeSound(String soundId) async {
    final sounds = loadSavedSounds()
        .where((savedSound) => savedSound.id != soundId)
        .toList();
    await _writeSavedSounds(sounds);
  }

  Future<void> replaceSavedSound(SavedSound sound) async {
    final sounds = loadSavedSounds();
    final replacement = _persistableRecord(sound);
    final existingIndex = sounds.indexWhere((saved) => saved.id == sound.id);
    if (existingIndex == -1) {
      await _writeSavedSounds([replacement, ...sounds]);
      return;
    }

    sounds[existingIndex] = replacement;
    await _writeSavedSounds(sounds);
  }

  /// Overwrites the persisted list. Used by the notifier after backfilling
  /// missing fields (e.g. duration) on legacy entries.
  Future<void> replaceAll(List<AudioEvent> sounds) {
    final existing = {
      for (final record in loadSavedSounds()) record.id: record,
    };
    return _writeSavedSounds(
      sounds
          .map(
            (sound) => (existing[sound.id] ?? SavedSound.fromLegacy(sound))
                .copyWith(audio: _persistableSound(sound)),
          )
          .toList(growable: false),
    );
  }

  Future<void> replaceAllSavedSounds(List<SavedSound> sounds) =>
      _writeSavedSounds(sounds);

  List<SavedSound> _readLegacySounds(List<dynamic> decoded) {
    final sounds = <SavedSound>[];
    for (final entry in decoded.whereType<Map>()) {
      try {
        sounds.add(
          SavedSound.fromLegacy(
            _persistableSound(
              AudioEvent.fromJson(Map<String, dynamic>.from(entry)),
            ),
          ),
        );
      } catch (_) {
        continue;
      }
    }
    return sounds;
  }

  /// Reads a versioned payload, migrating any schema at or below the current
  /// version into the current record shape.
  ///
  /// Payloads from a *newer* build are reported unreadable rather than
  /// downgraded — [_isForeignPayload] then stops a write from flattening them.
  /// Entries are parsed individually so one malformed record cannot cost the
  /// user the rest of the library.
  List<SavedSound> _readVersionedSounds(Map<String, dynamic> decoded) {
    if (_isNewerSchema(decoded)) return [];

    final rawSounds = decoded['sounds'];
    if (rawSounds is! List) return [];

    final sounds = <SavedSound>[];
    for (final entry in rawSounds.whereType<Map>()) {
      try {
        sounds.add(
          _persistableRecord(
            SavedSound.fromJson(Map<String, dynamic>.from(entry)),
          ),
        );
      } catch (_) {
        continue;
      }
    }
    return sounds;
  }

  static bool _isNewerSchema(Map<String, dynamic> decoded) {
    final version = decoded['schemaVersion'];
    return version is int &&
        version > SavedSoundLibraryPayload.currentSchemaVersion;
  }

  /// Whether the stored payload was written by a build this one cannot read.
  bool _isForeignPayload() {
    final raw = _preferences.getString(storageKey);
    if (raw == null || raw.isEmpty) return false;
    try {
      final decoded = jsonDecode(raw);
      return decoded is Map &&
          _isNewerSchema(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return false;
    }
  }

  Future<void> _writeSavedSounds(List<SavedSound> sounds) async {
    if (_isForeignPayload()) {
      throw StateError(
        'Refusing to overwrite a saved sound library written by a newer build',
      );
    }
    final payload = SavedSoundLibraryPayload(
      schemaVersion: SavedSoundLibraryPayload.currentSchemaVersion,
      sounds: sounds.map(_persistableRecord).toList(growable: false),
    );
    final didWrite = await _preferences.setString(
      storageKey,
      jsonEncode(payload.toJson()),
    );
    if (!didWrite) {
      throw StateError('Failed to persist saved sounds');
    }
  }

  SavedSound _persistableRecord(SavedSound sound) {
    return sound.copyWith(audio: _persistableSound(sound.audio));
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
    if (_legacyMigrationClaimed) return;
    final legacy = _preferences.getString(_legacyStorageKey);
    if (legacy == null) return;

    // Claim synchronously: there is no await between reading the legacy key and
    // setting this flag, so a second account that loads during the async write
    // below sees the claim and cannot re-adopt the same list. setString also
    // updates the in-memory cache synchronously, so the load right after this
    // call still sees the migrated data.
    _legacyMigrationClaimed = true;
    unawaited(_migrateLegacyBucket(_consentedLegacy(legacy)));
  }

  /// Persists the migrated list into the account bucket, then retires the
  /// legacy key. The claim is released only when the account write itself fails,
  /// so a failed or interrupted write can never drop the data (the migration
  /// retries on the next load while the legacy key survives); once the write
  /// succeeds the claim stays, so no other account can re-adopt the list even if
  /// retiring the legacy key later fails.
  Future<void> _migrateLegacyBucket(String migrated) async {
    try {
      if (!await _preferences.setString(storageKey, migrated)) {
        // The account write was rejected: release the claim and leave the
        // legacy key so the next load retries the whole migration.
        _legacyMigrationClaimed = false;
        return;
      }
    } catch (_) {
      // The account write threw: same as above — retry on the next load.
      _legacyMigrationClaimed = false;
      return;
    }
    try {
      await _preferences.remove(_legacyStorageKey);
    } catch (_) {
      // Account bucket is durably written; leaving the legacy key is harmless
      // now that the claim is permanent for this process.
    }
  }

  /// Filters the pre-namespacing list to entries safe to adopt without
  /// confirming reuse consent.
  ///
  /// A video's original sound (`video_*` id) may have been saved during the
  /// pre-fix device-wide bug even though its creator had disabled reuse. That
  /// consent can't be validated offline, so those entries are dropped (fail
  /// closed). Shared (Kind 1063), bundled, and imported sounds were reusable by
  /// construction and are kept.
  String _consentedLegacy(String legacy) {
    try {
      final decoded = jsonDecode(legacy);
      if (decoded is! List) return '[]';
      final kept = <Map<String, dynamic>>[];
      for (final entry in decoded.whereType<Map>()) {
        try {
          final sound = AudioEvent.fromJson(Map<String, dynamic>.from(entry));
          if (sound.isOriginalSound) continue;
          kept.add(_persistableSound(sound).toJson());
        } catch (_) {
          continue;
        }
      }
      return jsonEncode(kept);
    } catch (_) {
      return '[]';
    }
  }
}
