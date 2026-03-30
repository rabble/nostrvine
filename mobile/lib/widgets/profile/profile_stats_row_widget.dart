// ABOUTME: Stats column widget for profile page showing stat count + label
// ABOUTME: Displays animated stat values with loading states

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:openvine/utils/string_utils.dart';

/// Individual stat column widget for followers/following/likes/loops counts.
///
/// Numbers use Bricolage Grotesque ExtraBold 20/28 (matching Figma).
/// Labels use bodySmall (Inter 12/16). Both are center-aligned.
class ProfileStatColumn extends StatelessWidget {
  const ProfileStatColumn({
    required this.count,
    required this.label,
    required this.isLoading,
    this.onTap,
    super.key,
  });

  final int? count;
  final String label;
  final bool isLoading;
  final VoidCallback? onTap;

  /// Bricolage Grotesque ExtraBold 20/28 — matches the Figma stat number style.
  static TextStyle _numberStyle({Color color = VineTheme.whiteText}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        height: 28 / 20,
        letterSpacing: 0,
        color: color,
      );

  @override
  Widget build(BuildContext context) {
    final column = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Text(
            isLoading || count == null
                ? '—'
                : StringUtils.formatCompactNumber(count!),
            key: ValueKey(isLoading ? 'loading' : count),
            style: _numberStyle(
              color: isLoading || count == null
                  ? VineTheme.onSurfaceMuted
                  : VineTheme.whiteText,
            ),
          ),
        ),
        Text(
          label,
          style: VineTheme.bodySmallFont(color: VineTheme.onSurfaceVariant),
        ),
      ],
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: column,
        ),
      );
    }

    return column;
  }
}
