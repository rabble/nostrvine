// ABOUTME: Compact badge for accounts known locally as original Viners.
// ABOUTME: Render-only widget used beside names after cache lookup.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';

class OgVinerBadge extends StatelessWidget {
  const OgVinerBadge({super.key, this.size = 14});

  final double size;

  @override
  Widget build(BuildContext context) {
    final dimension = MediaQuery.textScalerOf(context).scale(size);
    return Semantics(
      label: context.l10n.ogVinerBadgeLabel,
      container: true,
      child: Container(
        margin: const EdgeInsetsDirectional.only(start: 4),
        width: dimension,
        height: dimension,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: VineTheme.primary,
          shape: BoxShape.circle,
        ),
        child: FittedBox(
          child: Text(
            'V',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: VineTheme.onPrimary,
              fontFamily: 'Pacifico',
              fontSize: dimension * 0.85,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}
