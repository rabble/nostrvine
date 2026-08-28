// ABOUTME: Shared follower list visibility helpers.
// ABOUTME: Keeps follower count and blocklist filtering semantics consistent.

import 'dart:math';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';

/// Computes the locally visible follower count from an authoritative count and
/// the known hidden followers.
///
/// The server aggregate is not yet block-aware. Keep known blocked or
/// follow-severed accounts out of the number shown beside an already-filtered
/// list until that calculation becomes canonical upstream.
int visibleFollowerCount({
  required int visiblePubkeyCount,
  required int rawPubkeyCount,
  required int authoritativeFollowerCount,
}) => max(
  visiblePubkeyCount,
  authoritativeFollowerCount - (rawPubkeyCount - visiblePubkeyCount),
);

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
