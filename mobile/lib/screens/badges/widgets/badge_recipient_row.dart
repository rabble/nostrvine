// ABOUTME: One badge awardee — who they are, and whether the award is pinned
// ABOUTME: to their profile. Shared by the issued list and the badge detail.

import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/badges/widgets/badge_status_pill.dart';
import 'package:openvine/widgets/user_profile_tile.dart';

/// Renders a badge recipient with their acceptance status.
///
/// The status sits under the profile row rather than beside it: the labels
/// are full sentences, and next to a display name they would be squeezed to
/// nothing on a narrow screen.
class BadgeRecipientRow extends StatelessWidget {
  /// Creates the row for [pubkey].
  const BadgeRecipientRow({
    required this.pubkey,
    required this.isAccepted,
    super.key,
  });

  /// The awardee.
  final String pubkey;

  /// Whether they pinned the badge to their profile.
  ///
  /// Null when acceptance was not resolved for this recipient, in which case
  /// no status is claimed rather than showing a wrong one.
  final bool? isAccepted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UserProfileTile(
          pubkey: pubkey,
          showFollowButton: false,
          // The enclosing sliver already pads to the screen inset.
          padding: const EdgeInsets.fromLTRB(0, 12, 16, 12),
        ),
        if (isAccepted case final accepted?)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: BadgeStatusPill(
              label: accepted
                  ? context.l10n.badgesRecipientAcceptedStatus
                  : context.l10n.badgesRecipientWaitingStatus,
              accepted: accepted,
            ),
          ),
      ],
    );
  }
}
