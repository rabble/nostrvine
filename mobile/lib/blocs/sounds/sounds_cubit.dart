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
  /// - [PreviewSoundOutcome.ignored] when a preview is already loading, or
  ///   when the screen was disposed mid-load (the loaded source is stopped
  ///   and nothing is left playing).
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
      if (isClosed) {
        // The screen was torn down while the source was still loading —
        // before [SoundsState.previewingSoundId] was set, so [close] could
        // not have stopped it. Stop the just-loaded source so it doesn't
        // keep buffering, and skip emitting into a closed Cubit.
        try {
          await _audioPlaybackService.stop();
        } catch (_) {
          // Best-effort cleanup during shutdown.
        }
        return PreviewSoundOutcome.ignored;
      }
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

  /// Closes the Cubit, guaranteeing no preview audio outlives the screen.
  ///
  /// This is the **navigate-away cleanup contract**: when the enclosing
  /// `BlocProvider` is disposed (route pop, account switch, app teardown),
  /// an actively-playing preview ([SoundsState.previewingSoundId] != null)
  /// is stopped here. `just_audio`'s `play()` stays pending for the whole
  /// duration of playback, so a sound that is audibly playing always has its
  /// id set and is covered by this guard.
  ///
  /// The earlier loading phase — where [SoundsState.isLoadingPreview] is true
  /// but the id isn't set yet — is handled by [previewSound]'s `isClosed`
  /// bail-out, so every preview phase is covered.
  ///
  /// Pinned by the "navigate-away cleanup contract" tests in
  /// `sounds_cubit_test.dart` and `sounds_screen_test.dart`.
  @override
  Future<void> close() async {
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
