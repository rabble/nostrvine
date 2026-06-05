// ABOUTME: Engagement count seed policy for feed action controls.
// ABOUTME: Preserves archival Vine baselines while adding live Divine counts.

import 'package:models/models.dart';

int? _sumNullableCounts(int? archivedCount, int? liveCount) {
  if (archivedCount == null && liveCount == null) return null;
  return (archivedCount ?? 0) + (liveCount ?? 0);
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
  final visibleReposterCount = video.reposterPubkeys?.length ?? 0;
  final liveCount = liveRepostCount == null && visibleReposterCount == 0
      ? null
      : liveRepostCount == null
      ? visibleReposterCount
      : liveRepostCount > visibleReposterCount
      ? liveRepostCount
      : visibleReposterCount;
  return _sumNullableCounts(video.originalReposts, liveCount);
}
