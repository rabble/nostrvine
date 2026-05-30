// ABOUTME: State for SoundsCubit — durable search query + audio-preview
// ABOUTME: lifecycle. Transient outcomes (save result, preview failure) flow
// ABOUTME: through method return values, not through state.

import 'package:equatable/equatable.dart';

/// State for `SoundsCubit`.
///
/// Only durable UI state lives here. Transient outcomes — "saved to
/// library", "already saved", "preview unavailable", "preview failed" —
/// are returned from the corresponding cubit method as a `Future<Result>`
/// so the View can decide on snackbar copy without state having to carry
/// error strings.
class SoundsState extends Equatable {
  const SoundsState({
    this.searchQuery = '',
    this.previewingSoundId,
    this.isLoadingPreview = false,
  });

  /// Lowercased search filter applied to bundled + Nostr sound lists.
  final String searchQuery;

  /// Id of the sound currently playing (null when nothing is previewing).
  final String? previewingSoundId;

  /// True while the audio service is loading a sound between the user's
  /// preview tap and `play()` actually starting.
  final bool isLoadingPreview;

  SoundsState copyWith({
    String? searchQuery,
    String? previewingSoundId,
    bool? isLoadingPreview,
    bool clearPreviewingSoundId = false,
  }) {
    return SoundsState(
      searchQuery: searchQuery ?? this.searchQuery,
      previewingSoundId: clearPreviewingSoundId
          ? null
          : (previewingSoundId ?? this.previewingSoundId),
      isLoadingPreview: isLoadingPreview ?? this.isLoadingPreview,
    );
  }

  @override
  List<Object?> get props => [searchQuery, previewingSoundId, isLoadingPreview];
}

/// Outcome of `SoundsCubit.previewSound(sound)`.
enum PreviewSoundOutcome {
  /// `previewSound` was a no-op: either a preview was already loading, or the
  /// Cubit was closed mid-load (the loaded source is stopped, nothing plays).
  ignored,

  /// Tapping the same sound stopped the currently-playing preview.
  stopped,

  /// The sound has no playable URL.
  unavailable,

  /// Playback completed (or was stopped) without error.
  completed,

  /// The audio service threw while loading or playing.
  failed,
}
