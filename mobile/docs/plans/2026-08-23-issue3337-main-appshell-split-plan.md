# Plan: refactor(app): split main.dart and AppShell into focused modules (#3337)

**Type**: Task (refactor) — carrying three confirmed defect fixes
**Issue**: https://github.com/divinevideo/divine-mobile/issues/3337 (child of epic #4339, Wave 2)
**Complexity**: **High**
**Direction**: Approach A — full decomposition in a single PR (user decision, 2026-08-23)
**Findings source of truth**: `tasks/findings_3337.md`
**Brainstorm**: `mobile/docs/brainstorm/2026-08-23-issue3337-main-appshell-split-brainstorm.md`

---

## Risk statement (raised once, then proceeding)

I recommended splitting this into an ordered sequence of independent PRs; the call was made for a
single PR and this plan builds that. The residual risk is concentrated in **Step 7** (startup
bootstrap, 599 lines on the app's launch path) and in conflict with **open PR #8075**, which
rewrites the startup redirect. Mitigations are built into the plan: one commit per extraction so any
single step can be reverted alone, characterization tests written *before* each move, Step 7 ordered
last, and a `#8075`-first merge order.

---

## Issue Summary

`mobile/lib/main.dart` is 3,451 lines / 154 imports, containing a single 1,195-line `_DivineAppState`
class whose `build()` is 889 lines. It is the #1 most-churned Dart file in `mobile/lib`
(170 commits, 13 authors, net +2,217 lines / 180 days). The tangle is not cosmetic: logic that stays
a closure inside `build()` is untestable and has silently drifted from its duplicates, producing a
shipping S2 navigation bug.

## Root causes being fixed (all verified at confidence 1.0)

| ID | Layer | File:line | Cause | Proof |
|---|---|---|---|---|
| **H1** | UI / app root | `main.dart:2893` | `PopScope(canPop:false)` is placed **above** `MaterialApp.router`. `_PopScopeState.didChangeDependencies` registers via `ModalRoute.of(context)`, which is null there, so no `PopEntry` is ever registered and `onPopInvokedWithResult` never fires. The 120-line `handleBackNavigation` closure (`main.dart:2728`) is therefore **dead on every non-Android platform**. | `test/scratch/popscope_root_proof_test.dart`: root `PopScope` invoked **0×** on a system pop; identical `PopScope` inside a route invoked **1×**. |
| **H4** | router / providers | `tab_history_provider.dart:66`, `back_button_handler.dart:162` | The `RouteType→tab index` map exists in **4 copies**. Only `app_shell.dart:195` has an `inbox` arm. `/inbox` is the destination of bottom-nav slot 2 (`vine_bottom_nav.dart:92`), so it is never recorded in tab history, and Android system back returns `false` → **the OS closes the app**. | `test/scratch/inbox_back_divergence_proof_test.dart`: `INBOX -> tabHistory=[0]` vs `NOTIFICATIONS -> [0,2]`. `test/scratch/android_back_exit_proof_test.dart`: `handled=false` (inbox) vs `handled=true` (notifications), driven through the real `org.openvine/navigation` channel. |
| **H5** | UI | `app_shell.dart:225-232` | `_navigateToTab` case 3 has `if (currentUserHex != null) { … }` with **no `else`**, so with no pubkey the shell back button silently does nothing. The other two copies fall back to `VideoFeedPage.pathForIndex(0)`. | source read |

**Regression provenance (H7):** `RouteType.inbox` landed in `14850ca430` (PR #2189, 2026-03-14) — a
53-file, +3,996-line PR with 16 new test files. `git log -S "RouteType.inbox"` on
`back_button_handler.dart` and `tab_history_provider.dart` returns **empty for all of history**.
**162 days shipping.**

## Product decisions (approved 2026-08-23)

- **P1 — Inbox participates in tab history.** `RouteType.inbox` maps to tab index 2 everywhere.
  This is what stops Android back from quitting the app.
- **P2 — Back from a hashtag grid pops.** `router.pop()`, not `go(ExploreScreen.path)`; popping
  preserves where the user came from. `main.dart`'s (dead) copy was right; the live Android copy
  was wrong. Note `RouteType.hashtag` still maps to tab index **1** for tab-history purposes —
  P2 governs only the sub-route branch, not the tab identity.

## Architecture

New leaves, all pure-Dart-testable, none importing Flutter UI beyond what is stated:

```
lib/startup/
  app_bootstrap.dart            <- _startOpenVineApp + the 8 _initialize* fns  (Step 7)
  startup_coordinator_factory.dart <- _createStartupCoordinator                (Step 7)
  app_composition_root.dart     <- MultiRepositoryProvider/MultiBlocProvider tree (Step 5)
lib/navigation/
  tab_identity.dart             <- the ONE RouteType<->tab map                 (Step 1)
  back_navigation_policy.dart   <- pure decision fn -> BackAction              (Step 2)
lib/router/
  deep_link_coordinator.dart    <- the ref.listen(deepLinksProvider) closure   (Step 4)
  shell/shell_title_resolver.dart <- _titleFor + _showBackButton               (Step 3)
  shell/shell_chrome.dart       <- AppShell app-bar/bottom-nav composition     (Step 3)
```

**Key design decision (I2):** `back_navigation_policy.dart` returns a **decision object**, it does
not navigate. `BackAction` is a sealed class — `PopRoute`, `GoTo(path)`, `NotHandled` — so the whole
policy is testable with no `BuildContext`, no `GoRouter`, and no widget pump. The three call sites
(Android channel, shell app-bar button, and any future one) execute the decision.

## Affected files

| File | Action | Description |
|---|---|---|
| `lib/navigation/tab_identity.dart` | **Create** | `routeTypeForTab(int)` / `tabIndexFromRouteType(RouteType)` — the single source of truth. Includes `inbox → 2` (P1) and `hashtag → 1`. |
| `lib/navigation/back_navigation_policy.dart` | **Create** | `BackAction resolveBackAction({RouteContext?, bool canPop, int? previousTab, int? lastIndexForPreviousTab, String? currentNpub})` — pure. |
| `lib/navigation/back_action.dart` | **Create** | Sealed `BackAction`: `PopRoute` / `GoTo(String path)` / `NotHandled`. |
| `lib/services/back_button_handler.dart` | **Modify** | Delete its 3 private copies; call `resolveBackAction` and execute. Keeps the channel plumbing only. |
| `lib/router/providers/tab_history_provider.dart` | **Modify** | Delete `_tabIndexFromRouteType`; import `tab_identity.dart`. **This one line fixes H4.** |
| `lib/router/app_shell.dart` | **Modify** | Delete `_routeTypeForTab`, `_tabIndexFromRouteType`, `_navigateToTab`, `_titleFor`, `_showBackButton`; delegate to the new leaves. Fixes H5. |
| `lib/widgets/vine_bottom_nav.dart` | **Modify** | Delete `_routeTypeForTab`; import `tab_identity.dart` (fixes the slot-2 → `notifications` mismatch, I3). |
| `lib/router/shell/shell_title_resolver.dart` | **Create** | `String resolveShellTitle(AppLocalizations, RouteContext?, UserProfile?)` + `bool showBackButton(RouteContext?)` — pure. |
| `lib/router/shell/shell_chrome.dart` | **Create** | App-bar + bottom-nav widget composition lifted out of `_AppShellState`. |
| `lib/router/deep_link_coordinator.dart` | **Create** | The `ref.listen(deepLinksProvider)` body as a named class. **Must preserve the documented idempotency with `appRouterRedirect`** (see H13). |
| `lib/startup/app_composition_root.dart` | **Create** | `MultiRepositoryProvider` / `MultiBlocProvider` / `BlocListener` tree (`main.dart` ~2940–3130). |
| `lib/startup/startup_coordinator_factory.dart` | **Create** | `_createStartupCoordinator` (`main.dart:634-905`, 272 lines). |
| `lib/startup/app_bootstrap.dart` | **Create** | `_startOpenVineApp` (`main.dart:937-1535`, 599 lines) + `_initializeCoreServices`…`_initializeZendeskSupport` (`1656-1886`). |
| `lib/main.dart` | **Modify** | Reduced to: `main()`, the `@pragma('vm:entry-point')` Firebase background handler, and `DivineApp` as thin composition. **Delete `handleBackNavigation` + the root `PopScope` entirely (H1) — do not move dead code.** |

## Implementation steps (bottom-up; one commit each, revertable alone)

1. **Navigation — tab identity.** Create `tab_identity.dart` with `inbox → 2` (P1). Point
   `tab_history_provider`, `back_button_handler`, `app_shell`, `vine_bottom_nav` at it and delete
   all 8 private copies. *Why first: it is the smallest change that fixes the S2 bug, and it is a
   prerequisite for step 2.*
2. **Navigation — back policy.** Create `back_action.dart` + `back_navigation_policy.dart` as pure
   functions, encoding P2 (hashtag grid pops). Rewrite `BackButtonHandler._handleBackButton` and
   `_AppShellState`'s back `onPressed` to call it. Fixes H5 by giving the profile branch a single
   documented fallback. **Delete `main.dart`'s `handleBackNavigation` and its dead `PopScope`.**
3. **Shell — chrome + title.** Extract `resolveShellTitle` / `showBackButton` as pure functions and
   `ShellChrome` as a widget. `_AppShellState` keeps only `RouteAware` lifecycle and
   `_setShellObscured`. Satisfies AC #5.
4. **Router — deep-link coordinator.** Move the `ref.listen(deepLinksProvider)` body
   (`main.dart` ~2270–2684) into `DeepLinkCoordinator`. Behaviour-preserving; the idempotency with
   `appRouterRedirect` is a contract, not a duplication to remove. Satisfies AC #2's deep-link half.
5. **App root — composition root.** Move the provider/bloc/listener tree into `AppCompositionRoot`.
   Satisfies AC #3.
6. **App root — DivineApp slimming.** `_DivineAppState` keeps lifecycle observers, memory telemetry,
   and the four deferred-startup initializers; everything else is delegated. `build()` becomes a
   composition of named widgets.
7. **Startup — bootstrap + coordinator factory.** Move `_createStartupCoordinator` and
   `_startOpenVineApp` + the `_initialize*` family into `lib/startup/`. **Ordered last, deliberately:
   this is the launch path.** Satisfies AC #1.
8. **Guards.** Extend the `test/startup/app_side_effects_test.dart` source-guard pattern with a new
   guard asserting that `main.dart`, `app_shell.dart`, `vine_bottom_nav.dart`,
   `back_button_handler.dart` and `tab_history_provider.dart` contain **no local `RouteType`→tab
   switch** — i.e. the 9th copy cannot appear.

## Testing strategy

| Layer | Test file | What to test |
|---|---|---|
| Navigation (pure) | `test/navigation/tab_identity_test.dart` | Every `RouteType` → expected tab, **including `inbox → 2` and `hashtag → 1`**; round-trip `routeTypeForTab`. |
| Navigation (pure) | `test/navigation/back_navigation_policy_test.dart` | Table-driven over every branch: hashtag grid → `PopRoute` (P2); hashtag feed index>0 → `GoTo(/hashtag/:tag)`; categoryGallery canPop/!canPop; the 5 editor types → `PopRoute`; feed index>0 per tab; previous-tab restore per tab; **inbox with empty history → `GoTo(/home/0)` not `NotHandled`**; profile with null npub → `GoTo(/home/0)` (H5). |
| Router (provider) | `test/router/providers/tab_history_provider_test.dart` | **Regression for H4**: visiting `/inbox` records tab 2. Promote `test/scratch/inbox_back_divergence_proof_test.dart`. |
| Service (channel) | `test/services/back_button_handler_test.dart` | **Regression for H4**: `onBackPressed` on `/inbox` returns `true` and navigates to `/home/0`. Promote `test/scratch/android_back_exit_proof_test.dart` — it drives the real platform channel, which is the exact native contract. |
| App root | `test/main_popscope_removed_test.dart` | **Regression for H1**: a guard asserting `main.dart` contains no `PopScope` above `MaterialApp` (source guard), so the dead pattern cannot return. Promote `test/scratch/popscope_root_proof_test.dart` as the explanatory harness. |
| Shell (pure) | `test/router/shell/shell_title_resolver_test.dart` | Title per `RouteType`, explore tab-name labels, profile display-name fallback, `showBackButton` matrix. Satisfies AC #5. |
| Router | `test/router/deep_link_coordinator_test.dart` | Each `DeepLinkType` → expected navigation; unknown → dropped; **and that it stays idempotent with `appRouterRedirect`**. Satisfies AC #2. |
| Startup | `test/startup/app_bootstrap_test.dart` | Characterization: phase order and the timed-task wrapper. Extend existing `test/startup/main_startup_registration_test.dart`. |
| Guard | `test/navigation/no_duplicate_tab_map_test.dart` | Step 8's source guard. |

**Write the characterization test BEFORE each move**, so each commit is provably behaviour-preserving
except where P1/P2 intentionally change it.

Verification before every push (from `mobile/`):
`dart format`, `flutter analyze lib test integration_test`, the scoped tests above, then
`bash scripts/golden.sh verify` (Step 3 touches shell chrome), then `gh pr checks <n> --watch`.

## Risks and mitigations

- **Startup regression (highest).** Step 7 moves 871 lines of launch-path code. *Mitigation*: last
  step; its own commit; characterization tests first; verified by a real device cold launch on the
  iPhone before push (the harness used in this investigation is reusable).
- **Conflict with open PR #8075.** It is the only other open PR touching `main.dart` and it rewrites
  the startup redirect. *Mitigation*: **let #8075 merge first**, then rebase. Do not race it.
- **A pure move preserving a bug.** Moving 8 divergent copies without deciding which is correct
  would enshrine the divergence. *Mitigation*: P1/P2 are decided up front, and Steps 1–2 land the
  behaviour change explicitly with regression tests, not as a side effect of a move.
- **Reviewability.** A single PR of this size is hard to review. *Mitigation*: one commit per step,
  ordered so each is independently comprehensible; PR description sectioned per step; the two
  behaviour changes (P1, P2) called out separately from the moves, per `pr_takeover.md` §2.
- **Design-system / ratchet baselines.** Moving code between files shifts per-file counts in
  `check_raw_colors_ceiling.sh`, `check_raw_textstyle_ceiling.sh`, `check_material_button_ceiling.sh`,
  `check_raw_dialog_ceiling.sh`, `check_post_close_emit_ceiling.sh`, `check_layer_direction.sh`.
  *Mitigation*: regenerate every affected baseline with `UPDATE_BASELINE=1` and commit — and note in
  the PR that these are **relocations, not new violations**.
- **`lib/navigation/` is a new top-level directory.** *Mitigation*: alternative is `lib/router/`;
  either is acceptable — pick `lib/router/` if a reviewer objects to a new root folder (I1).

## Out of scope, filed separately

- **H9** — the cold-launch `setState() during build` exception at the root `UncontrolledProviderScope`,
  forwarded to Crashlytics, no existing issue. Attribution is 0.7 (most likely the account-deletion
  router redirect). **Check whether open PR #8075 already removes it before filing.**
- Live-log observations unrelated to #3337: a 17.8 s `nip44_decrypt` Keycast round trip; both feed
  providers losing Nostr tag enrichment to a 5 s timeout on every cold start.
