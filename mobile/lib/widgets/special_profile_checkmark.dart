// ABOUTME: Decides which profiles carry the Divine team checkmark.
// ABOUTME: Keeps the team badge separate from generic NIP-05 validation.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/l10n/l10n.dart';

/// Whether [profile] carries the Divine team checkmark.
///
/// Matches on pubkey alone. A NIP-05 identifier is not an input: the name
/// server can reassign a handle, which would carry the checkmark to whoever
/// claims it next.
bool shouldShowSpecialProfileCheckmark(UserProfile? profile) {
  if (profile == null) return false;
  final pubkey = profile.pubkey.toLowerCase();
  return kDivineTeamPubkeys.contains(pubkey) ||
      kLegacyProfileCheckmarkPubkeys.contains(pubkey);
}

class SpecialProfileCheckmark extends StatelessWidget {
  const SpecialProfileCheckmark({
    super.key,
    this.iconSize = 10,
    this.padding = 2,
  });

  final double iconSize;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.profileBadgeCheckmarkTitle,
      container: true,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 4),
          child: Container(
            padding: EdgeInsets.all(padding),
            decoration: const BoxDecoration(
              color: VineTheme.info,
              shape: BoxShape.circle,
            ),
            child: DivineIcon(
              icon: DivineIconName.check,
              color: context.vineColors.primaryText,
              size: iconSize,
            ),
          ),
        ),
      ),
    );
  }
}
