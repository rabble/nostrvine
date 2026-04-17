import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_cubit.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_state.dart';

/// Fires [onSkipBrokenVideo] once when the active feed item's video enters a
/// non-ready [PlaybackStatus] (error / forbidden / not-found / age-restricted).
///
/// Needed because [FeedAutoAdvanceCompletionListener] only fires when the
/// player crosses a loop boundary — a broken video never emits positions,
/// so without this, Auto gets stuck on the error overlay.
///
/// Gated on [isAutoAdvanceActive] and [isActive] so background / preloaded
/// pages can't yank the feed forward if they fail while the user is still
/// on an earlier page.
class FeedAutoAdvancePastErrorListener extends StatefulWidget {
  const FeedAutoAdvancePastErrorListener({
    required this.videoId,
    required this.isActive,
    required this.isAutoAdvanceActive,
    required this.onSkipBrokenVideo,
    required this.child,
    super.key,
  });

  final String videoId;
  final bool isActive;
  final bool isAutoAdvanceActive;
  final VoidCallback onSkipBrokenVideo;
  final Widget child;

  @override
  State<FeedAutoAdvancePastErrorListener> createState() =>
      _FeedAutoAdvancePastErrorListenerState();
}

class _FeedAutoAdvancePastErrorListenerState
    extends State<FeedAutoAdvancePastErrorListener> {
  /// True once we've fired for this videoId's current broken streak. Reset
  /// when the id or status change.
  bool _firedForCurrentBreak = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The cubit may already be reporting a non-ready status by the time we
    // mount (e.g. user swiped onto a page whose player has already failed,
    // or the item rebuilt with a different videoId). Evaluate once on each
    // dependency change so that case still fires.
    _evaluateCurrentStatus();
  }

  @override
  void didUpdateWidget(covariant FeedAutoAdvancePastErrorListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId != widget.videoId) {
      _firedForCurrentBreak = false;
    }

    // Re-evaluate when any gate flips — e.g. user swiped onto an already-
    // errored video (isActive false → true), or Auto was just enabled.
    if (oldWidget.videoId != widget.videoId ||
        oldWidget.isActive != widget.isActive ||
        oldWidget.isAutoAdvanceActive != widget.isAutoAdvanceActive) {
      _evaluateCurrentStatus();
    }
  }

  void _evaluateCurrentStatus() {
    final cubit = context.read<VideoPlaybackStatusCubit>();
    _maybeFire(cubit.state.statusFor(widget.videoId));
  }

  void _maybeFire(PlaybackStatus status) {
    if (_firedForCurrentBreak) return;
    if (!widget.isActive) return;
    if (!widget.isAutoAdvanceActive) return;
    if (status == PlaybackStatus.ready) return;

    _firedForCurrentBreak = true;
    // Defer so we don't advance mid-build while the cubit is emitting.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onSkipBrokenVideo();
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<VideoPlaybackStatusCubit, VideoPlaybackStatusState>(
      listenWhen: (prev, curr) =>
          prev.statusFor(widget.videoId) != curr.statusFor(widget.videoId),
      listener: (context, state) {
        final status = state.statusFor(widget.videoId);
        if (status == PlaybackStatus.ready) {
          // Reset the guard so a later, distinct failure can still fire.
          _firedForCurrentBreak = false;
          return;
        }
        _maybeFire(status);
      },
      child: widget.child,
    );
  }
}
