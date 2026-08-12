// ABOUTME: Shared NIP-39 identity-event helpers — newest-wins and i-tag
// ABOUTME: filtering, used by both the read and the write path.

import 'package:nostr_sdk/nostr_sdk.dart';

/// Picks the newest event in [events], or null when empty.
///
/// Relays do not guarantee newest-first ordering, so recency is decided here
/// rather than by return order. On a same-second tie NIP-01 breaks by lowest
/// event id, so the same event wins regardless of which relay answered first.
Event? newestIdentityEvent(List<Event> events) {
  if (events.isEmpty) return null;
  return events.reduce((a, b) {
    if (a.createdAt != b.createdAt) {
      return b.createdAt > a.createdAt ? b : a;
    }
    return b.id.compareTo(a.id) < 0 ? b : a;
  });
}

/// Filters [tags] down to structurally valid NIP-39 `i` tags.
List<List<String>> identityTagsOf(List<List<String>> tags) {
  return [
    for (final tag in tags)
      if (tag.length >= 3 && tag[0] == 'i') tag,
  ];
}
