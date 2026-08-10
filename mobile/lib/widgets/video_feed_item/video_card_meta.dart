// ABOUTME: Resolves what a video card's secondary meta line shows.
// ABOUTME: Vines always show their archival count; diVine counts carry a floor.

import 'package:meta/meta.dart';
import 'package:models/models.dart';

/// Smallest live diVine count that reads as a recommendation rather than a
/// warning.
///
/// Applies only to counts diVine itself accumulated. Our current view volume
/// is small enough that a bare number below this tells a viewer not to bother
/// with content the feed just paid to surface.
///
/// Archival Vine counts are deliberately exempt — see [_resolveLoopCount].
///
/// This threshold is a product call, not a technical one. It is the single
/// value to change if the bar sits wrong.
const int publicLoopCountFloor = 1000;

/// The date and count a video card's secondary line should render.
@immutable
class VideoCardMeta {
  const VideoCardMeta({this.timestamp, this.loopCount});

  /// Post time in Unix seconds, or null when no reliable date exists.
  final int? timestamp;

  /// Loop count to display, or null when the count stays hidden.
  final int? loopCount;

  /// Whether there is nothing to render, so the caller omits the line.
  bool get isEmpty => timestamp == null && loopCount == null;
}

/// Resolves the meta line for [video].
///
/// With [showPostDate] false this returns today's behaviour unchanged — the
/// combined loop count and no date — so the feature flag is a true no-op when
/// off.
///
/// Creators always see their own number, however small: it is their
/// performance data rather than a public signal, and correcting a creator's
/// underestimate of their audience is what keeps them posting.
VideoCardMeta resolveVideoCardMeta({
  required VideoEvent? video,
  required bool isOwnVideo,
  required bool showPostDate,
}) {
  if (!showPostDate) {
    return VideoCardMeta(loopCount: video?.totalLoops ?? 0);
  }

  if (video == null) return const VideoCardMeta();

  final timestamp = video.hasUnknownOriginalDate
      ? null
      : int.tryParse(video.publishedAt ?? '') ?? video.createdAt;

  final loopCount = _resolveLoopCount(video: video, isOwnVideo: isOwnVideo);

  return VideoCardMeta(timestamp: timestamp, loopCount: loopCount);
}

int? _resolveLoopCount({required VideoEvent video, required bool isOwnVideo}) {
  if (isOwnVideo) return video.totalLoops;

  // A classic Vine always shows its archival figure, however small. The
  // number is a historical fact about how the clip did on Vine, not a claim
  // about diVine, so it never reads as a verdict on us. The median archived
  // Vine sits near 300 loops, so a floor here would silently hide most of the
  // archive — the opposite of the intent.
  //
  // Never [VideoEvent.totalLoops]: adding live diVine views to an archival
  // count both misreports how popular the Vine was and buries the archival
  // number under ours.
  if (video.isOriginalVine) {
    final originalLoops = video.originalLoops;
    if (originalLoops == null || originalLoops <= 0) return null;
    return originalLoops;
  }

  // diVine's own counts are the ones that read small, so they carry the floor.
  final liveCount = video.totalLoops;
  return liveCount >= publicLoopCountFloor ? liveCount : null;
}
