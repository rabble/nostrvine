# Brainstorm: Eliminating the residual "No videos" flash on profile cold-load

Date: 2026-05-09

Context: PR #4182 (`fix(profile): wire isInitialLoad through to videos tab loading state`) closes #4164. Reviewer hm21 reports the empty state still flashes for 1–2 seconds when opening profiles of newly-followed users before videos populate.

## Problem statement

The profile videos tab briefly renders the "No videos" empty state during cold load before videos arrive. The PR fixed the wiring contract — the widget already routes to `ProfileTabLoadingState` vs `ProfileTabEmptyState` from its `isLoading` parameter, and the two screen call sites now thread `value.isInitialLoad` into it correctly. The residual flash is upstream: `profileFeedProvider` flips `isInitialLoad: false` while the fetch is not yet genuinely settled.

## Constraints

- Riverpod legacy provider (`profileFeedProvider`); not migrating to BLoC in this fix.
- `VideoFeedState` is shared with home/discovery flows — schema changes need cross-consumer review.
- `architecture.md` forbids source-selection / fallback logic in the UI, so widget-level papering is undesirable.
- No `Future.delayed()` for UI timing per `code_style.md`.
- Dark-mode-only; existing widget classes (`ProfileTabLoadingState`, `ProfileTabEmptyState`) already correct.

## Prior art

- `mobile/lib/providers/profile_feed_provider.dart` — `ProfileFeed.build()` (lines 79–160), `_refreshFromNostrSource` (896–922), `_refreshFromRestApi` (295–394), `_mergeSourceVideos` (945–989), `_cacheSnapshot` (1140–1153).
- `mobile/lib/state/video_feed_state.dart` — Freezed state with the `isInitialLoad` field and its docstring.
- `mobile/lib/services/video_event_service.dart` — `subscribeToUserVideos` (2795), EOSE tracking (1861–2015).
- `mobile/lib/widgets/profile/profile_videos_grid.dart` lines 250–266 — correct loading-vs-empty branch on `isLoading`.
- PR #4182 widget regression tests in `profile_videos_grid_test.dart` already pin the widget contract.

## Failure trace (cold load, follow whose videos haven't been seen)

1. `build()` returns `videos: [], isInitialLoad: true` — UI shows loading.
2. `_refreshFromNostrSource` awaits `subscribeToUserVideos`. That call returns when the **subscription is registered**, not when EVENT messages arrive. `_relayVideosSnapshot()` is still empty.
3. `_mergeSourceVideos(empty, isInitialLoad: false)` emits `videos: [], isInitialLoad: false` — **UI shows "No videos"**.
4. ~500–1500ms later, relay events arrive → listener fires → `videos: [...]` — UI populates.

Secondary failure mode: `_refreshFromRestApi` empty-branch (line 374) sets `isInitialLoad: false` and uses `mergeWithCurrent: false`, wiping any Nostr-arrived videos with empty + cleared loading. Same flash, different originator.

Cache-warm path is not affected — `retainedState.videos.isNotEmpty` guard ensures `videos` is non-empty when `isInitialLoad: false` is emitted.

## Approaches Explored

### Approach A — Don't flip `isInitialLoad: false` from intermediate empty emissions

**Description:** Treat `_refreshFromNostrSource` and `_refreshFromRestApi` as contributors, not arbiters. Track per-build "expected source" pending flags inside the notifier. Each source clears its own flag when complete (success / empty / error / timeout). Compute `isInitialLoad = anyPendingSource && videos.isEmpty`. Add a hard timeout cap so neither-source-completes can't strand the spinner.

**Layers affected:** Provider only.

**Pros:**
- Targets the actual race, not the symptom.
- Self-contained in the legacy Riverpod provider.
- No `VideoFeedState` schema change; no codegen.
- Easy to pin with provider-level tests (no widget-side changes).

**Cons:**
- Coordination across two unawaited paths is fiddly; needs a small dedicated holder + `ref.onDispose` to guarantee no leaks.
- Hard-timeout magic number must be picked (likely 10s, aligned with `_restApiTimeout`).

**Risks / Unknowns:**
- Stuck-loading regression if neither source finishes — must verify timeout fires on disconnected relay AND missing funnelcake.
- Need to handle `_addNewVideoToState` and `onNostrVideosChanged` as flag-clearing events too (videos arrived → not pending).

**Complexity:** Medium

### Approach B — Per-source loading flags in `VideoFeedState`

