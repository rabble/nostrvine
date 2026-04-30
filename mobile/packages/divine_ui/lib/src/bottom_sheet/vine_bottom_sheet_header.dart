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
  /// leading and trailing widgets.
  const VineBottomSheetHeader({
    this.title,
    this.leading,
    this.trailing,
    this.showDivider = true,
    this.padding,
    super.key,
  });

  /// Optional title widget displayed in the center
  final Widget? title;

  /// Optional leading widget on the left (e.g., close button)
  final Widget? leading;

  /// Optional trailing widget on the right (e.g., badge, button)
  final Widget? trailing;

  /// Whether to show the divider below the header.
  ///
  /// Defaults to true.
  final bool showDivider;

  /// Optional padding override for the inner content area.
  ///
  /// Defaults to `EdgeInsetsDirectional.only(start: 24, end: 24, top: 8)`.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final hasTitle = title != null && title is! SizedBox;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding:
              padding ??
              const EdgeInsetsDirectional.only(start: 24, end: 24, top: 8),
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
                // Title (centered) + optional leading/trailing actions
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: 40),
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

                        // Leading widget aligned to the center-left
                        if (leading != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: leading,
                          ),

                        // Trailing widget aligned to the center-right
                        if (trailing != null)
                          Align(
                            alignment: Alignment.centerRight,
                            child: trailing,
                          ),
                      ],
                    ),
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
