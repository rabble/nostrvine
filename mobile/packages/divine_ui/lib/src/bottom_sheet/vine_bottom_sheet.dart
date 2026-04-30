// ABOUTME: Reusable bottom sheet component with Vine design system
// ABOUTME: Supports both scrollable (draggable) and fixed modes

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
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
    this.showHeader = true,
    this.title,
    this.contentTitle,
    this.scrollController,
    this.children,
    this.body,
    this.buildScrollBody,
    this.trailing,
    this.onComplete,
    this.bottomInput,
    this.expanded = true,
    this.showHeaderDivider = true,
    this.headerPadding,
    super.key,
  }) : assert(
         children != null || body != null || buildScrollBody != null,
         'Provide either children, body, or buildScrollBody',
       ),
       assert(
         buildScrollBody == null || scrollController != null,
         'scrollController must be provided when using buildScrollBody',
       );

  /// Whether the sheet is scrollable/draggable.
  ///
  /// When true (default), the sheet uses DraggableScrollableSheet and content
  /// is scrollable. When false, the sheet has fixed height based on content.
  final bool scrollable;

  /// Whether to show the full header (drag handle + title + divider).
  ///
  /// When false, only the drag handle is shown and content starts immediately
  /// below it. Useful for sheets where the title is part of the scrollable
  /// content rather than pinned in a header bar.
  final bool showHeader;

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

  /// Builder function for custom scrollable content.
  ///
  /// Use this when you need direct access to the [ScrollController]
  /// for custom scroll behavior. Requires [scrollController] to be provided.
  final Widget Function(ScrollController scrollController)? buildScrollBody;

  /// Optional trailing widget in header (e.g., badge, button)
  final Widget? trailing;

  /// Optional callback invoked when the complete/check button is tapped.
  ///
  /// When provided, the header automatically shows a close (X) button on the
  /// left and a check button on the right. The close button dismisses the
  /// sheet; the check button awaits [onComplete] then dismisses the sheet.
  /// The check button shows a loading indicator while [onComplete] is running.
  final AsyncCallback? onComplete;

  /// Optional bottom input section (e.g., comment input)
  final Widget? bottomInput;

  /// Whether the body should expand to fill available space.
  /// Set to false for simple content that should wrap.
  final bool expanded;

  /// Whether to show the divider below the header.
  ///
  /// Defaults to true.
  final bool showHeaderDivider;

  /// Optional padding override forwarded to [VineBottomSheetHeader].
  final EdgeInsetsGeometry? headerPadding;

  /// Shows the bottom sheet as a modal.
  ///
  /// Set [scrollable] to false for fixed-height sheets (e.g., action menus).
  /// The size parameters are only used when [scrollable] is true.
  ///
  /// When [scrollable] is true, [snap] and [snapSizes] are forwarded to the
  /// underlying [DraggableScrollableSheet] to enable snap-to-position
  /// behaviour between user-defined fractions of the viewport.
  ///
  /// [useRootNavigator] is forwarded to [showModalBottomSheet]; set it to
  /// true when the sheet must appear above a nested navigator such as the
  /// tab shell.
  ///
  /// [tapOutsideToDismiss], when true (the default) and [scrollable] is
  /// true, wraps the sheet so that taps on the scrim above the sheet
  /// dismiss the modal. This compensates for
  /// [DraggableScrollableSheet]'s default `expand: true` behaviour, which
  /// otherwise absorbs barrier-tap events. Set to false to keep the
  /// original layout semantics (full-viewport draggable area, no outer
  /// tap-catcher). Has no effect in fixed mode — the standard modal
  /// barrier already dismisses on tap there.
  ///
  /// [contentWrapper] wraps the entire sheet subtree once. Useful for
  /// injecting a single `BlocProvider` / `InheritedWidget` above every
  /// slot (title, trailing, bottomInput, body, buildScrollBody) without
  /// having to re-wrap each slot individually at the call site.
  static Future<T?> show<T>({
    required BuildContext context,
    List<Widget>? children,
    bool scrollable = true,
    bool showHeader = true,
    Widget? title,
    String? contentTitle,
    Widget? body,
    Widget Function(ScrollController scrollController)? buildScrollBody,
    Widget? trailing,
    AsyncCallback? onComplete,
    Widget? bottomInput,
    bool expanded = true,
    bool showHeaderDivider = true,
    EdgeInsetsGeometry? headerPadding,
    bool? isScrollControlled,
    double initialChildSize = 0.6,
    double minChildSize = 0.3,
    double maxChildSize = 0.9,
    bool snap = false,
    List<double>? snapSizes,
    bool useRootNavigator = false,
    bool tapOutsideToDismiss = true,
    Widget Function(BuildContext context, Widget child)? contentWrapper,
    VoidCallback? onShow,
    VoidCallback? onDismiss,
    bool isDismissible = true,
    bool enableDrag = true,
  }) {
    // Call onShow callback before showing modal
    onShow?.call();
    assert(
      children != null || body != null || buildScrollBody != null,
      'Provide either children, body, or buildScrollBody to '
      'VineBottomSheet.show',
    );
    assert(
      scrollable || buildScrollBody == null,
      'buildScrollBody can only be used when scrollable is true',
    );
    assert(
      scrollable || !snap,
      'snap can only be used when scrollable is true',
    );
    assert(snapSizes == null || snap, 'snapSizes requires snap: true');

    // When `tapOutsideToDismiss` is explicitly disabled, also disable
    // Flutter's modal barrier dismissal so the two outside-tap mechanisms
    // stay consistent. Otherwise a caller that set `tapOutsideToDismiss:
    // false` would still see the sheet dismissed by barrier taps above the
    // DraggableScrollableSheet's content area.
    final effectiveIsDismissible = isDismissible && tapOutsideToDismiss;

    if (scrollable) {
      // Draggable/scrollable mode
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        useRootNavigator: useRootNavigator,
        isDismissible: effectiveIsDismissible,
        enableDrag: enableDrag,
        backgroundColor: VineTheme.transparent,
        elevation: 0,
        builder: (modalContext) {
          Widget buildSheet(ScrollController scrollController) {
            final Widget sheet = VineBottomSheet(
              showHeader: showHeader,
              title: title,
              contentTitle: contentTitle,
              scrollController: scrollController,
              buildScrollBody: buildScrollBody,
              trailing: trailing,
              onComplete: onComplete,
              bottomInput: bottomInput,
              expanded: expanded,
              showHeaderDivider: showHeaderDivider,
              headerPadding: headerPadding,
              body: body,
              children: children,
            );
            return contentWrapper?.call(modalContext, sheet) ?? sheet;
          }

          // Default path preserves the original layout semantics
          // (`expand: true`, no outer tap-catcher).
          if (!tapOutsideToDismiss) {
            return DraggableScrollableSheet(
              initialChildSize: initialChildSize,
              minChildSize: minChildSize,
              maxChildSize: maxChildSize,
              snap: snap,
              snapSizes: snapSizes,
              builder: (context, scrollController) =>
                  buildSheet(scrollController),
            );
          }

          // Tap-outside-to-dismiss path.
          //
          // Three layers each with a specific job:
          //   * Outer translucent GestureDetector — receives taps in the
          //     empty area above the sheet and pops the route.
          //   * `expand: false` on DraggableScrollableSheet — stops it from
          //     claiming the entire modal area, so the region above the
          //     sheet is free space the outer detector can own.
          //   * Inner opaque GestureDetector with an empty onTap — swallows
          //     taps on non-interactive sheet surfaces so they do not
          //     bubble up to the outer detector. Drags still win via
          //     gesture arena, and interactive children handle their own
          //     taps before bubbling.
          return GestureDetector(
            behavior: HitTestBehavior.translucent,
            // coverage:ignore-start
            // Defensive fallback. In practice the modal barrier pops the
            // route first on taps above the DraggableScrollableSheet, so
            // this lambda rarely if ever fires — hence the coverage
            // exemption. Kept in place for scenarios where the barrier is
            // somehow non-dismissible but the sheet should still close on
            // an outside tap.
            onTap: () => Navigator.of(modalContext).pop(),
            // coverage:ignore-end
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: initialChildSize,
              minChildSize: minChildSize,
              maxChildSize: maxChildSize,
              snap: snap,
              snapSizes: snapSizes,
              builder: (context, scrollController) {
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: buildSheet(scrollController),
                );
              },
            ),
          );
        },
      ).whenComplete(() => onDismiss?.call());
    } else {
      // Fixed mode
      return showModalBottomSheet<T>(
        context: context,
        isScrollControlled: isScrollControlled ?? expanded,
        useSafeArea: true,
        useRootNavigator: useRootNavigator,
        isDismissible: effectiveIsDismissible,
        enableDrag: enableDrag,
        backgroundColor: VineTheme.transparent,
        elevation: 0,
        builder: (modalContext) {
          final Widget sheet = VineBottomSheet(
            scrollable: false,
            showHeader: showHeader,
            title: title,
            contentTitle: contentTitle,
            trailing: trailing,
            onComplete: onComplete,
            bottomInput: bottomInput,
            expanded: expanded,
            showHeaderDivider: showHeaderDivider,
            headerPadding: headerPadding,
            body: body,
            children: children,
          );
          return contentWrapper?.call(modalContext, sheet) ?? sheet;
        },
      ).whenComplete(() => onDismiss?.call());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(VineTheme.bottomSheetBorderRadius),
      ),
      child: ColoredBox(
        color: VineTheme.surfaceBackground,
        child: scrollable
            ? _ScrollableContent(
                showHeader: showHeader,
                title: title,
                trailing: trailing,
                onComplete: onComplete,
                body: body,
                buildScrollBody: buildScrollBody,
                scrollController: scrollController,
                contentTitle: contentTitle,
                bottomInput: bottomInput,
                showHeaderDivider: showHeaderDivider,
                headerPadding: headerPadding,
                children: children,
              )
            : _FixedContent(
                showHeader: showHeader,
                title: title,
                trailing: trailing,
                onComplete: onComplete,
                body: body,
                contentTitle: contentTitle,
                bottomInput: bottomInput,
                showHeaderDivider: showHeaderDivider,
                headerPadding: headerPadding,
                children: children,
              ),
      ),
    );
  }
}

