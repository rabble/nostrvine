# Brainstorm: Dedupe WS-first notifications against later REST loads (#4264)

Date: 2026-05-12 (Round 3 final)

## Problem Statement

When a notification arrives over WebSocket first and a later REST page
(typically pagination) pulls the same logical event,
`NotificationRepository._emitSnapshotForPage` appends a duplicate row
(or a duplicate contribution to a `(videoEventId, kind)` group) because it
dedupes by the rendered `NotificationItem.id`. WS sets `id = nostr_event_id`
via the bridge; REST sets `id = server_uuid` from
`RelayNotification.fromJson`. PR #4247 closed the REST → WS direction with
`_knownSourceEventIds` inside `acceptRealtime`. The reverse case
(WS → REST) has no equivalent guard inside `_emitSnapshotForPage`.

## Cross-path dedupe matrix

| Direction | Current gate | Caught? | After this fix |
|-----------|-------------|---------|----------------|
| REST → REST same UUID (same page repeat) | `existingIds = ...map(id)` line 338 | ✅ | unchanged |
| REST → WS (same Nostr event over WS after REST) | `_knownSourceEventIds.contains(raw.id)` line 260 | ✅ (PR #4247) | unchanged |
| WS → WS same Nostr event id | `n.id == newItem.id` line 267 | ✅ | unchanged |
| **WS → REST in pagination** | none | ❌ | **new `sourceEventIds` overlap + `(videoEventId, kind)` merge in `_emitSnapshotForPage`** |

## Constraints

- **Layered architecture** (`.claude/rules/architecture.md`): composition,
  caching, source-selection live in the repository; the BLoC/UI must not
  reach around it.
- **Engineering Standard from #4200 epic**: fix without adding new debt;
  repay adjacent debt where reasonable.
- **AC line "dedupe key is explicit and covered by tests"**: typed field
  on the rendered item is the cleanest way to satisfy this.
- **No regression to PR #4247's REST → WS guard** — `acceptRealtime`'s
  early return on `_knownSourceEventIds.contains(raw.id)` MUST stay.
  Test at `notification_repository_test.dart:1611` is load-bearing
  (`tests-guard-intentional-workarounds`).
- **No regression to WS → WS dedupe** (`acceptRealtime` line 267).
- **`mark-as-read` server contract** uses `NotificationItem.id` — do NOT
  change `id`. The pre-existing WS-first mark-as-read concern is tracked
  under #4208, not this issue.
- **`NotificationItem` lives in `models/`** (Flutter-free domain layer).
- **Snapshot-first reactivity**: `BehaviorSubject<NotificationPage>` is
  the single source of truth.

## Prior Art

- **Legacy `relay_notifications_provider.dart:442, :541`**: the legacy
  Riverpod stack used `metadata?['sourceEventId'] == notification.id`
  for cross-path dedupe. PR #4247 ported half of this pattern
  (`_knownSourceEventIds`); this PR ports the other half.
- **`acceptRealtime`'s `_mergeIntoExistingVideoGroup`** (`notification_repository.dart:293-322`):
  symmetric merger for "incoming WS → existing in-snapshot group" — the
  new `_emitSnapshotForPage` merger mirrors this in reverse direction.
- **Prior brainstorm `2026-05-11-issue4204-unify-unread-state-brainstorm.md`**:
  predecessor; established the snapshot architecture and
  `_knownSourceEventIds`. This brainstorm extends it.
- **PR #2821 `fix/notification-dedup-and-refresh-merge`**: historical
  cross-path dedup work on the legacy stack. Pattern confirmed; not
  directly reusable post-rewrite.

## Approaches Explored

### Approach A — Carry `sourceEventIds` on `NotificationItem`; merge-or-skip in `_emitSnapshotForPage` (RECOMMENDED — locked)

**Description:** Add `sourceEventIds: List<String>` (default `const []`)
to the `NotificationItem` base. Populate at the 4 production construction
sites in `notification_repository.dart` (`_groupVideoAnchored` line 532,
`_mapActorAnchored` line 583, `enrichOne` lines 629 and 660). Extend
`_mergeIntoExistingVideoGroup` to union `sourceEventIds` when WS arrivals
merge into existing groups. Add a non-first-page branch in
`_emitSnapshotForPage` that (a) merges by `(videoEventId, kind)` for
`VideoNotification`, (b) skips items whose `sourceEventIds` overlap the
rendered set, (c) appends otherwise.

**Layers affected:** Repository (`notification_repository`),
Models (`models`).

**Pros:**
- Dedupe key is typed on the rendered item — AC "explicit and covered by
  tests" satisfied.
- Symmetric with `_mergeIntoExistingVideoGroup`: both gates speak the
  same identity language.
- No hidden repository state.
- Enables a follow-up cleanup that retires `_knownSourceEventIds` — debt
  reduction over time.
- Bounded blast radius (4 production sites + 1 new helper + model field).

**Cons:**
- Touches `models/`. `Equatable.props` change makes two otherwise-equal
  items with different sourceEventIds compare unequal — verified no
  existing test asserts cross-construction equality that would break.

**Risks / Unknowns** (all closed):
- ✅ Merge semantics for `(videoEventId, kind)` overlap — locked:
  union `sourceEventIds`; `totalCount = unionIds.length`; rebuild `actors`
  preserving existing-first then non-duplicate-incoming, capped at
  `_maxGroupActors`; `isRead = existing.isRead && incoming.isRead`;
  `timestamp = max(existing.timestamp, incoming.timestamp)`; preserve
  existing thumbnail/title with incoming as fallback (mirrors line 538);
  `commentText` for `kind == comment`: prefer incoming non-null else
  existing; else null.
- ✅ `_mergeIntoExistingVideoGroup` MUST also union `sourceEventIds` —
  required so WS-only groups carry the seen sourceEventId for the new
  page-merge gate to recognize.
- ✅ First-page emit UNCHANGED — full replace remains correct (REST first
  page is ground truth).
- ✅ `acceptRealtime` line 267 (`n.id == newItem.id`) migration to
  `sourceEventIds`-overlap — DEFER. Small consistency win; not required
  by AC; would expand the diff. Track as a follow-up if reviewers ask.
- ✅ `_knownSourceEventIds` removal — DEFER. Required by PR #4247's
  test; remove only when a follow-up consolidates dedupe substrate.
- ✅ Empty `sourceEventIds` raw — if `n.sourceEventId.isEmpty`, contribute
  no entry to the rendered item's list. Same guard as line 381.
- ✅ Extract `_mergeAppendedPage` helper or inline in
  `_emitSnapshotForPage`? Extract — readability and testability.

**Complexity:** Medium. Well-bounded.

### Approach B — Pre-filter raws in `_enrichAndGroup` (REJECTED — Round 1 + 2)

Fails AC "explicit and covered by tests"; forces merge logic into
`_emitSnapshotForPage` anyway; hidden coupling to grouping internals.

### Approach C — Internal `Map<String, String>` `_sourceEventIdToItemId` (REJECTED — Round 1 + 2)

Two parallel data structures to keep in sync; same AC weakness as B.

### Approach D — Always use Nostr event id as `NotificationItem.id` (REJECTED — Round 1 + 2)

Breaks `mark-as-read` server contract; cross-package risk.

## Recommendation

**Approach A — locked.**

1. AC fit: typed `sourceEventIds` on the rendered item, asserted in
   repository tests and model tests.
2. Symmetry with PR #4247.
3. Composition stays in the repository per `architecture.md`.
4. Bounded blast radius: 4 production construction sites + 1 helper +
   2 model fields (one base, transparently exposed to subtypes).
5. Enables debt reduction follow-up (retire `_knownSourceEventIds`).

## Open Questions for /plan

All directional questions resolved. Remaining items are pure
implementation details (covered by the merge-semantics lock-in above):

- [x] Merge semantics for `(videoEventId, kind)` overlap → locked.
- [x] `_mergeIntoExistingVideoGroup` sourceEventIds union → required.
- [x] First-page behavior → unchanged.
- [x] `acceptRealtime` line 267 migration → defer.
- [x] `_knownSourceEventIds` removal → defer.
- [x] Helper extraction shape → extract `_mergeAppendedVideoGroup`.

## Prerequisites

- [ ] None. All context is in-repo. No protocol decisions, no design
  mockups, no new packages.

## Final test plan (for /plan)

Repository tests (`notification_repository_test.dart`):

1. `WS-first ActorNotification, then REST page-2 returns same Nostr event
   with server UUID → snapshot has 1 ActorNotification with sourceEventIds
   containing the Nostr event id.`
2. `WS-first VideoNotification (1 actor) on video_a, then REST page-2
   returns 3 likes on video_a → snapshot has 1 VideoNotification with
   totalCount = 3, actors cap = 3, sourceEventIds union of 3 unique ids;
   existing row's position preserved.`
3. `WS-first on video_a, REST page-2 has video_b only → snapshot has 2
   items (no false dedupe across unrelated events).`
4. `WS-first then REST page-2 with same event AND additional new events →
   snapshot has new events appended once; WS row merged once with no
   duplication.`
5. `Regression: existing test "acceptRealtime dedupes a WS arrival whose
   id matches a REST item's sourceEventId" still passes verbatim.`

Model tests (`video_notification_test.dart`, `actor_notification_test.dart`):

6. `VideoNotification accepts sourceEventIds and defaults to const [].`
7. `VideoNotification.copyWith(sourceEventIds: ...) round-trips.`
8. `Two VideoNotifications with different sourceEventIds are unequal
   via Equatable.`
9. Same three for `ActorNotification`.

## Next Step

`/plan #4264` — produce the file-by-file diff intent.
