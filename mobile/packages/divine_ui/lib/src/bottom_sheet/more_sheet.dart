// ABOUTME: Simple non-scrollable bottom sheet for action menus
// ABOUTME: Fixed height based on content, not draggable

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// A simple non-scrollable bottom sheet for action menus.
///
/// Unlike [VineBottomSheet], this component:
/// - Has fixed height based on content
/// - Is not draggable or scrollable
/// - Is optimized for simple action menus with 1-4 items
///
/// Use [MoreSheet.show] to display the sheet.
class MoreSheet extends StatelessWidget {
  /// Creates a [MoreSheet] with the given children.
  const MoreSheet({
    required this.children,
    this.title,
    super.key,
  });

  /// Optional title widget displayed in the header
  final Widget? title;

  /// Action items to display in the sheet
  final List<Widget> children;

  /// Shows the more sheet as a modal
  static Future<T?> show<T>({
    required BuildContext context,
    required List<Widget> children,
    Widget? title,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => MoreSheet(
        title: title,
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(VineTheme.bottomSheetBorderRadius),
        topRight: Radius.circular(VineTheme.bottomSheetBorderRadius),
      ),
      child: Container(
        color: VineTheme.surfaceBackground,
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with drag handle and divider
              VineBottomSheetHeader(title: title),

              // Action items with minimum height for 2 entries (2 × 56px)
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 112),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: children,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
