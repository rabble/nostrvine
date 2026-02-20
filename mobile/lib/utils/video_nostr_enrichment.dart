import 'package:models/models.dart' hide LogCategory;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show Filter;
import 'package:openvine/utils/unified_logger.dart';

/// Enrich REST API videos with raw Nostr tags for ProofMode/C2PA badges.
///
/// REST API responses don't include the raw Nostr event tags array,
/// so ProofMode/C2PA/verification tags are missing. This function fetches
/// the full events from Nostr relays by ID and merges their rawTags.
Future<List<VideoEvent>> enrichVideosWithNostrTags(
  List<VideoEvent> videos, {
  required NostrClient nostrService,
  String callerName = 'VideoEnrichment',
}) async {
  if (videos.isEmpty) return videos;

  // Collect IDs of videos that need enrichment.
  // REST API always includes 'id' and 'loops' tags, but not additional Nostr
  // tags like ProofMode/C2PA verification. Check for < 3 tags to identify
  // videos missing the full tag set.
  final idsToEnrich = videos
      .where((v) => v.rawTags.length < 3)
      .map((v) => v.id)
      .toList();

  if (idsToEnrich.isEmpty) return videos;

  try {
    // Batch query Nostr relays for the full events
    final filter = Filter(
      ids: idsToEnrich,
      kinds: [34236],
      limit: idsToEnrich.length,
    );
    final nostrEvents = await nostrService
        .queryEvents([filter])
        .timeout(const Duration(seconds: 5));

    if (nostrEvents.isEmpty) return videos;

    // Build a lookup map: event ID -> rawTags from parsed VideoEvent
    final nostrTagsMap = <String, Map<String, String>>{};
    for (final event in nostrEvents) {
      try {
        final parsed = VideoEvent.fromNostrEvent(event, permissive: true);
        if (parsed.rawTags.isNotEmpty) {
          nostrTagsMap[parsed.id] = parsed.rawTags;
        }
      } catch (_) {
        // Skip events that fail to parse
      }
    }

    if (nostrTagsMap.isEmpty) return videos;

    // Merge rawTags into REST API videos
    return videos.map((video) {
      final tags = nostrTagsMap[video.id];
      if (tags != null && tags.isNotEmpty) {
        return video.copyWith(rawTags: tags);
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
