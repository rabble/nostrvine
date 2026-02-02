// ABOUTME: BuildContext extensions for showing modals that pause video playback
// ABOUTME: Automatically calls setModalOpen(true/false) to pause/resume videos

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/overlay_visibility_provider.dart';

/// Extension methods for showing modals that automatically pause video
/// playback.
///
/// These methods wrap Flutter's [showModalBottomSheet] and [showDialog] to
/// integrate with [OverlayVisibility], ensuring videos pause when modals open
/// and resume when they close.
///
/// Example:
/// ```dart
/// // Instead of:
/// showModalBottomSheet(context: context, builder: ...);
///
/// // Use:
/// context.showVideoPausingBottomSheet(builder: ...);
/// ```
extension PauseAwareModals on BuildContext {
  /// Shows a bottom sheet that automatically pauses video playback.
  ///
  /// Calls [OverlayVisibility.setModalOpen(true)] before showing and
  /// [setModalOpen(false)] after the sheet is dismissed.
  Future<T?> showVideoPausingBottomSheet<T>({
    required WidgetBuilder builder,
    Color? backgroundColor,
    String? barrierLabel,
    double? elevation,
    ShapeBorder? shape,
    Clip? clipBehavior,
    BoxConstraints? constraints,
    Color? barrierColor,
    bool isScrollControlled = false,
    bool useRootNavigator = false,
    bool isDismissible = true,
    bool enableDrag = true,
    bool? showDragHandle,
    bool useSafeArea = false,
    RouteSettings? routeSettings,
    AnimationController? transitionAnimationController,
    Offset? anchorPoint,
  }) {
    final container = ProviderScope.containerOf(this, listen: false);
    final overlayNotifier = container.read(overlayVisibilityProvider.notifier);

    overlayNotifier.setModalOpen(true);

    return showModalBottomSheet<T>(
      context: this,
      builder: builder,
      backgroundColor: backgroundColor,
      barrierLabel: barrierLabel,
      elevation: elevation,
      shape: shape,
      clipBehavior: clipBehavior,
      constraints: constraints,
      barrierColor: barrierColor,
      isScrollControlled: isScrollControlled,
      useRootNavigator: useRootNavigator,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      showDragHandle: showDragHandle,
      useSafeArea: useSafeArea,
      routeSettings: routeSettings,
      transitionAnimationController: transitionAnimationController,
      anchorPoint: anchorPoint,
    ).whenComplete(() {
      overlayNotifier.setModalOpen(false);
    });
  }

  /// Shows a dialog that automatically pauses video playback.
  ///
  /// Calls [OverlayVisibility.setModalOpen(true)] before showing and
  /// [setModalOpen(false)] after the dialog is dismissed.
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

    overlayNotifier.setModalOpen(true);

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
      overlayNotifier.setModalOpen(false);
    });
  }

  /// Shows a [VineBottomSheet] that automatically pauses video playback.
  ///
  /// This is a convenience wrapper around [VineBottomSheet.show] that provides
  /// the [onShow] and [onDismiss] callbacks for video pause integration.
  Future<T?> showVideoPausingVineBottomSheet<T>({
    List<Widget>? children,
    bool scrollable = true,
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
  }) {
    final container = ProviderScope.containerOf(this, listen: false);
    final overlayNotifier = container.read(overlayVisibilityProvider.notifier);

    return VineBottomSheet.show<T>(
      context: this,
      children: children,
      scrollable: scrollable,
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
      onShow: () => overlayNotifier.setModalOpen(true),
      onDismiss: () => overlayNotifier.setModalOpen(false),
    );
  }
}
