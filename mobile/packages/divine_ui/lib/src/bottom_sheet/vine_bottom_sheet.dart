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
  ///
  /// Set [expanded] to false for content that should wrap (not fill space).
  const VineBottomSheet({
    this.scrollable = true,
    this.title,
    this.contentTitle,
    this.scrollController,
    this.children,
    this.body,
    this.trailing,
    this.bottomInput,
    this.expanded = true,
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

  /// Optional title widget displayed in the header (above divider)
  final Widget? title;

  /// Optional title displayed in the content area (below divider)
  ///
  /// Styled with titleMedium font in onSurface color.
  final String? contentTitle;

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

  /// Whether the body should expand to fill available space.
  /// Set to false for simple content that should wrap.
  final bool expanded;

  /// Shows the bottom sheet as a modal.
  ///
  /// Set [scrollable] to false for fixed-height sheets (e.g., action menus).
  /// The size parameters are only used when [scrollable] is true.
  static Future<T?> show<T>({
    required BuildContext context,
    List<Widget>? children,
    bool scrollable = true,
    Widget? title,
    String? contentTitle,
    Widget? body,
    Widget? trailing,
    Widget? bottomInput,
    bool expanded = true,
    bool? isScrollControlled,
    double initialChildSize = 0.6,
    double minChildSize = 0.3,
    double maxChildSize = 0.9,
  }) {
    assert(
      children != null || body != null,
      'Provide either children or body to VineBottomSheet.show',
    );
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
            contentTitle: contentTitle,
            scrollController: scrollController,
            trailing: trailing,
            bottomInput: bottomInput,
            expanded: expanded,
            body: body,
            children: children,
          ),
        ),
      );
    } else {
      // Fixed mode
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: isScrollControlled ?? expanded,
        backgroundColor: Colors.transparent,
        builder: (_) => VineBottomSheet(
          scrollable: false,
          title: title,
          contentTitle: contentTitle,
          trailing: trailing,
          bottomInput: bottomInput,
          expanded: expanded,
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

        // Scrollable content area (contentTitle is first element inside)
        Expanded(
          child:
              body ??
              ListView(
                controller: scrollController,
                padding: EdgeInsets.zero,
                children: [
                  // Optional content title (56px total height)
                  if (contentTitle != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          contentTitle!,
                          style: VineTheme.titleMediumFont(
                            color: VineTheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ...children!,
                ],
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

          // Fixed content area with minimum height for menu entries (2 × 56px)
          ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 112),
            child:
                body ??
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Optional content title (56px total height)
                    if (contentTitle != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            contentTitle!,
                            style: VineTheme.titleMediumFont(
                              color: VineTheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ...children!,
                  ],
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
