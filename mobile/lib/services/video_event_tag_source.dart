// ABOUTME: Shared helpers for sourcing raw Nostr tags before republishing.
// ABOUTME: Recovers tags from the personal cache when JSON rehydration omits them.

import 'package:models/models.dart' show VideoEvent;
import 'package:openvine/services/personal_event_cache_service.dart';

/// Returns the raw tags for [video], recovering them from [personalEventCache]
/// when the in-memory copy came from a JSON snapshot that omits raw tags.
List<List<String>> sourceOriginalVideoTags({
  required VideoEvent video,
  required PersonalEventCacheService? personalEventCache,
}) {
  if (video.nostrEventTags.isNotEmpty) return video.nostrEventTags;
  final cached = personalEventCache?.getEventById(video.id);
  if (cached == null) return const [];
  return cached.tags
      .map((tag) => (tag as List).map((e) => e.toString()).toList())
      .toList();
}
