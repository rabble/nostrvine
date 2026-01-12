// ABOUTME: Reusable bottom sheet component with Vine design system
// ABOUTME: Matches Figma design with drag handle, header, content area, and optional input

import 'package:flutter/material.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/widgets/bottom_sheets/vine_bottom_sheet_header.dart';

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
  const VineBottomSheet({
    required this.title,
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

  /// Title displayed in the header
  final String title;

  /// Scroll controller from DraggableScrollableSheet (required if using children)
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
    required String title,
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
          children: children,
          body: body,
        ),
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
      child: Column(
        children: [
          // Header with drag handle, title, and trailing actions
          VineBottomSheetHeader(title: title, trailing: trailing),

          // Content area (either managed ListView or custom body)
          Expanded(
            child:
                body ??
                ListView(
                  controller: scrollController!,
                  padding: EdgeInsets.zero,
                  children: children!,
                ),
          ),

          // Optional bottom input
          if (bottomInput != null) bottomInput!,
        ],
      ),
    );
  }
}
