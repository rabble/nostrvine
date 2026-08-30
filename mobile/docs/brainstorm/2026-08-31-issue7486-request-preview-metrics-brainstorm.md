# Brainstorm: message-request preview profile metrics (#7486)

Date: 2026-08-31

## Problem Statement

Issue #7486 asks the message-request preview to stop using `UserProfile.followerCount` /
`videoCount` — getters that fall back from Funnelcake REST counts to Vine-archive Kind 0
metrics — and to use the REST-only `restFollowerCount` / `restVideoCount` introduced by
PR #7453 instead.

Investigation (see `tasks/findings_7486.md`) established at 1.0 confidence that **the issue's
diagnosis is wrong**. Both operands of the conflating getters are structurally `null` on this
screen, so the preview's stats line has **never rendered in production**. The real problem is
not a mislabelled number; it is a feature that silently never shipped, reading two sources that
are both permanently empty.

## Constraints

- **Layered architecture** — UI → BLoC/Cubit → Repository → Client. Count selection is a data
  concern; the widget may read a provider but must not choose between sources itself.
- **Riverpod is legacy but is the established bridge here.** The preview is already a
  `ConsumerWidget` reading `userProfileReactiveProvider`; the sibling count source
  (`userProfileStatsReactiveProvider`) is a Riverpod `StreamProvider.family`. Introducing a new
  Cubit purely to wrap it would add a layer nothing else on this screen uses.
