// ABOUTME: Shared NIP-39 identity-event helpers — newest-wins and i-tag
// ABOUTME: filtering, used by both the read and the write path.

import 'package:nostr_sdk/nostr_sdk.dart';

/// Orders two identity events the way NIP-01 orders replaceable events:
/// the later `created_at` wins, and a same-second tie breaks by lowest event
/// id so every relay agrees on the same winner.
///
/// Returns a positive number when `(createdAt, id)` supersedes
/// `(otherCreatedAt, otherId)`, zero when they are the same event, and a
/// negative number when it is the superseded one.
int compareIdentityEvents({
  required int createdAt,
  required String id,
  required int otherCreatedAt,
  required String otherId,
}) {
  if (createdAt != otherCreatedAt) return createdAt > otherCreatedAt ? 1 : -1;
  return otherId.compareTo(id);
}

/// Picks the newest event in [events], or null when empty.
///
/// Relays do not guarantee newest-first ordering, so recency is decided here
/// rather than by return order.
Event? newestIdentityEvent(List<Event> events) {
  if (events.isEmpty) return null;
  return events.reduce((a, b) {
    final order = compareIdentityEvents(
      createdAt: b.createdAt,
      id: b.id,
      otherCreatedAt: a.createdAt,
      otherId: a.id,
    );
    return order > 0 ? b : a;
  });
}

/// Filters [tags] down to structurally valid NIP-39 `i` tags.
List<List<String>> identityTagsOf(List<List<String>> tags) {
  return [
    for (final tag in tags)
      if (tag.length >= 3 && tag[0] == 'i') tag,
  ];
}
