import 'dart:async';

import 'package:models/models.dart' hide LogCategory;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show Filter;
import 'package:openvine/utils/video_event_merge_utils.dart';
import 'package:unified_logger/unified_logger.dart';

/// Enrich REST API videos with full Nostr event data.
///
/// REST API responses may be missing fields that are present in the raw
/// Nostr event (rawTags for ProofMode/C2PA badges, dimensions, hashtags,
/// blurhash, etc.). This function fetches the full events from Nostr relays
/// by ID and merges any missing fields into the REST API videos.
///
/// Tag merge uses [mergeVideoRawTagsPrimaryWins] so Nostr wins on metadata
/// collisions but `views` (and thus [VideoEvent.totalLoops]) takes the
/// higher parsed count — Nostr must not zero out Funnelcake aggregates (#3384).
/// Nullable engagement ints use [mergeNullableEngagementMax] for the same
/// reason as profile relay/REST merge.
Future<List<VideoEvent>> enrichVideosWithNostrTags(
  List<VideoEvent> videos, {
  required NostrClient nostrService,
  String callerName = 'VideoEnrichment',
}) async {
  if (videos.isEmpty) return videos;

  // Collect IDs of videos that need enrichment.
  // It's possible that stat's are already added like 'views', 'loops', 'id'
  // which is the reason we check for < 4 tags to identify
  // videos missing the full tag set.
  final idsToEnrich = videos
      .where((v) => v.rawTags.length < 4)
      .map((v) => v.id)
      .toList();

  if (idsToEnrich.isEmpty) return videos;

  try {
    // Batch query Nostr relays for the full events
    final filter = Filter(
      ids: idsToEnrich,
      kinds: NIP71VideoKinds.getAllVideoKinds(),
      limit: idsToEnrich.length,
    );
    final nostrEvents = await nostrService
        .queryEvents([filter])
        .timeout(const Duration(seconds: 5));

    if (nostrEvents.isEmpty) return videos;

    // Build a lookup map: event ID -> parsed VideoEvent for enrichment
    final nostrEventsMap = <String, VideoEvent>{};
    for (final event in nostrEvents) {
      try {
        final parsed = VideoEvent.fromNostrEvent(event, permissive: true);
        Log.info(
          'enrichVideos: parsed Nostr event ${parsed.id} '
          'blurhash=${parsed.blurhash} '
          'rawTags.len=${parsed.rawTags.length}',
          name: callerName,
        );
        if (parsed.rawTags.isNotEmpty) {
          nostrEventsMap[parsed.id] = parsed;
        }
      } catch (_) {
        // Skip events that fail to parse
      }
    }

    if (nostrEventsMap.isEmpty) return videos;

    // Merge Nostr-parsed fields into REST API videos
    return videos.map((video) {
      final parsed = nostrEventsMap[video.id];
      if (parsed != null) {
        // Check if Nostr event has original Vine metric tags

        return video.copyWith(
          // Merge: Nostr wins on key collisions for canonical event tags;
          // `views` uses the higher of REST vs Nostr so API aggregates survive
          // enrichment (#3384) — see [mergeVideoRawTagsPrimaryWins].
          rawTags: mergeVideoRawTagsPrimaryWins(parsed.rawTags, video.rawTags),
          contentWarningLabels: video.contentWarningLabels.isEmpty
              ? parsed.contentWarningLabels
              : video.contentWarningLabels,
          // Enrich with all missing fields from Nostr event
          title: video.title ?? parsed.title,
          videoUrl: video.videoUrl ?? parsed.videoUrl,
          thumbnailUrl: video.thumbnailUrl ?? parsed.thumbnailUrl,
          duration: video.duration ?? parsed.duration,
          dimensions: video.dimensions ?? parsed.dimensions,
          mimeType: video.mimeType ?? parsed.mimeType,
          sha256: video.sha256 ?? parsed.sha256,
          fileSize: video.fileSize ?? parsed.fileSize,
          hashtags: video.hashtags.isEmpty ? parsed.hashtags : video.hashtags,
          publishedAt: video.publishedAt ?? parsed.publishedAt,
          vineId: video.vineId ?? parsed.vineId,
          group: video.group ?? parsed.group,
          altText: video.altText ?? parsed.altText,
          blurhash: video.blurhash ?? parsed.blurhash,
          // Original metrics: take max so a Nostr zero/static tag cannot wipe
          // Funnelcake aggregates (same rule as ProfileFeed — #3384).
          originalLoops: mergeNullableEngagementMax(
            parsed.originalLoops,
            video.originalLoops,
          ),
          originalLikes: mergeNullableEngagementMax(
            parsed.originalLikes,
            video.originalLikes,
          ),
          originalComments: mergeNullableEngagementMax(
            parsed.originalComments,
            video.originalComments,
          ),
          originalReposts: mergeNullableEngagementMax(
            parsed.originalReposts,
            video.originalReposts,
          ),
          audioEventId: video.audioEventId ?? parsed.audioEventId,
          audioEventRelay: video.audioEventRelay ?? parsed.audioEventRelay,
          collaboratorPubkeys: video.collaboratorPubkeys.isEmpty
              ? parsed.collaboratorPubkeys
              : video.collaboratorPubkeys,
          inspiredByVideo: video.inspiredByVideo ?? parsed.inspiredByVideo,
          textTrackRef: video.textTrackRef ?? parsed.textTrackRef,
          textTrackContent: video.textTrackContent ?? parsed.textTrackContent,
          nostrEventTags: video.nostrEventTags.isEmpty
              ? parsed.nostrEventTags
              : video.nostrEventTags,
          nostrLikeCount: mergeNullableEngagementMax(
            parsed.nostrLikeCount,
            video.nostrLikeCount,
          ),
        );
      }
      return video;
    }).toList();
  } catch (e) {
    // Non-fatal: return original videos if enrichment fails
    Log.warning(
      '$callerName: Failed to enrich with Nostr tags: $e',
      name: callerName,
      category: LogCategory.video,
    );
    return videos;
  }
}

/// Fire-and-forget enrichment that calls [onEnriched] when complete.
///
/// Returns the original [videos] immediately. Enrichment runs in the
/// background; when it finishes, [onEnriched] is called with the
/// enriched list so the caller can update its state.
///
/// [onEnriched] is NOT called when enrichment fails, when all videos
/// already have full tags (nothing to enrich), or when the relay query
/// returns no events. Callers must not rely on it firing.
List<VideoEvent> enrichVideosInBackground(
  List<VideoEvent> videos, {
  required NostrClient nostrService,
  required void Function(List<VideoEvent> enrichedVideos) onEnriched,
  String callerName = 'VideoEnrichment',
}) {
  unawaited(
    enrichVideosWithNostrTags(
      videos,
      nostrService: nostrService,
      callerName: callerName,
    ).then((enriched) {
      // Only call back if enrichment actually changed something
      if (enriched != videos) {
        onEnriched(enriched);
      }
    }),
  );
  return videos;
}
