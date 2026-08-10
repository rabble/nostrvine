// ABOUTME: Builds SavedSound fixtures for creator sync tests.
// ABOUTME: Keeps AudioEvent construction in one place.

import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/models/saved_sound.dart';

/// Builds a [SavedSound] with a full 64-char [id] for sync tests.
SavedSound buildSavedSound({required String id, String? label}) {
  return SavedSound(
    audio: AudioEvent.fromJson({
      'id': id,
      'pubkey': 'b' * 64,
      'createdAt': 1700000000,
    }),
    savedAt: DateTime.utc(2026, 8, 7),
    personalLabel: label,
    personalHashtags: const [],
    catalogTags: const [],
    waveformSamples: const [],
  );
}
