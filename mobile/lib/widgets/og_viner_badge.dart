// ABOUTME: Compact badge for accounts known locally as original Viners.
// ABOUTME: Render-only widget used beside names after cache lookup.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/profile_badge_explanation_dialog.dart';

class OgVinerBadge extends StatelessWidget {
  const OgVinerBadge({super.key, this.size = 14});

  final double size;

  @override
  Widget build(BuildContext context) {
    final dimension = DivineIcon.scaleSize(context, size);
    return Semantics(
      button: true,
      label: context.l10n.profileBadgeOgVinerSemanticLabel,
      container: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showProfileBadgeExplanationDialog(
          context,
          ProfileBadgeExplanationType.ogViner,
        ),
        child: ExcludeSemantics(
          child: Container(
            margin: const EdgeInsetsDirectional.only(start: 4),
            width: dimension,
            height: dimension,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: VineTheme.primary,
              shape: BoxShape.circle,
            ),
            // The glyph is a logo mark sized off the circle, not readable text:
            // `dimension` already carries the text scale, so scaling the font
            // again would square the factor. `FittedBox` stays as a guard
            // against font-fallback metrics overflowing the circle.
            child: FittedBox(
              child: Text(
                'V',
                textAlign: TextAlign.center,
                textScaler: TextScaler.noScaling,
                style: TextStyle(
                  color: VineTheme.onPrimary,
                  fontFamily: 'Pacifico',
                  fontSize: dimension * 0.85,
                  height: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
