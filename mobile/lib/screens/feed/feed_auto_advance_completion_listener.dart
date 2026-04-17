import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:openvine/screens/feed/feed_auto_advance_policy.dart';

/// Fires [onCompleted] when a looping player crosses the end -> start boundary.
class FeedAutoAdvanceCompletionListener extends StatefulWidget {
  const FeedAutoAdvanceCompletionListener({
    required this.child,
    required this.onCompleted,
    this.player,
    this.isEnabled = true,
    this.startThreshold = FeedAutoAdvanceDefaults.startThreshold,
    this.endThreshold = FeedAutoAdvanceDefaults.endThreshold,
    super.key,
  });

  final Widget child;
  final Player? player;
  final bool isEnabled;
  final VoidCallback onCompleted;
  final Duration startThreshold;
  final Duration endThreshold;

  @override
  State<FeedAutoAdvanceCompletionListener> createState() =>
      _FeedAutoAdvanceCompletionListenerState();
}

class _FeedAutoAdvanceCompletionListenerState
    extends State<FeedAutoAdvanceCompletionListener> {
  StreamSubscription<Duration>? _positionSubscription;
  Duration _lastPosition = Duration.zero;
  bool _armedForCompletion = false;

  @override
  void initState() {
    super.initState();
    _syncSubscription();
  }

  @override
  void didUpdateWidget(
    covariant FeedAutoAdvanceCompletionListener oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.player != widget.player ||
        oldWidget.isEnabled != widget.isEnabled) {
      _syncSubscription();
    }
  }

  @override
  void dispose() {
    unawaited(_positionSubscription?.cancel());
    super.dispose();
  }

  void _syncSubscription() {
    unawaited(_positionSubscription?.cancel());
    _positionSubscription = null;
    _lastPosition = Duration.zero;
    _armedForCompletion = false;

    final player = widget.player;
    if (!widget.isEnabled || player == null) return;

    try {
      _lastPosition = player.state.position;
    } catch (_) {
      _lastPosition = Duration.zero;
    }

    _positionSubscription = player.stream.position.listen(_handlePositionTick);
  }

  void _handlePositionTick(Duration position) {
    if (!widget.isEnabled) {
      _lastPosition = position;
      return;
    }

    final player = widget.player;
    if (player == null) {
      _lastPosition = position;
      return;
    }

    Duration duration;
    try {
      duration = player.state.duration;
    } catch (_) {
      _lastPosition = position;
      return;
    }

    if (duration <= Duration.zero) {
      _lastPosition = position;
      return;
    }

    if (position >= duration - widget.endThreshold) {
      _armedForCompletion = true;
    }

    final crossedLoopBoundary =
        _armedForCompletion &&
        position <= widget.startThreshold &&
        _lastPosition > position;

    if (crossedLoopBoundary) {
      _armedForCompletion = false;
      widget.onCompleted();
    }

    _lastPosition = position;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
