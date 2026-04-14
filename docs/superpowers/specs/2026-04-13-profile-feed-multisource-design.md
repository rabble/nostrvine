# Profile Feed Multi-Source Design

**Date:** 2026-04-13

## Goal

Improve profile-feed startup latency and freshness by treating session cache, Funnelcake REST, and Nostr relay data as coordinated sources instead of a strict REST-first fallback chain.

## Priorities

1. Fastest possible initial profile render, especially after publish.
2. Correct canonical feed state when REST and relay data disagree.
3. Minimal review risk in the current Riverpod-based profile feed.

## Current Constraints

- `ProfileFeed` is a Riverpod family provider with substantial coordination logic in `mobile/lib/providers/profile_feed_provider.dart`.
- Funnelcake REST is valuable for:
  - first-page fetch speed when the index is warm
  - `totalVideoCount`
  - offset-based historical pagination
- Nostr is valuable for:
  - protocol truth
  - post-publish freshness
  - full event tags used for badges, metadata, and replaceable-event semantics
- The provider already has useful primitives:
  - session cache
  - metadata cache
  - timestamp preservation
  - Nostr enrichment helpers
  - optimistic new-video insertion

## Protocol Assumptions

- Short-form video events are addressable replaceable events keyed by `(kind, pubkey, d)` when the `d` tag exists.
- Relay queries are filtered subscriptions where `limit` only constrains the initial backfill, not the real-time stream.
- Clients should prefer the author's write relays when downloading that author's events.

These assumptions come from the current repo protocol docs and the official NIP-01, NIP-65, and NIP-71 specs.

## Proposed Architecture

Introduce a profile-feed source coordinator inside `ProfileFeed` with these responsibilities:

- Emit the session cache immediately when available.
- Start REST first-page fetch and Nostr author sync in parallel.
- Accept the first non-empty result as the provisional head snapshot.
- Merge later source results into canonical state using stable identity rules.
- Keep Nostr subscribed for freshness after initial render.
- Keep REST as the source of truth for `totalVideoCount` and `loadMore()`.

This keeps the current provider API stable while changing its orchestration model.

## Canonical Identity And Merge Rules

### Identity

Use a stable key in this order:

1. `kind:pubkey:stableId` when `stableId`/`d` is present
2. `pubkey:eventId` fallback when no stable identity exists

### Field ownership

- Prefer Nostr for event-native fields:
  - `rawTags`
  - `content`
  - `hashtags`
  - `blurhash`
  - `altText`
  - collaborators and other parsed tag data
- Prefer REST for indexed overlays:
  - count/engagement values already coming from Funnelcake
  - `totalVideoCount`
  - offset pagination semantics
- Preserve publish ordering using:
  - `publishedAt` when available
  - otherwise first-seen publish timestamp, not edit time

### Emission rules

- Do not re-emit state for late-arriving source data unless visible feed content changes.
- Do not reorder existing videos unless the canonical publish-order key changes.
- Do not duplicate edited replaceable events with new event ids.

## Runtime Flow

### Initial load

1. Read session cache.
2. If cache exists, emit it immediately as stale-but-usable state.
3. Start:
   - REST first page
   - Nostr author subscribe/query
4. If Nostr produces fresher head items first, show them immediately.
5. When REST arrives, merge in count data, missing videos, and pagination metadata.
6. Keep Nostr listeners active for updates and new publishes.

### Refresh

- Refresh should re-run REST and relay head synchronization in parallel.
- Relay can satisfy freshness first.
- REST overlays count and pagination metadata later.

### Load more

- Keep REST-backed `loadMore()` for now.
- Merge appended REST pages into canonical state using the same stable identity logic.
- Do not attempt full relay-based deep pagination in this change.

## State Changes

Keep `VideoFeedState` mostly stable for UI compatibility, but extend internal provider bookkeeping with:

- source status tracking for REST and Nostr
- canonical keyed map or equivalent merge helper
- timestamps for rest sync and relay sync

Only add public state fields if needed for tests or UI behavior. Avoid widening the UI contract unless necessary.

## Test Strategy

Add contract tests that prove the new behavior:

- cache is emitted immediately while both sources run
- relay can win head-of-feed freshness when REST is slow
- REST can arrive later and add counts without duplicating or reordering incorrectly
- replaceable edits merge by stable identity
- `loadMore()` still appends correctly after a mixed-source initial load
- one source failing does not block usable state from the other

## Non-Goals

- Full migration of `ProfileFeed` from Riverpod to BLoC/Cubit
- Replacing REST pagination with relay history pagination
- Generalizing the coordinator for every feed in the app during this change

## Implementation Shape

Deliver this in small slices:

1. Extract merge helpers and add tests.
2. Parallelize initial load with cache-first behavior.
3. Parallelize refresh and preserve REST pagination.
4. Expand contract tests for mixed-source behavior.
