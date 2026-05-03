// ABOUTME: Compact badge for accounts known locally as original Viners.
// ABOUTME: Render-only widget used beside names after cache lookup.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

class OgVinerBadge extends StatelessWidget {
  const OgVinerBadge({super.key, this.size = 14});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'OG Viner',
      container: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: 4),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: VineTheme.primary,
            shape: BoxShape.circle,
          ),
          child: Text(
            'V',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: VineTheme.onPrimary,
              fontFamily: 'Pacifico',
              fontSize: size * 0.85,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
