// ABOUTME: Long-press-and-drag range selection across a scrollable grid
// ABOUTME: Hit-tests the slot under the finger and auto-scrolls at the edges

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter/widgets.dart';

/// Wraps a scrollable grid and turns a long press followed by a drag into a
/// range selection, the way a device photo gallery does.
///
/// The long press picks out the slot under the finger — the anchor — and every
/// further move reports the slot the finger has reached. The owner is expected
/// to select everything between the two, so dragging back shrinks the range
/// again rather than piling more onto it.
///
/// Items opt in by wrapping themselves in a [DragSelectSlot], which is what
/// this region hit-tests for; anything else under the finger is ignored and
/// leaves the range where it was. Items must not take the long press for
/// themselves — a handler of their own sits deeper in the tree and would win
/// the gesture arena from this one.
///
/// While the finger sits near the top or bottom edge the grid scrolls itself,
/// and the range keeps growing into whatever scrolls into view.
class DragSelectRegion extends StatefulWidget {
  const DragSelectRegion({
    required this.scrollController,
    required this.onStarted,
    required this.onExtended,
    required this.onEnded,
    required this.child,
    super.key,
  });

  /// Controller of the scroll view in [child], used for the edge auto-scroll.
  final ScrollController scrollController;

  /// Called with the anchor slot when a long press opens a drag selection.
  final ValueChanged<int> onStarted;

  /// Called with the slot the finger has moved onto, once per slot.
  final ValueChanged<int> onExtended;

  /// Called when the finger lifts or the gesture is cancelled.
  final VoidCallback onEnded;

  /// The scroll view this region covers.
  final Widget child;

  @override
  State<DragSelectRegion> createState() => _DragSelectRegionState();
}

