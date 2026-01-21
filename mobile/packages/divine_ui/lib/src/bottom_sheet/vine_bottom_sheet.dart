// ABOUTME: Reusable bottom sheet component with Vine design system
// ABOUTME: Matches Figma design with drag handle, header, content area,
// ABOUTME: and optional input

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// A reusable bottom sheet component following Vine's design system.
///
/// Features:
/// - Drag handle for gesture indication
/// - Customizable header with title and trailing actions
/// - Content area (expanded or wrapped)
/// - Optional bottom input section
/// - Dark mode optimized with proper theming
///
/// This component is designed to be used with [showModalBottomSheet] and
/// [DraggableScrollableSheet] for consistent modal behavior across the app.
class VineBottomSheet extends StatelessWidget {
  /// Creates a [VineBottomSheet] with the given parameters.
  ///
  /// Set [expanded] to false for content that should wrap (not fill space).
  const VineBottomSheet({
    required this.body,
    this.title,
    this.trailing,
    this.bottomInput,
    this.expanded = true,
    super.key,
  });

  /// Optional title widget displayed in the header.
  /// When null, only the drag handle is shown.
  final Widget? title;

  /// The content widget to display in the bottom sheet.
  final Widget body;

  /// Optional trailing widget in header (e.g., badge, button)
  final Widget? trailing;

  /// Optional bottom input section (e.g., comment input)
  final Widget? bottomInput;

  /// Whether the body should expand to fill available space.
  /// Set to false for simple content that should wrap.
  final bool expanded;

  /// Shows the bottom sheet as a modal with proper configuration.
  ///
  /// Set [expanded] to false for content that should wrap (not fill space).
  static Future<T?> show<T>({
    required BuildContext context,
    required Widget body,
    Widget? title,
    Widget? trailing,
    Widget? bottomInput,
    bool expanded = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: expanded,
      backgroundColor: Colors.transparent,
      builder: (_) => VineBottomSheet(
        title: title,
        trailing: trailing,
        bottomInput: bottomInput,
        expanded: expanded,
        body: body,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: VineTheme.surfaceBackground,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
          children: [
            // Header with drag handle, title, and trailing actions
            VineBottomSheetHeader(title: title, trailing: trailing),
            if (title != null)
              const Divider(height: 2, color: VineTheme.outlinedDisabled),

            // Content area
            if (expanded) Expanded(child: body) else body,

            if (bottomInput != null)
              const Divider(height: 2, color: VineTheme.outlinedDisabled),

            // Optional bottom input
            ?bottomInput,
          ],
        ),
      ),
    );
  }
}
