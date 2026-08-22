# Video Series — Design

Date: 2026-08-22
Status: Approved design, pending implementation plan

## Problem

A creator has a story that doesn't fit in one 6-second loop. Today they post
part 1, part 2, and part 3 as three unrelated videos. A viewer who meets part 3
in the feed has no way to know parts 1 and 2 exist, and no way to watch them in
order.

Series makes that ordering explicit: a viewer sees "Part 3 of 10", can jump to
the start, and can walk forward and back through the parts.

## Non-goals

- Series containing other people's videos. Curating other creators' work is the
  existing curated-list feature and stays there.
- A dedicated Discover surface for series, series cards on profile, or
  "start from part 1" entry points. Deferred until series exist in the wild.
- Any new Nostr event kind.

## Data model

A series is a **kind 30005 curated video list** with `playorder=manual`. The
existing `curated_list_repository` package already models, converts, publishes,
and deep-links these lists; series reuse all of it.

Two additions:

**On the list event (kind 30005):**

```
["series", "true"]
```

Marks the list as a series so ordinary curated lists stay ordinary in Discover
and in list UI. Part order is the existing `a`-tag order under
`playorder=manual` — no separate order field on the list.

**On each part (kind 34236, the creator's own video):**

```
["a", "30005:<owner_pubkey>:<series_d_tag>"]
["part", "3"]
```

`part` is the 1-based position. It exists so a video can render its own chip
without first fetching the list. **The list is authoritative for order.** If the
two disagree — the owner reordered parts after publishing — the list wins and
the chip renders from list position.

**Parts also chain as video replies.** Every part after the first publishes as a
NIP-22 video reply, root (`E`/`A`/`K`) pointing at part 1 and parent
(`e`/`a`/`k`) at part N-1 — the same tag shape `comments_repository` already
builds for video replies. This is free continuity: the chain renders as a thread
in any Nostr client, and `VideoReplyParentLink` already shows the parent link in
this app with no new work.

The chain is a second, redundant expression of the order. The list stays
authoritative: it survives a deleted part, supports reorder without re-parenting
videos, and answers "of 10" in one fetch, none of which a chain does. When the
two disagree, the list wins.

### Series parts are not comments

Because parts reply to part 1, they would otherwise appear as comments on it — a
10-part series reading as 9 comments. The comments list filters out a video
reply when it is authored by the root video's author *and* carries the root's
series coordinate. Those are series parts, surfaced by the series UI, not the
comment thread. Video replies from anyone else, and the author's own video
replies that are not series parts, are unaffected.

### Why tags on the video

Tagging the video gives reverse lookup for free: a video met anywhere (main
feed, profile, hashtag, deep link) already names its series, so the chip needs
one addressable fetch of the list, cached, and no `#a` scan or server index.

Two alternatives were considered and folded in or rejected:

- **Prev/next tags with no list object** — rejected. Linking part N to part N+1
  means republishing part N *after* N+1 exists: one edit per link, and a single
  failed edit breaks the chain with nothing holding the truth.
- **Reply chain only** (part N is a video reply to part N-1, no list) — folded
  in as the redundant layer rather than adopted alone. It costs nothing and
  reads natively as a thread, but on its own it can't answer "of 10" without
  walking every hop, branches ambiguously if the author posts two video replies
  to one part, snaps when a middle part is deleted, and needs re-parenting edits
  to reorder.

### Membership

Own videos only. A creator can only sign their own events, so a series built
from someone else's videos would have untagged parts and no chip. Series is a
creator's own multi-part story; curating others stays the curated-list feature.

### Edit path

Assigning an already-published video to a series republishes its kind 34236
event. The repo has a known bug where `published_at` goes null on edit and the
publication date is permanently rewritten. That path must preserve every
original tag verbatim, `published_at` included. This is a hard blocker for the
feature, covered by a regression test — not worked around.

## Components

### Package: `curated_list_repository`

- `isSeries` on `CuratedList`, round-tripped through the converter's tag
  read/write.
- `createSeries()`.
- `reorderParts(listId, from, to)` — rewrites `a`-tag order and republishes the
  30005 event. No video edits.
- `seriesForVideo(videoCoordinate)` — resolves a video's series `a` tag to the
  list, cached.

### Publish path

The existing publish/metadata flow gains a series field. The picked series
coordinate and computed part index are written into the kind 34236 tags at sign
time, so first-publish assignment never involves an edit. When the series
already has parts, the same sign step adds the NIP-22 root and parent tags,
reusing the tag builder in `comments_repository`.

### Comments list

`comments_list_bloc` drops video replies that are authored by the root video's
author and carry the root's series coordinate, so series parts stay out of the
comment thread. Everything else about comments is untouched.

### BLoC: `mobile/lib/features/series/bloc/`

- `SeriesBloc` — loads a series and its ordered parts, owns `currentIndex`,
  exposes `hasPrev` / `hasNext`. Drives both the series screen and the player
  chrome.
- `VideoSeriesChipCubit` — per video: resolves the series `a` tag to a name and
  a part position. Emits nothing when the video carries no series tag, so the
  chip never renders on ordinary videos.

### UI

- `SeriesChip` — renders `Part 3 of 10 · Series name`, tappable, opens the
  series. App-level (not `divine_ui`) because it needs l10n; built from
  `divine_ui` primitives.
- Prev / next `DivineIconButton`s beside the chip in the fullscreen overlay,
  shown only while a series is active.
- Series screen — the existing `CuratedListFeedScreen` in a series mode:
  numbered parts, drag-to-reorder for the owner, viewer-only for everyone else.
- "Add to series" in the existing video menu; series picker in the publish
  metadata screen.

### Reused as-is

Playback stays `PooledFullscreenVideoFeedScreen`, fed a series-ordered video
list. Auto-advance inherits the user's existing feed setting — no new toggle,
no new policy. Sharing, deep links, and list CRUD already exist.

## User flows

**Publish, series doesn't exist yet.** Metadata screen → "Part of a series" →
picker lists your series plus "New series…" → name it → the 30005 list is
created and the video is tagged part 1, in one submit.

**Publish, series exists.** Pick the series; the video is tagged with the next
part number (highest existing part + 1).

**Retroactive.** Two ways into the same sheet: the video's own menu
("Add to series"), or "Add videos" from inside a series — a grid of the
creator's own videos, multi-select, ordered by pick order. This is the edit
path described above.

**Reorder / remove.** Owner sees numbered parts with drag handles on the series
screen. Reordering republishes only the 30005 list. Videos' `part` tags go
stale, which is expected: the list is authoritative and the chip renders from
list position. Removing a part never blocks — a video pointing at a series that
no longer lists it simply shows no chip.

**Viewer.** Meets part 3 in the feed → chip reads `Part 3 of 10 · Name`. Tap
the chip for the series screen numbered from part 1, or use prev/next to walk
the series without leaving the player.

**Someone else's series.** Chip, prev/next, series screen, share. No add, no
reorder.

## Long-record → series

The strongest entry point, and new capability rather than a wire-up.

Record or import a long clip → the editor offers "Split into a series" → cut
points default to roughly every 6 seconds and are draggable → name the series →
export N segments → publish N videos, each tagged with the series coordinate
and its part index, in order.

What this requires that does not exist today:

- The editor accepting a source longer than `VideoEditorConstants.maxDuration`
  (6.3s) in series mode. That cap is a hard invariant today; series mode carves
  an explicit exception.
- N sequential exports through `VideoEditorRenderService`, with progress UI.
- Batch publish with partial-failure handling. The series list publishes first;
  each part publishes independently; failures fall into the existing
  background-upload retry path. A series with gaps renders the parts that
  exist and never blocks.
- Segment preview and adjustment before committing.

`VideoEditorSplitService` is not reusable directly — it splits within a single
video's timeline (trim-based, both halves stay one post). Its split-position
validation math is reusable; the segment-to-separate-post pipeline is new.

This is roughly as much work as the rest of the design combined. It ships in
v1 by decision.

## Failure handling

| Failure | Behavior |
|---|---|
| Part published, list republish fails | Video carries the series tag, list lacks the part. Chip resolves the list, finds no part, renders nothing. Retried on next series open. |
| List published, parts fail to upload | Series exists with gaps. Landed parts render; failed parts sit in the existing background-upload retry queue. |
| Retro-assign edit drops `published_at` | Hard blocker. Republish preserves all original tags verbatim; regression test asserts `published_at` survives. |
| Part deleted (kind 5) | Remaining parts render, renumbered from list position. |
| Series list deleted, videos still tagged | Chip resolves nothing and renders nothing. Never an error state. |
| Middle part deleted, breaking the reply chain | List renumbers and playback continues; the chain is redundant, so a snapped link is cosmetic. Later parts keep pointing at a deleted parent and their parent link renders nothing. |
| Retro-assigned part has no reply tags | Expected. Videos assigned after publish keep their original threading; only the list places them. The chain is best-effort, the list is complete. |
| Segment export fails mid-batch | Already-exported segments keep their queued uploads; the failed segment retries without redoing the others. |

## Testing

- **Package** (`curated_list_repository`, 100% coverage gate): converter
  round-trip for the `series` tag, `orderedVideoIds` under manual order,
  reorder republish, `seriesForVideo` resolution and caching.
- **BLoC**: `SeriesBloc` load, prev/next, boundary behavior;
  `VideoSeriesChipCubit` emits nothing for untagged videos; list position wins
  over a stale `part` tag.
- **Widget**: chip renders `Part 3 of 10`; prev disabled at part 1; next
  disabled at the last part; no chip on ordinary videos; l10n delegates wired.
- **Publish**: tags written on first publish; part N carries NIP-22 root at
  part 1 and parent at part N-1; retro-assign preserves `published_at` and
  every prior tag and adds no reply tags.
- **Comments**: a series part does not appear in the root video's comment
  thread; a non-series video reply from the same author still does.
- **Editor**: split-point math, N-segment export, partial-failure recovery.
- **Golden**: chip in the fullscreen overlay.

All new copy goes through `context.l10n`, with keys mirrored into every
`app_*.arb` locale or recorded as known untranslated debt.

## Delivery note

Series core and the editor split flow are dependent, so they either combine
into one PR or the core merges to `main` first and the split flow follows as a
second PR branched from fresh `main`. The second form is not stacking and keeps
review tractable. This is a plan-level decision, resolved in the
implementation plan rather than here.
