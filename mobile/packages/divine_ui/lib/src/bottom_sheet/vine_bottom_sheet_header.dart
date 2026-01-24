// ABOUTME: Header component for VineBottomSheet
// ABOUTME: Displays title with optional trailing actions (badges, buttons)

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// Header component for [VineBottomSheet].
///
/// Combines drag handle and title section as per Figma design.
/// Uses Bricolage Grotesque bold font at 24px for title.
class VineBottomSheetHeader extends StatelessWidget {
  /// Creates a [VineBottomSheetHeader] with the given title and optional
  /// trailing widget.
  const VineBottomSheetHeader({
    this.title,
    this.trailing,
    this.showDivider = true,
    super.key,
  });

  /// Optional title widget displayed in the center
  final Widget? title;

  /// Optional trailing widget on the right (e.g., badge, button)
  final Widget? trailing;

  /// Whether to show the divider below the header.
  ///
  /// Defaults to true.
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final hasTitle = title != null && title is! SizedBox;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 24, right: 24, top: 8),
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

              if (hasTitle)
                // Title (centered) + optional trailing actions
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Centered title
                      Center(
                        child: DefaultTextStyle(
                          style: VineTheme.titleMediumFont(),
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
                ),
            ],
          ),
        ),

        // Divider separating header from content
        if (showDivider)
          const Divider(
            height: 2,
            thickness: 2,
            color: VineTheme.outlinedDisabled,
          ),
      ],
    );
  }
}
