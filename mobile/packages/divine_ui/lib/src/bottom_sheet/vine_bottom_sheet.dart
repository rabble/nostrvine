// ABOUTME: Reusable bottom sheet component with Vine design system
// ABOUTME: Supports both scrollable (draggable) and fixed modes

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// A reusable bottom sheet component following Vine's design system.
///
/// Features:
/// - Drag handle for gesture indication
/// - Customizable header with title and trailing actions
/// - Two modes: scrollable (draggable) and fixed
/// - Optional bottom input section
/// - Dark mode optimized with proper theming
///
/// Use [VineBottomSheet.show] to display the sheet:
/// - `scrollable: true` (default) - Draggable sheet with scrollable content
/// - `scrollable: false` - Fixed height based on content, not draggable
class VineBottomSheet extends StatelessWidget {
  /// Creates a [VineBottomSheet] with the given parameters.
  const VineBottomSheet({
    this.scrollable = true,
    this.title,
    this.scrollController,
    this.children,
    this.body,
    this.trailing,
    this.bottomInput,
    super.key,
  }) : assert(
         children != null || body != null,
         'Provide either children or body',
       );

  /// Whether the sheet is scrollable/draggable.
  ///
  /// When true (default), the sheet uses DraggableScrollableSheet and content
  /// is scrollable. When false, the sheet has fixed height based on content.
  final bool scrollable;

  /// Optional title widget displayed in the header
  final Widget? title;

  /// Scroll controller from DraggableScrollableSheet (used when scrollable)
  final ScrollController? scrollController;

  /// Content widgets to display
  final List<Widget>? children;

  /// Custom body widget (alternative to children)
  final Widget? body;

  /// Optional trailing widget in header (e.g., badge, button)
  final Widget? trailing;

  /// Optional bottom input section (e.g., comment input)
  final Widget? bottomInput;

  /// Shows the bottom sheet as a modal.
  ///
  /// Set [scrollable] to false for fixed-height sheets (e.g., action menus).
  /// The size parameters are only used when [scrollable] is true.
  static Future<T?> show<T>({
    required BuildContext context,
    required List<Widget> children,
    bool scrollable = true,
    Widget? title,
    Widget? body,
    Widget? trailing,
    Widget? bottomInput,
    double initialChildSize = 0.6,
    double minChildSize = 0.3,
    double maxChildSize = 0.9,
  }) {
    if (scrollable) {
      // Draggable/scrollable mode
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
    } else {
      // Fixed mode
      return showModalBottomSheet<T>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => VineBottomSheet(
          scrollable: false,
          title: title,
          trailing: trailing,
          bottomInput: bottomInput,
          body: body,
          children: children,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(VineTheme.bottomSheetBorderRadius),
        topRight: Radius.circular(VineTheme.bottomSheetBorderRadius),
      ),
      child: ColoredBox(
        color: VineTheme.surfaceBackground,
        child: scrollable ? _buildScrollableContent() : _buildFixedContent(),
      ),
    );
  }

  Widget _buildScrollableContent() {
    return Column(
      children: [
        // Header with drag handle, title, trailing actions, and divider
        VineBottomSheetHeader(title: title, trailing: trailing),

        // Scrollable content area
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
        ?bottomInput,
      ],
    );
  }

  Widget _buildFixedContent() {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with drag handle and divider
          VineBottomSheetHeader(title: title, trailing: trailing),

          // Fixed content with minimum height for 2 entries (2 × 56px)
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 112),
            child:
                body ??
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: children!,
                ),
          ),

          if (bottomInput != null)
            const Divider(height: 2, color: VineTheme.outlinedDisabled),

          // Optional bottom input
          ?bottomInput,
        ],
      ),
    );
  }
}
