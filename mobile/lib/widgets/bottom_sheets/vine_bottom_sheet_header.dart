// ABOUTME: Header component for VineBottomSheet
// ABOUTME: Displays title with optional trailing actions (badges, buttons)

import 'package:flutter/material.dart';
import 'package:openvine/theme/vine_theme.dart';

/// Header component for [VineBottomSheet].
///
/// Combines drag handle and title section as per Figma design.
/// Uses Bricolage Grotesque bold font at 24px for title.
class VineBottomSheetHeader extends StatelessWidget {
  const VineBottomSheetHeader({required this.title, this.trailing, super.key});

  /// Title widget displayed on the left
  final Widget title;

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
            width: 64,
            height: 4,
            decoration: BoxDecoration(
              color: VineTheme.alphaLight25,
              borderRadius: BorderRadius.circular(8),
            ),
          ),

          const SizedBox(height: 20),

          // Title (centered) + optional trailing actions
          Stack(
            alignment: Alignment.center,
            children: [
              // Centered title
              Center(child: title),

              // Trailing widget positioned on the right
              if (trailing != null)
                Positioned(
                  right: 0,
                  child: SizedBox(width: 62, child: trailing),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