/// Standalone drag handle shown when [VineBottomSheet.showHeader] is false.
class _HeaderlessDragHandle extends StatelessWidget {
  const _HeaderlessDragHandle();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 8, bottom: 20),
      child: Center(child: VineBottomSheetDragHandle()),
    );
  }
}

class _ScrollableContent extends StatelessWidget {
  const _ScrollableContent({
    required this.showHeader,
    required this.title,
    required this.trailing,
    required this.onComplete,
    required this.body,
    required this.buildScrollBody,
    required this.scrollController,
    required this.contentTitle,
    required this.children,
    required this.bottomInput,
    required this.showHeaderDivider,
    this.headerPadding,
  });

  final bool showHeader;
  final Widget? title;
  final Widget? trailing;
  final AsyncCallback? onComplete;
  final Widget? body;
  final Widget Function(ScrollController scrollController)? buildScrollBody;
  final ScrollController? scrollController;
  final String? contentTitle;
  final List<Widget>? children;
  final Widget? bottomInput;
  final bool showHeaderDivider;
  final EdgeInsetsGeometry? headerPadding;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (showHeader)
          // Header with drag handle, title, trailing actions, and divider
          VineBottomSheetHeader(
            title: title,
            leading: onComplete != null
                ? _CloseButton(onClose: () => Navigator.of(context).pop())
                : null,
            trailing: onComplete != null
                ? _CompleteButton(
                    onComplete: onComplete!,
                    onDismiss: () => Navigator.of(context).pop(),
                  )
                : trailing,
            showDivider: showHeaderDivider,
            padding: headerPadding,
          )
        else
          // Drag handle only — content manages its own layout below
          const _HeaderlessDragHandle(),

