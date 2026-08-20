// ABOUTME: Compact badge for accounts that beta-tested Divine before launch.
// ABOUTME: Render-only widget used beside names after a roster lookup.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';

class OgBetaBadge extends StatelessWidget {
  const OgBetaBadge({super.key, this.size = 14, this.leadingGap = 4});

  final double size;
  final double leadingGap;

  @override
  Widget build(BuildContext context) {
    final dimension = DivineIcon.scaleSize(context, size);
    return Semantics(
      label: context.l10n.ogBetaTesterBadgeLabel,
      container: true,
      child: ExcludeSemantics(
        child: Container(
          margin: EdgeInsetsDirectional.only(start: leadingGap),
          width: dimension,
          height: dimension,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: VineTheme.primary,
            shape: BoxShape.circle,
          ),
          // The glyph is a logo mark sized off the circle, not readable text:
          // `dimension` already carries the text scale, so scaling the font
          // again would square the factor. `FittedBox` keeps the two letters
          // inside the circle whatever the font fallback metrics turn out to
          // be, and the inset stops them touching the rim.
          child: Padding(
            padding: EdgeInsets.all(dimension * 0.16),
            child: FittedBox(
              child: Text(
                'OG',
                textAlign: TextAlign.center,
                textScaler: TextScaler.noScaling,
                style:
                    VineTheme.labelSmallFont(
                      color: VineTheme.onPrimary,
                    ).copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: dimension * 0.6,
                      letterSpacing: -0.5,
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
