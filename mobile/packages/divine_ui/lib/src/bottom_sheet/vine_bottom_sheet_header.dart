// ABOUTME: Header component for VineBottomSheet
// ABOUTME: Displays title with optional trailing actions (badges, buttons)

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// Header component for [VineBottomSheet].
///
/// Combines drag handle and optional title section as per Figma design.
/// Uses Bricolage Grotesque bold font at 24px for title.
/// When title is null, only the drag handle is displayed.
class VineBottomSheetHeader extends StatelessWidget {
  /// Creates a [VineBottomSheetHeader] with an optional title and trailing
  /// widget.
  const VineBottomSheetHeader({this.title, this.trailing, super.key});

  /// Optional title widget displayed centered below the drag handle.
  final Widget? title;

  /// Optional trailing widget on the right (e.g., badge, button)
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 8,
        bottom: title != null ? 16 : 24,
      ),
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

          // Title section (only shown when title is provided)
          if (title != null) ...[
            const SizedBox(height: 20),

            // Title (centered) + optional trailing actions
            Stack(
              alignment: Alignment.center,
              children: [
                // Centered title
                Center(
                  child: DefaultTextStyle(
                    style: VineTheme.titleFont(
                      fontSize: 18,
                      height: 1.33,
                      letterSpacing: 0.15,
                    ),
                    child: title!,
                  ),
                ),

                // Trailing widget positioned on the right
                if (trailing != null)
                  Positioned(
                    right: 0,
                    child: SizedBox(width: 62, child: trailing),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
