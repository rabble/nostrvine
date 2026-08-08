---
name: nostr-replaceable-event-mutation-overwrite
description: |
  Fix silent data loss when mutating Nostr replaceable events (Kind 0 profile, Kind 3 contact/follow
  list, Kind 10002 relay list, etc.) in client apps. Use when: (1) Following someone wipes the user's
  entire follow list, (2) Updating profile metadata loses existing fields, (3) Fresh browser session
  or mobile login causes data loss on first action, (4) Replaceable event mutation uses stale or null
  cached state. Root cause: Nostr replaceable events are full-replace (no partial update), so
  publishing based on stale/unloaded cache overwrites the canonical version. Applies to any Nostr
  client using React, Flutter, or similar reactive frameworks where query state may not be loaded
  when a mutation fires.
author: Claude Code
version: 1.0.0
date: 2026-03-23
---

# Nostr Replaceable Event Mutation Overwrite

## Problem

Nostr replaceable events (Kind 0, 3, 10002, etc.) use a full-replace model: publishing a new
event completely replaces the previous one. If a client publishes a mutation based on stale,
incomplete, or null cached state, it silently overwrites the canonical version on relays, causing
data loss. The most common case is follow list (Kind 3) wipes when a user follows someone before
the client has loaded their existing contact list.

## Context / Trigger Conditions

- User reports "I followed someone and lost all my other follows"
- Follow/unfollow action on a fresh browser session or mobile login
- Profile update loses existing metadata fields
- Relay list update drops existing relays
- Any mutation on a replaceable event where the UI passes cached state to the mutation function
- React Query / TanStack Query `data` is `undefined` when mutation fires (query still loading)
- The mutation function accepts the current event as a parameter from the UI layer

## Solution

### 1. Always Fetch Fresh State Inside the Mutation

Never rely solely on the UI's cached/query state. Fetch the latest version of the replaceable
event directly from the relay inside the mutation function, before publishing:

```typescript
// BAD: Relies on UI cache which may be null/stale
mutationFn: async ({ targetPubkey, currentContactList }) => {
  const currentTags = currentContactList?.tags || []; // null -> [] -> data loss!
  // ... publish with only the new follow
}

// GOOD: Fetches fresh from relay before mutating
mutationFn: async ({ targetPubkey, currentContactList }) => {
  let bestContactList = currentContactList;

  try {
    const relayEvents = await nostr.query([
      { kinds: [3], authors: [userPubkey], limit: 1 },
    ], { signal: AbortSignal.timeout(5000) });

    const relayContactList = relayEvents
      .sort((a, b) => b.created_at - a.created_at)[0] || null;

    if (relayContactList) {
      // Use whichever has more data to prevent loss
      const relayCount = relayContactList.tags.filter(t => t[0] === 'p').length;
      const passedCount = currentContactList?.tags.filter(t => t[0] === 'p').length ?? 0;
      if (relayCount >= passedCount) {
        bestContactList = relayContactList;
      }
    }
  } catch {
    // Fall back to passed contact list
  }

  if (!bestContactList) {
    throw new Error('Could not load existing data. Please try again.');
  }

  // Now mutate bestContactList...
}
```

### 2. "Best of Both" Strategy

Compare the relay's version against the UI's cached version and use whichever has MORE data
(more tags, more fields, etc.). This protects against:
- Stale relay (UI cache is newer from a recent local action)
- Stale UI cache (relay has updates from another client)
- Null UI cache (query hasn't loaded on fresh session)

### 3. Refuse to Publish on Total Failure

If neither the relay fetch nor the UI cache provides data, throw an error instead of
publishing an empty/minimal replaceable event. A user-friendly error message is always
better than silent data loss.

### 4. Apply to Both Directions

Apply this pattern to ALL mutation directions (follow AND unfollow, add AND remove relay,
update AND clear profile fields). The unfollow path is just as dangerous as follow.

## Verification

1. Open the app in a private/incognito browser window
2. Log in with an account that has multiple follows
3. Navigate to a profile and tap Follow IMMEDIATELY (before the page fully loads)
4. Check that the follow count increased by 1 (not reset to 1)

## Example

```typescript
// Real-world fix from divine-web useFollowUser hook
export function useFollowUser() {
  const { nostr } = useNostr();

  return useMutation({
    mutationFn: async ({ targetPubkey, currentContactList }) => {
      // Step 1: Fetch fresh from relay
      let bestContactList = currentContactList;
      try {
        const events = await nostr.query([
          { kinds: [3], authors: [user.pubkey], limit: 1 }
        ], { signal: AbortSignal.timeout(5000) });
        const relayList = events.sort((a, b) => b.created_at - a.created_at)[0];
        if (relayList) {
          const relayFollows = relayList.tags.filter(t => t[0] === 'p').length;
          const cachedFollows = currentContactList?.tags.filter(t => t[0] === 'p').length ?? 0;
          if (relayFollows >= cachedFollows) bestContactList = relayList;
        }
      } catch { /* fall back to cached */ }

      // Step 2: Refuse if no data
      if (!bestContactList) throw new Error('Could not load follow list');

      // Step 3: Mutate safely
      const tags = [...bestContactList.tags, ['p', targetPubkey]];
      return publishEvent({ kind: 3, tags, content: bestContactList.content });
    }
  });
}
```

## Notes

- This pattern applies to ALL Nostr replaceable event kinds: Kind 0 (profile), Kind 3
  (contacts), Kind 10002 (relay list), Kind 10000 (mute list), Kind 30000+ (addressable)
- The race condition is most common on mobile browsers where network is slower and users
  tap quickly
- Safety check dialogs (like "are you sure?") don't help because they check the same
  stale cache - the fix must be inside the mutation itself
- The 5-second timeout on the relay fetch is a reasonable balance between safety and UX
- Consider also disabling the mutation button while the initial query is loading, as a
  belt-and-suspenders approach
