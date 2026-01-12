// ABOUTME: Header component for VineBottomSheet
// ABOUTME: Displays title with optional trailing actions (badges, buttons)

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:openvine/theme/vine_theme.dart';

/// Header component for [VineBottomSheet].
///
/// Combines drag handle and title section as per Figma design.
/// Uses Bricolage Grotesque bold font at 24px for title.
class VineBottomSheetHeader extends StatelessWidget {
  const VineBottomSheetHeader({required this.title, this.trailing, super.key});

  /// Title text displayed on the left
  final String title;

  /// Optional trailing widget on the right (e.g., badge, button)
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, right: 24, top: 8, bottom: 16),
      child: Column(
        children: [
          // Drag handle
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: VineTheme.onSurfaceMuted,
              borderRadius: BorderRadius.circular(100),
            ),
          ),

          const SizedBox(height: 12),

          // Title + trailing actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Title
              Text(
                title,
                style: GoogleFonts.bricolageGrotesque(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  height: 32 / 24,
                  color: VineTheme.onSurface,
                ),
              ),

              // Trailing widget (badges, buttons, etc.)
              if (trailing != null) SizedBox(width: 62, child: trailing),
            ],
          ),
        ],
      ),
    );
  }
}

/// Badge widget for showing count of new items (e.g., "3 new")
class VineBottomSheetBadge extends StatelessWidget {
  const VineBottomSheetBadge({required this.text, super.key});

  /// Badge text (e.g., "3 new", "12 unread")
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 26,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: VineTheme.tabIndicatorGreen,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          text,
          style: GoogleFonts.bricolageGrotesque(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            height: 20 / 14,
            color: Colors.white,
            letterSpacing: 0.1,
          ),
        ),
      ),
    );
  }
}
