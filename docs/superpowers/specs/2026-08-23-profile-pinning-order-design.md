# Profile Pinning and Ordering Design

**Date:** 2026-08-23  
**Status:** Approved UX direction; awaiting written-spec review

## Goal

Let a creator choose an unlimited ordered list of their videos to showcase at
the start of their profile. Everyone sees those pinned videos in the creator's
chosen order, followed by the creator's remaining videos in their existing
newest-first order.

The mental model is:

> The pin list is the curated start of the profile. Everything outside the
> list follows normally.

There is no product-level pin limit. Relay or event-size limits must surface as
a save error; the client must never silently truncate the list.

## Current Experience

- The profile Videos tab is a three-column grid backed by `ProfileFeedCubit`.
- Published profile videos currently retain the feed's normal order.
- Tapping a tile opens the fullscreen profile feed.
- Long-pressing an owned tile opens the existing Edit/Delete action sheet.
- In-progress uploads appear before published videos on the owner's profile.

## Viewer Experience

The Videos tab renders up to three sections:

1. **Publishing** — transient uploads, visible only to the owner.
2. **Pinned** — available videos referenced by the profile's ordered pin list.
3. **Latest** — all other profile videos, retaining the current newest-first
   order.

`Pinned` and `Latest` have small section labels. Each pinned thumbnail also has
a subtle pin badge. A section is omitted when it has no items. Pinned and
Latest are separate grids, so Latest begins on a new row even when the final
Pinned row is not full; preserving the section boundary is more important than
filling every grid cell.

The list order applies to both the grid and fullscreen playback. Tapping a
pinned or unpinned tile opens one sequence ordered as:

```text
available pinned videos in pin-list order
+ unpinned profile videos in normal feed order
```

The tapped video remains the initial fullscreen item. Pagination and
prefetching continue from that same sequence, so the grid never opens a
differently ordered feed.

## Owner Experience

### Quick Pin and Unpin

The existing long-press sheet for an owned video adds one contextual action:

- `Pin to profile` when the video is not pinned.
- `Unpin from profile` when the video is pinned.

Quick pin appends the video to the end of the ordered list. Success feedback
uses a short snackbar with an `Arrange` action. Quick unpin removes the video
without changing the relative order of the remaining pins. A failed quick
action leaves the visible order unchanged and offers retry feedback.

The full arranger is the first item in the owner's existing top-right profile
options sheet. This keeps the profile header unchanged while providing a stable
non-contextual entry point.

### Arrange Profile

`Arrange profile` is a full-screen flow with `Cancel`, a title, and `Done` in
the app bar.

The main view is a virtualized, numbered list of pinned videos. Each row shows:

- thumbnail and video title;
- current position;
- a dedicated drag handle;
- an accessible remove action.

Dragging a handle reorders the local draft. The entire row is not draggable,
which keeps scrolling and opening a preview unambiguous. Assistive-technology
actions provide equivalent `Move earlier`, `Move later`, `Move to top`, and
`Move to bottom` operations.

A persistent `Add videos` button opens a full-screen, paginated grid of the
creator's unpinned videos in newest-first order. The owner can select multiple
videos and add them; selected videos append to the ordered list in selection
order. Selection badges show that order before the owner confirms. Keeping the
picker behind this button avoids forcing someone with hundreds of pins to
scroll through the entire ordered list before reaching their unpinned videos.

Removing, adding, and reordering only mutate the local draft. `Done` publishes
the complete updated list once. `Done` is disabled while there are no changes
or while saving. Leaving with unsaved changes asks the owner to discard changes
or keep editing.

## Loading and Failure Behavior

- The last cached pin list renders immediately when available, then revalidates
  from relays.
- Pinned references are resolved directly in display-sized batches. An old
  pinned video must not wait for normal profile pagination to reach it.
- An unavailable, deleted, blocked, or no-longer-owned referenced video is
  omitted without leaving an empty grid cell. The reference remains in the
  stored list unless the owner explicitly saves an edited list, avoiding
  destructive cleanup caused by a temporary fetch failure.
- A save failure leaves the draft and current scroll position intact and shows
  a clear retry action. The profile keeps showing the last successfully saved
  order.
