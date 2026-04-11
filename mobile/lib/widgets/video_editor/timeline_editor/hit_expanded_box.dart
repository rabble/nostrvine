import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Expands the hit-test area horizontally beyond the widget's layout bounds.
///
/// Used so that trim handles positioned outside a parent's bounds via
/// [Stack] + [Clip.none] remain interactive. Wrapping the parent hierarchy
/// with this widget extends the hit-test rect so outer-positioned children
/// can still receive touches.
///
/// When [height] is provided, the widget also applies a tight height
/// constraint — combining size control and hit expansion in one render
/// object so there is no intermediate node that blocks expanded-margin
/// hits.
class HitExpandedBox extends SingleChildRenderObjectWidget {
  const HitExpandedBox({
    required super.child,
    super.key,
    this.expandLeft = 0,
    this.expandRight = 0,
    this.height,
  });

  final double expandLeft;
  final double expandRight;

  /// Optional tight height constraint applied to the child.
  final double? height;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderHitExpandedBox(
      expandLeft: expandLeft,
      expandRight: expandRight,
      additionalConstraints: height != null
          ? BoxConstraints.tightFor(height: height)
          : const BoxConstraints(),
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    RenderHitExpandedBox renderObject,
  ) {
    renderObject
      ..expandLeft = expandLeft
      ..expandRight = expandRight
      ..additionalConstraints = height != null
          ? BoxConstraints.tightFor(height: height)
          : const BoxConstraints();
  }
}

/// Custom [RenderConstrainedBox] that extends the hit-test area
/// horizontally.
///
/// Positions inside the normal layout bounds use the standard hit-test
/// path so [GestureDetector]s register correctly. Positions in the
/// expanded margins bypass the child's own `size.contains()` check and
/// delegate directly to [hitTestChildren].
class RenderHitExpandedBox extends RenderConstrainedBox {
  RenderHitExpandedBox({
    required double expandLeft,
    required double expandRight,
    required super.additionalConstraints,
  }) : _expandLeft = expandLeft,
       _expandRight = expandRight;

  double _expandLeft;
  double get expandLeft => _expandLeft;
  set expandLeft(double value) {
    if (_expandLeft == value) return;
    _expandLeft = value;
  }

  double _expandRight;
  double get expandRight => _expandRight;
  set expandRight(double value) {
    if (_expandRight == value) return;
    _expandRight = value;
  }

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (position.dx >= -_expandLeft &&
        position.dx < size.width + _expandRight &&
        position.dy >= 0 &&
        position.dy < size.height) {
      // Inside normal bounds → standard path so GestureDetectors
      // (e.g. longPress for reorder) register in the hit result.
      if (size.contains(position)) {
        if (hitTestChildren(result, position: position) ||
            hitTestSelf(position)) {
          result.add(BoxHitTestEntry(this, position));
          return true;
        }
      } else {
        // Expanded margin → bypass child's size.contains() so
        // touches reach the positioned children outside bounds.
        final childHit =
            child?.hitTestChildren(result, position: position) ?? false;
        if (childHit || hitTestSelf(position)) {
          result.add(BoxHitTestEntry(this, position));
          return true;
        }
      }
    }
    return false;
  }
}
