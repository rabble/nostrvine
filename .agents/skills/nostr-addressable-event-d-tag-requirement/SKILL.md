---
name: nostr-addressable-event-d-tag-requirement
description: |
  Fix duplicate Nostr events (Kind 30000+ parameterized replaceable events) caused by missing d-tag.
  Use when: (1) Same content appears multiple times on relay for same pubkey, (2) Events aren't
  being replaced/updated as expected, (3) Publishing NIP-71 video events (Kind 34236) or other
  addressable events and seeing duplicates. The d-tag is REQUIRED for addressability - without it,
  each publish creates a new non-replaceable event.
author: Claude Code
version: 1.0.0
date: 2026-01-29
---

# Nostr Addressable Event d-tag Requirement

## Problem
When publishing parameterized replaceable events (Kind 30000-39999, including NIP-71 video
events Kind 34236), events appear as duplicates on the relay instead of replacing each other.
The same content shows up multiple times for the same user.

## Context / Trigger Conditions
- Publishing Kind 30000+ events (parameterized replaceable events)
- Same video/content appears multiple times in user's feed
- Events have identical pubkey, kind, and content but different event IDs
- Relay returns multiple events when you expect one
- Using NIP-71 (Kind 34236) for video events
- Using NIP-23 (Kind 30023) for long-form content
- Any addressable event type showing duplicates

## Solution

### Root Cause
Parameterized replaceable events (Kind 30000-39999) require a `d` tag to be addressable.
The combination of `pubkey + kind + d-tag value` forms the unique address. Without a `d` tag,
the relay treats each event as a separate non-replaceable event.

### Fix
Always include a `d` tag with a unique identifier for the content:

```typescript
// CORRECT - has d tag, will be replaceable
const event = {
  kind: 34236, // NIP-71 video
  pubkey: userPubkey,
  content: "Video description",
  tags: [
    ["d", videoId],  // REQUIRED for addressability
    ["title", "My Video"],
    ["url", "https://..."],
    // ... other tags
  ]
};

// WRONG - missing d tag, creates new event each time
const badEvent = {
  kind: 34236,
  pubkey: userPubkey,
  content: "Video description",
  tags: [
    ["title", "My Video"],  // No d tag!
    ["url", "https://..."],
  ]
};
```

### For NIP-71 Video Events
Use the video's unique identifier (vine_id, video_id, etc.) as the d-tag value:
```typescript
tags.push(["d", video.id]);
```

### Cleaning Up Existing Duplicates
1. Fetch all events for the pubkey: `{ kinds: [34236], authors: [pubkey] }`
2. Identify events without d-tags (these are the duplicates)
3. Publish NIP-09 deletion events (Kind 5) referencing the bad event IDs
4. Republish with proper d-tags

## Verification
After adding the d-tag:
1. Publish the same content twice
2. Query the relay for events with that pubkey+kind
3. Should return only ONE event (the latest)
4. Event ID will change but d-tag address remains constant

```javascript
// Verify no duplicates
const events = await ndk.fetchEvents({ kinds: [34236], authors: [pubkey] });
const byDTag = new Map();
for (const e of events) {
  const d = e.tags.find(t => t[0] === 'd')?.[1];
  if (!byDTag.has(d)) byDTag.set(d, []);
  byDTag.get(d).push(e);
}
// Each d-tag value should have exactly 1 event
for (const [d, evts] of byDTag) {
  if (evts.length > 1) console.log(`Duplicate: d=${d} has ${evts.length} events`);
}
```

## Example

Before fix - events without d-tag create duplicates:
```
Event 1: id=abc123, kind=34236, tags=[["title", "My Video"]]
Event 2: id=def456, kind=34236, tags=[["title", "My Video"]]  // Duplicate!
```

After fix - events with d-tag replace each other:
```
Event 1: id=abc123, kind=34236, tags=[["d", "video-001"], ["title", "My Video"]]
// Republishing same content...
Event 2: id=xyz789, kind=34236, tags=[["d", "video-001"], ["title", "My Video Updated"]]
// Event 1 is replaced, only Event 2 exists
```

## Notes
- The d-tag value should be stable across republishes (use content ID, not random)
- Empty string `["d", ""]` is valid but means only one event of that kind per pubkey
- Regular replaceable events (Kind 0, 3, 10000-19999) don't need d-tag
- This applies to ALL parameterized replaceable events, not just videos
- Frontend caching may show old duplicates even after relay is cleaned - hard refresh

## References
- [NIP-01: d-tag for parameterized replaceable events](https://github.com/nostr-protocol/nips/blob/master/01.md)
- [NIP-71: Video Events](https://github.com/nostr-protocol/nips/blob/master/71.md)
- [NIP-33: Parameterized Replaceable Events](https://github.com/nostr-protocol/nips/blob/master/33.md)
