---
name: nostr-addressable-event-dual-tag-query
description: |
  Fix "count shows X but list shows empty" bugs when querying related events (comments, reactions,
  zaps, reposts) for Nostr addressable events (Kind 30000-39999). Use when: (1) REST API shows
  engagement count > 0 but WebSocket query returns empty, (2) Comments/reactions exist but app
  shows "No comments yet" or similar, (3) Working with NIP-22 comments, NIP-25 reactions, or
  NIP-18 reposts on Kind 34235/34236 video events or other addressable events. Root cause:
  clients may reference addressable events using either E tag (event ID) or A tag
  (kind:pubkey:d-tag format), and querying only one tag misses events tagged with the other.
author: Claude Code
version: 1.0.0
date: 2026-02-01
---

# Nostr Addressable Event Dual-Tag Query

## Problem

When querying related events (comments, reactions, reposts, zaps) for Nostr addressable events
(Kind 30000-39999), the query returns fewer or zero results even though an indexing service
shows the correct count. This happens because addressable events can be referenced two ways,
and different clients use different methods.

## Context / Trigger Conditions

Use this skill when:
- Video/post shows comment count of 5, but comments modal says "No comments yet"
- REST API (like Funnelcake) returns correct engagement counts, but WebSocket queries return empty
- Working with NIP-22 comments (Kind 1111) on addressable events
- Working with NIP-25 reactions (Kind 7) on addressable events
- Working with NIP-18 reposts (Kind 6/16) on addressable events
- Any feature querying events that reference Kind 30000-39999 events

## Root Cause

For addressable events (Kind 30000-39999, like Kind 34236 videos), related events can reference
the target using either:

1. **E tag**: References by event ID (64-character hex)
   ```json
   ["E", "abc123...def456", "", "author-pubkey"]
   ```

2. **A tag**: References by addressable identifier (`kind:pubkey:d-tag`)
   ```json
   ["A", "34236:abc123...def456:my-video-id", "", "author-pubkey"]
   ```

Different Nostr clients and indexers use different conventions:
- Some always use E tags (event ID-based)
- Some prefer A tags for addressable events (following NIP-22 strictly)
- Some use both tags

If your app only queries by one tag type, you'll miss events tagged with the other.

## Solution

### 1. Update Filter Class (if needed)

Ensure your Filter class supports uppercase A tag queries:

```dart
// In Filter class
List<String>? uppercaseA;  // Add this field

// In toJson()
if (uppercaseA != null) {
  data['#A'] = uppercaseA;
}
```

### 2. Query by BOTH Tags

When loading related events, run two parallel queries and merge results:

```dart
Future<List<Event>> loadRelatedEvents({
  required String eventId,
  required String? addressableId,  // Format: "kind:pubkey:d-tag"
}) async {
  // Query by E tag (event ID)
  final filterByE = Filter(
    kinds: [targetKind],
    uppercaseE: [eventId],
  );

  // If addressable ID available, also query by A tag
  if (addressableId != null && addressableId.isNotEmpty) {
    final filterByA = Filter(
      kinds: [targetKind],
      uppercaseA: [addressableId],
    );

    // Run both queries in parallel
    final results = await Future.wait([
      nostrClient.queryEvents([filterByE]),
      nostrClient.queryEvents([filterByA]),
    ]);

    // Merge and deduplicate by event ID
    final eventMap = <String, Event>{};
    for (final event in results[0]) {
      eventMap[event.id] = event;
    }
    for (final event in results[1]) {
      eventMap[event.id] = event;
    }

    return eventMap.values.toList();
  }

  return nostrClient.queryEvents([filterByE]);
}
```

### 3. Post with BOTH Tags

When creating related events, include both E and A tags for maximum compatibility:

```dart
final tags = <List<String>>[
  // Always include E tag
  ['E', rootEventId, '', authorPubkey],

  // Include A tag for addressable events
  if (rootAddressableId != null && rootAddressableId.isNotEmpty)
    ['A', rootAddressableId, '', authorPubkey],

  // ... other tags
];
```

### 4. Build Addressable ID

Construct the addressable identifier from event metadata:

```dart
String? get addressableId {
  if (dTag == null) return null;
  return '$kind:$pubkey:$dTag';  // e.g., "34236:abc123...:my-video-id"
}
```

## Verification

After implementing:
1. Find an event where REST API shows count > 0 but your app showed empty
2. Verify the list now shows the expected items
3. Post a new related event (comment/reaction)
4. Verify it appears when querying by either E or A tag

## Example

Before fix - only queries by E tag:
```dart
final filter = Filter(
  kinds: [1111],  // Comments
  uppercaseE: [videoEventId],  // Only E tag!
);
// Returns 0 comments even though 5 exist (tagged with A)
```

After fix - queries both tags:
```dart
final filterByE = Filter(kinds: [1111], uppercaseE: [videoEventId]);
final filterByA = Filter(kinds: [1111], uppercaseA: [addressableId]);

final results = await Future.wait([
  client.queryEvents([filterByE]),
  client.queryEvents([filterByA]),
]);
// Returns all 5 comments regardless of how they were tagged
```

## Notes

- This pattern applies to ANY feature that queries events referencing addressable events
- The d-tag may contain colons, so parse addressable IDs carefully: `parts.sublist(2).join(':')`
- For count queries (NIP-45), take the maximum of both counts (may over-count if events have both tags)
- Some relays may not support `#A` filter queries yet - test with your target relays
- This is especially important for interoperability between different Nostr clients

## Affected NIPs

- NIP-22: Comments (Kind 1111) - uses E/A tags for root scope
- NIP-25: Reactions (Kind 7) - references target event
- NIP-18: Reposts (Kind 6/16) - references reposted event
- NIP-33: Parameterized Replaceable Events (Kind 30000-39999) - defines addressable format
- NIP-71: Video Events (Kind 34235/34236) - common use case for this pattern

## References

- [NIP-22: Comment](https://github.com/nostr-protocol/nips/blob/master/22.md) - Threading spec with E/A tags
- [NIP-33: Parameterized Replaceable Events](https://github.com/nostr-protocol/nips/blob/master/33.md) - Addressable event format
- [Nostr Protocol Spec](https://nostrbook.dev) - General Nostr documentation
