// ABOUTME: BLoC owning the current account's device-local saved sound library.
// ABOUTME: Persists basic saves first, then quietly enriches optional waveform data.

import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:creator_sync/creator_sync.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/saved_sounds/saved_sound_media_probe.dart';
import 'package:openvine/blocs/saved_sounds/saved_sounds_event.dart';
import 'package:openvine/blocs/saved_sounds/saved_sounds_state.dart';
import 'package:openvine/models/saved_sound.dart';
import 'package:openvine/services/saved_sounds_service.dart';

export 'saved_sounds_event.dart';
export 'saved_sounds_state.dart';

class SavedSoundsBloc extends Bloc<SavedSoundsEvent, SavedSoundsState> {
  SavedSoundsBloc({
    required SavedSoundsService service,
    required SavedSoundMediaProbe mediaProbe,
    SoundSyncRepository? syncRepository,
    DateTime Function()? now,
  }) : _service = service,
       _mediaProbe = mediaProbe,
       _syncRepository = syncRepository,
       _now = now ?? DateTime.now,
       super(const SavedSoundsState()) {
    on<SavedSoundsEvent>(_onEvent, transformer: sequential());
  }

  final SavedSoundsService _service;
  final SavedSoundMediaProbe _mediaProbe;

  /// Cross-device sync, or null until the vault key resolves.
  final SoundSyncRepository? _syncRepository;

  final DateTime Function() _now;

  /// Mirrors a local mutation to the user's other devices.
  ///
  /// Sync is best-effort: the local write has already succeeded, and a
  /// relay outage must never surface as a failed save. The next reconcile
  /// pass picks up anything that did not publish.
  Future<void> _mirror(Future<void> Function() publish) async {
    if (_syncRepository == null) return;
    try {
      await publish();
    } on SyncIndexException catch (e, stackTrace) {
      addError(e, stackTrace);
    } on VaultKeyUnavailableException catch (e, stackTrace) {
      addError(e, stackTrace);
    }
  }

  Future<SavedSoundSaveResult> saveSound(
    AudioEvent sound, {
    SavedSoundSourceContext? sourceContext,
  }) {
    final completer = Completer<SavedSoundSaveResult>();
    add(
      SavedSoundSaveRequested(
        sound: sound,
        sourceContext: sourceContext,
        completer: completer,
      ),
    );
    return completer.future;
  }

  /// Removes [soundId], completing with an error when it could not be
  /// persisted so the caller can report the failure.
  Future<void> removeSound(String soundId) {
    final completer = Completer<void>();
    add(SavedSoundRemoveRequested(soundId, completer: completer));
    return completer.future;
  }

  Future<void> _onEvent(
    SavedSoundsEvent event,
    Emitter<SavedSoundsState> emit,
  ) async {
    switch (event) {
      case SavedSoundsLoadRequested():
        emit(
          state.copyWith(
            status: SavedSoundsStatus.loaded,
            sounds: _service.loadSavedSounds(),
          ),
        );
      case SavedSoundSaveRequested():
        await _save(event, emit);
      case SavedSoundDetailsChanged():
        await _edit(event, emit);
      case SavedSoundRemoveRequested():
        await _remove(event, emit);
      case SavedSoundsQueryChanged():
        emit(state.copyWith(query: event.query));
      case SavedSoundsHashtagSelected():
        emit(state.copyWith(selectedHashtag: event.hashtag));
      case SavedSoundProbeCompleted():
        await _applyProbe(event, emit);
    }
  }

  Future<void> _save(
    SavedSoundSaveRequested event,
    Emitter<SavedSoundsState> emit,
  ) async {
    final record = SavedSound(
      audio: event.sound,
      savedAt: _now().toUtc(),
      personalHashtags: const [],
      catalogTags: event.sound.externalSource?.catalogTags ?? const [],
      waveformSamples: const [],
      sourceContext: event.sourceContext,
    );
    try {
      final result = await _service.saveSavedSound(record);
      await _mirror(() => _syncRepository!.publishLocalChange(record.id));
      if (!event.completer.isCompleted) event.completer.complete(result);
      if (emit.isDone) return;
      emit(
        state.copyWith(
          status: SavedSoundsStatus.loaded,
          sounds: _service.loadSavedSounds(),
        ),
      );
      if (result == SavedSoundSaveResult.saved) {
        unawaited(_probe(record));
      }
    } catch (error, stackTrace) {
      if (!event.completer.isCompleted) {
        event.completer.completeError(error, stackTrace);
      }
    }
  }

  Future<void> _probe(SavedSound record) async {
    final result = await _mediaProbe.probe(record.audio);
    if (!isClosed) {
      add(SavedSoundProbeCompleted(soundId: record.id, result: result));
    }
  }

  Future<void> _edit(
    SavedSoundDetailsChanged event,
    Emitter<SavedSoundsState> emit,
  ) async {
    final index = state.sounds.indexWhere((sound) => sound.id == event.soundId);
    if (index == -1) return;
    final updated = state.sounds[index].copyWith(
      personalLabel: event.label,
      personalHashtags: event.hashtags,
    );
    final optimistic = [...state.sounds]..[index] = updated;
    emit(
      state.copyWith(
        sounds: optimistic,
        unsavedSoundIds: {...state.unsavedSoundIds}..remove(event.soundId),
      ),
    );
    try {
      await _service.replaceSavedSound(updated);
      await _mirror(() => _syncRepository!.publishLocalChange(updated.id));
    } catch (_) {
      if (!emit.isDone) {
        emit(
          state.copyWith(
            unsavedSoundIds: {...state.unsavedSoundIds, event.soundId},
          ),
        );
      }
    }
  }

  Future<void> _remove(
    SavedSoundRemoveRequested event,
    Emitter<SavedSoundsState> emit,
  ) async {
    final completer = event.completer;
    try {
      await _service.removeSound(event.soundId);
    } catch (error, stackTrace) {
      // The row stays on screen because the delete did not happen; the caller
      // completes with the error so the UI can say so instead of claiming
      // success.
      addError(error, stackTrace);
      if (completer != null && !completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
      return;
    }

    await _mirror(() => _syncRepository!.publishLocalDeletion(event.soundId));

    if (completer != null && !completer.isCompleted) completer.complete();
    if (emit.isDone) return;
    emit(
      state.copyWith(
        sounds: state.sounds
            .where((sound) => sound.id != event.soundId)
            .toList(growable: false),
        unsavedSoundIds: {...state.unsavedSoundIds}..remove(event.soundId),
      ),
    );
  }

  Future<void> _applyProbe(
    SavedSoundProbeCompleted event,
    Emitter<SavedSoundsState> emit,
  ) async {
    final result = event.result;
    if (result == null) return;
    final index = state.sounds.indexWhere((sound) => sound.id == event.soundId);
    if (index == -1) return;
    final current = state.sounds[index];
    final duration = result.durationSeconds;
    final updated = current.copyWith(
      audio: duration == null
          ? current.audio
          : current.audio.copyWith(duration: duration),
      waveformSamples: result.waveformSamples,
    );
    try {
      await _service.replaceSavedSound(updated);
      await _mirror(() => _syncRepository!.publishLocalChange(updated.id));
      if (emit.isDone) return;
      emit(state.copyWith(sounds: [...state.sounds]..[index] = updated));
    } catch (_) {
      // Optional enrichment must never turn a successful save into an error.
    }
  }
}
