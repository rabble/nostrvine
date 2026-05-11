import 'dart:async';

import 'package:divine_ui/src/skeleton/vine_skeleton_effect.dart';
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Wraps an avatar + name subtree with the identity-loading skeleton pattern
/// originally tuned in `_ProfileHeaderWidgetState` (#4163 / #4183).
///
/// While [isLoading] is `true`, the subtree shimmers via [Skeletonizer]. After
/// [fallthroughTimeout] elapses without [isLoading] flipping to `false`, the
/// shimmer dissolves so the underlying widgets — typically a generated-name
/// fallback or identicon — become visible. This avoids an indefinite shimmer
/// for users whose Kind 0 profile genuinely never resolves (classic Viners).
///
/// The fallthrough timer is reconciled in `initState` and `didUpdateWidget`,
/// so `build()` is a pure function of [isLoading] and the expired flag.
/// Repeated rebuilds with the same [isLoading] value are no-ops; the timer
/// only restarts when [isLoading] flips.
///
/// Static chrome inside the wrapped subtree (timestamps, "You" pills, link
/// affordances) should be wrapped in `Skeleton.keep` so it stays interactive
/// during the loading window — the same pattern used on the profile header.
class IdentitySkeletonizer extends StatefulWidget {
  /// Wraps [child] in a skeleton shimmer while [isLoading] is `true`,
  /// dissolving the shimmer after [fallthroughTimeout] regardless.
  const IdentitySkeletonizer({
    required this.isLoading,
    required this.child,
    this.fallthroughTimeout = const Duration(seconds: 7),
    super.key,
  });

  /// Whether the underlying identity is still resolving. The caller is
  /// responsible for deriving this from its own loading source (BLoC state,
  /// Riverpod `AsyncValue`, nullable profile field, etc.).
  final bool isLoading;

  /// Maximum window during which the shimmer is shown. After this elapses
  /// the shimmer dissolves even if [isLoading] is still `true`, so a user
  /// who genuinely has no Kind 0 sees the underlying generated-name
  /// fallback instead of an infinite shimmer.
  final Duration fallthroughTimeout;

  /// The avatar + name subtree to skeletonize.
  final Widget child;

  @override
  State<IdentitySkeletonizer> createState() => _IdentitySkeletonizerState();
}

class _IdentitySkeletonizerState extends State<IdentitySkeletonizer> {
  Timer? _timer;
  bool _timeoutExpired = false;
  bool? _wasLoading;

  @override
  void initState() {
    super.initState();
    _syncTimer(isLoading: widget.isLoading);
  }

  @override
  void didUpdateWidget(IdentitySkeletonizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTimer(isLoading: widget.isLoading);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _syncTimer({required bool isLoading}) {
    if (_wasLoading == isLoading) return;
    _wasLoading = isLoading;
    _timer?.cancel();
    _timer = null;
    _timeoutExpired = false;
    if (!isLoading) return;
    _timer = Timer(widget.fallthroughTimeout, () {
      if (mounted) setState(() => _timeoutExpired = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      enabled: widget.isLoading && !_timeoutExpired,
      enableSwitchAnimation: true,
      effect: vineSkeletonEffect,
      child: widget.child,
    );
  }
}
