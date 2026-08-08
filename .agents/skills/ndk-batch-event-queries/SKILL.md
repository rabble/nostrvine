---
name: ndk-batch-event-queries
description: |
  Optimize Nostr relay queries using NDK batch fetching. Use when: (1) Checking existence
  of many events one-by-one is slow, (2) Loop with individual fetchEvents calls causing
  N+1 query problem, (3) Need to verify multiple addressable events (Kind 30000+) exist.
  NDK's fetchEvents accepts arrays for tag filters (#d, #p, #e, authors), enabling
  batch queries that reduce hundreds of round-trips to a single request.
author: Claude Code
version: 1.0.0
date: 2026-01-25
---

# NDK Batch Event Queries

## Problem

When checking if many Nostr events exist (e.g., 300 videos for a user), querying
one-by-one causes hundreds of sequential relay round-trips, making the operation
extremely slow (minutes instead of seconds).

## Context / Trigger Conditions

- Loop with `await fetchEvents()` inside, checking events individually
- Processing takes minutes when it should take seconds
- Checking existence of addressable events (Kind 30000-39999) by d-tag
- Need to find which items from a list already exist on a relay

## Solution

NDK's `fetchEvents` filter accepts **arrays** for most fields. Instead of:

```typescript
// SLOW: 300 sequential queries
for (const id of vineIds) {
  const exists = await ndk.fetchEvents({
    kinds: [34236],
    authors: [pubkey],
    "#d": [id],  // Single value
  });
}
```

Use a batch query:

```typescript
// FAST: 1-3 queries (chunked if needed)
const CHUNK_SIZE = 100;  // Relays may limit query size
const existingIds = new Set<string>();

for (let i = 0; i < vineIds.length; i += CHUNK_SIZE) {
  const chunk = vineIds.slice(i, i + CHUNK_SIZE);
  const events = await ndk.fetchEvents({
    kinds: [34236],
    authors: pubkeys,  // Can also be an array
    "#d": chunk,       // Array of d-tag values
  });

  for (const event of events) {
    const dTag = event.tags.find(t => t[0] === "d");
    if (dTag?.[1]) existingIds.add(dTag[1]);
  }
}

// O(1) lookup in processing loop
for (const id of vineIds) {
  if (existingIds.has(id)) continue;  // Skip existing
  // Process new items...
}
```

### Key Points

1. **Array filters**: `#d`, `#p`, `#e`, `authors` all accept arrays
2. **Chunk size**: Use 50-100 items per query to avoid relay limits
3. **Multiple authors**: Pass array of pubkeys if checking across users
4. **Extract results**: Parse the d-tag from returned events to build a Set

## Verification

- Processing time drops from minutes to seconds
- Total relay connections decrease dramatically
- Same results as individual queries (verified by comparison)

## Example

Real-world application - checking 294 videos across 2 pubkeys:

```typescript
async videosExistBatch(pubkeys: string[], vineIds: string[]): Promise<Set<string>> {
  await this.connect();
  const existingIds = new Set<string>();
  const CHUNK_SIZE = 100;

  for (let i = 0; i < vineIds.length; i += CHUNK_SIZE) {
    const chunk = vineIds.slice(i, i + CHUNK_SIZE);
    const events = await this.ndk.fetchEvents({
      kinds: [34236],
      authors: pubkeys,
      "#d": chunk,
    });

    for (const event of events) {
      const dTag = event.tags.find((t) => t[0] === "d");
      if (dTag && dTag[1]) {
        existingIds.add(dTag[1]);
      }
    }
  }

  return existingIds;
}
```

Usage:
```typescript
const vineIds = vines.map(v => v.vine_id);
const existingVineIds = await relay.videosExistBatch([pubkey, oldPubkey], vineIds);
console.log(`Found ${existingVineIds.size}/${vineIds.length} already on relay`);
```

## Notes

- Some relays may have stricter limits on query size; adjust CHUNK_SIZE accordingly
- The buffered queries feature in NDK can also help with component-level batching
- For very large sets, consider parallel chunk requests with Promise.all
- This pattern works for any tag-based lookup, not just #d tags

## References

- [NDK GitHub Repository](https://github.com/nostr-dev-kit/ndk)
- [NDK Documentation](https://nostr-dev-kit.github.io/ndk/)
- [Nostr Filter Protocol](https://nostrbook.dev/protocol/filter)
