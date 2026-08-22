# Video Series — Design

Date: 2026-08-22
Status: Revised design, pending review

## Problem

A creator has a story that does not fit in one 6-second loop. Today they post
part 1, part 2, and part 3 as unrelated videos. A viewer who meets part 3 in a
feed cannot tell that earlier parts exist or watch the story in order.

The first release needs one complete loop: a creator publishes a new video into
a named series, and a viewer can identify the part and start the series from
part 1.

## Scope

Version 1 includes:

- Creating or selecting one of the creator's series while publishing a video.
- Appending each successfully published video to that series.
- Showing `Part 3 of 10 · Series name` on a series video.
- Opening the existing curated-list feed at part 1 from that label.
- Showing part numbers in the existing curated-list grid.
- Swiping through the ordered parts with the existing fullscreen list player.

Version 1 does not include:

- Assigning already-published videos to a series.
- Removing or reordering parts.
- Splitting a long recording into several posts or batch publishing.
- Encoding series order as a NIP-22 reply chain.
- A dedicated series discovery surface, profile section, or series card.
- Collaborative series or series containing another creator's videos.
- A new Nostr event kind.

These are separate product problems. They should be reconsidered after the
publish-and-watch loop has real usage rather than built speculatively.

## Protocol and data model

### Series list

A series is a public kind-30005 curated video list with manual play order. It
uses the existing list fields and adds one marker:

```text
["series", "true"]
```

Each part is an existing ordered `a` tag containing the part's kind-34236
coordinate. The list order is the only source of truth for part number and
total count.

Series created by Divine are non-collaborative and public. When reading a
series, the app only accepts kind-34236 coordinates whose embedded author
matches the list author. Malformed or foreign-author entries are ignored.

### Video reference

Each newly published series video carries a marked reference to the list:

```text
["a", "30005:<creator_pubkey>:<series_d_tag>", "", "series"]
```

The `series` marker distinguishes this reference from inspired-by, reply, and
other `a` tags already used on video events. The creator pubkey in the
coordinate must match the video author.

There is deliberately no `part` tag. Rendering `Part 3 of 10` already requires
the list for its name and total, so a second copy of the index only creates
stale state. There are also no reply tags: a reply chain would duplicate order,
change comment semantics, and require filtering work unrelated to the core
feature.

If the referenced list is missing, is not marked as a series, does not contain
the video's addressable coordinate, or has a different owner, the video is
treated as an ordinary video and no series UI is shown.

## Architecture

### Models and conversion

- Add `isSeries` to `CuratedList` and persist it through JSON serialization,
  `copyWith`, equality, and `CuratedListConverter` event conversion.
- Add a nullable `seriesCoordinate` to `VideoEvent`. Parse only an `a` tag with
  the `series` marker and persist the value through JSON serialization and
  `copyWith` so cached REST and relay videos behave the same.
- Preserve the full coordinate everywhere. Nostr identifiers are never
  truncated.

### Existing list mutation path

Keep kind-30005 writes in `CuratedListService`, where list creation, local
persistence, serialized mutation, relay publication, and retry state already
live. Version 1 adds only:

- `createSeries(name)`, which creates a public, non-collaborative manual list
  with the series marker.
- Appending a published video's addressable coordinate through the existing
  list-mutation path.

Do not move all list CRUD into `curated_list_repository` as part of this
feature. That package is currently a read-oriented bridge, and completing the
larger Riverpod-to-repository migration is unrelated scope.

### Series lookup

Add one exact-coordinate fetch to `CuratedListRepository`, backed by its
existing `NostrClient`: query kind 30005 by author and `d` tag, apply
replaceable-event ordering, validate `isSeries`, and cache the result by full
coordinate for the session. This supports videos encountered anywhere without
a broad `#a` scan.

`VideoSeriesCubit` is the only new state-management unit. Given a `VideoEvent`,
it:

1. Returns no series state when `seriesCoordinate` is absent or malformed.
2. Loads the exact list through `CuratedListRepository`.
3. Validates matching ownership and membership.
4. Exposes the list and the video's zero-based index.

There is no separate `SeriesBloc`; the existing curated-list providers and
fullscreen player already own list loading and playback.

### Publish flow

