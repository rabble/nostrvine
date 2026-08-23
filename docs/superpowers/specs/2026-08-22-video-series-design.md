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
coordinate. This supports videos encountered anywhere without a broad `#a`
scan.

#### Cache freshness contract

A series list is a replaceable event, so a session-long cache would freeze it.
A viewer who cached parts 1-3 would keep reading `of 3` for the rest of the
session, and a newly published part 4 would fail membership validation and show
no series UI at all — the feature silently disappearing on exactly the video
that motivated it. The cache is therefore bounded:

- **Entries carry a fetch timestamp and a 60-second TTL.** A read older than
  that refetches before answering. 60 seconds is chosen so a creator publishing
  consecutive parts sees the count move without a restart, while a viewer
  scrolling a feed of one series' parts still gets one fetch, not one per video.
- **A negative membership result is never served from cache.** If the cached
  list does not contain the video's coordinate, refetch once before concluding
  the video is not a member. Only a fresh miss suppresses the series UI. This is
  the rule that keeps a just-published part from rendering as an ordinary video;
  everything else here is an optimization, this one is correctness.
- **Local mutation invalidates immediately.** `createSeries` and the append path
  in `CuratedListService` evict the affected coordinate synchronously, before
  their futures complete, so the publishing creator never reads their own stale
  list.
- **A newer replaceable event wins on arrival.** If any live subscription
  delivers a kind-30005 event for a cached coordinate with a higher `created_at`
  (ties broken by lower event id, matching the replaceable-event ordering
  already applied on fetch), it replaces the entry rather than waiting for the
  TTL.

Staleness that survives all four is bounded to 60 seconds on the total, and to
zero on membership. `Part 3 of 9` briefly reading `of 8` is acceptable; `no
series UI` for a valid part is not, which is why only the count is allowed to
lag.

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

1. If a new series was requested, create its empty kind-30005 event first, and
   do not begin the video publish until a relay has accepted it. A creation
   failure keeps the user on the metadata screen with retry and cancel actions.

   The existing `CuratedListService.createList()` already provides this proof
   and needs no new API. For a public list by an authenticated user it calls
   `_publishListToNostr(newList, confirmed: true)`, which awaits
   `publishEventAwaitOk` and treats `outcome.acceptedByAny` as the bar; on
   failure it removes the local list, re-saves, and returns `null`
   (`mobile/lib/services/curated_list_service.dart:273-280`, `1135-1148`). The
   publication result is not discarded — a non-null return **is** the
   relay-acceptance proof.

   Two conditions are load-bearing, and `createSeries` must enforce both rather
   than inherit them by luck: the list must be `isPublic: true`, and the user
   must be authenticated. When either is false the publish is skipped entirely
   and a local-only list is returned — which for a series would mean a creator
   builds parts against a list no viewer can resolve. `createSeries` therefore
   fixes `isPublic: true` and fails closed when unauthenticated, and the publish
   flow treats a `null` return as the creation failure above.
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
`CuratedListFeedScreen` playback at index 0. That screen cannot do this today,
so version 1 extends it — see [Playback entry contract](#playback-entry-contract). The series mode of that screen adds
part numbers to grid items; playback remains
`PooledFullscreenVideoFeedScreen` with the list's existing order. Swipe and
auto-advance behavior remain unchanged.

#### Playback entry contract

`CuratedListFeedScreen` currently opens in grid mode and has no way to start in
playback: its constructor takes `listId`, `listName`, `videoIds` and
`authorPubkey` only, and `_activeVideoIndex` is initialized to `null`, which is
exactly what selects the grid
(`mobile/lib/screens/curated_list_feed_screen.dart:59-64`, `82`, `95`). The
acceptance criterion "tapping the chip starts the ordered series at part 1"
therefore requires a screen change, not just navigation.

Version 1 adds:

- **`final int? initialVideoIndex;`** to `CuratedListFeedScreen`, defaulting to
  `null` so every existing call site keeps today's grid-first behavior
  unchanged.
- **`initState` seeds `_activeVideoIndex` from it.** The field stays mutable and
  every existing transition — selecting a grid item, backing out to the grid —
  is untouched, so back from playback still lands on the grid rather than
  leaving the screen.
- **An out-of-range or negative value falls back to the grid** rather than
  throwing. The existing guard at line 265 already discards an index past the
  loaded video count; the constructor value goes through the same path, which
  matters because the list can name a part whose video fails to load.
- **`CuratedListByAuthorScreen` forwards it** from an optional `play` query
  parameter on `/list/:pubkey/:listId`, parsed with `int.tryParse` so a
  malformed value degrades to the grid instead of failing the route. This keeps
  the entry point a plain deep link, so a shared series URL can also open at a
  part.
- **`SeriesChip` navigates to** `CuratedListByAuthorScreen.pathFor(...)` with
  `play=0`.

The existing list route, deep link, sharing, loading, and missing-video behavior
are otherwise reused. Version 1 adds no previous/next overlay buttons and no new series
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
| Series creation fails (`createSeries` returns `null`, i.e. no relay accepted the list, or the user is unauthenticated) | Do not start the video publish. Keep the metadata state and offer retry or cancel. |
| Video publish fails | Do not append the part. The background retry retains the selected series coordinate. |
| Video succeeds but list relay publish fails | Keep the locally appended part and the existing pending-republish state; remote viewers see no chip until the list update reaches a relay. |
| Series list is missing or deleted | Render no chip. The video remains an ordinary playable video. |
| Video tag and list membership disagree | The list wins. Render no chip until the list contains the video's coordinate. |
| A listed video cannot be loaded | Omit it from the grid/player without rewriting the list. Part numbers still come from the authoritative list order and may contain a gap. |

## Testing

- `models`: `CuratedList.isSeries` and `VideoEvent.seriesCoordinate` JSON,
  `copyWith`, equality, tag parsing, and marked-versus-unmarked `a` tags.
- `curated_list_repository`: series marker round-trip, exact-coordinate fetch,
  replaceable-event winner selection, validation, and caching. Cache freshness
  specifically: a read inside the TTL does not refetch, a read past it does, a
  cached negative membership refetches before suppressing the UI, a local
  mutation evicts synchronously, and a higher-`created_at` event arriving on a
  subscription replaces the entry.
- `CuratedListService`: `createSeries` invariants and append behavior using a
  full kind-34236 coordinate, including that it forces `isPublic: true`, fails
  closed when unauthenticated, and returns `null` when no relay accepts the
  list.
- Publish: selected series is retained in the draft, the marked tag is signed,
  append happens only after successful video publication, and failed list
  publication retains retry state.
- `VideoSeriesCubit`: absent/malformed coordinate, missing list, wrong owner,
  missing membership, and valid index.
- Widget: chip copy, no chip for ordinary or invalid videos, numbered series
  grid, and chip navigation starts playback at part 1. Also that
  `initialVideoIndex: null` still opens the grid, that an out-of-range value
  falls back to the grid, and that backing out of seeded playback lands on the
  grid.
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
