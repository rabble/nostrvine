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
/// - Scrollable content area (or custom body)
/// - Optional bottom input section
/// - Dark mode optimized with proper theming
///
/// This component is designed to be used with [showModalBottomSheet] and
/// [DraggableScrollableSheet] for consistent modal behavior across the app.
class VineBottomSheet extends StatelessWidget {
  /// Creates a [VineBottomSheet] with the given parameters.
  const VineBottomSheet({
    this.title,
    this.scrollController,
    this.children,
    this.body,
    this.trailing,
    this.bottomInput,
    super.key,
  }) : assert(
         (children != null && body == null) ||
             (children == null && body != null),
         'Provide either children or body, not both',
       );

  /// Optional title widget displayed in the header
  final Widget? title;

  /// Scroll controller from DraggableScrollableSheet (required if using
  /// children)
  final ScrollController? scrollController;

  /// Content widgets to display in a scrollable ListView
  /// Use this for simple lists of widgets
  final List<Widget>? children;

  /// Custom body widget that manages its own scrolling
  /// Use this when you need custom scroll behavior (e.g., ListView.builder)
  final Widget? body;

  /// Optional trailing widget in header (e.g., badge, button)
  final Widget? trailing;

  /// Optional bottom input section (e.g., comment input)
  final Widget? bottomInput;

  /// Shows the bottom sheet as a modal with proper configuration
  static Future<T?> show<T>({
    required BuildContext context,
    Widget? title,
    List<Widget>? children,
    Widget? body,
    Widget? trailing,
    Widget? bottomInput,
    double initialChildSize = 0.6,
    double minChildSize = 0.3,
    double maxChildSize = 0.9,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: initialChildSize,
        minChildSize: minChildSize,
        maxChildSize: maxChildSize,
        builder: (context, scrollController) => VineBottomSheet(
          title: title,
          scrollController: scrollController,
          trailing: trailing,
          bottomInput: bottomInput,
          body: body,
          children: children,
        ),
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
        child: Column(
          children: [
            // Header with drag handle, title, trailing actions, and divider
            VineBottomSheetHeader(title: title, trailing: trailing),

            // Content area
            Expanded(
              child:
                  body ??
                  ListView(
                    controller: scrollController,
                    padding: EdgeInsets.zero,
                    children: children!,
                  ),
            ),
            if (bottomInput != null)
              const Divider(height: 2, color: VineTheme.outlinedDisabled),

            // Optional bottom input
            if (bottomInput != null) bottomInput!,
          ],
        ),
      ),
    );
  }
}
