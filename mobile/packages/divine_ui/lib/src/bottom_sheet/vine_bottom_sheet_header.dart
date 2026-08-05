// ABOUTME: Header component for VineBottomSheet
// ABOUTME: Displays title with optional trailing actions (badges, buttons)

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// Header component for [VineBottomSheet].
///
/// Combines drag handle and title section as per Figma design.
/// Uses Bricolage Grotesque bold font at 24px for title.
///
/// When a title is shown and only one of the leading/trailing slots is filled,
/// the empty side reserves the filled one's width so the title stays centered.
/// That slot widget is therefore built twice — keep [GlobalKey]s out of it.
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
    final leadingSlot = leadingAction ?? leading;
    final trailingSlot = trailingAction ?? trailing;
    final hasHeaderRow =
        hasTitle || leadingSlot != null || trailingSlot != null;

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
                    color: context.vineColors.disabled,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),

              Padding(
                padding: .only(bottom: hasHeaderRow ? 14 : 0),
                child: Row(
                  mainAxisAlignment: .spaceBetween,
                  spacing: 12,
                  children: [
                    if (leadingSlot != null)
                      leadingSlot
                    else if (hasTitle && trailingSlot != null)
                      _SlotMirror(trailingSlot),

                    if (hasTitle)
                      Flexible(
                        child: Center(
                          child: DefaultTextStyle(
                            style: VineTheme.titleMediumFont(
                              color: context.vineColors.onSurface,
                            ),
                            textAlign: .center,
                            child: title!,
                          ),
                        ),
                      )
                    else
                      const Spacer(),

                    if (trailingSlot != null)
                      trailingSlot
                    else if (hasTitle && leadingSlot != null)
                      _SlotMirror(leadingSlot),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Divider separating header from content
        if (showDivider)
          Divider(
            height: 2,
            thickness: 2,
            color: context.vineColors.surfaceContainer,
          ),
      ],
    );
  }
}

/// Reserves the width of the opposite header slot so the title stays centered
/// when only one side is filled.
///
/// A fixed-size box cannot do this: slot widgets size themselves, so a sort
/// chip is as wide as its current label and a [DivineIconButton] is 48px, not
/// the 40px a constant placeholder used to reserve. Mirroring the filled slot
/// always reserves exactly the right width. The copy is laid out but never
/// painted, focusable, tappable, or announced to screen readers.
class _SlotMirror extends StatelessWidget {
  const _SlotMirror(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Visibility(
      visible: false,
      maintainState: true,
      maintainAnimation: true,
      maintainSize: true,
      child: child,
    );
  }
}
