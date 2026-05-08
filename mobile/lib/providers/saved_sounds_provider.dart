// ABOUTME: Riverpod providers for user-saved reusable sounds.
// ABOUTME: Exposes a synchronous saved sounds list backed by SharedPreferences.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/saved_sounds_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

final savedSoundsServiceProvider = Provider<SavedSoundsService>((ref) {
  return SavedSoundsService(ref.watch(sharedPreferencesProvider));
});

final savedSoundsProvider =
    NotifierProvider<SavedSoundsNotifier, List<AudioEvent>>(
      SavedSoundsNotifier.new,
    );

class SavedSoundsNotifier extends Notifier<List<AudioEvent>> {
  bool _backfillScheduled = false;

  @override
  List<AudioEvent> build() {
    final sounds = ref.watch(savedSoundsServiceProvider).loadSounds();
    if (!_backfillScheduled && sounds.any((s) => (s.duration ?? 0) <= 0)) {
      // Fire-and-forget backfill for legacy entries that were saved
      // before SavedSoundsNotifier started persisting durations.
      _backfillScheduled = true;
      Future.microtask(_backfillMissingDurations);
    }
    return sounds;
  }

  Future<SavedSoundSaveResult> saveSound(AudioEvent sound) async {
    final enriched = await _ensureDuration(sound);
    final result = await ref
        .read(savedSoundsServiceProvider)
        .saveSound(enriched);
    state = ref.read(savedSoundsServiceProvider).loadSounds();
    return result;
  }

  Future<void> removeSound(String soundId) async {
    await ref.read(savedSoundsServiceProvider).removeSound(soundId);
    state = ref.read(savedSoundsServiceProvider).loadSounds();
  }

  Future<void> _backfillMissingDurations() async {
    final current = state;
    final updated = <AudioEvent>[];
    var changed = false;
    for (final sound in current) {
      if ((sound.duration ?? 0) > 0) {
        updated.add(sound);
        continue;
      }
      final enriched = await _ensureDuration(sound);
      if ((enriched.duration ?? 0) > 0) changed = true;
      updated.add(enriched);
    }
    if (!changed) return;
    await ref.read(savedSoundsServiceProvider).replaceAll(updated);
    state = updated;
  }

  /// Probes [ProVideoEditor] for the missing duration so the saved
  /// entry persists with the correct length. Nostr Kind 1063 events
  /// frequently omit the `duration` tag.
  Future<AudioEvent> _ensureDuration(AudioEvent sound) async {
    if ((sound.duration ?? 0) > 0) return sound;

    final EditorVideo source;
    if (sound.isBundled && sound.assetPath != null) {
      source = EditorVideo.asset(sound.assetPath!);
    } else if (sound.url != null && sound.url!.isNotEmpty) {
      source = EditorVideo.network(sound.url!);
    } else {
      return sound;
    }

    try {
      final metadata = await ProVideoEditor.instance.getMetadata(source);
      final seconds = metadata.duration.inMilliseconds / 1000.0;
      if (seconds <= 0) return sound;
      return sound.copyWith(duration: seconds);
    } catch (e, s) {
      Log.error(
        'Failed to resolve duration for saved sound ${sound.id}: $e',
        name: 'SavedSoundsNotifier',
        error: e,
        stackTrace: s,
      );
      return sound;
    }
  }
}