class _DragSelectRegionState extends State<DragSelectRegion>
    with SingleTickerProviderStateMixin {
  /// How close to an edge the finger has to be for the grid to scroll itself.
  ///
  /// Clamped against the viewport further down, so a short grid keeps a
  /// usable band in the middle where nothing scrolls.
  static const _autoScrollEdge = 72.0;

  /// Speed of the edge auto-scroll with the finger right at the edge, in
  /// logical pixels per second. Ramps up from zero across the edge band.
  static const _autoScrollMaxVelocity = 900.0;

  late final Ticker _autoScrollTicker;

  /// Slot the range currently ends on, or `-1` while no drag is running.
  int _focusSlot = -1;

  /// Where the finger is, in global coordinates. The auto-scroll re-reads the
  /// slot under it as the grid moves beneath a finger that is holding still.
  Offset? _fingerPosition;

  /// Pixels per second the grid is scrolling itself at, signed like a scroll
  /// offset: negative moves towards the top of the list.
  double _autoScrollVelocity = 0;

  Duration? _lastTick;

  bool get _isDragging => _focusSlot >= 0;

  @override
  void initState() {
    super.initState();
    _autoScrollTicker = createTicker(_onAutoScrollTick);
  }

  @override
  void dispose() {
    _autoScrollTicker.dispose();
    super.dispose();
  }

  void _onLongPressStart(LongPressStartDetails details) {
    final slot = _slotAt(details.globalPosition);
    if (slot == null) return;
    _focusSlot = slot;
    _fingerPosition = details.globalPosition;
    unawaited(HapticFeedback.selectionClick());
    widget.onStarted(slot);
  }

  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (!_isDragging) return;
    _fingerPosition = details.globalPosition;
    _updateAutoScroll(details.globalPosition);
    _extendTo(details.globalPosition);
  }

  void _onLongPressEnd(LongPressEndDetails details) => _finishDrag();

  /// Also fires for a press that was released before it became a long press,
  /// which is why this is a no-op unless a drag actually opened.
  void _onLongPressCancel() {
    if (_isDragging) _finishDrag();
  }

  void _finishDrag() {
    _stopAutoScroll();
    _fingerPosition = null;
    if (!_isDragging) return;
    _focusSlot = -1;
    widget.onEnded();
  }

  /// Reports the slot under [globalPosition], if the finger has moved onto a
  /// different one. Positions between slots, over an item that cannot be
  /// selected, or outside the grid leave the range where it is.
  void _extendTo(Offset globalPosition) {
    final slot = _slotAt(globalPosition);
    if (slot == null || slot == _focusSlot) return;
    _focusSlot = slot;
    unawaited(HapticFeedback.selectionClick());
    widget.onExtended(slot);
  }

  int? _slotAt(Offset globalPosition) {
    final box = _renderBox;
    if (box == null || box.size.isEmpty) return null;
    // A finger that has wandered off the grid — past the bottom edge and onto
    // whatever sits below it, most of all — is still dragging the range along
    // the nearest column, so the search runs from the closest point inside.
    final local = box.globalToLocal(globalPosition);
    final inside = Offset(
      local.dx.clamp(0.0, box.size.width - 1),
      local.dy.clamp(0.0, box.size.height - 1),
    );
    final result = BoxHitTestResult();
    if (!box.hitTest(result, position: inside)) return null;
    for (final entry in result.path) {
      final target = entry.target;
      if (target is! RenderMetaData) continue;
      final slot = target.metaData;
      if (slot is _DragSelectSlotData) return slot.enabled ? slot.index : null;
    }
    return null;
  }

  RenderBox? get _renderBox {
    final box = context.findRenderObject();
    return box is RenderBox && box.hasSize ? box : null;
  }

  void _updateAutoScroll(Offset globalPosition) {
    final box = _renderBox;
    if (box == null) {
      _stopAutoScroll();
      return;
    }

    final height = box.size.height;
    final edge = math.min(_autoScrollEdge, height / 4);
    final dy = box.globalToLocal(globalPosition).dy;
    var depth = 0.0;
    if (dy < edge) {
      depth = (dy - edge) / edge;
    } else if (dy > height - edge) {
      depth = (dy - (height - edge)) / edge;
    }

    _autoScrollVelocity = depth.clamp(-1.0, 1.0) * _autoScrollMaxVelocity;
    if (_autoScrollVelocity == 0) {
      _stopAutoScroll();
    } else if (!_autoScrollTicker.isActive) {
      _lastTick = null;
      _autoScrollTicker.start();
    }
  }

  void _stopAutoScroll() {
    if (!_autoScrollTicker.isActive) return;
    _autoScrollTicker.stop();
    _autoScrollVelocity = 0;
  }

  void _onAutoScrollTick(Duration elapsed) {
    // Last tick's scroll has been laid out by now, so this is the first
    // moment the grid can report a new slot under a finger holding still.
    final finger = _fingerPosition;
    if (finger != null) _extendTo(finger);

    final last = _lastTick;
    _lastTick = elapsed;
    if (last == null) return;
    final seconds =
        (elapsed - last).inMicroseconds / Duration.microsecondsPerSecond;
    if (seconds <= 0) return;

    final controller = widget.scrollController;
    if (!controller.hasClients) return;
    final position = controller.position;
    final target = (position.pixels + _autoScrollVelocity * seconds).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (target == position.pixels) return;
    position.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      excludeFromSemantics: true,
      onLongPressStart: _onLongPressStart,
      onLongPressMoveUpdate: _onLongPressMoveUpdate,
      onLongPressEnd: _onLongPressEnd,
      onLongPressCancel: _onLongPressCancel,
      child: widget.child,
    );
  }
}

/// Marks [child] as the item at [index] for an enclosing [DragSelectRegion].
class DragSelectSlot extends StatelessWidget {
  const DragSelectSlot({
    required this.index,
    required this.child,
    this.enabled = true,
    super.key,
  });

  /// Position of this item in the list the region reports slots from.
  final int index;

  /// Whether a drag may start on or run onto this item. A disabled slot reads
  /// as a gap: the range simply stays where it was.
  final bool enabled;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MetaData(
      metaData: _DragSelectSlotData(index: index, enabled: enabled),
      // Opaque so the whole tile answers for the slot, whatever part of its
      // content the finger happens to be over.
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }
}

@immutable
class _DragSelectSlotData {
  const _DragSelectSlotData({required this.index, required this.enabled});

  final int index;
  final bool enabled;
}