**Description:** Add `isLoadingFromNostr` / `isLoadingFromRest` to the Freezed state. Each refresh path manages its own flag. The widget consumes a derived `isInitialLoad` getter combining them.

**Layers affected:** State model (Freezed), provider, possibly tests in other consumers.

**Pros:**
- Cleanest semantics; future bugs in this area are easier to reason about.
- Surfaces the actual shape of the model.

**Cons:**
- Largest diff. Touches state model, codegen (`build_runner`), and any test exercising `VideoFeedState`.
- `VideoFeedState` is shared with home / discovery — needs verification that no other consumer breaks.
- Slightly leaks "two sources" into a model used in non-profile contexts.

**Risks / Unknowns:**
- Cross-consumer impact on home and discovery feeds.

**Complexity:** Medium-High

### Approach C — EOSE-aware Nostr completion signal

**Description:** Make `subscribeToUserVideos` (or a parallel API) return a Future that resolves on **EOSE-or-timeout**. The provider awaits this before clearing the loading flag for the Nostr source. Aligns with the Nostr protocol's actual "initial backfill done" signal.

**Layers affected:** `VideoEventService` (Client-ish), profile provider.

**Pros:**
- Most semantically correct — loading state mirrors the protocol's completion signal.
- Generalizable: other subscriptions could opt in.

**Cons:**
- Larger blast radius. `VideoEventService` is shared infrastructure.
- EOSE handling already has subtle timeout / multi-relay edge cases in the service; new API surface needs careful testing.

**Risks / Unknowns:**
- Potential regressions in subscriptions that already track EOSE differently (e.g., `seedHomeFeedFromFollowedUsers`).

**Complexity:** High

### Approach D — Widget-level OR over existing state fields

**Description:** Change the screens' wiring from `isLoadingVideos: value.isInitialLoad` to `value.isInitialLoad || (value.isFetchingTotalCount && value.videos.isEmpty)`.

**Pros:**
- Smallest possible diff.

**Cons:**
- Doesn't fix the primary race: `isFetchingTotalCount` is set from a synchronous read of `funnelcakeAvailableProvider`. If funnelcake isn't ready at build time, the flag is `false` even though `_awaitFunnelcakeAvailability` may resolve and run REST.
- Pushes provider-level source composition into the UI (architecture rule violation).
- Same partial-fix shape that produced this thread.

**Complexity:** Low (not recommended)

## Recommendation

**Approach A.** Provider-internal "expected source" tracking with a hard timeout cap. Reasons:

1. Targets the actual race condition — `isInitialLoad: false` emitted before any source has settled with data — rather than papering over a symptom.
2. Keeps the Riverpod-legacy code self-contained; no `VideoFeedState` schema change, no codegen, no UI-layer source composition.
3. Small enough for a follow-up commit on this branch without growing scope.
4. Doesn't preclude Approach C as a future improvement; in fact, A makes C strictly easier (the per-source pending flag is exactly what an EOSE signal would clear).

Approach C is cleaner long-term but the `VideoEventService` blast radius doesn't justify the size for a single bug fix. File as follow-up.
Approach B is overkill for this bug.
Approach D papers over only some scenarios.

## Open Questions for /plan

- [ ] Where does the "expected source" tracker live — a small private holder in `ProfileFeed`, or a derived getter on `VideoFeedState`?
- [ ] Hard timeout value: 10s (aligned with `_restApiTimeout`) or 15s (slack for slow relays)?
- [ ] Should `_refreshFromRestApi`'s empty branch keep `mergeWithCurrent: false`? (Authority decision is separate from loading-flag fix; likely yes-keep.)
- [ ] Existing tests to update: `profile_feed_provider_test.dart`, `profile_feed_pagination_test.dart`, `profile_feed_session_cache_test.dart`. Need a new case: "Nostr settles empty, REST pending → still loading."
- [ ] How does the timeout interact with `ref.mounted` and `_isRefreshing`?

## Prerequisites

- None. Approach A doesn't touch generated code or other layers.

## Next step

`/plan` Approach A as a follow-up commit on `fix/4164-profile-videos-loading-state`. The plan should produce:

- A small change to `_refreshFromNostrSource` and `_refreshFromRestApi` so they don't unilaterally clear `isInitialLoad`.
- A per-build pending-source tracker initialised in `build()` and torn down via `ref.onDispose`.
- A hard timeout that flips both flags off after N seconds.
- Tests pinning the timeline: cold-load → Nostr empty + REST pending → still loading; eventual events → loading clears.
