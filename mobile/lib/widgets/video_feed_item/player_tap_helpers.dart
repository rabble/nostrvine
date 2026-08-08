// ABOUTME: Pure decision helper for the tap-to-toggle-playback gesture on feed
// ABOUTME: videos. Keeps the "which states count as running" rule testable in
// ABOUTME: isolation from the FeedVideos overlay widget and the native player.

import 'package:divine_video_player/divine_video_player.dart';

/// The action a tap on a feed video should trigger.
enum PlayerTapAction {
  /// Start (or restart) playback.
  play,

  /// Stop playback.
  pause,
}

/// Decides how a tap on a feed video should behave, given the player's
/// [status].
///
/// Keyed on whether the player is *running*, not on whether it is paused.
/// [PlaybackStatus.isPaused] is strictly `status == paused`, so a controller
/// that initialized but never started ([PlaybackStatus.ready]) and a finished
/// non-looping clip ([PlaybackStatus.completed]) are both stopped without being
/// `paused`. Keying on `isPaused` sent those to `pause()`, so the viewer's first
/// tap did nothing and they had to tap twice (#6239).
///
/// [PlaybackStatus.buffering] counts as running, so a tap mid-load still
/// pauses rather than issuing a redundant play.
PlayerTapAction resolvePlayerTapAction(PlaybackStatus status) {
  return status.isPlaying || status.isBuffering
      ? PlayerTapAction.pause
      : PlayerTapAction.play;
}
