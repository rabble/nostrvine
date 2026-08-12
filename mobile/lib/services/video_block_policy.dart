// ABOUTME: Shared video blocklist policy for feed/detail visibility decisions.
// ABOUTME: Checks every visible account attached to a VideoEvent, not only authors.

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:models/models.dart';

class VideoBlockPolicy {
  const VideoBlockPolicy._();

  static bool isHiddenByBlocklist(
    VideoEvent video,
    ContentBlocklistRepository? blocklistRepository,
  ) {
    if (blocklistRepository == null) return false;
    return [
      video.pubkey,
      if (video.reposterPubkey != null) video.reposterPubkey!,
      ...?video.reposterPubkeys,
    ].any(
      (pubkey) =>
          pubkey.isNotEmpty &&
          blocklistRepository.shouldFilterFromFeeds(pubkey),
    );
  }
}
