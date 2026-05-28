// ABOUTME: Cubit backing the SoundsScreen — owns the search filter and the
// ABOUTME: audio-preview lifecycle. Search controller stays in the View
// ABOUTME: (hybrid pattern per #4744 WS-1 #5 precedent).

import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/blocs/sounds/sounds_state.dart';
import 'package:openvine/services/saved_sounds_service.dart';
import 'package:sound_service/sound_service.dart';

/// Callable that hides the Riverpod `savedSoundsProvider.notifier.saveSound`
/// surface so the Cubit doesn't need to know about the notifier directly.
typedef SaveSoundAction = Future<SavedSoundSaveResult> Function(AudioEvent);

/// Cubit backing `SoundsScreen`.
///
/// Owns:
/// - the lowercased [SoundsState.searchQuery] applied to both bundled +
///   Nostr sound lists in the View,
/// - the audio-preview lifecycle ([SoundsState.previewingSoundId] +
///   [SoundsState.isLoadingPreview]).
///
/// Transient outcomes (save result, preview unavailable, preview failure)
/// are returned from the corresponding method as a `Future<Result>` so the
/// View can pick snackbar copy without state having to carry error strings
/// (per `state_management.md`).
class SoundsCubit extends Cubit<SoundsState> {
  SoundsCubit({
    required AudioPlaybackService audioPlaybackService,
    required SaveSoundAction saveSound,
  }) : _audioPlaybackService = audioPlaybackService,
       _saveSound = saveSound,
       super(const SoundsState());

  final AudioPlaybackService _audioPlaybackService;
  final SaveSoundAction _saveSound;

  void setSearchQuery(String query) {
    emit(state.copyWith(searchQuery: query.toLowerCase()));
  }

  /// Filters [sounds] by the current [SoundsState.searchQuery] against the
  /// lowercased title. Returns the input unchanged when the query is empty.
  List<AudioEvent> filterSounds(List<AudioEvent> sounds) {
    final query = state.searchQuery;
    if (query.isEmpty) return sounds;
    return sounds.where((sound) {
      final title = sound.title?.toLowerCase() ?? '';
      return title.contains(query);
    }).toList();
  }

  /// Toggles or starts a preview for [sound].
  ///
  /// Returns:
  /// - [PreviewSoundOutcome.ignored] when a preview is already loading.
  /// - [PreviewSoundOutcome.stopped] when the user tapped the currently-
  ///   playing sound — the audio service is stopped and state is cleared.
  /// - [PreviewSoundOutcome.unavailable] when the sound has no playable URL.
  /// - [PreviewSoundOutcome.completed] when playback ran to completion (or
  ///   was stopped) without error.
  /// - [PreviewSoundOutcome.failed] when the audio service threw — the
  ///   error is also reported via `addError` for observability.
  Future<PreviewSoundOutcome> previewSound(AudioEvent sound) async {
    if (state.isLoadingPreview) return PreviewSoundOutcome.ignored;

    if (state.previewingSoundId == sound.id) {
      await _stopAudio();
      _clearPreviewing();
      return PreviewSoundOutcome.stopped;
    }

    final url = sound.url;
    if (url == null || url.isEmpty) {
      return PreviewSoundOutcome.unavailable;
    }

    emit(state.copyWith(isLoadingPreview: true));
    try {
      await _audioPlaybackService.stop();
      await _audioPlaybackService.loadAudio(url);
      emit(
        state.copyWith(
          previewingSoundId: sound.id,
          isLoadingPreview: false,
        ),
      );
      await _audioPlaybackService.play();
      _clearPreviewing();
      return PreviewSoundOutcome.completed;
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      _clearPreviewing();
      return PreviewSoundOutcome.failed;
    }
  }

  /// Stops any in-flight preview. No-op when nothing is previewing.
  Future<void> stopPreview() async {
    if (state.previewingSoundId == null) return;
    await _stopAudio();
    _clearPreviewing();
  }

  /// Delegates to the injected save action and returns the result so the
  /// View can pick the right snackbar copy.
  Future<SavedSoundSaveResult> saveSound(AudioEvent sound) => _saveSound(sound);

  Future<void> _stopAudio() async {
    await _audioPlaybackService.stop();
  }

  void _clearPreviewing() {
    if (isClosed) return;
    emit(state.copyWith(isLoadingPreview: false, clearPreviewingSoundId: true));
  }

  @override
  Future<void> close() async {
    // Stop any in-flight playback so disposing the screen doesn't leave the
    // audio service playing into the void.
    if (state.previewingSoundId != null) {
      try {
        await _audioPlaybackService.stop();
      } catch (_) {
        // Best-effort cleanup; ignore failures during shutdown.
      }
    }
    return super.close();
  }
}