        // Scrollable content area (contentTitle is first element inside)
        Expanded(
          child:
              body ??
              buildScrollBody?.call(scrollController!) ??
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
                        alignment: AlignmentDirectional.centerStart,
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
}

class _FixedContent extends StatelessWidget {
  const _FixedContent({
    required this.showHeader,
    required this.title,
    required this.trailing,
    required this.onComplete,
    required this.body,
    required this.contentTitle,
    required this.children,
    required this.bottomInput,
    required this.showHeaderDivider,
    this.headerPadding,
  });

  final bool showHeader;
  final Widget? title;
  final Widget? trailing;
  final AsyncCallback? onComplete;
  final Widget? body;
  final String? contentTitle;
  final List<Widget>? children;
  final Widget? bottomInput;
  final bool showHeaderDivider;
  final EdgeInsetsGeometry? headerPadding;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showHeader)
            // Header with drag handle and divider
            VineBottomSheetHeader(
              title: title,
              leading: onComplete != null
                  ? _CloseButton(onClose: () => Navigator.of(context).pop())
                  : null,
              trailing: onComplete != null
                  ? _CompleteButton(
                      onComplete: onComplete!,
                      onDismiss: () => Navigator.of(context).pop(),
                    )
                  : trailing,
              showDivider: showHeaderDivider,
              padding:
                  headerPadding ??
                  const EdgeInsetsDirectional.only(start: 24, end: 24, top: 8),
            )
          else
            // Drag handle only
            const _HeaderlessDragHandle(),

          // Fixed content area with minimum height for menu entries (2 × 56px)
          Flexible(
            child: ConstrainedBox(
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
                            alignment: AlignmentDirectional.centerStart,
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

/// Close (X) button used in the header when [VineBottomSheet.onComplete]
/// is set.
class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return DivineIconButton(
      icon: DivineIconName.x,
      type: DivineIconButtonType.secondary,
      size: DivineIconButtonSize.small,
      onPressed: onClose,
    );
  }
}

/// Check button used in the header when [VineBottomSheet.onComplete] is set.
///
/// Shows a loading indicator while the async [onComplete] callback runs,
/// then calls [onDismiss] to close the sheet.
class _CompleteButton extends StatefulWidget {
  const _CompleteButton({
    required this.onComplete,
    required this.onDismiss,
  });

  final AsyncCallback onComplete;
  final VoidCallback onDismiss;

  @override
  State<_CompleteButton> createState() => _CompleteButtonState();
}

class _CompleteButtonState extends State<_CompleteButton> {
  bool _loading = false;

  Future<void> _handleTap() async {
    if (_loading) return;
    setState(() => _loading = true);
    try {
      await widget.onComplete();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
        widget.onDismiss();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SizedBox(
        width: 40,
        height: 40,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: VineTheme.primary,
            ),
          ),
        ),
      );
    }

    return DivineIconButton(
      icon: DivineIconName.check,
      size: DivineIconButtonSize.small,
      onPressed: _handleTap,
    );
  }
}
