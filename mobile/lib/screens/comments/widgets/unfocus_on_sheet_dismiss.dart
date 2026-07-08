// ABOUTME: Drops the keyboard when the enclosing modal sheet starts dismissing
// ABOUTME: so iOS does not strand an orphaned keyboard over the screen below.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Unfocuses the active text field and hides the software keyboard the moment
/// the enclosing [ModalRoute] begins its dismiss transition.
///
/// The comments bottom sheet has no close button — it is dismissed by dragging
/// it down, tapping the scrim, or the system back gesture. Most of those
/// vectors reverse the modal route's transition animation, so
/// [AnimationStatus.reverse] is the primary dismiss signal (#5604). Two
/// teardown paths never emit it (#5959):
///
/// * a chrome drag that rides the route controller to its 0.0 clamp goes
///   completed→forward→dismissed (both fling branches in
///   `material/bottom_sheet.dart` are guarded by `value > 0.0`, and the
///   follow-up pop's `reverse()` takes the zero-duration branch), covered by
///   also reacting to [AnimationStatus.dismissed];
/// * route removal without a pop emits no status change at all, covered by
///   the [dispose] fallback.
///
/// `unfocus()` alone is not enough: when iOS tears down the text-input
/// session during a background/resume cycle, the framework nulls its side of
/// the connection without any outbound `TextInput.hide`, while iOS
/// re-presents the keyboard for the stale first responder on resume. In that
/// split-brain state `unfocus()` produces zero text-input channel traffic, so
/// an explicit `TextInput.hide` — which resigns the first responder
/// engine-side regardless of framework connection state — is sent as well.
///
/// The [dispose] fallback runs only when no route-status change already
/// dismissed the keyboard and only when there was an enclosing modal route, so
/// it is scoped to a sheet actually tearing down rather than firing on every
/// disposal of a generic subtree.
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
  bool _dismissed = false;

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
    // reverse: pop-driven dismissals (scrim tap, drag release, back, pop),
    // fired while the comment field still holds focus. dismissed: a chrome
    // drag that reaches the route controller's 0.0 clamp skips reverse
    // entirely — see the class doc.
    if (status == AnimationStatus.reverse ||
        status == AnimationStatus.dismissed) {
      _dismissKeyboard();
    }
  }

  void _dismissKeyboard() {
    // A single teardown can surface more than one signal (a pop emits reverse
    // then dismissed); dismiss exactly once so we don't re-send TextInput.hide.
    if (_dismissed) return;
    _dismissed = true;
    FocusManager.instance.primaryFocus?.unfocus();
    // unfocus() sends nothing over the text-input channel when the framework
    // side of the connection is already gone (platform-initiated teardown
    // during background/resume — see the class doc). Hide explicitly; this is
    // a harmless no-op when the keyboard is already down.
    unawaited(SystemChannels.textInput.invokeMethod<void>('TextInput.hide'));
  }

  @override
  void dispose() {
    _animation?.removeStatusListener(_onStatusChanged);
    // Fallback for the one teardown that emits no status change at all: a
    // route removed without a pop. Gated on `!_dismissed` so a status-handled
    // close doesn't fire it again, and on an enclosing modal route having
    // existed so a generic non-sheet host that never stranded a keyboard
    // doesn't yank global focus / hide another route's keyboard on disposal.
    if (!_dismissed && _animation != null) {
      _dismissKeyboard();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
