# Profile Pinning and Ordering Design

**Date:** 2026-08-23

**Status:** Approved UX direction; spec scoped down to a minimal first ship

## Goal

Let a creator showcase a few of their videos at the start of their profile.
Everyone sees pinned videos first, then the rest of the profile's videos in
the existing newest-first order.

The user goal is "put my best stuff first". It is not "manage a playlist".
The spec below is deliberately the smallest thing that serves that goal.

## Scope Decisions (why this is small)

Three choices remove most of the original design's surface area:

1. **Pin order is the pinning order — newest pin first.** Pinning is the
   reorder gesture. Want a video at the top? Pin it. Want it lower? Unpin the
   ones above it, or unpin and re-pin. No arranger screen, no drag handles, no
   draft/dirty/discard flow, no multi-select picker, no second cubit.
2. **Hard cap of 12 pins.** A showcase is a handful, not a catalog. The cap
   removes the oversize-event failure path, virtualization, and paginated
   reference resolution. 12 `a` tags is a small event.
3. **One grid, no section headers.** Pinned tiles carry a pin badge and are
   simply first. No second grid, no partial-row / new-row rules, no section
   labels to localize.

If creators actually ask for manual reordering after this ships, an arranger
is an additive follow-up on the same data model. Do not build it now.

## Current Experience

- The profile Videos tab is a three-column grid backed by `ProfileFeedCubit`.
- Published profile videos retain the feed's normal newest-first order.
- Tapping a tile opens the fullscreen profile feed.
- Long-pressing an owned tile opens the existing Edit/Delete action sheet.
- In-progress uploads appear before published videos on the owner's profile.

## Viewer Experience

One grid. Order:

```text
owner-only in-progress uploads (unchanged)
+ resolved pinned videos, newest pin first
+ every other profile video in normal feed order
```

Pinned tiles show a pin badge. No section labels, no layout break between
pinned and unpinned.

The same order applies to fullscreen playback. Tapping any tile opens that one
sequence with the tapped video as the initial item, so pagination and
prefetching continue from the sequence the grid displayed.

## Owner Experience

The existing long-press sheet for an owned video gains one action:

- `Pin to profile` when not pinned — prepends the video to the pin list.
- `Unpin from profile` when pinned — removes it, leaving the rest in order.

Feedback is a plain snackbar. At the cap, `Pin to profile` is disabled with a
message naming the limit ("You can pin up to 12 videos"), so the pin never
silently evicts another video.

A failed pin or unpin leaves the visible order unchanged and offers retry.

That is the entire owner surface. No profile-options entry point, no
`Arrange profile` screen.

## Loading and Failure Behavior

- The cached pin list renders immediately when available, then revalidates.
- With at most 12 references, resolve them in a single batch. Nothing waits on
  profile pagination.
- An unavailable, deleted, blocked, or no-longer-owned reference is omitted
  from display without leaving an empty cell. The reference stays in the
  stored list — a temporary fetch failure must not delete pins.
- A failed publish leaves the previously saved order live and shows a retry.

## Ordering Rules

Let `P` be the ordered identities from the pin list and `V` the profile's
videos in normal feed order.

1. De-duplicate `P` by stable video identity; first occurrence wins.
2. Keep only references resolving to a visible video authored by the owner.
3. Emit that resolved subset in `P` order.
4. Append every video in `V` not already emitted, keeping `V` order.
5. Transient uploads stay in the owner-only publishing position, ahead of both.

One pure function returns this order and feeds the grid, tile indexes,
prefetching, and the fullscreen seed. It is the first thing to write and the
first thing to test.

## Architecture and Data Flow

```text
Profile UI
    ↓
ProfileFeedCubit
    ↓
ProfilePinsRepository + VideosRepository
    ↓
Nostr client and local cache
```

`ProfilePinsRepository` owns the pin-list subscription, cache, parsing,
merging, signing, and publishing, and exposes `pin`, `unpin`, and an ordered
identity stream. UI never constructs Nostr tags.

`ProfileFeedCubit` combines that stream with profile video pages and exposes
the single ordered sequence, pin membership by identity, and whether the pin
list is still loading. There is no editor cubit, because there is no draft:
pin and unpin publish immediately.

### Nostr Representation

Kind `10001` (NIP-51 pin list), one replaceable event per profile. Divine's
addressable kind `34236` videos are stored as ordered NIP-71 `a` references
using `34236:<author-pubkey>:<d-tag>`, so a metadata edit never loses a pin.

Divine manages only valid kind `34236` `a` tags authored by the list owner. On
save it preserves every unrelated public tag and the `content` field
byte-for-byte, so using Divine never destroys pins another Nostr client keeps
in the same list.

References: [NIP-51](https://github.com/nostr-protocol/nips/blob/master/51.md),
[NIP-71](https://github.com/nostr-protocol/nips/blob/master/71.md)

## Accessibility

- The pin badge is not the only signal: tile semantics announce pinned state
  and position.
- Pin and unpin are sheet actions, so they are already reachable and labeled.
- Success and failure are announced without moving focus.
- Labels are full localized strings, not concatenated fragments.

## Testing

Written in this order, test before implementation at each step.

**Pure ordering** (first, no Flutter, no mocks):

- pinned precede unpinned;
- pin-list order preserved;
- unpinned retain normal order;
- duplicate references collapse to the first position;
- unavailable, foreign-authored, blocked, and deleted references are omitted;
- no identity is emitted twice;
- a metadata replacement of a kind `34236` video keeps its pin.

**Repository:**

- cached list emits before relay revalidation;
- parsing preserves ordered kind `34236` `a` tags;
- saving preserves unrelated tags and `content`;
- pin prepends, unpin removes without reordering the remainder;
- pin at the cap is rejected without publishing.

**Cubit and widget:**

- pin and unpin update the visible order;
- a failed pin leaves the order unchanged and surfaces retry;
- pin badge and pinned semantics render;
- tapping any tile opens the identical ordered fullscreen sequence;
- paginated unpinned videos stay de-duplicated against pinned ones.

## Out of Scope

- Manual reordering of pins (an arranger screen), and therefore drag handles,
  semantic move actions, drafts, and a multi-select add picker.
- Section headers or a separate pinned grid.
- Unlimited pins, and the oversize-event handling it would require.
- Reordering unpinned videos.
- Pinning another account's videos.
- Multiple named pin sets.
- Changing video metadata or deletion behavior.
