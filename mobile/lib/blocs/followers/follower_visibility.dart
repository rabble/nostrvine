// ABOUTME: Shared follower list visibility helpers.
// ABOUTME: Keeps follower count and blocklist filtering semantics consistent.

import 'package:content_blocklist_repository/content_blocklist_repository.dart';

/// Filters followers hidden from the current user's own follower list.
List<String> filterMyFollowerPubkeys({
  required List<String> pubkeys,
  required ContentBlocklistRepository blocklistRepository,
}) => pubkeys
    .where(
      (pubkey) =>
          !blocklistRepository.isBlocked(pubkey) &&
          !blocklistRepository.isFollowSevered(pubkey),
    )
    .toList();

/// Filters followers hidden from another user's follower list.
List<String> filterOtherFollowerPubkeys({
  required List<String> pubkeys,
  required ContentBlocklistRepository blocklistRepository,
  required bool isFollowingTarget,
  required String currentUserPubkey,
}) => pubkeys
    .where(
      (pubkey) =>
          !blocklistRepository.isBlocked(pubkey) &&
          !(!isFollowingTarget && pubkey == currentUserPubkey),
    )
    .toList();
