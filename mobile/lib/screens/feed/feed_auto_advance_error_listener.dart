import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_cubit.dart';
import 'package:openvine/blocs/video_playback_status/video_playback_status_state.dart';

/// Fires [onSkipBrokenVideo] when the active feed item's video enters a
/// non-ready [PlaybackStatus] (error / forbidden / not-found / age-restricted).
///
/// Needed because loop-completion detection only fires when the player crosses
/// a loop boundary — a broken video never emits positions, so without this,
/// Auto gets stuck on the error overlay.
///
/// Behavior by mode (see #5953):
/// * **Auto mode** ([isAutoAdvanceActive] true) — skips immediately on any
///   non-ready status (unchanged), and additionally, when
///   [confirmAndMarkMissing] is supplied, marks a HEAD-confirmed hard-404 item
///   broken (fire-and-forget) so it is pruned from every surface on refetch.
/// * **Manual scroll** — skips *only* when [confirmAndMarkMissing] resolves
///   `true` (a HEAD-confirmed hard 404, which also marks it broken). Transient
///   or non-404 failures keep the error tile, so a network flake can't evict a
///   valid video. Without a [confirmAndMarkMissing] callback, manual scroll
///   never auto-skips (prior behavior).
///
/// Gated on [isActive] so background / preloaded pages can't yank the feed
/// forward if they fail while the user is still on an earlier page.
class FeedAutoAdvancePastErrorListener extends StatefulWidget {
  const FeedAutoAdvancePastErrorListener({
    required this.videoId,
    required this.isActive,
    required this.isAutoAdvanceActive,
    required this.onSkipBrokenVideo,
    required this.child,
    this.confirmAndMarkMissing,
    super.key,
  });

  final String videoId;
  final bool isActive;
  final bool isAutoAdvanceActive;
  final VoidCallback onSkipBrokenVideo;
  final Widget child;

  /// Confirms (via a HEAD request) whether the active item's media is a hard
  /// 404 and, if so, marks it broken. Returns `true` only for a confirmed 404.
  /// Injected by the feed item from `deadMediaFeedGuardProvider`.
  final Future<bool> Function()? confirmAndMarkMissing;

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
    // errored video (isActive false → true), Auto was just enabled, or the
    // home-feed guard ([confirmAndMarkMissing]) just resolved for an item
    // that already failed while it was still null. Without this branch, an
    // item that failed before the guard loaded latches `_firedForCurrentBreak`
    // and never gets a confirm attempt (see #5953 review).
    if (oldWidget.videoId != widget.videoId ||
        oldWidget.isActive != widget.isActive ||
        oldWidget.isAutoAdvanceActive != widget.isAutoAdvanceActive ||
        (oldWidget.confirmAndMarkMissing == null &&
            widget.confirmAndMarkMissing != null)) {
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
    if (status == PlaybackStatus.ready) return;

    final confirm = widget.confirmAndMarkMissing;
    if (widget.isAutoAdvanceActive) {
      // Auto already skips any non-ready item — preserve that immediately, and
      // mark a hard-404 item broken (fire-and-forget) so it's pruned on refetch.
      _firedForCurrentBreak = true;
      _deferSkip();
      if (confirm != null) unawaited(confirm());
      return;
    }

    // Manual scroll: only skip past a HEAD-confirmed hard 404 (which also
    // marks it broken). Transient / non-404 failures keep the error tile.
    //
    // Don't latch `_firedForCurrentBreak` when the guard isn't loaded yet —
    // no confirmation attempt happened, so `didUpdateWidget` must be able to
    // retry once [confirmAndMarkMissing] becomes available for this same
    // failed item.
    if (confirm == null) return;
    _firedForCurrentBreak = true;
    final videoId = widget.videoId;
    unawaited(
      confirm().then((isMissing) {
        if (!mounted) return;
        if (!isMissing) return;
        // The result raced a page change, a deactivation, or a recovery —
        // none of which should move a different/now-ready item.
        if (!widget.isActive) return;
        if (widget.videoId != videoId) return;
        final cubit = context.read<VideoPlaybackStatusCubit>();
        if (cubit.state.statusFor(videoId) == PlaybackStatus.ready) return;
        _deferSkip();
      }),
    );
  }

  void _deferSkip() {
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
