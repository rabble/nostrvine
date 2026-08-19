// ABOUTME: One badge awardee — who they are, whether the award is pinned to
// ABOUTME: their profile, and the issuer's action to take the badge back.

import 'package:divine_ui/divine_ui.dart';
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
    this.showRevokeAction = false,
    this.onRevoke,
    super.key,
  });

  /// The awardee.
  final String pubkey;

  /// Whether they pinned the badge to their profile.
  ///
  /// Null when acceptance was not resolved for this recipient, in which case
  /// no status is claimed rather than showing a wrong one.
  final bool? isAccepted;

  /// Whether to offer taking the award back. Only the issuer can.
  final bool showRevokeAction;

  /// Called when the revoke action is used.
  ///
  /// Null while another mutation is in flight, which greys the action out
  /// rather than removing it — the same shape [showRevokeAction] keeps
  /// stable across rebuilds.
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: UserProfileTile(
                pubkey: pubkey,
                showFollowButton: false,
                // The enclosing sliver already pads to the screen inset; the
                // revoke button brings its own 48px tap target.
                padding: EdgeInsets.fromLTRB(
                  0,
                  12,
                  showRevokeAction ? 4 : 16,
                  12,
                ),
              ),
            ),
            if (showRevokeAction)
              // The button's own `Semantics` does not open a container, so
              // without this boundary the acceptance pill below merges into
              // its node and a screen reader reads the two as one control.
              Semantics(
                container: true,
                child: DivineIconButton(
                  icon: DivineIconName.userMinus,
                  type: DivineIconButtonType.ghostSecondary,
                  size: DivineIconButtonSize.small,
                  showShadow: false,
                  tooltip: context.l10n.badgeDetailRevokeAction,
                  semanticLabel: context.l10n.badgeDetailRevokeAction,
                  onPressed: onRevoke,
                ),
              ),
          ],
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
