// ABOUTME: Nostr-enrichment merge policy for the profile/author feed (#3705).
// ABOUTME: Fills missing fields on the current videos from their enriched Nostr
// ABOUTME: copies without clobbering relay updates that arrived meanwhile.

import 'package:models/models.dart';
import 'package:videos_repository/videos_repository.dart';

/// Merges enriched copies over [sourceKeys] against [current], filling missing
/// fields without clobbering relay updates that arrived during the enrichment
/// window (#3705).
///
/// [removeTombstones] drops NIP-09-deleted events; it is injected because
/// tombstone state is a session-scoped, `VideoEventService`-owned concern that
/// this Flutter-free merge must not depend on directly.
List<VideoEvent> mergeProfileFeedEnrichment({
  required List<VideoEvent> current,
  required Set<String> sourceKeys,
  required List<VideoEvent> incoming,
  required List<VideoEvent> Function(List<VideoEvent>) removeTombstones,
}) {
  if (sourceKeys.isEmpty) {
    return removeTombstones(mergeProfileFeedVideoLists(current, incoming));
  }
  final currentByKey = {
    for (final video in current)
      if (sourceKeys.contains(canonicalProfileFeedVideoKey(video)))
        canonicalProfileFeedVideoKey(video): video,
  };
  final keepFromCurrent = current
      .where((v) => !sourceKeys.contains(canonicalProfileFeedVideoKey(v)))
      .toList();
  final mergedSource = incoming.map((video) {
    final currentVideo = currentByKey[canonicalProfileFeedVideoKey(video)];
    return currentVideo == null
        ? video
        : _mergeEnrichmentIntoCurrent(currentVideo, video);
  }).toList();
  return removeTombstones(
    mergeProfileFeedVideoLists(keepFromCurrent, mergedSource),
  );
}

VideoEvent _mergeEnrichmentIntoCurrent(
  VideoEvent current,
  VideoEvent enriched,
) {
  return current.copyWith(
    publishedAt:
        (current.publishedAt != null && current.publishedAt!.isNotEmpty)
        ? current.publishedAt
        : enriched.publishedAt,
    rawTags: mergeVideoRawTagsPrimaryWins(current.rawTags, enriched.rawTags),
    contentWarningLabels: current.contentWarningLabels.isNotEmpty
        ? current.contentWarningLabels
        : enriched.contentWarningLabels,
    title: current.title ?? enriched.title,
    videoUrl: current.videoUrl ?? enriched.videoUrl,
    thumbnailUrl: current.thumbnailUrl ?? enriched.thumbnailUrl,
    duration: current.duration ?? enriched.duration,
    dimensions: current.dimensions ?? enriched.dimensions,
    mimeType: current.mimeType ?? enriched.mimeType,
    sha256: current.sha256 ?? enriched.sha256,
    fileSize: current.fileSize ?? enriched.fileSize,
    hashtags: current.hashtags.isNotEmpty
        ? current.hashtags
        : enriched.hashtags,
    vineId: current.vineId ?? enriched.vineId,
    group: current.group ?? enriched.group,
    altText: current.altText ?? enriched.altText,
    blurhash: current.blurhash ?? enriched.blurhash,
    originalLoops: mergeNullableEngagementMax(
      current.originalLoops,
      enriched.originalLoops,
    ),
    originalLikes: mergeNullableEngagementMax(
      current.originalLikes,
      enriched.originalLikes,
    ),
    originalComments: mergeNullableEngagementMax(
      current.originalComments,
      enriched.originalComments,
    ),
    originalReposts: mergeNullableEngagementMax(
      current.originalReposts,
      enriched.originalReposts,
    ),
    audioEventId: current.audioEventId ?? enriched.audioEventId,
    audioEventRelay: current.audioEventRelay ?? enriched.audioEventRelay,
    collaboratorPubkeys: current.collaboratorPubkeys.isNotEmpty
        ? current.collaboratorPubkeys
        : enriched.collaboratorPubkeys,
    inspiredByVideo: current.inspiredByVideo ?? enriched.inspiredByVideo,
    textTrackRef: current.textTrackRef ?? enriched.textTrackRef,
    textTrackRefs: current.textTrackRefs.isNotEmpty
        ? current.textTrackRefs
        : enriched.textTrackRefs,
    textTrackContent: current.textTrackContent ?? enriched.textTrackContent,
    nostrEventTags: current.nostrEventTags.isNotEmpty
        ? current.nostrEventTags
        : enriched.nostrEventTags,
    authorName: current.authorName ?? enriched.authorName,
    authorAvatar: current.authorAvatar ?? enriched.authorAvatar,
    nostrLikeCount: mergeNullableEngagementMax(
      current.nostrLikeCount,
      enriched.nostrLikeCount,
    ),
  );
}