- **`ProfileStats.followers` is null-means-unknown, never zero.** `_cacheProfileStatsFromResult`
  (`profile_repository.dart:767-772`) deliberately withholds a REST `0`, because funnelcake
  collapses ClickHouse failures into `{0, 0}` (#8259 review). Rendering `null` as `0` would be a
  correctness regression.
- **l10n** — every user-facing string via `context.l10n`; any new ARB key must be mirrored into
  22 locales and is policed by the orphan ratchet (#3630) and `arb_consistency_test`.
- **Theming** — `context.vineColors.*` for adaptive surfaces; `VineTheme.*Font()` for type.
- **Design-system ratchets** — per-file ceilings on raw `TextStyle(`, raw colors, Material
  buttons and raw dialogs may not grow.
- **PR #8384** (open, same file) must merge first; work is prepared and held.

## Prior Art

- **PR #7453** (`76147bc0`, merged 2026-08-15) introduced the REST-only getters and migrated
  people search. It is correct *for search*, which is the one path that populates
  `follower_count` in `rawData`.
- **`_ProfileStatsRow`** (`mobile/lib/widgets/profile/profile_header_media.dart:245-360`) is the
  canonical consumer of `ProfileStats`: Skeletonizer while `profileStats == null`, a 7 s timeout
  after which each count degrades to `—` rather than shimmering forever or collapsing the row.
- **`profileLoopsVisibilityFloor = 10000`** (`profile_header_media.dart:21`) with an explicit
  doc comment that it is a deliberate product call, independent of the feed-card floor.
- **`videoFeedLoopCountLine`** (`app_en.arb:1211`) — a loops count string already translated in
  **22/22** locales.
- No prior brainstorm covers profile metric sourcing.

## Key findings that shaped the options

1. `UserProfile.rawData` has exactly three producers, with **disjoint** shapes
   (`findings_7486.md` F8). Only `ProfileSearchResult.toUserProfile()` ever writes
   `follower_count` / `video_count`, and it is never persisted to the Drift cache (F10).
2. REST by-pubkey (`GET /api/users/{pk}`) nests counts under `social` / `stats`, not `profile`,
   so they land in the **`profile_statistics`** Drift table, not in `rawData` (F9, F14).
3. `vine_followers` / `vine_loops` are written by `divine-resurrection-publisher`
   (`src/nostr.ts:122-123`) as **tags**, never into kind-0 content. Measured across 3,313 unique
   production kind-0 events: 0 in content, 6 in tags (F12, F13).
4. `user_profiles` has **no tags column**; `rawTags` is not persisted, so a cache-read profile
   always has empty tags (F19).
5. `request_preview_view.dart:272-273` is the **only** reader of the conflating getters in all
   production code (F18).

## Approaches Explored

### Approach A: Read `profile_statistics` via `userProfileStatsReactiveProvider` — **CHOSEN**

**Description:** Watch `userProfileStatsReactiveProvider(otherPubkey)` alongside the existing
`userProfileReactiveProvider`, and render `followers` / `videoCount` / `totalViews` from
`ProfileStats`. This is the store where the REST by-pubkey counts already land, so no new
network path, no new repository method, and no protocol work is required.

**Layers affected:** UI only. Repository, client and model are untouched.

**Pros:**
- Makes the line render real Divine counts for the first time — it fixes the feature rather than
  renaming a null.
- Uses the store that already receives these counts; zero new data plumbing.
- Reuses the profile header's established loading vocabulary, so the two surfaces agree.
- Respects `followers == null` ⇒ unknown, which is the documented contract.

**Cons:**
- Adds a second provider watch to the widget.
- Adds the header's Skeletonizer/timeout machinery to a previously stateless subtree.

**Risks / Unknowns:** `ProfileStats.videoCount` is a non-nullable `int` defaulting to `0`, so
"genuinely zero", "row unpopulated" and "ClickHouse was down" are indistinguishable — funnelcake
returns HTTP 200 with `video_count: 0` on failure (`handlers.rs:6183-6190`). Resolved by suppressing
zero at the call site, matching the zero-guard the repository already applies to followers.

**Complexity:** Medium

### Approach B: Apply the issue literally, document the dead getters

**Description:** Swap lines 272-273 to `restFollowerCount` / `restVideoCount` exactly as #7486
asks, and add doc comments marking the conflating getters as source-ambiguous.

**Layers affected:** UI only.

**Pros:** Smallest possible diff; literally faithful to the issue; zero behaviour risk.

**Cons:** **Knowingly ships an always-null expression.** The stats line still never renders. It
closes the ticket without fixing anything, and leaves the next reader with the same false belief
that the preview shows counts.

**Risks:** Entrenches the misdiagnosis in the codebase.

**Complexity:** Low

### Approach C: Delete the stats line and its ARB keys

**Description:** Remove `_StatsLine` from the preview and drop
`messageRequestFollowersCount` / `messageRequestVideosCount` from all 22 locales.

**Layers affected:** UI + l10n.

**Pros:** Honest — deletes code that has never executed. Removes two effectively-orphaned keys
from 22 locales. Smallest surviving surface.

**Cons:** Discards clear product intent. Someone deliberately designed a stats line into this
screen; the counts *are* available one store away. Deleting is cheaper than fixing but throws
away the trust signal a request preview is supposed to give ("who is this contacting me?").

**Risks:** Would need re-adding, and re-translating, if product still wants it.

**Complexity:** Low

### Approach D: Repoint `vineFollowers` / `vineLoops` at `rawTags`

**Description:** Fix the getters to read the tag array where the importer actually writes them,
keeping the REST-first fallback intact.

**Layers affected:** Model (`packages/models`) + its tests.

**Pros:** Fixes a genuine bug at its root; revives real Vine-archive data that provably exists
on the relay.

**Cons — decisive:**
- **It would still return `null` on this screen.** `rawTags` is not persisted (F19: `user_profiles`
  has no tags column, `fromDrift` never sets it), and the preview reads through the Drift cache.
  Making it work would require a schema migration to persist tags — far outside this issue.
- Even if it worked, a Vine-archive number rendered as plain "Followers" is precisely the
  conflation #7486 objects to.
- Nothing currently wants to display Vine metrics, so it revives an unused capability.

**Risks:** High effort, no user-visible benefit, and it re-creates the labelling problem.

**Complexity:** High

## Recommendation

**Approach A**, with the dead `vine*` getters left in place and documented (a tracking issue
covers their removal).

Approach A is the only option that makes the screen do what it was designed to do. B closes the
ticket while shipping a known no-op — expressly the kind of deferred, cosmetic change
`.claude/rules/agent_workflow.md` §4 forbids. C is defensible and cheap, but discards intent when
the correct data is one already-populated Drift table away. D is disqualified on evidence: the
transport it depends on (`rawTags`) does not survive the cache this screen reads from.

Documenting rather than deleting the `vine*` getters keeps the models package and its tests out
of this PR's blast radius, which matters because those same fixtures are shared with the
`search_user_tile`, `conversation_view` and `user_profile_tile` suites.

## Decisions taken (user, 2026-08-31)

| Question | Decision |
|---|---|
| Count source | `userProfileStatsReactiveProvider` (`profile_statistics`) |
| Loading state | Mirror the profile-header skeleton (Skeletonizer + 7 s → `—`) |
| Zero videos | **Suppress** zero, matching the followers zero-guard (revised on backend evidence) |
| `vine*` getters | Leave in place, document as dead + tracking issue; report the upstream `ProfileContent` type that caused it |
| Stats shown | Followers + Videos **+ Loops** |
| Loops floor | Reuse `profileLoopsVisibilityFloor` (10 000); sender is never the viewer |
| Loops copy | Reuse `videoFeedLoopCountLine` (22/22 locales) via an argument-order adapter |
| Sibling surfaces | Out of scope → issue with a concrete proposal + follow-up PR |
| PR #8384 | Prepare and hold; push once it merges |

## Open Questions for /plan

- [ ] Where does the stats watch live — `RequestPreviewPage` (passing `ProfileStats?` down) or
      `RequestPreviewView`? The page/view split argues for the page; the view already watches
      `userProfileReactiveProvider` itself.
- [ ] Does `_StatsLine` become stateful (timeout timer) or does a small wrapper own the timer so
      `_StatsLine` stays a pure `StatelessWidget`?
- [ ] Is `Skeletonizer` already a dependency reachable from this screen, and what does the
      existing golden/widget-test setup need to keep it deterministic?
- [ ] Exact null/zero matrix: which parts render for each combination of
      `stats == null`, `followers == null`, `videoCount == 0`, `totalViews < 10 000`.
- [ ] Test strategy for a feature that has never rendered — the regression test must fail on
      today's `main`.

## Prerequisites

- [ ] PR #8384 merged (same file; user chose to hold).
- [ ] Comment posted on #7486 with the reframed diagnosis, tagging @NotThatKindOfDrLiz.

## Next Step

`/plan 7486`
