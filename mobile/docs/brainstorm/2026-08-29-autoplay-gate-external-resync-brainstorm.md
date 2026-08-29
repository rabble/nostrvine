# Brainstorm: autoplay gate cannot detect live external gate changes

Date: 2026-08-29

Target issue: **#6899**. #7541 and #7542 duplicate it with mechanisms that do not exist — they
describe a `FeedAutoPlayCubit` and an `_autoPlayGateTimer` doing periodic polling, and
`git log --all -S` finds zero commits for either name. Do not design against their acceptance
criteria.

## Problem Statement

`InfiniteVideoFeedState._syncCurrentAutoPlayGate` decides whether to pause/resume the current
video by comparing `_canAutoPlayAtFor(oldWidget, i)` against `_canAutoPlayAt(i)`. In production
both calls invoke the *same* live-reading closure (`feed_videos.dart:422` passes the tear-off
`_canAutoPlayVideo`), so the only input that can differ is `source.videos[index]`. A gate that
flips because *external state* changed is therefore invisible, and playback desyncs from the
content-warning overlay in both directions.

Empirically reproduced on a live iOS Simulator against the production feed, in both directions: a
warning that lapses leaves the video paused with the blur gone, and one that newly applies leaves it
playing with audio behind the blur.

## Constraints

1. **A "fresher reference" fix is already dead.** PR #7425 tried it; commit `2ed54f3bb` reverted it:
   `communityContentLabelServiceProvider` is a `ChangeNotifierProvider`, so `ref.listen` and
   `ref.read` hand back the *same long-lived object*. **The fix must CAPTURE a value, not re-read
   a source.**
2. **The equality guard is load-bearing.** `feed_videos.dart:804-814` gives the user tap-to-pause,
   calling `controller.pause()` directly — the package never learns about it. So the sync must act
   only on a genuine gate TRANSITION. Anything that reconciles "gate says play but we're paused"
   unconditionally will resume a video the user deliberately paused.
3. `mobile/packages/infinite_video_feed` is on a **100% coverage gate**
   (`baseline/package_coverage_floors.txt:40`). New public API costs new package tests.
4. Repo rules: UI → BLoC → Repository → Client; package must stay Flutter-widget-generic and
   must not learn about content warnings, Riverpod, or feature flags.

## Prior Art

