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
class FullscreenSponsorDisclosure extends StatelessWidget {
  const FullscreenSponsorDisclosure({required this.sponsorName, super.key});

  final String sponsorName;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: VineTheme.scrim50,
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
