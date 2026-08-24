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
/// The scrim matches the app bar's own icon buttons ([VineTheme.scrim15], the
/// `0x26000000` those buttons use in transparent mode) so the disclosure reads
/// as part of the top chrome rather than as something dropped on the video.
///
/// That fill was chosen for an icon, and an icon is a thick shape that carries
/// itself; text is thin strokes. At 15% the scrim measures 1.4:1 against a
/// pure-white shot, so it is [_glyphShadows], not the box, that keeps this
/// readable over a bright frame.
///
/// It is deliberately small and quiet rather than sized like a control. This
/// is the one chrome layer that survives immersive viewing, so it is the only
/// thing on screen while the viewer holds the video — heavy enough to read on
/// any frame, light enough not to become the subject.
class FullscreenSponsorDisclosure extends StatelessWidget {
  const FullscreenSponsorDisclosure({required this.sponsorName, super.key});

  final String sponsorName;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: VineTheme.scrim15,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text(
            context.l10n.exploreFeaturedSponsoredBy(sponsorName),
            style: VineTheme.bodyTinyFont(
              color: VineTheme.whiteText,
            ).copyWith(shadows: _glyphShadows),
          ),
        ),
      ),
    );
  }
}

/// Carries the legibility the chrome-matched scrim does not provide on its own.
///
/// Contrast against a scrim is one number for the whole box; a shadow works at
/// the glyph edge instead, which is where reading actually happens. The tight
/// shadow separates the letters from whatever sits directly behind them and
/// the wider one lifts the whole word off a bright frame.
///
/// Deliberately heavier than the single `shadow25` blur that `caption_pill`
/// uses over the same video. A caption that loses a word to a bright frame is
/// a cosmetic problem; a disclosure that does has stopped disclosing.
const _glyphShadows = <Shadow>[
  Shadow(color: VineTheme.scrim80, blurRadius: 4, offset: Offset(0, 1)),
  Shadow(color: VineTheme.scrim50, blurRadius: 12),
];
