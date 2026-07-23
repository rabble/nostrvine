// ABOUTME: Riverpod providers for user-saved reusable sounds.
// ABOUTME: Exposes a synchronous saved sounds list backed by SharedPreferences.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/saved_sounds_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

final savedSoundsServiceProvider = Provider<SavedSoundsService>((ref) {
  // Rebuild on sign-in/out and account switch so the service (and the sounds
  // list built from it) always targets the current account's bucket.
  ref.watch(currentAuthStateProvider);
  final pubkeyHex = ref.watch(authServiceProvider).currentPublicKeyHex;
  return SavedSoundsService(
    ref.watch(sharedPreferencesProvider),
    pubkeyHex: pubkeyHex,
  );
});

final savedSoundsProvider =
    NotifierProvider<SavedSoundsNotifier, List<AudioEvent>>(
      SavedSoundsNotifier.new,
    );

class SavedSoundsNotifier extends Notifier<List<AudioEvent>> {
  SavedSoundsService? _backfillService;
  bool _backfillScheduled = false;

  @override
  List<AudioEvent> build() {
    final service = ref.watch(savedSoundsServiceProvider);
    // Allow one backfill per account: reset when the service (and therefore
    // the account bucket) changes so an account switch re-evaluates instead of
    // staying suppressed by a previous account's run.
    if (!identical(service, _backfillService)) {
      _backfillService = service;
      _backfillScheduled = false;
    }
    final sounds = service.loadSounds();
    if (!_backfillScheduled && sounds.any((s) => (s.duration ?? 0) <= 0)) {
      // Fire-and-forget backfill for legacy entries that were saved
      // before SavedSoundsNotifier started persisting durations.
      _backfillScheduled = true;
      Future.microtask(() => _backfillMissingDurations(service));
    }
    return sounds;
  }

  Future<SavedSoundSaveResult> saveSound(AudioEvent sound) async {
    // Freeze the account bucket before any await: an account switch mid-save
    // must not redirect the write — or a stale-account state update — into a
    // different account's bucket.
    final service = ref.read(savedSoundsServiceProvider);
    final enriched = await _ensureDuration(sound);
    final result = await service.saveSound(enriched);
    if (_targetsCurrentBucket(service)) {
      state = service.loadSounds();
    }
    return result;
  }

  Future<void> removeSound(String soundId) async {
    final service = ref.read(savedSoundsServiceProvider);
    await service.removeSound(soundId);
    if (_targetsCurrentBucket(service)) {
      state = service.loadSounds();
    }
  }

  /// Whether [service] still targets the account bucket the provider is
  /// currently bound to. Compares the stable storage key rather than object
  /// identity: an A→B→A switch mid-write yields a *fresh* service instance for
  /// the same A bucket, so `identical` would wrongly drop the completed write
  /// from the current state.
  bool _targetsCurrentBucket(SavedSoundsService service) =>
      ref.read(savedSoundsServiceProvider).storageKey == service.storageKey;

  Future<void> _backfillMissingDurations(SavedSoundsService service) async {
    final current = service.loadSounds();
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
    await service.replaceAll(updated);
    if (_targetsCurrentBucket(service)) {
      state = updated;
    }
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
