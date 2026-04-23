// ABOUTME: BuildContext extensions for showing modals/navigating that pause
// ABOUTME: video playback. Uses setPageOpen for full-screen pages/dialogs
// ABOUTME: and setBottomSheetOpen for bottom sheets (retains current player).

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';

/// Extension methods for showing modals and navigating that automatically
/// pause video playback.
///
/// These methods wrap [VineBottomSheet.show], [showDialog], and
/// [GoRouter.push] to integrate with [OverlayVisibility], ensuring videos
/// pause when overlays/routes open and resume when they close.
///
/// Example:
/// ```dart
/// // Push a route with video pause:
/// context.pushWithVideoPause('/profile/npub1...');
///
/// // Standard VineBottomSheet with video pause:
/// context.showVideoPausingVineBottomSheet(
///   title: Text('Options'),
///   children: [...],
/// );
/// ```
extension PauseAwareModals on BuildContext {
  /// Pushes a route that automatically pauses video playback.
  ///
  /// Calls [OverlayVisibility.setPageOpen(true)] before pushing and
  /// [setPageOpen(false)] when the pushed route is popped.
  /// This releases all video players to free memory.
  Future<T?> pushWithVideoPause<T extends Object?>(
    String location, {
    Object? extra,
  }) {
    final container = ProviderScope.containerOf(this, listen: false);
    final overlayNotifier = container.read(overlayVisibilityProvider.notifier);

    overlayNotifier.setPageOpen(true);

    return push<T>(location, extra: extra).whenComplete(() {
      overlayNotifier.setPageOpen(false);
    });
  }

  /// Shows a dialog that automatically pauses video playback.
  ///
  /// Calls [OverlayVisibility.setPageOpen(true)] before showing and
  /// [setPageOpen(false)] after the dialog is dismissed.
  /// This releases all video players (dialogs block full UI).
  Future<T?> showVideoPausingDialog<T>({
    required WidgetBuilder builder,
    bool barrierDismissible = true,
    Color? barrierColor,
    String? barrierLabel,
    bool useSafeArea = true,
    bool useRootNavigator = true,
    RouteSettings? routeSettings,
    Offset? anchorPoint,
    TraversalEdgeBehavior? traversalEdgeBehavior,
  }) {
    final container = ProviderScope.containerOf(this, listen: false);
    final overlayNotifier = container.read(overlayVisibilityProvider.notifier);

    overlayNotifier.setPageOpen(true);

    return showDialog<T>(
      context: this,
      builder: builder,
      barrierDismissible: barrierDismissible,
      barrierColor: barrierColor,
      barrierLabel: barrierLabel,
      useSafeArea: useSafeArea,
      useRootNavigator: useRootNavigator,
      routeSettings: routeSettings,
      anchorPoint: anchorPoint,
      traversalEdgeBehavior: traversalEdgeBehavior,
    ).whenComplete(() {
      overlayNotifier.setPageOpen(false);
    });
  }

  /// Shows a [VineBottomSheet] that automatically pauses video playback.
  ///
  /// This is a convenience wrapper around [VineBottomSheet.show] that provides
  /// the [onShow] and [onDismiss] callbacks for video pause integration.
  ///
  /// For standard bottom sheets, use the [VineBottomSheet] parameters like
  /// [children], [body], [title], etc.
  ///
  /// For fully custom bottom sheet widgets that don't fit the [VineBottomSheet]
  /// structure (e.g., custom headers), use the [builder] parameter instead.
  /// When [builder] is provided, a raw [showModalBottomSheet] is used with
  /// video pause integration, bypassing [VineBottomSheet].
  Future<T?> showVideoPausingVineBottomSheet<T>({
    /// Builder for fully custom bottom sheet widgets.
    /// When provided, bypasses [VineBottomSheet] and uses raw modal.
    WidgetBuilder? builder,
    List<Widget>? children,
    bool scrollable = true,
    bool showHeader = true,
    Widget? title,
    String? contentTitle,
    Widget? body,
    Widget Function(ScrollController scrollController)? buildScrollBody,
    Widget? trailing,
    Widget? bottomInput,
    bool expanded = true,
    bool showHeaderDivider = true,
    bool? isScrollControlled,
    double initialChildSize = 0.6,
    double minChildSize = 0.3,
    double maxChildSize = 0.9,
    bool snap = false,
    List<double>? snapSizes,
    // Defaults to true because video-pausing sheets are inherently
    // full-takeover interactions that should cover the tab bar. Callers on
    // screens without a shell/tab bar can opt out with false. Matches the
    // sibling showVideoPausingDialog.
    bool useRootNavigator = true,
    bool tapOutsideToDismiss = true,
    Widget Function(BuildContext context, Widget child)? contentWrapper,
  }) {
    final container = ProviderScope.containerOf(this, listen: false);
    final overlayNotifier = container.read(overlayVisibilityProvider.notifier);

    // Custom builder path: raw modal bottom sheet with video pause integration
    // Uses setBottomSheetOpen to retain current player for instant resume.
    //
    // The custom-builder path is an escape hatch for sheets that do not fit
    // the VineBottomSheet structure (e.g. Share's custom Material header).
    // New VineBottomSheet-specific parameters are intentionally NOT forwarded
    // here — the caller owns the full sheet layout in this mode.
    if (builder != null) {
      overlayNotifier.setBottomSheetOpen(true);
      return showModalBottomSheet<T>(
        context: this,
        builder: builder,
        isScrollControlled: true,
        useSafeArea: true,
        useRootNavigator: useRootNavigator,
        backgroundColor: VineTheme.transparent,
      ).whenComplete(() {
        overlayNotifier.setBottomSheetOpen(false);
      });
    }

    // Standard VineBottomSheet path
    // Uses setBottomSheetOpen to retain current player for instant resume.
    return VineBottomSheet.show<T>(
      context: this,
      children: children,
      scrollable: scrollable,
      showHeader: showHeader,
      title: title,
      contentTitle: contentTitle,
      body: body,
      buildScrollBody: buildScrollBody,
      trailing: trailing,
      bottomInput: bottomInput,
      expanded: expanded,
      showHeaderDivider: showHeaderDivider,
      isScrollControlled: isScrollControlled,
      initialChildSize: initialChildSize,
      minChildSize: minChildSize,
      maxChildSize: maxChildSize,
      snap: snap,
      snapSizes: snapSizes,
      useRootNavigator: useRootNavigator,
      tapOutsideToDismiss: tapOutsideToDismiss,
      contentWrapper: contentWrapper,
      onShow: () => overlayNotifier.setBottomSheetOpen(true),
      onDismiss: () => overlayNotifier.setBottomSheetOpen(false),
    );
  }
}
