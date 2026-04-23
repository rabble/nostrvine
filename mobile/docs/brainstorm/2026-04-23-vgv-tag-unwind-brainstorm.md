# Brainstorm: VGV `skip_very_good_optimization` Tag Unwind Strategy

Date: 2026-04-23
Issue: [#3137](https://github.com/divinevideo/divine-mobile/issues/3137)
Parent (closed): #2899 — VGV CLI runner migration
Related merged: #3081 (runner switch), #3082 (reference pattern), #3083 (initial tags)

## Problem Statement

The VGV optimized CI runner merges eligible test files into one Dart isolate.
60 files currently opt out via `@Tags(['skip_very_good_optimization'])` because
they leak process-wide state (factory singletons without reset helpers,
`setMockMethodCallHandler` at file scope, shared mocks/providers,
integration-grade bindings). Each tagged file pays a full Dart VM startup
cost, which forced `--concurrency=2` and caps the Tests job at ~5:40 wall-clock
on main.

#3137 tracks unwinding these tags incrementally. The mechanical work per file
is well-understood (pattern established in #3082). What is **not** decided is
the **strategy**: which files first, how to batch, what gate prevents drift,
what the concurrency ramp looks like, and what the definition-of-done is for
the legitimately-unfixable cases.

This brainstorm converges on a direction. It does not produce implementation
code.

## Constraints

- **CI critical path.** Tests is the longest job (5:40 last green main). Any
  win flows through this number.
- **`--exclude-tags integration`.** The 17 Bucket-A files are dual-tagged with
  `integration` and are already excluded from the Tests job. Unwinding them
  buys zero CI wall-clock — pure hygiene.
- **Silent drift.** #2571 added `profile_saved_grid_test.dart` to the tagged
  set while #3137 was open. No gate prevents a feature PR from regressing
  progress.
- **Reviewer bandwidth.** Repo norm is small, atomic, test-backed PRs
  (CLAUDE.md). 15-file batch PRs are a non-starter.
- **Reference pattern is proven.** #3082 established
  `@visibleForTesting resetInstance()` + `setUp`/`tearDown` for 3 services and
  fixed 7 test files. The fix is additive and has landed; the tag was never
  removed on those 7 files because #3081 hadn't switched the runner yet.
- **Ubuntu-latest free tier.** 4 vCPU on `ubuntu-latest`; current
  `--concurrency=2` leaves headroom. No paid-runner usage configured.

## Prior Art

- **PR #3082** — singleton resets + test isolation (`feed_performance_tracker`,
  `screen_analytics_service`, `notification_service_enhanced` plus 7 test
  files). Template for every remaining bucket-B fix.
- **PR #3081** — CI runner switch to `very_good test --optimization
  --concurrency=2 --exclude-tags integration --test-randomize-ordering-seed
  random`. Created the debt #3137 pays down.
- **PR #3083** — Tagged 28 files prospectively before the runner switch.
- **Issue #3137 comment (2026-04-22)** — commenter flagged 4 unresolved
  strategy questions: concurrency ceiling, stop-the-bleed gate, Bucket A
  disposition, permanent-tag budget. Proposed BackgroundActivityManager as
  PR 1.

## Current State (ground truth, 2026-04-23)

- **60 tagged files** total (verified via
  `grep -rln "skip_very_good_optimization" mobile/test | wc -l`)
  - `@Tags(['skip_very_good_optimization', 'integration'])`: **17** (Bucket A)
  - `@Tags(['skip_very_good_optimization'])` single: **43** (Buckets B/C/D/E)
- **Drift from issue text:**
  - `video_event_thumbnail_integration_test.dart` deleted by #3226 (Bucket A: 17 ≠ 18)
  - `profile_saved_grid_test.dart` added by #2571 (Bucket D: 20 ≠ 19)
  - `sounds_screen_test.dart` (Bucket E) is not `@Tags`-tagged; it has 3
    `skip: true` markers, not 1
  - `seed_media_preload_service_test.dart` (Bucket E) has 2 `skip: true`
    markers, not 1
- **Already-fixed-still-tagged (7 files).** PR #3082 shipped the pattern but
  did not strip the tags:
  - `feed_performance_tracker_stale_session_test.dart`
  - `screen_analytics_service_test.dart`
  - `notification_service_enhanced_test.dart`
  - `draft_storage_service_test.dart`
  - `profile_drafts_button_test.dart`
  - `video_thumbnail_service_test.dart`
  - `share_video_menu_comprehensive_test.dart`
- **No unwind PRs have merged.** Verified via
  `gh pr list --search "skip_very_good_optimization"` — the only history is
  tag-adding PRs.

## Approaches Explored

### Approach A — Depth-first pattern PRs, one file at a time

**Description.** PR 1 = BackgroundActivityManager `resetInstance()` + untag
`background_activity_manager_test.dart`. Continue one file per PR through
Buckets B → C → D, applying the #3082 template. Bucket A handled later as
strike-only. No upfront gate. (This is the commenter's default.)

**Layers affected:** test infrastructure + one service per PR.

**Pros:**
- Every PR is atomic, revertable, easy to review.
- Starts on a real code-change fix — validates the template against a
  currently-leaking file (not just one that was already fixed).
- Matches repo norm exactly.

**Cons:**
- Slow: 43 PRs at ~1/day is 8+ weeks of drag.
- Ignores the Track 1 freebie — 7 files could untag with textual-only edits.
- No drift gate → another feature PR can regress the tag count mid-effort
  (precedent: #2571).
- Every PR requires someone to run the 3× seed verification manually.

**Risks:** reviewer fatigue, silent drift, low momentum.
**Complexity:** Low per PR, High cumulative coordination.

---

### Approach B — Verify-first bundle, then gate, then pattern PRs

**Description.** Three phases:

1. **PR 1** — Delete `@Tags([...])` line from the 7 already-fixed files from
   #3082. No source edits. Verification = `very_good test --optimization
   --concurrency=2 --exclude-tags integration --test-randomize-ordering-seed
   random` locally, 3× with different seeds, output captured in the PR body.
2. **PR 2** — Stop-the-bleed gate: CI step that greps the tag count and fails
   PRs that increase it above a committed baseline. Exemption path via inline
   `// Permanent: <reason>` comment adjacent to the tag.
3. **PR 3+** — Pattern PRs for remaining Bucket B files (start with
   BackgroundActivityManager per the commenter's suggestion), then C, then D.
   Bucket A handled as a single strike-only PR (17 tag-line deletions).

**Layers affected:** test infrastructure + CI config.

**Pros:**
- **Fastest first CI win.** 7 files off the tagged list in PR 1, no code
  change. If they pass, `--concurrency` can rise in the very next PR.
- **Gate lands early.** Drift risk closes in PR 2, before the long tail of
  pattern PRs begins. Every subsequent PR contributes to a visibly-declining
  baseline.
- **Information value on partial failure.** If 5 of 7 files pass and 2 fail,
  the 2 failures tell us the PR #3082 pattern was *insufficient* for those
  leaks — data for Approach A's followup.
- **Bucket A becomes one cheap PR** (17 tag-line deletions, purely textual)
  instead of either being ignored or expanded into a separate effort.
- **Pattern validation still happens** at PR 3 on an actually-leaking file.

**Cons:**
- PR 1 spans 7 files. Bigger surface than Approach A's first PR, though the
  diff is only 7 deleted lines.
- Needs a verification story the reviewer will accept (raw paste vs scripted
  runner).
- If a file verifies locally but flakes in CI, the retag is a small follow-up
  PR — not catastrophic but adds a cycle.

**Risks:** PR 1 verification under-covered → later flake; reviewer pushback on
7-file scope.
**Complexity:** Low PR 1, Low PR 2, Medium overall.

---

### Approach C — Gate-first, then parallel tracks

**Description.** PR 1 = stop-the-bleed gate only (zero tag removals). Then
three parallel tracks open for independent contributors: verify-only
(Track 1), pattern PRs (Track 2), Bucket A strike (Track 3).

**Layers affected:** CI config for PR 1, everything else after.

**Pros:**
- Drift risk closes on day 1.
- Maximum throughput *if* multiple contributors pick up files.
- Definition of done is testable: gate passes when tag count hits the
  permanent-tag budget.

**Cons:**
- PR 1 delivers zero visible CI speedup. Weaker first story than Approach B.
- Parallel tracks create merge conflicts on the baseline file (the gate's
  counter) if they race.
- Reality check: single-contributor work makes the parallelism claim hollow —
  this is Approach A with an upfront gate.

**Risks:** gate spec becomes the bikeshed (what's a "permanent" tag?);
parallelism never materializes.
**Complexity:** Low PR 1, Medium gate spec, Low cumulative.

---

### Approach D — Big bucket PRs (ruled out)

**Description.** One PR per bucket. 15 files untagged in one shot.

**Why ruled out.** Violates repo norm on PR size. A single flake on file 14
stalls 15 files. Post-merge regression bisection is painful. Conflicts with
any in-flight feature work touching those services become probable. CLAUDE.md
explicitly says "keep migrations incremental, test-backed, and small enough
to review."

## Recommendation

**Approach B** — Verify-first bundle (7 files) → stop-the-bleed gate →
pattern PRs for the rest.

**Why it fits divine-mobile better than alternatives:**

1. **Highest-yield PR 1.** 7 files untag with pure textual diff. That is the
   fastest possible demonstration that the unwind path actually works in
   production CI, not just in #3082's local test environment.
2. **Gate arrives early.** PR 2 closes the drift window so the remaining
   ~36-file tail doesn't regress mid-effort. Approach C's main benefit,
   delivered on day 2 instead of day 1, after one measurable CI win.
3. **Pattern validation preserved.** PR 3 is still
   `BackgroundActivityManager.resetInstance()` against a currently-leaking
   file — the commenter's original PR-1 candidate just slides to PR-3.
4. **Bucket A disposition becomes a single small PR**, not an argument.
5. **Respects repo norms.** Every PR is small, revertable, test-backed. No
   approach here deviates from "small incremental PRs."

## Open Questions for /plan

- [ ] **PR 1 scope** — all 7 files in one bundle, or 2–3 mini-bundles (service
  singletons / widget-mock / platform channel) to narrow review focus?
- [ ] **Verification artifact** — ship `scripts/verify_untag.sh` in PR 1 so
  every future unwind PR runs the same command, or capture a paste of the 3×
  seed output in the PR body only?
- [ ] **Gate implementation** — bash-grep step in `mobile_ci.yaml` with a
  committed `tasks/vgv_tag_baseline.txt` counter, or a Dart tool in
  `mobile/tool/`?
- [ ] **Gate semantics** — fail-above-baseline (static count; baseline updated
  by each unwind PR) or fail-above-N (N declines on a schedule, forcing
  progress)?
- [ ] **Concurrency ramp** — bump to `=3` after PR 1 lands, or hold at `=2`
  until count ≤ X (e.g. ≤10) and jump to `=4`?
- [ ] **Permanent-tag convention** — exempt via inline `// Permanent:
  <reason>` comment adjacent to `@Tags(...)`, or a separate allowlist file?
- [ ] **Bucket A disposition** — strike `skip_very_good_optimization` only
  (keep `integration`) in one PR (recommended), or file a separate hygiene
  issue for full relocation to `mobile/integration_test/`?
- [ ] **Bucket E reality** — re-enable the 2 listed `skip: true` tests, or do
  an audit pass (investigation found 5 `skip: true` markers across 2 files)?

## Prerequisites (blocking PR 1)

- [ ] `@omartinma` answers the 4 original strategy questions from #3137
  comment (2026-04-22): concurrency ceiling, gate yes/no, Bucket A
  disposition, permanent-tag budget.
- [ ] Local VGV run against the 7 candidate files passes 3× under different
  random seeds. Any file that fails is demoted from PR 1 and queued for
  Approach A's pattern-PR flow (likely = re-open as Bucket B with a note on
  what leak survived the #3082 fix).

## Next Step

`/plan 3137` — scope narrowed to "PR 1 = verify-only untag of 7 files from
PR #3082," list below. Follow-up plans draft after PR 1 merges.

**PR 1 file list:**
- `mobile/test/services/feed_performance_tracker_stale_session_test.dart`
- `mobile/test/services/screen_analytics_service_test.dart`
- `mobile/test/services/notification_service_enhanced_test.dart`
- `mobile/test/services/draft_storage_service_test.dart`
- `mobile/test/widgets/profile_drafts_button_test.dart`
- `mobile/test/services/video_thumbnail_service_test.dart`
- `mobile/test/widgets/share_video_menu_comprehensive_test.dart`

## Lesson Seed (for `tasks/lessons.md` after PR 1 lands)

> **Opt-out tags silently accumulate.** When a migration introduces a
> file-level opt-out (e.g. `skip_very_good_optimization`), add a CI gate that
> fails PRs increasing the count above a committed baseline in the same
> migration PR — not in a follow-up issue. Otherwise every unrelated feature
> PR can grow the debt unnoticed, and the follow-up issue's checklist drifts
> out of sync with the tree.

---

## Addendum: 2026-04-23 PR 1 verification findings

Before opening PR 1, the 7-file untag was verified locally with
`very_good test --optimization --concurrency=2 --exclude-tags integration
--test-randomize-ordering-seed 42`. **The "already fixed" hypothesis was
wrong.** None of the 7 files are safe to untag against main as it stands.

### Runs performed

| Run | Untagged set | Pass | Fail | Skip | Verdict |
|---|---|---:|---:|---:|---|
| Baseline | (none — pure main) | clean | 0 | 368 | ✅ main is green on seed 42 |
| v1 | all 7 | 7524 | 27 | 368 | ❌ 4 files failed directly |
| v2 | 3 (demoted v1's 4 direct failures) | 7500 | 54 | 368 | ❌ `share_video_menu_comprehensive` cascaded into `video_editor_timeline` |
| v3 | 2 (`notification_service_enhanced`, `draft_storage_service`) | ~7490 | 59 | 368 | ❌ `video_editor_timeline` + `video_editor_timeline_clip_strip` cascaded |

### Direct failures (v1) — 4 of 7 files

These tests break immediately when run in the shared isolate:

- `mobile/test/services/feed_performance_tracker_stale_session_test.dart`
- `mobile/test/services/screen_analytics_service_test.dart`
- `mobile/test/services/video_thumbnail_service_test.dart`
- `mobile/test/widgets/profile_drafts_button_test.dart`

**Pattern in services/**: tests use `testInstance()` inside `setUp` but only
reset in `tearDown`. The first test in the file inherits the singleton from
whatever ran before it in the merged isolate. `notification_service_enhanced_test`
(which does NOT directly fail) uses `resetInstance()` at the top of `setUp`
*before* creating the service — that's the subtle difference.

**Fix template** (to apply in the follow-up pattern PR):

```dart
setUp(() {
  FeedPerformanceTracker.resetInstance();   // ← add this
  service = FeedPerformanceTracker.testInstance();
});

tearDown(FeedPerformanceTracker.resetInstance);
```

`profile_drafts_button_test` fails on a navigation assertion; root cause TBD
(likely a provider scope leak from another widget test adjacent in the merged
suite).

### Cascade failures (v2, v3) — unrelated tests break

Even after demoting the direct failures, `share_video_menu_comprehensive`
(which passed in v1 by lucky ordering) cascaded into
`video_editor/timeline_editor/video_editor_timeline_test.dart` in v2. And in
v3 — with only `notification_service_enhanced` and `draft_storage_service`
untagged — the video-editor tests STILL cascade-failed, even though those two
files appear minimal and `notification_service_enhanced` follows the correct
reset pattern.

The v3 cascade is the most worrying finding: untagging two files that
individually look safe still breaks unrelated tests. The simplest theory is
test-order sensitivity — the composition change shifts when the video-editor
tests run relative to some other leaky file already in the merged suite.

### Implications for the plan

1. **Approach B's PR 1 is invalid as originally scoped.** The "7 files ship
   with no code change" premise assumed the #3082 reset pattern was complete.
   It is not. At least 4 files have a subtle setUp/reset ordering bug, and
   other files have latent leaks that manifest only under specific test
   ordering.
2. **Per-file untag verification is insufficient.** A file passing on seed X
   says nothing about seed Y. The verification must run N× across random
   seeds AND be evaluated against the entire merged suite's pass rate
   (including tests the untagged files have no apparent relationship to).
3. **Cascade target needs investigation.** The video-editor timeline tests
   are the common cascade victim. Either they have a pre-existing latent
   leak that only surfaces under certain orderings, or there is an unrelated
   leak that was previously hidden because the tag set kept certain files
   out of the shared isolate. This is its own investigation.
4. **Approach A (pattern PRs, one file with code changes) becomes PR 1 by
   default.** Starting point: apply the setUp-reset pattern fix to
   `feed_performance_tracker_stale_session_test` and verify the suite is
   still green on 3× random seeds.

### Updated PR 1 proposal

**Scope** — single file, code change:
- Add `FeedPerformanceTracker.resetInstance()` to `setUp` in
  `feed_performance_tracker_stale_session_test.dart` before the `testInstance()`
  call (copy the pattern from `notification_service_enhanced_test`).
- Remove the `@Tags(['skip_very_good_optimization'])` line.
- Verify 3× random seeds locally before PR.

**Why this changes the calculus.** This PR genuinely fixes a bug (missing
reset in setUp), not just a verification question. It also validates the
pattern on a file whose direct failure mode we now understand, rather than
relying on #3082's "fixed enough" claim.

### Deferred questions for `/plan`

Still outstanding from the original brainstorm, plus new ones:

- [ ] Is `video_editor_timeline_test`'s cascade susceptibility a real issue to
  investigate before any further untag work, or can we work around it by
  tagging it temporarily?
- [ ] Does the stop-the-bleed gate need to ship *before* any untag PR, given
  how fragile the composition is? (Previously this was PR 2; moving to PR 1
  would make every subsequent untag safer.)
- [ ] Should the project add a `scripts/verify_untag.sh` that automates the
  3× seed verification and captures the result for PR bodies? (Previously
  deferred; given the cascade risk, this is now close to a prerequisite.)
