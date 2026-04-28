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
                padding: .only(
                  bottom:
                      hasTitle ||
                          leadingAction != null ||
                          leading != null ||
                          trailing != null ||
                          trailingAction != null
                      ? 14
                      : 0,
                ),
                child: Row(
                  mainAxisAlignment: .spaceBetween,
                  spacing: 12,
                  children: [
                    if (leadingAction != null)
                      leadingAction!
                    else if (leading != null)
                      leading!
                    else if (trailingAction != null || trailing != null)
                      IgnorePointer(
                        child: Opacity(
                          opacity: 0,
                          child: trailingAction ?? trailing,
                        ),
                      ),

                    if (hasTitle)
                      // Title (centered) + optional trailing actions
                      Flexible(
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Centered title
                            Center(
                              child: DefaultTextStyle(
                                style: VineTheme.titleMediumFont(),
                                textAlign: .center,
                                child: title!,
                              ),
                            ),

                            // Trailing widget positioned on the right
                            if (trailing != null)
                              Positioned(right: 0, child: trailing!),
                          ],
                        ),
                      ),

                    if (trailingAction != null)
                      trailingAction!
                    else if (trailing != null)
                      trailing!
                    else if (leadingAction != null)
                      IgnorePointer(
                        child: Opacity(opacity: 0, child: leadingAction),
                      )
                    else if (leading != null)
                      IgnorePointer(child: Opacity(opacity: 0, child: leading)),
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
