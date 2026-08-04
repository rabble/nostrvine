// ABOUTME: Immutable state for the device-local saved sounds library.
// ABOUTME: Owns search and hashtag filtering across private and source metadata.

import 'package:equatable/equatable.dart';
import 'package:openvine/models/saved_sound.dart';

enum SavedSoundsStatus { initial, loading, loaded }

class SavedSoundsState extends Equatable {
  const SavedSoundsState({
    this.status = SavedSoundsStatus.initial,
    this.sounds = const [],
    this.query = '',
    this.selectedHashtag,
    this.unsavedSoundIds = const {},
  });

  final SavedSoundsStatus status;
  final List<SavedSound> sounds;
  final String query;
  final String? selectedHashtag;
  final Set<String> unsavedSoundIds;

  List<SavedSound> get visibleSounds {
    final normalizedQuery = query.trim().toLowerCase();
    return sounds
        .where((sound) {
          final matchesTag =
              selectedHashtag == null ||
              sound.personalHashtags.contains(selectedHashtag);
          return matchesTag &&
              (normalizedQuery.isEmpty ||
                  _searchableValues(sound).any(
                    (value) => value.toLowerCase().contains(normalizedQuery),
                  ));
        })
        .toList(growable: false);
  }

  SavedSoundsState copyWith({
    SavedSoundsStatus? status,
    List<SavedSound>? sounds,
    String? query,
    Object? selectedHashtag = _unset,
    Set<String>? unsavedSoundIds,
  }) => SavedSoundsState(
    status: status ?? this.status,
    sounds: sounds ?? this.sounds,
    query: query ?? this.query,
    selectedHashtag: identical(selectedHashtag, _unset)
        ? this.selectedHashtag
        : selectedHashtag as String?,
    unsavedSoundIds: unsavedSoundIds ?? this.unsavedSoundIds,
  );

  @override
  List<Object?> get props => [
    status,
    sounds,
    query,
    selectedHashtag,
    unsavedSoundIds,
  ];
}

const _unset = Object();

Iterable<String> _searchableValues(SavedSound sound) sync* {
  final source = sound.sourceContext;
  final nullableValues = [
    sound.personalLabel,
    sound.audio.title,
    source?.title,
    source?.creatorName,
    source?.description,
    source?.transcript,
  ];
  yield* nullableValues.whereType<String>();
  yield* sound.personalHashtags;
  yield* sound.catalogTags;
}
