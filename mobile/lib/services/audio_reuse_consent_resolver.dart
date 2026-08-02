// ABOUTME: Verifies reuse consent for legacy audio events without consent tags.
// ABOUTME: Fails closed unless one unambiguous source-video event grants reuse.

import 'package:models/models.dart';
import 'package:sounds_repository/sounds_repository.dart';
import 'package:videos_repository/videos_repository.dart';

class AudioReuseConsentResolver {
  const AudioReuseConsentResolver({
    required SoundsRepository soundsRepository,
    required VideosRepository videosRepository,
  }) : _soundsRepository = soundsRepository,
       _videosRepository = videosRepository;

  final SoundsRepository _soundsRepository;
  final VideosRepository _videosRepository;

  Future<bool> verify(AudioEvent sound) async {
    if (sound.allowsReuse) return true;
    if (sound.hasExplicitReuseConsent) return false;

    final sourceAddress = sound.sourceVideoReference;
    if (sourceAddress == null || sourceAddress.isEmpty) return false;

    try {
      final ids = await _soundsRepository.fetchVideosUsingSound(sound.id);
      if (ids.isEmpty) return false;
      final candidates = await _videosRepository.getVideosByIds(
        ids,
        hydrateBulkStats: false,
      );
      // `addressableId` is stable across edits, so several revisions of the
      // same video can match. `allow_audio_reuse` is rebuilt on every edit —
      // dropping the tag is how a creator revokes consent — so the newest
      // revision is the current answer.
      final matching =
          candidates
              .where((video) => video.addressableId == sourceAddress)
              .where((video) => video.createdAt >= sound.createdAt)
              .toList()
            ..sort((left, right) => right.createdAt.compareTo(left.createdAt));
      if (matching.isEmpty) return false;
      // Two revisions stamped the same second leave no way to tell which one
      // is current, so fail closed rather than guess at the consent state.
      if (matching.length > 1 &&
          matching[0].createdAt == matching[1].createdAt) {
        return false;
      }
      return matching.first.allowAudioReuse;
    } catch (_) {
      return false;
    }
  }
}
