import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A sliver that contains multiple box children that each fills the viewport.
class ExtendedSliverFillViewport extends StatelessWidget {
  /// Creates a sliver whose box children that each fill the viewport.
  const ExtendedSliverFillViewport({
    super.key,
    required this.delegate,
    this.viewportFraction = 1.0,
    this.padEnds = true,
    this.preloadPaintCount = 0,
  }) : assert(viewportFraction > 0.0),
       assert(preloadPaintCount >= 0);

  /// The fraction of the viewport that each child should fill in the main axis.
  ///
  /// If this fraction is less than 1.0, more than one child will be visible at
  /// once. If this fraction is greater than 1.0, each child will be larger than
  /// the viewport in the main axis.
  final double viewportFraction;

  /// Whether to add padding to both ends of the list.
  ///
  /// If this is set to true and [viewportFraction] < 1.0, padding will be added
  /// such that the first and last child slivers will be in the center of the
  /// viewport when scrolled all the way to the start or end, respectively. You
  /// may want to set this to false if this [ExtendedSliverFillViewport] is not the only
  /// widget along this main axis, such as in a [CustomScrollView] with multiple
  /// children.
  ///
  /// If [viewportFraction] is greater than one, this option has no effect.
  /// Defaults to true.
  final bool padEnds;

  /// Number of extra children to preload and paint before and after the visible area.
  /// Useful when the viewport is scaled down and you need to see more items.
  final int preloadPaintCount;

  /// {@macro flutter.widgets.SliverMultiBoxAdaptorWidget.delegate}
  final SliverChildDelegate delegate;

  @override
  Widget build(BuildContext context) {
    return _SliverFractionalPadding(
      viewportFraction: padEnds
          ? clampDouble(1 - viewportFraction, 0, 1) / 2
          : 0,
      sliver: _SliverFillViewportRenderObjectWidget(
        viewportFraction: viewportFraction,
        delegate: delegate,
        preloadPaintCount: preloadPaintCount,
      ),
    );
  }
}

class _SliverFillViewportRenderObjectWidget
    extends SliverMultiBoxAdaptorWidget {
  const _SliverFillViewportRenderObjectWidget({
    required super.delegate,
    this.viewportFraction = 1.0,
    this.preloadPaintCount = 0,
  }) : assert(viewportFraction > 0.0);

  final double viewportFraction;
  final int preloadPaintCount;

  @override
  _RenderExtendedSliverFillViewport createRenderObject(BuildContext context) {
    final element = context as SliverMultiBoxAdaptorElement;
    return _RenderExtendedSliverFillViewport(
      childManager: element,
      viewportFraction: viewportFraction,
      preloadPaintCount: preloadPaintCount,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderExtendedSliverFillViewport renderObject,
  ) {
    renderObject
      ..viewportFraction = viewportFraction
      ..preloadPaintCount = preloadPaintCount;
  }
}

class _SliverFractionalPadding extends SingleChildRenderObjectWidget {
  const _SliverFractionalPadding({this.viewportFraction = 0, Widget? sliver})
    : assert(viewportFraction >= 0),
      assert(viewportFraction <= 0.5),
      super(child: sliver);

  final double viewportFraction;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSliverFractionalPadding(viewportFraction: viewportFraction);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSliverFractionalPadding renderObject,
  ) {
    renderObject.viewportFraction = viewportFraction;
  }
}

class _RenderSliverFractionalPadding extends RenderSliverEdgeInsetsPadding {
  _RenderSliverFractionalPadding({double viewportFraction = 0})
    : assert(viewportFraction <= 0.5),
      assert(viewportFraction >= 0),
      _viewportFraction = viewportFraction;

  SliverConstraints? _lastResolvedConstraints;

  double get viewportFraction => _viewportFraction;
  double _viewportFraction;
  set viewportFraction(double newValue) {
    if (_viewportFraction == newValue) {
      return;
    }
    _viewportFraction = newValue;
    _markNeedsResolution();
  }

  @override
  EdgeInsets? get resolvedPadding => _resolvedPadding;
  EdgeInsets? _resolvedPadding;

  void _markNeedsResolution() {
    _resolvedPadding = null;
    markNeedsLayout();
  }

  void _resolve() {
    if (_resolvedPadding != null && _lastResolvedConstraints == constraints) {
      return;
    }

    final paddingValue = constraints.viewportMainAxisExtent * viewportFraction;
    _lastResolvedConstraints = constraints;
    _resolvedPadding = switch (constraints.axis) {
      Axis.horizontal => EdgeInsets.symmetric(horizontal: paddingValue),
      Axis.vertical => EdgeInsets.symmetric(vertical: paddingValue),
    };

    return;
  }

  @override
  void performLayout() {
    _resolve();
    super.performLayout();
  }
}

