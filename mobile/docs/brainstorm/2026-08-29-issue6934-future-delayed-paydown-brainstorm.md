# Brainstorm: paying down the remaining production `Future.delayed` sites

Date: 2026-08-29
Seeded by: `tasks/findings_6934.md` (11 hypotheses, all load-bearing ones at 1.0)

Issue: #6934 (child of #4339, follow-up to closed #4517)

## Problem Statement

Eleven `Future.delayed` call sites remain in `mobile/lib`, frozen by a shrink-only
ratchet since 2026-06-16. The ratchet has held, but **no deliberate paydown has ever
landed** — the baseline's only three reductions were files deleted for unrelated
reasons. The open question is not *whether* to remove them but *what each one should
become*, because the repo's designated alternative (`AsyncUtils`) turns out to be a
rename rather than a remedy.

This is the **third** attempt at this scope. #3582 closed as COMPLETED in May 2026
without the work landing at all; #4517 then merged exactly one PR — #4553
(`0851e4424`), a single-file `Future.any` → `.timeout()` swap whose own body calls it
*"API hygiene, not behavior"* — and auto-closed on merge. Both prior attempts closed
green on inaccurate accounting, which is a reason to state the ground truth precisely
before starting rather than to inherit either issue's numbers.

## Constraints

- **Layered architecture** — `UI → BLoC/Cubit → Repository → Client`. Fetch strategy,
  fallback and retry policy belong below the UI.
- **`Future.delayed` production ratchet stays hard-gated.** The issue says so
  explicitly: *"not a request to weaken or remove the existing ratchet."*
- **That ratchet is file-scoped, not count-scoped.** `emit_current()` ends in
  `grep -lE` and the baseline stores bare paths with no counts, so a **partial**
  migration moves nothing — only fully clearing a file drops it from the baseline.
  Every commit below therefore clears the files it touches completely. (A baselined
  file can also gain unlimited new sites without failing CI; that hole is a follow-up,
  not this PR.)
- **Test-scoped sibling ratchet.** `future_delayed_tests.txt` (34 entries) does **not**
  list any of the six existing test files for these production files. Adding a single
  `Future.delayed` to them would grow that baseline and fail CI. New tests must drive
  time with `fake_async` (`^1.3.3`, already a dev-dependency, used in 49 files) or
  `tester.pump(duration)`.
- **Untested-services floor.** `connection_status_service` is entry 13 of
  `untested_services.txt`; adding its test shrinks that baseline and requires
  regenerating it.
- **No stacked PRs** (`agent_workflow.md` §3); `#4517` asked for per-file landing.
- **Preserve user-visible behaviour** — read as "don't regress UX", not "preserve
  latent races".

## Prior Art

