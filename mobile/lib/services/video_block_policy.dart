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
    if (video.pubkey.isNotEmpty &&
        blocklistRepository.shouldFilterFromFeeds(video.pubkey)) {
      return true;
    }
    return [
      if (video.reposterPubkey != null) video.reposterPubkey!,
      ...?video.reposterPubkeys,
    ].any(
      (pubkey) =>
          pubkey.isNotEmpty && _shouldHideReposter(blocklistRepository, pubkey),
    );
  }

  static bool _shouldHideReposter(
    ContentBlocklistRepository blocklistRepository,
    String pubkey,
  ) {
    return blocklistRepository.isBlocked(pubkey) ||
        blocklistRepository.isMutedByUs(pubkey);
  }
}