/// Custom RenderSliverFillViewport that can layout extra children
/// before/after the visible area based on [extraChildrenCount].
class _RenderExtendedSliverFillViewport
    extends RenderSliverFixedExtentBoxAdaptor {
  _RenderExtendedSliverFillViewport({
    required super.childManager,
    double viewportFraction = 1.0,
    int preloadPaintCount = 0,
  }) : assert(viewportFraction > 0.0),
       assert(preloadPaintCount >= 0),
       _viewportFraction = viewportFraction,
       _preloadPaintCount = preloadPaintCount;

  @override
  double get itemExtent =>
      constraints.viewportMainAxisExtent * viewportFraction;

  double get viewportFraction => _viewportFraction;
  double _viewportFraction;
  set viewportFraction(double value) {
    if (_viewportFraction == value) return;
    _viewportFraction = value;
    markNeedsLayout();
  }

  /// Number of extra children to preload and paint before and after the
  /// visible area.
  int get preloadPaintCount => _preloadPaintCount;
  int _preloadPaintCount;
  set preloadPaintCount(int value) {
    if (_preloadPaintCount == value) return;
    _preloadPaintCount = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    if (preloadPaintCount == 0) {
      // Use default behavior
      super.performLayout();
      return;
    }

    // Custom layout with extra children before/after
    final constraints = this.constraints;
    childManager
      ..didStartLayout()
      ..setDidUnderflow(false);

    final itemExtent = this.itemExtent;
    final childCount = childManager.estimatedChildCount;

    if (childCount == null || childCount == 0) {
      geometry = SliverGeometry.zero;
      childManager.didFinishLayout();
      return;
    }

    // Calculate visible range based on scroll position
    final scrollOffset = constraints.scrollOffset;
    final visibleFirstIndex = (scrollOffset / itemExtent).floor();
    final visibleLastIndex =
        ((scrollOffset + constraints.viewportMainAxisExtent) / itemExtent)
            .ceil();

    // Extend range by preloadPaintCount
    final int firstIndex = math.max(0, visibleFirstIndex - preloadPaintCount);
    final int lastIndex = math.min(
      childCount - 1,
      visibleLastIndex + preloadPaintCount,
    );

    // Collect garbage outside our range
    if (firstChild != null) {
      final int leadingGarbage = math.max(0, indexOf(firstChild!) - firstIndex);
      final int trailingGarbage = math.max(0, lastIndex - indexOf(lastChild!));
      collectGarbage(leadingGarbage, trailingGarbage);
    }

    // Create first child if needed
    if (firstChild == null) {
      if (!addInitialChild(
        index: firstIndex,
        layoutOffset: firstIndex * itemExtent,
      )) {
        geometry = SliverGeometry.zero;
        childManager.didFinishLayout();
        return;
      }
    }

    // Layout first child
    var child = firstChild;
    child?.layout(
      constraints.asBoxConstraints(
        minExtent: itemExtent,
        maxExtent: itemExtent,
      ),
      parentUsesSize: true,
    );

    // Add children before first if needed
    var currentFirstIndex = indexOf(firstChild!);
    while (currentFirstIndex > firstIndex) {
      child = insertAndLayoutLeadingChild(
        constraints.asBoxConstraints(
          minExtent: itemExtent,
          maxExtent: itemExtent,
        ),
      );
      if (child == null) break;
      currentFirstIndex--;
    }

    // Add children after last
    child = lastChild;
    var currentLastIndex = indexOf(lastChild!);
    while (currentLastIndex < lastIndex) {
      child = insertAndLayoutChild(
        constraints.asBoxConstraints(
          minExtent: itemExtent,
          maxExtent: itemExtent,
        ),
        after: child,
      );
      if (child == null) break;
      currentLastIndex++;
    }

    // Set layout offsets for all children
    child = firstChild;
    var index = indexOf(firstChild!);
    while (child != null) {
      final childParentData =
          child.parentData! as SliverMultiBoxAdaptorParentData
            ..layoutOffset = index * itemExtent;
      child = childParentData.nextSibling;
      index++;
    }

    // Calculate geometry
    final maxScrollExtent = childCount * itemExtent;
    final paintExtent = calculatePaintOffset(
      constraints,
      from: 0,
      to: maxScrollExtent,
    );
    final cacheExtent = calculateCacheOffset(
      constraints,
      from: 0,
      to: maxScrollExtent,
    );

    geometry = SliverGeometry(
      scrollExtent: maxScrollExtent,
      paintExtent: paintExtent,
      cacheExtent: cacheExtent,
      maxPaintExtent: maxScrollExtent,
      hasVisualOverflow: true,
    );

    childManager.didFinishLayout();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (preloadPaintCount == 0) {
      super.paint(context, offset);
      return;
    }

    // Paint ALL laid out children (including extra ones)
    if (firstChild == null) return;

    var child = firstChild;
    while (child != null) {
      final childParentData =
          child.parentData! as SliverMultiBoxAdaptorParentData;
      final mainAxisDelta = childMainAxisPosition(child);

      // Calculate paint offset based on axis direction
      final childOffset = switch (constraints.axis) {
        .horizontal => Offset(offset.dx + mainAxisDelta, offset.dy),
        .vertical => Offset(offset.dx, offset.dy + mainAxisDelta),
      };

      // Paint this child regardless of visibility
      context.paintChild(child, childOffset);

      child = childParentData.nextSibling;
    }
  }
}