- **`lib/blocs/close_guard.dart` (#7370)** — the repo's one precedent for consolidating a
  repeated lifecycle guard. Notably it was written *after* four hand-rolled `_emitIfOpen`
  copies had accumulated, not before. The house rule is hand-roll first, consolidate on
  demonstrated duplication.
- **54 files in `mobile/lib`** already use the `Timer? _foo` field + cancel-in-`dispose`
  pattern. There is **no** shared timer/disposal mixin, and `CancelableOperation` has
  **zero** usages despite `package:async` being a dependency.
- **`lib/utils/async_utils.dart`** — written expressly to replace `Future.delayed`, with
  exactly **two** adopters in `lib` five months on.
- **`lib/widgets/video_editor/timeline_editor/strips/video_editor_timeline_clip_strip.dart`**
  — the only file that already did this properly: it drives reorder timing off an
  `AnimationController` and documents *"instead of guessing with `[Future.delayed]`"*.
  That dartdoc is itself one of the two ratchet false positives.

## What the investigation established (see `tasks/findings_6934.md`)

Two findings reshape the solution space, and both are settled at full confidence:

1. **`AsyncUtils.retryWithBackoff` is a grep-launder.** Dart SDK `future.dart:425-447`
   defines `Future.delayed` as an unstored `Timer` completing a future. `AsyncUtils`
   does *literally that*, under a comment claiming it is different. Migrating onto it
   would turn the ratchet green while changing nothing — so it is not an available
   target.
1b. **The ratchet is the odd one out.** Seven sibling ratchets strip comments and string
   literals through `scripts/lib/dart_code_only.awk` before counting
   (`check_raw_colors`, `check_raw_textstyle`, `check_material_button`, `check_raw_dialog`,
   `check_implicit_font_color`, `check_unsafe_back_pop`, `check_profile_read_write_split`).
   The `Future.delayed` production ratchet is the only one of the eight that greps raw
   source — which is why two of its eleven entries are comment-only and the baseline can
   never reach zero. Fixing it is a consistency change, not a new idea.
2. **Four of the eleven sites are not debt at all.** Two are in `VideoProcessingService`,
   which has zero code references anywhere in the repo; one is an explicitly fake
   *"Simulate connection check"* wait; one is a 2 s wait for work that is already awaited
   seven layers down to `await channel.ready`. For these the remedy is deletion, not
   replacement.

## The eleven sites, by behavioural category

| # | category | sites | remedy shape |
|---|---|---|---|
| 1 | dead code | `video_processing_service.dart` ×2 | delete the service |
| 2 | fake work | `connection_status_service.dart` ×1 | delete the wait |
| 3 | redundant wait | `relay_diagnostic_screen.dart` ×1 | delete the line |
| 4 | animation timing | `more_sheet_content.dart`, `video_metadata_preview_screen.dart` | drive off the animation that already exists |
| 5 | owned wait | `discover_lists_screen.dart` ×2, `upload_initialization_helper.dart` ×1, and the two `clearAll` sites | owned `Timer`, or a lifecycle hook |

Categories 1-3 account for **4 of 11** sites and need no coordination primitive at all.
That is the single most important input to choosing an approach.

## Approaches Explored

### Approach A: Per-site remedy, grouped into category commits

**Description.** No new abstraction. Delete what is dead or redundant (categories 1-3),
drive the animation sites off the controller/route animation each already owns
(category 4), and use the established 54-file `Timer? _field` + cancel-in-`dispose`
pattern only where a wait is genuinely required (category 5). One PR, one commit per
category, each independently revertable.

**Layers affected:** UI (screens, widgets), Provider/Notifier, Service. No repository or
client changes.

**Pros:**
- Matches the dominant existing convention exactly; nothing new for a reviewer to learn.
- Deletes ~40% of the problem instead of migrating it.
- Each remedy is the *strongest* one its context supports, so the ratchet going green
  actually means something.
- No new public API surface, which is what the global review rule asks for.

**Cons:**
- Leaves `AsyncUtils` in place as a misleading signpost for the next person.
- Five different shapes across nine files; a reviewer must evaluate each on its merits
  rather than checking one pattern.

**Risks / Unknowns:**
- The two `clearAll` sites need a lifecycle edge that is not yet empirically pinned
  (see Open Questions).

**Complexity:** Medium

### Approach B: Introduce a shared cancellable-delay abstraction

**Description.** Add a small owned-delay primitive — a `CancelableDelay` value type, or a
`State` mixin that owns and cancels its timers — and route every remaining site through
it, giving #4339's remaining async work a sanctioned target that is not `AsyncUtils`.

**Layers affected:** a new shared utility plus every call site.

**Pros:**
- One shape to review and to teach.
- Deliberately sets the precedent instead of leaving the next person to rediscover that
  `AsyncUtils` is hollow.

**Cons:**
- **Contradicts the repo's own consolidation precedent.** `close_guard.dart` was created
  after four duplicates existed; here we would be adding roughly three owned timers to a
  population of 54 that already do this by hand. That is not new duplication.
- A single primitive cannot serve categories 1-4 at all — deletion and animation-driven
  coordination are not delays — so it would apply to about three sites while implying it
  is the general answer.
- New API surface for a problem the language already solves with a field and a `cancel()`.

**Risks / Unknowns:**
- High risk of becoming the *second* under-adopted async helper in `lib/utils`.

**Complexity:** Medium-High

### Approach C: Repair `AsyncUtils`, then migrate onto it

**Description.** Treat the hollow helper as the root cause. Make `retryWithBackoff` and
`waitForCondition` own and cancel their timers, expose real cancellation, and migrate the
retry/backoff sites onto the repaired helper.

**Layers affected:** `lib/utils/async_utils.dart` plus the backoff sites.

**Pros:**
- Fixes the misleading signpost rather than routing around it — arguably the truest root
  cause, and the finding that motivated the "genuinely cancellable" bar.
- `retryWithBackoff` already carries real value (`retryWhen`, `maxDelay` clamping,
  structured logging) that would survive.

**Cons:**
- Changes a shared utility with two existing adopters, one of them
  `pending_action_service.dart` — which is *also* the service implicated in the 30 s
  spurious-sync finding. Coupling those two changes in one PR makes the blast radius
  much harder to reason about.
- Still does not address categories 1-4, i.e. 8 of the 11 sites.
- Scope creep against an issue that asks for paydown of call sites.

**Risks / Unknowns:**
- Cancellation semantics for an in-flight retry (does cancelling mid-backoff throw,
  or resolve?) is a design question of its own.

**Complexity:** High

### Approach D: Make the detector honest and stop there

**Description.** Fix the ratchet to count code only (dropping the two comment-only false
positives), declare the count truthful, and accept the remaining sites as tolerable.

**Layers affected:** tooling only.

**Pros:**
- Very small, zero product risk.
- The detector fix is genuinely needed regardless.

**Cons:**
- **Directly contradicts the issue**, which states this is a paydown tracker and not a
  request to weaken the ratchet.
- Would leave a proven data-loss race, a 30 s spurious-sync loop, a dead service and a
  gratuitous 2 s button delay in place.

**Complexity:** Low

**Rejected** — recorded so the option is visibly considered rather than overlooked. The
detector fix is folded into Approach A as one commit, not offered as a substitute for
the work.

## Recommendation

**Approach A**, with the detector fix from D folded in as its own commit.

The deciding argument is the category table: only about three of eleven sites actually
need a delay primitive, so any approach organised *around* a delay primitive (B, C)
optimises for the minority of the problem while adding API surface the codebase has
already shown it does not adopt — `AsyncUtils` has two users, `CancelableOperation` has
zero, and the hand-rolled `Timer?` field has 54. Approach A also lets each remedy be the
strongest one its site supports, which is what makes a green ratchet mean something after
this lands.

`AsyncUtils` is deliberately left alone. Its hollowness is now documented in the findings
file and worth its own issue, but repairing a shared utility whose second adopter is the
very service this PR is already changing would make the blast radius much harder to
review.

## Open Questions for /plan

- [ ] Does GoRouter's `go()` (a stack *replace*, not a push) deliver a usable `RouteAware`
      edge? The chosen editor-teardown hook depends on it. Must be pinned by a widget test
      before the shape is committed — it could not be observed on the signed-out patrol
      device.
- [ ] `ModalRoute.of(context)` is unavailable in `initState`, so the preview screen's
      route-animation listener needs a `didChangeDependencies` hook. Confirm the listener is
      attached exactly once across rebuilds.
- [ ] Deleting `VideoProcessingService` removes a service that *has* a test, so the
      untested-services floor is unaffected — but `COVERAGE_GAPS.md` and
      `TEST_QUALITY_AUDIT.md` both name the file. Update or leave those audit docs?
- [ ] Where exactly to tighten the `_isSyncing` guard in `PendingActionService` so the
      TOCTOU window closes without changing the offline-sync contract.
- [ ] Exact commit split within the PR: five behavioural categories plus detector fix plus
      baseline regeneration — does the baseline regeneration ride with each commit or land
      once at the end?

## Prerequisites

- [ ] None blocking. No design mockups, no protocol decisions, no new packages.
- [ ] Baselines to regenerate on completion: `future_delayed_production.txt` (after the
      detector fix and the migrations) and `untested_services.txt` (after the
      `connection_status_service` test).

## Next Step

`/plan 6934`
