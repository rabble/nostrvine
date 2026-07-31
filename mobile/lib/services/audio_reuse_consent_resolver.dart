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
      final matching =
          candidates
              .where((video) => video.addressableId == sourceAddress)
              .where((video) => video.createdAt >= sound.createdAt)
              .toList()
            ..sort((left, right) => left.createdAt.compareTo(right.createdAt));
      if (matching.isEmpty) return false;
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
