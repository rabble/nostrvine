import 'package:models/models.dart';

/// Returns the first index whose video identity matches the supplied event id
/// or stable id. Event id wins when both identities are supplied.
int indexOfVideoIdentity(
  List<VideoEvent> videos, {
  String? videoId,
  String? stableId,
  String? pubkey,
}) {
  if (videoId == null && stableId == null) return -1;

  return videos.indexWhere(
    (video) =>
        (videoId != null && video.id == videoId) ||
        (stableId != null &&
            video.stableId == stableId &&
            (pubkey == null || video.pubkey == pubkey)),
  );
}

/// Returns the first index whose identity matches [target].
int indexOfMatchingVideo(List<VideoEvent> videos, VideoEvent target) {
  return indexOfVideoIdentity(
    videos,
    videoId: target.id,
    stableId: target.stableId,
    pubkey: target.pubkey,
  );
}
