// ABOUTME: Verifies reuse consent for legacy audio events without consent tags.
// ABOUTME: Fails closed unless the sound's source video grants reuse.

import 'package:models/models.dart';
import 'package:videos_repository/videos_repository.dart';

class AudioReuseConsentResolver {
  const AudioReuseConsentResolver({required VideosRepository videosRepository})
    : _videosRepository = videosRepository;

  final VideosRepository _videosRepository;

  Future<bool> verify(AudioEvent sound) async {
    if (sound.allowsReuse) return true;
    if (sound.hasExplicitReuseConsent) return false;

    final sourceAddress = sound.sourceVideoReference;
    if (sourceAddress == null || sourceAddress.isEmpty) return false;

    try {
      // Read the source video straight off the address the sound already
      // carries. Resolving it the other way round — asking which videos
      // reference this sound — only works once a video carries the
      // `['e', <audioEventId>, <relay>, 'audio']` tag, which legacy videos
      // predate. That is the same population this resolver exists to rescue,
      // so the reverse lookup returned nothing for every one of them (#6769).
      final candidates = await _videosRepository.getVideosByAddressableIds([
        sourceAddress,
      ]);
      final matching = candidates
          .where((video) => video.addressableId == sourceAddress)
          .toList();
      if (matching.isEmpty) return false;
      // `allow_audio_reuse` is rebuilt on every edit — dropping the tag is how
      // a creator revokes consent — and an addressable read resolves to the
      // current revision, so this is the live answer. A revision predating the
      // sound cannot speak for it.
      final source = matching.first;
      if (source.createdAt < sound.createdAt) return false;
      return source.allowAudioReuse;
    } catch (_) {
      return false;
    }
  }
}
