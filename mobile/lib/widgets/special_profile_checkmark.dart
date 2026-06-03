// ABOUTME: Hosts explicit exceptions for profile checkmark display.
// ABOUTME: Keeps special-case badges separate from generic NIP-05 validation.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart';

const _specialProfileHosts = {
  'kirstenswasey.divine.video',
  'rabble.divine.video',
};

const _specialProfilePubkeys = {
  'aa50001ef150418f30f62f827399d5c26a5ade52ab45ca4849f99b1726bb47b4',
};

bool shouldShowSpecialProfileCheckmark(UserProfile? profile) {
  if (profile == null) return false;
  return _specialProfilePubkeys.contains(profile.pubkey.toLowerCase()) ||
      _matchesSpecialProfile(profile.nip05) ||
      _matchesSpecialProfile(profile.displayNip05);
}

bool _matchesSpecialProfile(String? identifier) {
  final host = _hostFromProfileIdentifier(identifier);
  return _specialProfileHosts.contains(host);
}

String? _hostFromProfileIdentifier(String? identifier) {
  if (identifier == null) return null;
  final value = identifier.trim().toLowerCase();
  if (value.isEmpty) return null;

  final uri = Uri.tryParse(value);
  if ((uri?.hasScheme ?? false) && uri!.host.isNotEmpty) {
    return uri.host;
  }

  final atIndex = value.indexOf('@');
  final hostLikeValue = atIndex == -1 ? value : value.substring(atIndex + 1);
  return hostLikeValue.split('/').first;
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
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 4),
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: const BoxDecoration(
          color: VineTheme.info,
          shape: BoxShape.circle,
        ),
        child: DivineIcon(
          icon: DivineIconName.check,
          color: VineTheme.whiteText,
          size: iconSize,
        ),
      ),
    );
  }
}
