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
    this.showDragHandle = true,
    this.padding,
    this.leadingAction,
    this.trailingAction,
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

  /// Whether to show the drag handle at the top of the header.
  ///
  /// Defaults to true.
  final bool showDragHandle;

  /// Optional padding override for the inner content area.
  ///
  /// Defaults to `EdgeInsetsDirectional.only(start: 24, end: 24, top: 8)`.
  final EdgeInsetsGeometry? padding;

  /// Optional icon button displayed on the left side of the header.
  final DivineIconButton? leadingAction;

  /// Optional icon button displayed on the right side of the header.
  final DivineIconButton? trailingAction;

  @override
  Widget build(BuildContext context) {
    final hasTitle = title != null && title is! SizedBox;
    final hasLeadingSlot = leadingAction != null || leading != null;
    final hasTrailingSlot = trailingAction != null || trailing != null;
    final hasHeaderRow = hasTitle || hasLeadingSlot || hasTrailingSlot;
    const placeholder = SizedBox(width: 40, height: 40);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding:
              padding ??
              (const EdgeInsetsDirectional.only(start: 16, end: 16, top: 8)),
          child: Column(
            spacing: 20,
            children: [
              // Drag handle
              if (showDragHandle)
                Container(
                  width: 64,
                  height: 4,
                  decoration: BoxDecoration(
                    color: VineTheme.alphaLight25,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),

              Padding(
                padding: .only(bottom: hasHeaderRow ? 14 : 0),
                child: Row(
                  mainAxisAlignment: .spaceBetween,
                  spacing: 12,
                  children: [
                    if (leadingAction != null)
                      leadingAction!
                    else if (leading != null)
                      leading!
                    else if (hasTrailingSlot)
                      placeholder,

                    if (hasTitle)
                      Flexible(
                        child: Center(
                          child: DefaultTextStyle(
                            style: VineTheme.titleMediumFont(),
                            textAlign: .center,
                            child: title!,
                          ),
                        ),
                      )
                    else
                      const Spacer(),

                    if (trailingAction != null)
                      trailingAction!
                    else if (trailing != null)
                      trailing!
                    else if (hasLeadingSlot)
                      placeholder,
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
