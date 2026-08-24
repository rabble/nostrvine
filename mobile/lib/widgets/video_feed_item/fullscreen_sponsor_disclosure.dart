// ABOUTME: Readable sponsorship disclosure for fullscreen video feeds.
// ABOUTME: Uses fixed over-video chrome and allows text to wrap without clipping.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';

/// A scrim-backed sponsorship label rendered over fullscreen video.
///
/// [sponsorName] must already be sanitized and clamped by the launching
/// surface. The text deliberately has no line ceiling so the disclosure stays
/// complete at large system text sizes.
///
/// The scrim is sized for the worst frame rather than the average one: a
/// disclosure has to stay readable over a blown-out white shot, not just over
/// the dark footage most reels open on. At [VineTheme.scrim80] white text
/// clears 12.6:1 against a pure-white frame; the 50% scrim this started at
/// was 4.0:1, under the 4.5:1 bar for 12px text.
class FullscreenSponsorDisclosure extends StatelessWidget {
  const FullscreenSponsorDisclosure({required this.sponsorName, super.key});

  final String sponsorName;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: VineTheme.scrim80,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            context.l10n.exploreFeaturedSponsoredBy(sponsorName),
            style: VineTheme.labelMediumFont(color: VineTheme.whiteText),
          ),
        ),
      ),
    );
  }
}
