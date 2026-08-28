// ABOUTME: Shared follower list visibility helpers.
// ABOUTME: Keeps follower count and blocklist filtering semantics consistent.

import 'dart:math';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';

/// Computes the locally visible follower count from an authoritative count and
/// the known hidden followers.
///
/// The server aggregate is not yet block-aware, so accounts the profile owner
/// blocked or follow-severed are subtracted here until that calculation
/// becomes canonical upstream (divinevideo/divine-funnelcake#1166).
///
/// The subtraction is deliberately *not* floored at [visiblePubkeyCount].
/// That count traces back to the relay-merged union in `_fetchOrderedFollowers`
/// (API + connected relays + indexers), so flooring on it makes the displayed
/// number the list length whenever the union is longer than the REST count —
/// which is the normal case — and it then moves with whichever relays
/// answered. That is the instability #8197 reports.
///
/// Dropping the floor also makes blocking legible rather than masking it: with
/// a floor, blocking five accounts moves the number by five while relay
/// variance moves it by ten, so the user cannot see that blocking did
/// anything. Without one, five blocks reliably read as five fewer followers.
///
/// The cost is that this count can sit below the number of rows on screen,
/// which is trade-off 1 in the pull request description and is intended.
int visibleFollowerCount({
  required int visiblePubkeyCount,
  required int rawPubkeyCount,
  required int authoritativeFollowerCount,
}) =>
    max(0, authoritativeFollowerCount - (rawPubkeyCount - visiblePubkeyCount));

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
