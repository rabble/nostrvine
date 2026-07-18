// ABOUTME: Pure decision helper for the double-tap-to-like gesture on feed
// ABOUTME: videos. Keeps the "you can't like your own video" rule testable in
// ABOUTME: isolation from the FeedVideos overlay widget.

/// The action a double-tap on a feed video should trigger.
enum DoubleTapLikeAction {
  /// Do nothing: the viewer owns the video (you can't like your own video), or
  /// a content warning is still blocking interaction.
  ignore,

  /// Play the heart animation without changing the like state — the video is
  /// already liked, so a double-tap re-affirms rather than unliking.
  animateOnly,

  /// Toggle the like on and play the heart animation.
  likeAndAnimate,
}

/// Decides how a double-tap on a feed video should behave.
///
/// Mirrors the like button's rule that the owner cannot like their own video
/// (see `LikeActionButton`): on the owner's own video the gesture is a no-op.
/// A content warning that still blocks the video also suppresses the gesture.
/// Otherwise an unliked video is liked; an already-liked video only replays the
/// heart animation, because double-tap never unlikes.
DoubleTapLikeAction resolveDoubleTapLikeAction({
  required bool isOwnVideo,
  required bool contentWarningBlocking,
  required bool alreadyLiked,
}) {
  if (isOwnVideo || contentWarningBlocking) {
    return DoubleTapLikeAction.ignore;
  }
  return alreadyLiked
      ? DoubleTapLikeAction.animateOnly
      : DoubleTapLikeAction.likeAndAnimate;
}
