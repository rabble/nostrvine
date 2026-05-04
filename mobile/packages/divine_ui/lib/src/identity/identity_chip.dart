// ABOUTME: Tappable chip for a verified NIP-39 external identity claim.
// ABOUTME: Caller passes localized platform name; widget handles styling/semantics.

import 'package:divine_ui/src/theme/vine_theme.dart';
import 'package:flutter/material.dart';

/// Renders a tappable verified-identity chip for a single platform.
///
/// `divine_ui` is l10n-free per the localization rule, so the caller is
/// responsible for passing an already-localized [platformDisplayName].
/// The semantic label is composed as
/// `Verified <platform> account: <handle>` so screen readers announce the
/// platform-specific verification state.
class IdentityChip extends StatelessWidget {
  /// Creates an [IdentityChip].
  const IdentityChip({
    required this.platformDisplayName,
    required this.identity,
    required this.onTap,
    this.icon,
    super.key,
  });

  /// Localized name of the platform (e.g. `GitHub`).
  final String platformDisplayName;

  /// Handle on the platform (e.g. `rabble`).
  final String identity;

  /// Invoked when the chip is tapped.
  final VoidCallback onTap;

  /// Optional leading icon — typically a platform glyph.
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Verified $platformDisplayName account: $identity',
      button: true,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 32),
        child: Material(
          color: VineTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: [
                  ?icon,
                  Text(
                    identity,
                    style: VineTheme.bodySmallFont(
                      color: VineTheme.lightText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
