// ABOUTME: Pubkey allowlist that drives profile checkmark display.
// ABOUTME: Keeps special-case badges separate from generic NIP-05 validation.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';

/// Accounts that carry the Divine profile checkmark, identified by pubkey.
///
/// Pubkey-only on purpose. Matching a NIP-05 host instead ties the checkmark
/// to a name the server can reassign, so it would follow the handle to
/// whoever claims it next rather than staying with the account it was
/// granted to.
const _specialProfilePubkeys = {
  'aa50001ef150418f30f62f827399d5c26a5ade52ab45ca4849f99b1726bb47b4',
};

bool shouldShowSpecialProfileCheckmark(UserProfile? profile) {
  if (profile == null) return false;
  return _specialProfilePubkeys.contains(profile.pubkey.toLowerCase());
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
