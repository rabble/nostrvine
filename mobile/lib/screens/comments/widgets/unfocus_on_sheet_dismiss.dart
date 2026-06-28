// ABOUTME: Drops the keyboard when the enclosing modal sheet starts dismissing
// ABOUTME: so iOS does not strand an orphaned keyboard over the screen below.

import 'package:flutter/material.dart';

/// Unfocuses the active text field the moment the enclosing [ModalRoute] begins
/// its dismiss transition.
///
/// The comments bottom sheet has no close button — it is dismissed by dragging
/// it down, tapping the scrim, or the system back gesture. Every one of those
/// vectors reverses the modal route's transition animation (the same
/// `AnimationStatus.reverse` signal Flutter's own `_dismissUnderway` checks in
/// `material/bottom_sheet.dart`). On iOS, tearing the route down does not
/// reliably resign first responder, so the software keyboard is left visible
/// over the feed below (#5604). Reacting to [AnimationStatus.reverse] unfocuses
/// while the field is still mounted and focused, which closes the text-input
/// connection in time for the keyboard to animate away with the sheet.
///
/// Renders [child] unchanged; it only observes the route animation. No-op when
/// there is no enclosing modal route (e.g. a non-modal host).
class UnfocusOnSheetDismiss extends StatefulWidget {
  const UnfocusOnSheetDismiss({required this.child, super.key});

  /// The sheet subtree this widget wraps and renders unchanged.
  final Widget child;

  @override
  State<UnfocusOnSheetDismiss> createState() => _UnfocusOnSheetDismissState();
}

class _UnfocusOnSheetDismissState extends State<UnfocusOnSheetDismiss> {
  Animation<double>? _animation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final animation = ModalRoute.of(context)?.animation;
    if (animation != _animation) {
      _animation?.removeStatusListener(_onStatusChanged);
      _animation = animation;
      _animation?.addStatusListener(_onStatusChanged);
    }
  }

  void _onStatusChanged(AnimationStatus status) {
    // The route only reverses when it is actually being dismissed (partial
    // sheet resizes do not touch the route animation), so this fires once per
    // dismiss, while the comment field still holds focus.
    if (status == AnimationStatus.reverse) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  @override
  void dispose() {
    _animation?.removeStatusListener(_onStatusChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
