# Brainstorm: splitting `main.dart` and `AppShell` (#3337)

Date: 2026-08-23
Findings source of truth: `tasks/findings_3337.md` (13 hypotheses, all load-bearing ones at 1.0)

## Problem Statement

`mobile/lib/main.dart` is 3,451 lines with 154 imports and a single 889-line `build()`. It is the
**#1 most-churned Dart file** in `mobile/lib` (170 commits / 13 authors / net +2,217 lines in 180
days). The concerns tangled inside `build()` are not merely untidy — they are **provably** the site
of shipping navigation bugs, because logic that stays a closure inside `build()` cannot be tested
and therefore drifts from its own duplicates.

This is not a hypothetical cost. Three defects were confirmed with executed tests during the
investigation, one of them S2 and shipping for 162 days.

## Constraints

- **No stacked PRs** (`AGENTS.md`). Interdependent work must land as ONE PR; only genuinely
  independent work may be split. This is the single biggest shaping constraint here.
- Layered flow `UI -> BLoC/Cubit -> Repository -> Client`; new state is BLoC-first, Riverpod legacy.
- `main.dart` is the app's riskiest code path: startup ordering, DB corruption gate, crash
  reporting, Firebase, zone guards. A regression here is a launch-blocking regression.
- The file-size ceiling is **advisory by explicit decision** (Liz, #4339, 2026-08-09) — a
  fail-closed size ratchet would contradict a stated policy call.
- Two open PRs currently touch `main.dart` (#8075, #5970); #8075 rewrites the startup redirect.
- `#3337` is a Wave-2 child of epic #4339, co-sequenced behind #3339 (already closed).

## Prior Art (both merged, both from this file)

- **#7969** `refactor(startup): own app-wide side-effect activation in one place` — moved 16
  activation-only `ref.watch` calls into `lib/startup/app_side_effects.dart` (136 lines, 2 hosts)
  **plus a source guard** (`test/startup/app_side_effects_test.dart:292-294`) that fails if
  `main.dart` / `app_shell.dart` / `routes/shell.dart` re-adds any of them. This already satisfied
  the issue's AC #4.
- **#7444** `refactor(router): extract route locations into a RoutePaths leaf` — plus the
  shrink-only `check_layer_direction.sh` ratchet.
- Sibling Wave-2 decompositions **already done**: #4506 (`app_providers.dart`), #4508
  (`app_router.dart`). `main.dart` is the last of that trio and now outranks both in churn.

The pattern that works in this repo is: **extract one leaf, add a guard that stops it coming back.**

## Confirmed defects that any approach must reckon with

| ID | Defect | Severity | Proof |
|---|---|---|---|
| H1 | `handleBackNavigation` (120 lines in `build()`) is **dead on every non-Android platform** — its `PopScope` sits above `MaterialApp`, so `ModalRoute.of` is null and no `PopEntry` is ever registered | dead code | `test/scratch/popscope_root_proof_test.dart` — root fires 0×, control inside a route fires 1× |
| H4 | **Android system back from the Inbox tab exits the app.** 4 copies of the `RouteType→tab` map; only `app_shell`'s knows `inbox` | **S2** | `test/scratch/android_back_exit_proof_test.dart` — `handled=false` (inbox) vs `handled=true` (notifications), driven through the real `org.openvine/navigation` channel |
| H5 | `app_shell._navigateToTab` case 3 silently no-ops when the pubkey is missing; the other two copies fall back to home | S3 | source, `app_shell.dart:225-232` |
| H7 | H4 is a **162-day** regression from PR #2189 (2026-03-14) — a 53-file, 16-new-test PR that still missed 2 of the 4 copies because they live in files it never opened | — | `git log -S "RouteType.inbox"` on both files → empty, ever |
| H9 | A `setState() during build` exception at the root `UncontrolledProviderScope` on cold launch, forwarded to Crashlytics; no existing issue | S3 | captured live on iPhone 17 Pro Max / iOS 26.6.1 |

## Approaches Explored

### Approach A — Full decomposition, one PR, exactly as the issue's "Recommended fix" says

Extract `AppBootstrap`, `StartupCoordinatorFactory`, `AppCompositionRoot`, `DeepLinkCoordinator`,
`BackNavigationController`, `ShellChrome`, `BottomNavBar`, `ShellTitleResolver` in a single change.

**Layers:** UI, app root, router, startup.
**Pros:** closes all five ACs at once; the issue is done.
**Cons:** a multi-thousand-line diff on the app's riskiest file, which is also its #1 merge hotspot
with 2 open PRs on it. Unreviewable in practice. Every regression it introduces is a
launch-blocking regression, and there is no test scaffolding to catch them because the code being
moved is precisely the code that has none. Guaranteed conflict with #8075.
**Does not handle:** the confirmed bugs — a pure move preserves them, and moving 8 divergent copies
without deciding which is correct would enshrine the divergence.
**Complexity: High.** **Risk: High.**

### Approach B — Ratchet first, pay down later

Add a fail-closed guard (per-file line ceiling, or a detector for duplicate `RouteType`-switch
shapes) and shrink under it over time.

**Pros:** matches the repo's strong ratchet culture; stops further growth; cheap.
**Cons:** contradicts an explicit, recent policy decision that the file-size ceiling stays advisory.
Fixes **zero** of the confirmed bugs — H4 would still exit the app on Android. A ratchet is a
brake, not a repair, and this file already grew 1801→3451 *while* the advisory guard watched.
**Complexity: Low.** **Value: Low on its own.**

### Approach C — Bug-bearing slice only: one navigation-ownership PR (folds in a deletion pass)

Scope-cut #3337 to the single concern that is demonstrably broken, and fix it by extracting it:

1. Create one leaf that owns tab identity and back-navigation policy — the `RouteType↔tab` map and
   the "sub-route / feed-index / tab-history / go-home / exit" decision — as **pure functions
   returning a decision object**, not as widgets performing navigation.
2. Delete all 8 duplicate copies (`main.dart`, `back_button_handler.dart`, `app_shell.dart`,
   `vine_bottom_nav.dart`, `tab_history_provider.dart`) and route every caller through the leaf.
3. **Delete** the dead root `PopScope` and `handleBackNavigation` outright (H1) rather than moving
   them — they have never executed.
4. Decide the two open product questions once, in one place: what back does from a hashtag grid,
   and whether Inbox participates in tab history.
5. Add a source guard in the shape of #7969's, so a fifth copy cannot reappear.

**Layers:** router + app root + one service; no BLoC/repository change.
**Pros:** ships a real S2 user-visible fix; the diff is *net-negative* on `main.dart` (~200+ lines
out) while being small enough to review line by line; makes ACs #2 and #5 genuinely true for the
back-navigation half; follows the exact precedent that has worked twice on this file; touches almost
nothing #8075 touches.
**Cons:** leaves AC #1 (entrypoint slimming) and AC #3 (provider composition) untouched, so #3337
stays open. Requires two product decisions before it can land.
**Complexity: Medium.** **Risk: Low-Medium.**

### Approach D — Ordered sequence of independent leaf extractions (C first, then the rest)

Do C, then continue with the same pattern in risk order, each as its own PR **against `main`**
because each is genuinely independent (no stacking):

| Order | Slice | Risk | Removes from main.dart |
|---|---|---|---|
| 1 | navigation ownership (= Approach C) | Low-Med | ~220 lines |
| 2 | shell chrome + title resolver (`app_shell` privates → pure functions) | Low | 0 (app_shell) |
| 3 | deep-link coordinator (`ref.listen` closure → named class) — **must preserve the documented idempotency with `appRouterRedirect`** | Med | ~415 lines |
| 4 | app composition root (`MultiRepositoryProvider`/`MultiBlocProvider` tree → `AppCompositionRoot`) | Med | ~200 lines |
| 5 | startup bootstrap (`_startOpenVineApp` + the 8 `_initialize*` fns → `lib/startup/`) | **High** | ~700 lines |

**Pros:** each step is reviewable, revertable, and independently valuable; risk is front-loaded low;
the highest-risk slice (startup) lands last, after the file is already half its size and after the
team has seen the pattern work four times.
**Cons:** #3337 stays open across several PRs; needs a tracking comment so the sequence is visible.
**Complexity: High overall, Low-Medium per step.**

### Approach E — Deletion-first census

Before extracting anything, measure how much of the 3,451 lines is dead or duplicated (H1 proves at
least 120 lines are literally unreachable; H8 proves 8 duplicate copies) and delete only that.

**Pros:** the cheapest lines to remove are the ones nobody runs; a smaller file is safer to split.
**Cons:** not a standalone approach — the census is a *sub-step* of C, and on its own it restructures
nothing. Folded into C above.
**Complexity: Low.**

## Recommendation

**Approach D, starting with C as PR #1** — and treat C as shippable on its own merit even if the
rest of D is never scheduled.

Why this fits divine-mobile specifically:

- It is the **only** approach that repays the issue's cost claim with a user-visible fix. #3337 has
  been open since April and slipped a wave because "refactor for its own sake" never wins against
  feature work. C reframes it as *"Android back exits the app from the Inbox tab, and here is why"* —
  which is a P1 bug, not a cleanup.
- It matches the two extractions that already succeeded **on this exact file** (#7969, #7444):
  small leaf, pure functions, source guard. Approach A matches nothing that has worked here.
- The no-stacking rule actively favours D over A: the five slices are genuinely independent (they
  share no symbol), so they legitimately go to `main` separately, whereas A's "one big PR" would be
  a single unreviewable change to the riskiest file in the repo.
- Deferring startup (slice 5) to last respects that startup ordering is where a mistake is a launch
  blocker, and that #8075 is currently rewriting part of it.

Approach B is rejected on policy grounds (contradicts the advisory-ceiling decision) and on value
grounds (fixes nothing). Approach A is rejected on reviewability and risk.

## Open questions for `/plan` — two are PRODUCT decisions, not implementation details

- [ ] **P1. Does Inbox participate in tab history?** Today `app_shell` says yes (tab 2),
      `tab_history_provider` and `back_button_handler` say no. Whichever is chosen, all copies must
      agree. Recommendation: **yes** — it is a bottom-nav tab, and "no" is what makes the app exit.
- [ ] **P2. What does back do from a hashtag grid?** `main.dart` says `router.pop()`
      ("standalone screen"), `back_button_handler` says `go(/explore)` ("part of the Explore tab").
      The comments state opposite intent. Recommendation: **pop** — it preserves where the user
      came from; `go(/explore)` destroys it.
- [ ] I1. Where does the leaf live — `lib/router/` (it is routing policy) or `lib/navigation/`?
- [ ] I2. Should the leaf return a decision object (`BackAction`) that callers execute, or perform
      `context.go` itself? Pure-decision is far more testable and keeps `BuildContext` out.
- [ ] I3. Does `vine_bottom_nav`'s `_routeTypeForTab` (which maps slot 2 → `notifications` while
      navigating to `/inbox`) fold into the same leaf?
- [ ] I4. Is the source guard a test (like #7969) or a shell ratchet (like #7444)?

## Prerequisites

- [ ] P1 and P2 answered by a maintainer (`@NotThatKindOfDrLiz`) — these change user-visible behavior.
- [ ] Confirm whether PR #8075 already removes the H9 startup exception before filing it separately.
- [ ] File the Inbox back-exit bug as its own issue so the fix has a bug number, linked to #3337.

## Next Step

`/plan 3337` for slice 1 (Approach C), gated on P1/P2.
