// ABOUTME: Engagement count seed policy for feed action controls.
// ABOUTME: Preserves archival Vine baselines while adding live Divine counts.

import 'package:models/models.dart';

int? _sumNullableCounts(int? archivedCount, int? liveCount) {
  if (archivedCount == null && liveCount == null) return null;
  return (archivedCount ?? 0) + (liveCount ?? 0);
}

int? _maxNullableCounts(int? firstCount, int? secondCount) {
  if (firstCount == null) return secondCount;
  if (secondCount == null) return firstCount;
  return firstCount > secondCount ? firstCount : secondCount;
}

/// Display reaction count suitable for seeding [VideoInteractionsBloc].
int? liveLikeCountSeed(VideoEvent video) =>
    _sumNullableCounts(video.originalLikes, video.nostrLikeCount);

/// Display comment/reply count suitable for seeding [VideoInteractionsBloc].
int? liveCommentCountSeed(VideoEvent video) =>
    _sumNullableCounts(video.originalComments, video.nostrCommentCount);

/// Display repost count suitable for seeding [VideoInteractionsBloc].
int? liveRepostCountSeed(VideoEvent video) {
  final liveRepostCount = video.nostrRepostCount;
  final visibleReposterCount = video.reposterPubkeys?.isEmpty ?? true
      ? null
      : video.reposterPubkeys!.length;
  final liveCount = _maxNullableCounts(liveRepostCount, visibleReposterCount);
  return _sumNullableCounts(video.originalReposts, liveCount);
}

/// Divine-only portion of a combined display count.
///
/// Display counts are seeded as archival + live (see the seeds above) and
/// then adjusted by optimistic taps, so subtracting the archival baseline
/// back out keeps a per-source breakdown consistent with the combined
/// number. Falls back to [liveCount] when the display count is unknown.
int divineOnlyCount({
  required int? displayCount,
  required int? archivedCount,
  int? liveCount,
}) {
  if (displayCount == null) return liveCount ?? 0;
  final live = displayCount - (archivedCount ?? 0);
  return live < 0 ? 0 : live;
}