The metadata screen adds an optional series picker containing the creator's
series and `New series…`. Creating a series asks only for a name. The selected
full series coordinate is stored in the publish draft/background-upload state
so retries do not lose it.

At publish time:

1. If a new series was requested, create its empty kind-30005 event first. A
   creation failure keeps the user on the metadata screen with retry and cancel
   actions.
2. Sign and publish the video with the marked series `a` tag.
3. After the video publish succeeds, append its stable kind-34236 coordinate to
   the list through `CuratedListService`.

The operations are intentionally not described as atomic; Nostr cannot provide
that guarantee. The existing list mutation path persists a failed relay update
locally and marks it for republish. A failed video publish does not append a
part, and its background retry retains the series selection.

Generic `Add to list` UI excludes series in version 1 because adding a video to
only the list would not add the required marked tag to an already-published
video.

### UI and routing

`SeriesChip` is app-level UI built from `divine_ui` primitives because its copy
is localized. It renders only from a loaded `VideoSeriesCubit` state and reads:

```text
Part 3 of 10 · Series name
```

Tapping it opens the existing author/list route and starts
`CuratedListFeedScreen` playback at index 0. The series mode of that screen adds
part numbers to grid items; playback remains
`PooledFullscreenVideoFeedScreen` with the list's existing order. Swipe and
auto-advance behavior remain unchanged.

The existing list route, deep link, sharing, loading, and missing-video behavior
are reused. Version 1 adds no previous/next overlay buttons and no new series
screen. Existing list discovery may show a series as a normal public list; no
special discovery treatment is added.

## User flows

### Publish into a new series

Metadata → `Part of a series` → `New series…` → enter a name → publish. The app
creates the empty series, publishes the tagged video, then appends the video's
coordinate as part 1.

### Publish the next part

Metadata → `Part of a series` → choose an existing series → publish. After the
video succeeds, its coordinate is appended and its position is derived from the
updated list.

### Watch

A viewer meets part 3 in any feed. Once the referenced list resolves, the chip
reads `Part 3 of 10 · Series name`. Tapping it starts the existing list player at
part 1; the viewer swipes or auto-advances through the remaining parts.

## Failure handling

| Failure | Behavior |
|---|---|
| Series creation fails | Do not start the video publish. Keep the metadata state and offer retry or cancel. |
| Video publish fails | Do not append the part. The background retry retains the selected series coordinate. |
| Video succeeds but list relay publish fails | Keep the locally appended part and the existing pending-republish state; remote viewers see no chip until the list update reaches a relay. |
| Series list is missing or deleted | Render no chip. The video remains an ordinary playable video. |
| Video tag and list membership disagree | The list wins. Render no chip until the list contains the video's coordinate. |
| A listed video cannot be loaded | Omit it from the grid/player without rewriting the list. Part numbers still come from the authoritative list order and may contain a gap. |

## Testing

- `models`: `CuratedList.isSeries` and `VideoEvent.seriesCoordinate` JSON,
  `copyWith`, equality, tag parsing, and marked-versus-unmarked `a` tags.
- `curated_list_repository`: series marker round-trip, exact-coordinate fetch,
  replaceable-event winner selection, validation, and caching.
- `CuratedListService`: `createSeries` invariants and append behavior using a
  full kind-34236 coordinate.
- Publish: selected series is retained in the draft, the marked tag is signed,
  append happens only after successful video publication, and failed list
  publication retains retry state.
- `VideoSeriesCubit`: absent/malformed coordinate, missing list, wrong owner,
  missing membership, and valid index.
- Widget: chip copy, no chip for ordinary or invalid videos, numbered series
  grid, and chip navigation starts playback at part 1.
- Localization: mirror new keys into every `app_*.arb` locale or record known
  untranslated debt, then run the ARB consistency test.
- Visual verification: run the existing golden verification workflow and
  update only goldens affected by the chip or numbered grid.

## Acceptance criteria

- A creator can create or select a series while publishing a new video.
- A successfully published part appears once at the end of the series list.
- A series video encountered outside the series resolves to the correct name,
  position, and total without scanning all lists.
- Tapping the chip starts the ordered series at part 1.
- Ordinary videos and inconsistent or unavailable series data show no series
  UI and continue to play normally.
- No reply/comment behavior, existing-video republish flow, editor duration
  rules, or batch uploader is changed by version 1.