- `556152171` (PR #5039) introduced `canAutoPlay`, `resumeCurrentPlayback`, `_syncCurrentAutoPlayGate`.
- `d56c1645b` (PR #5720, "M1") added `pauseCurrentPlayback` + the app-layer `_pauseCurrentIfCommunityWarned`
  workaround, after two reviewers independently diagnosed this exact early-return.
- hm21's original review offered two remedies: **snapshot the gate into widget props**, or pause
  imperatively. The author took the imperative route; the snapshot has never been tried.
- PR #7425 / revert `2ed54f3bb` — see constraint 1.

## The defect has TWO independent halves

Worth separating, because a fix for one does not fix the other:

- **H-a (detection):** given a rebuild, the sync cannot tell the gate changed. (All five triggers.)
- **H-b (no rebuild at all):** TTL expiry (`_cacheTtl = 5 min`, evaluated at read time) fires no
  event of any kind — no notify, no timer. So for that trigger there may be no rebuild to detect
  *with*. Ironically, #7541's "remove the periodic polling timer" is backwards: no timer exists,
  and a scheduled callback is arguably the only thing that can catch a wall-clock expiry.

## Approaches Explored

### Approach A: Compare against a remembered gate value inside the package

**Description:** Replace `wasAllowed = _canAutoPlayAtFor(oldWidget, i)` with a `bool? _lastAppliedGate`
field the package maintains. `didUpdateWidget` evaluates the predicate once and compares it to the
value the package *last acted on*, updating the field on every index/video change so a swipe cannot
fire a spurious transition.

**Layers affected:** package only (`infinite_video_feed`). No app change, no public API change.

**Pros:**
- Directly satisfies constraint 1 — the remembered bool is a genuine captured snapshot, immune to
  the shared-`ChangeNotifier` problem that killed #7425.
- Preserves constraint 2 exactly: still transition-only, so user tap-to-pause is untouched.
- Zero public API growth → smallest exposure to the 100% coverage gate.
- Fixes **all five** gate-opening triggers at once (H-a), with no per-trigger wiring.
- Would let the app delete `_pauseCurrentIfCommunityWarned` and its `ref.listen`.

**Cons / risks:**
- Does not address H-b: a TTL expiry that triggers no rebuild still goes unnoticed until some
  unrelated rebuild occurs.
- Adds one piece of package state that must be invalidated correctly on index change, video-list
  change, and `isActive` transitions — the bug surface if it is got wrong is spurious pause/resume.

**Complexity:** Low–Medium

### Approach B: Snapshot the gate into a widget prop (hm21's original suggestion)

**Description:** Add e.g. `final bool canAutoPlayCurrent` (or an opaque `gateRevision`) that
`FeedVideos.build` computes and passes down, so `oldWidget` genuinely carries the previous value.

**Layers affected:** package public API + app.

**Pros:** Most literal reading of the reviewer's suggestion; the comparison becomes honest by
construction; the app keeps ownership of gate semantics.

**Cons / risks:**
- The caller cannot reliably compute "the gate for the package's *current* index" — the package owns
  `_currentIndex` after a swipe, so the prop and the index can disagain during a swipe frame.
- Grows public API on a 100%-coverage package, and creates a second source of truth alongside the
  existing predicate (which is still needed at `:850`, `:1431`, `:1528` for arbitrary indices).
  Predicate and snapshot disagreeing is a new failure mode.

**Complexity:** Medium

### Approach C: Unconditional reconciliation against real playback state

**Description:** Drop the old/new comparison; on every rebuild, compare the gate against
`controller.state.isPlaying` and correct the difference.

**Layers affected:** package only. Smallest diff of all.

**Pros:** No API change, no remembered state, immune to the #7425 revert reason, and covers every
trigger including several that produce no transition.

**Cons / risks:**
- **Violates constraint 2 and is therefore rejected.** After the user taps to pause
  (`feed_videos.dart:813`, which the package never sees), the next rebuild would observe
  "gate open, not playing" and resume — overriding an explicit user action. That is a worse
  regression than the bug being fixed.

**Complexity:** Low — but incorrect.

### Approach D: App-layer only — add the missing symmetric hatches

**Description:** Add `_resumeCurrentIfNoLongerWarned()` mirroring `_pauseCurrentIfCommunityWarned()`,
and a `ref.listen` on the kill-switch driving both.

**Layers affected:** app only.

**Pros:** No package change at all; zero exposure to the coverage gate; very small diff.

**Cons / risks:**
- **Incomplete by construction.** It cannot fix TTL expiry, LRU eviction, or a content-filter
  preference flip, because those emit no notification to listen to — and those are the most
  reachable triggers.
- Perpetuates exactly the imperative-workaround pattern #6899 exists to remove, and adds a third
  hatch to keep in sync with the package.

**Complexity:** Low

## Recommendation

**Approach A**, optionally paired with a decision on H-b.

A is the only option that satisfies both hard constraints simultaneously: it captures the value
(defeating the #7425 revert reason) while staying transition-only (protecting user tap-to-pause).
It also has the smallest public surface, which matters on a package gated at 100% coverage, and it
fixes every trigger uniformly instead of wiring one listener per cause. It additionally lets the
app *delete* the M1 workaround rather than grow a fourth one, which is what #6899 actually asks for.

C is rejected outright on constraint 2. B is A's idea with a worse ownership split. D cannot reach
the most reachable triggers.

## Open Questions for /plan

- [ ] **Scope: H-a only, or H-a + H-b?** Fixing detection without a rebuild trigger leaves TTL
      expiry latent until an unrelated rebuild. H-b's only real remedies are a scheduled callback
      at cache-write time, or dropping silent read-time expiry — both touch
      `CommunityContentLabelService`, not the feed.
- [ ] Should the app-layer `_pauseCurrentIfCommunityWarned` + its `ref.listen` be **deleted** in the
      same PR (and its regression test `feed_videos_community_pause_test.dart` retargeted), or left
      in place as belt-and-braces for one release?
- [ ] Exact invalidation points for the remembered value: `_onIndexChanged`, video-list splice,
      `_setPlaybackActive`, controller re-init.
- [ ] Test shape: the package tests must exercise a **stable predicate whose return value changes** —
      the shape with zero current coverage — not another closure swap.

## Prerequisites

- [ ] Issue disposition confirmed (#7541/#7542 closed as duplicates; work tracked on #6899, which is
      currently assigned to another engineer).

## Next Step

`/plan 6899` once the scope question above is answered.
