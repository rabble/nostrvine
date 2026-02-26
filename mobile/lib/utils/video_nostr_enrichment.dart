import 'package:models/models.dart' hide LogCategory;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show Filter;
import 'package:openvine/utils/unified_logger.dart';

/// Enrich REST API videos with full Nostr event data.
///
/// REST API responses may be missing fields that are present in the raw
/// Nostr event (rawTags for ProofMode/C2PA badges, dimensions, hashtags,
/// blurhash, etc.). This function fetches the full events from Nostr relays
/// by ID and merges any missing fields into the REST API videos.
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
          rawTags: parsed.rawTags,
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
          // Original Vine metrics: keep Funnelcake values when present
          // (they include Nostr-era counts), fill from Nostr tags only
          // when missing. Don't clear existing values — Funnelcake's
          // aggregates are more accurate than the static Nostr tags.
          originalLoops: video.originalLoops ?? parsed.originalLoops,
          originalLikes: video.originalLikes ?? parsed.originalLikes,
          originalComments: video.originalComments ?? parsed.originalComments,
          originalReposts: video.originalReposts ?? parsed.originalReposts,
          /* FIXME: The audio show always a skeleton below of the video
          description, so we don't add them for the ZapStore.

          audioEventId: video.audioEventId? parsed.audioEventId: null
          audioEventRelay: video.audioEventRelay ?? parsed.audioEventRelay,
          */
          collaboratorPubkeys: video.collaboratorPubkeys.isEmpty
              ? parsed.collaboratorPubkeys
              : video.collaboratorPubkeys,
          inspiredByVideo: video.inspiredByVideo ?? parsed.inspiredByVideo,
          textTrackRef: video.textTrackRef ?? parsed.textTrackRef,
          nostrEventTags: video.nostrEventTags.isEmpty
              ? parsed.nostrEventTags
              : video.nostrEventTags,
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