- If the list exceeds a relay's accepted event size, saving fails visibly; no
  prefix-only or otherwise truncated list is published.

## Ordering Rules

Let `P` be the ordered stable identities from the pin list and `V` be the
profile's videos in normal feed order.

1. De-duplicate `P` by stable video identity; the first occurrence wins.
2. Keep only references that resolve to a visible video authored by the
   profile owner.
3. Emit the resolved intersection of `P` and `V` in `P` order.
4. Append every video from `V` whose stable identity was not emitted, retaining
   its order from `V`.
5. Keep transient uploads outside `P` and `V` in the owner-only Publishing
   section.

The same pure ordering result supplies the profile grid, tile indexes,
prefetching, and fullscreen feed seed.

## Architecture and Data Flow

Follow the repository's preferred layered flow:

```text
Profile UI / Arrange Profile UI
        ↓
ProfileFeedCubit / ProfilePinsEditorCubit
        ↓
ProfilePinsRepository + VideosRepository
        ↓
Nostr client and local cache
```

`ProfilePinsRepository` owns pin-list subscription, cache, parsing, merging,
signing, and publishing. UI and cubits work only with ordered stable video
identities and never construct Nostr tags.

`ProfileFeedCubit` combines the repository's pin stream with profile video
pages and exposes:

- the single ordered published-video sequence;
- the number of resolved pinned videos;
- pin membership by stable identity;
- pin-list loading and revalidation state.

`ProfilePinsEditorCubit` owns the mutable draft, add/remove/reorder operations,
dirty state, and one-shot save state. A successful repository write updates the
shared pin stream, which makes the profile feed adopt the new order without a
separate UI-side patch.

### Nostr Representation

Use the standard replaceable NIP-51 pin list, kind `10001`, as the single list
per profile. Divine's addressable kind `34236` videos are stored as ordered
NIP-71 `a` references using the stable coordinate
`34236:<author-pubkey>:<d-tag>`.

NIP-51's pinned-notes table describes kind-1 `e` references, while its general
list model allows references to things and NIP-71 defines `a` as the stable way
to reference addressable videos. Divine therefore manages only valid kind
`34236` `a` tags authored by the list owner. On save, the repository must
preserve all unrelated public tags and encrypted `content` byte-for-byte so
using Divine never destroys pins maintained by another Nostr client.

Canonical references:

- [NIP-51 Lists](https://github.com/nostr-protocol/nips/blob/master/51.md)
- [NIP-71 Video Events](https://github.com/nostr-protocol/nips/blob/master/71.md)

## Accessibility

- Pin badges are not the only indication of state; section labels and tile
  semantics announce pinned status and position.
- Reordering has semantic actions equivalent to drag gestures.
- Drag handles and remove controls meet the platform tap-target minimums.
- Saving, success, and failure changes are announced without moving focus away
  from the affected control.
- Dynamic labels use full localized strings rather than concatenated fragments.

## Testing

### Pure ordering tests

- pinned videos precede unpinned videos;
- pin-list order is preserved;
- unpinned videos retain normal order;
- duplicate pin references use the first position;
- unavailable, foreign-authored, blocked, and deleted videos are omitted;
- the same stable identity is not emitted twice;
- metadata replacement of a kind `34236` video does not lose its pin.

### Repository tests

- cached list emits before relay revalidation;
- parsing preserves ordered kind `34236` `a` tags;
- saving preserves unrelated public tags and encrypted content;
- one editor save produces one signed replacement event;
- partial relay failure follows the repository's normal publish-success policy;
- oversize rejection never produces a truncated fallback event.

### Cubit and widget tests

- quick pin appends and quick unpin removes;
- add, remove, and drag operations update only the draft before `Done`;
- dirty back navigation protects changes;
- save failure preserves the draft and exposes retry;
- owner profiles show Publishing separately;
- Pinned and Latest section labels and pin semantics render correctly;
- tapping any tile opens the identical ordered fullscreen sequence;
- paginated unpinned videos remain de-duplicated against pinned videos.

## Out of Scope

- Reordering unpinned videos.
- Pinning videos authored by another account.
- Multiple named profile-pin sets.
- A product-level maximum number of pins.
- Search, folders, or bulk automatic ordering in the arranger.
- Changing video metadata or deletion behavior.
