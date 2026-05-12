# Brainstorm: Inconsistent error handling in notification methods (#3590)

Date: 2026-05-12

## Problem Statement

`FunnelcakeApiClient.getNotifications` (line 2128) and
`markNotificationsRead` (line 2177) silently catch all exceptions and
non-200 responses, returning empty/failure DTOs instead of throwing
typed exceptions like every other method in the same file. The
downstream stack — `NotificationRepository`'s rollback try/catch on
`markAsRead`/`markAllAsRead`, `NotificationFeedBloc`'s
`NotificationFeedStatus.failure` emission, and the `_FailureBody` retry
widget — is **already wired up to receive these throws** but never
fires because the API client swallows everything. Users see "No
notifications" indistinguishably from a real empty inbox; the
optimistic mark-read flip is never rolled back on server failure
because the API returns `MarkReadResponse(success: false)` instead of
throwing.

## Constraints

- **Layered architecture (UI → BLoC → Repository → Client).** Fix
  lives at the client layer with a small repository propagation; UI
  and BLoC are already correct as designed.
- **No errors in BLoC state** (`state_management.md`). The BLoC must
  surface failures via a status enum + `addError`, never via an error
  message field. Already conformant.
- **Reportable matrix** (`error_handling.md`): network/IO, HTTP
  4xx/5xx, auth/session, and timeout errors are all NOT reportable.
  The BLoC's current bare `addError(e, s)` calls are correct — do not
  wrap in `Reportable(...)`. `DivineBlocObserver`
  (`divine_bloc_observer.dart:48`) gates Crashlytics on
  `if (error is! ReportableError) return;` — the new throws are
  filtered automatically.
- **Snapshot architecture (PR #4247).** `NotificationRepository._snapshot`
  is a `BehaviorSubject<NotificationPage>` that always has a value;
  the feed BLoC and badge cubit derive everything from it. Whatever
  propagation shape we pick must coexist with this contract.
- **Blast radius is contained.** `FunnelcakeApiClient.getNotifications`
  has exactly one caller (`NotificationRepository.getNotifications`,
  line 127). `markNotificationsRead` has exactly two callers
  (`markAsRead` line 185, `markAllAsRead` line 221). The legacy
  `relay_notification_api_service.dart` is a separate code path that
  does not invoke the funnelcake client. The
  `notification_settings_screen.dart` calls
  `relayNotificationsProvider.notifier.markAllAsRead()` (legacy
  Riverpod), not the funnelcake client. The
  `notification_realtime_bridge.dart` imports from
  `funnelcake_api_client` only for the `RelayNotification` *model
  type*, not for the methods.
- **CI coverage gate** (re-verified): `funnelcake_api_client` enforces
  `min_coverage: 44` via `.github/workflows/funnelcake_api_client.yaml`.
  Adding throws-assertion tests is purely additive; coverage stays
  comfortably above the gate. `notification_repository` has no
  dedicated workflow (its tests run in main mobile CI).
- **PR #4247 hint, not mandate.** The author wrote: "the new repo
  surface makes this easier to fix later — the snapshot can carry a
  `failure` flag." Read as guidance, not a requirement; the canonical
  rethrow pattern in the same file is also valid.
- **No new technical debt** (epic #4200 standard). Whatever shape
  ships must not require a follow-up PR to be useful — wake the dead
  failure UI in the same change.
- **Issue #4208 overlap.** `#4208` lists `#3590` in "Relevant Debt"
  and its acceptance criteria include "failure/loading behavior is
  explicit and testable" — exactly what this fix produces. Per the
  no-stacked-PRs rule and #4208's engineering standard ("repay the
  relevant portion as part of the implementation instead of layering
  on a narrow patch"), this ships as its own PR and removes one
  bullet from #4208's debt list.

## Prior Art

- **`FunnelcakeApiClient.getVideosByAuthor`**
  (`funnelcake_api_client.dart:175-265`) — the canonical pattern in
  this file. `if (!isAvailable) throw FunnelcakeNotConfiguredException`,
  status-code-based throws of `FunnelcakeNotFoundException` /
  `FunnelcakeApiException`, `on TimeoutException` →
  `FunnelcakeTimeoutException`, `on FunnelcakeException { rethrow }`,
  generic `catch` → `FunnelcakeException`. Repeated across all 24
  non-notification methods.
- **`NotificationRepository.markAsRead`** (lines 170-198) and
  **`markAllAsRead`** (lines 207-231) — already snapshot the
  pre-write `_snapshot.value`, optimistically flip, and `rethrow`
  after rolling back on any caught exception. This rollback is
  currently dead because the API client never throws — but the
  *shape* is the established pattern for write paths in the
  repository.
- **`NotificationFeedBloc`** — every event handler has its
  appropriate failure branch wired up. `_onStarted` (lines 99-125)
  emits `failure` status on cold-load throw; `_onLoadMore` (lines
  128-143) clears `isLoadingMore` and `addError`; `_onRefreshed`
  (lines 146-157) flips status to `failure` and `addError`;
  `_onItemTapped` / `_onMarkAllRead` / `_onFollowBack` use
  `addError` only. **The `_onRefreshed` flip-to-failure shape
  predates PR #4247 by months** — it was written in PR #4034
  (`fix(notifications): rollback mark-all-read on server failure`,
  commit `a6c07df56`) and confirmed by every follow-up. This is the
  intended design contract, not an oversight.
- **`_FailureBody`** (`notifications_view.dart:336-369`) — the retry
  widget the BLoC's failure status drives. Renders
  `context.l10n.notificationsFailedToLoad` and
  `context.l10n.notificationsRetry` (translated to 16+ locales —
  every supported language has the strings).
- **Existing tests that are dead today and become live after the
  fix:**
  - `notification_repository_test.dart:1366` — markAsRead optimistic
    flip + rollback on API throw
  - `notification_repository_test.dart:1388` — markAsRead rolls back
    snapshot when API throws
  - `notification_repository_test.dart:1448` — markAllAsRead rolls
    back when API throws
  - `notification_feed_bloc_test.dart:200` — emits failure when refresh
    throws (cold load)
  - `notification_feed_bloc_test.dart:217` — stays loaded when refresh
    succeeds but markAllAsRead throws
  - `notification_feed_bloc_test.dart:322` — emits failure when refresh
    throws (refresh path)
  - `notification_feed_bloc_test.dart:348, 371` — forwards repository
    errors via addError (item tap, mark-all)
  - `notifications_view_test.dart:168-193` — `_FailureBody` renders
    localized error + retry button + tap dispatches refresh
- **PR #4247** (`fix(notifications): unify unread state via reactive
  repository + badge cubit`, merged 2026-05-11) — set up the
  `BehaviorSubject` snapshot architecture; explicitly listed #3590
  as adjacent debt and suggested the failure-flag shape but did not
  prescribe it.
- **PR #4250** (`feat(nostr): distinguish PublishNoRelays vs
  PublishFailed`, currently open) — same "make silent failures
  distinguishable" pattern applied to the nostr publish path.
- **Issue #3586** (`Extract _request<T> helper`) — independently
  scoped code-quality refactor across all 24 methods. Not a
  prerequisite for #3590; would naturally enforce consistency once
  shipped, on top of #3590.
- **Prior brainstorm**:
  `mobile/docs/brainstorm/2026-05-11-issue4204-unify-unread-state-brainstorm.md`
  notes "funnelcake_api_client error-handling consistency (#3590) —
  a separate client-layer PR can address it once #4208 simplifies
  the repository surface" (line 328-330). This brainstorm is that
  separate PR's pre-work.

## Approaches Explored

### Approach A: Client-only fix (minimal scope)

**Description:** Make `FunnelcakeApiClient.getNotifications` and
`markNotificationsRead` throw the canonical typed exceptions
(`FunnelcakeApiException`, `FunnelcakeTimeoutException`,
`FunnelcakeException`) matching every other method in the file.
Leave `NotificationRepository.getNotifications`'s `on Exception`
swallow (line 146) untouched — it would catch the new throws and
return `NotificationPage.empty` exactly like before. Update the 5
silent-fail tests in `funnelcake_api_client_notification_test.dart`
to assert throws.

**Layers affected:** Client only.

**Pros:**
- Smallest possible change; literally implements the issue's text
  ("Make these methods throw like the rest").
- Mark-read paths *do* get fixed end-to-end: the repository's
  existing rollback try/catch finally fires when the server returns
  5xx, and the BLoC's `addError` reaches Crashlytics-gated logging.
  Optimistic flip rolls back correctly.
- Zero risk to the cold-load UX — the snapshot still always emits an
  empty page on `getNotifications` failure, exactly like today.

**Cons:**
- The cold-load failure UI (`_FailureBody`, the
  `NotificationFeedStatus.failure` enum, the
  `notificationsFailedToLoad` / `notificationsRetry` l10n strings)
  stays dead. Users still cannot distinguish "no notifications"
  from "network down" on initial load.
- Leaves obvious stranded code that demands a follow-up PR —
  violates epic #4200's "no new technical debt" standard.
- The "failed-to-load + retry" UX is a real product gap; punting it
  forward when the half-build already exists is wasted opportunity.

**Risks / Unknowns:**
- None on the API client side — pattern is well-established in the
  same file.

**Complexity:** Low.

### Approach B: Client throws + Repository rethrows (wake the dead UI) — RECOMMENDED

**Description:** Make the API client throw (Approach A's change),
then delete the `on Exception` swallow in
`NotificationRepository.getNotifications` at lines 146-154 — replace
with `rethrow;` after the existing `developer.log`. The mark-read
rollback paths (lines 194-197, 227-230) need no change — they
already rethrow correctly. The BLoC's existing try/catch in
`_onStarted` (line 108) flips status to failure on cold load; the
existing `_FailureBody` widget renders. Tests at
`funnelcake_api_client_notification_test.dart` and
`notification_repository_test.dart:280` ("returns empty page on API
error") get updated to assert throws / rethrows respectively.

**Layers affected:** Client + Repository (delete one swallow). No
BLoC change. No view change.

**Pros:**
- End-to-end fix. The dead `_FailureBody` widget, the
  `NotificationFeedStatus.failure` enum, the l10n strings, the
  Crashlytics-gated `addError` paths — all wake up in one PR.
- Matches the existing pattern in the same repository file
  (`markAsRead`/`markAllAsRead` already rethrow).
- Eight existing dead-code tests (listed above in Prior Art) become
  real production-path coverage instead of asserting unreachable
  behavior. Net coverage of error paths goes from 0% effective to
  ~100% effective.
- Smallest possible end-to-end change — touches one production file
  in the client + one production file in the repository (delete a
  catch arm and rethrow).
- Respects the BLoC's intended design: PR #4034 set the
  flip-to-failure-on-refresh contract back in 2026-04. PR #4247
  carried it forward unchanged. Approach B activates that contract
  as designed; it does not second-guess it.

**Cons:**
- A failed pull-to-refresh on a feed that already has data will hide
  the existing list behind `_FailureBody` (because BLoC's
  `_onRefreshed` flips to failure status unconditionally). However:
  - This is **not a regression** vs today: today, the API silently
    returns empty → snapshot updates to empty → view renders empty
    state. The user already loses visibility of their data on a
    failed refresh; after the fix they at least get an actionable
    retry button instead of misleading "No notifications" copy.
  - This is the design intent (PR #4034); changing it here would be
    out-of-scope BLoC work.

**Risks / Unknowns:**
- Existing `notification_repository_test.dart:280` test (`returns
  empty page on API error`) needs renaming + reshaping to `rethrows
  on API error after logging`. Predictable.

**Complexity:** Low.

### Approach C: Client throws + Repository carries failure flag in NotificationPage (PR #4247 hint)

**Description:** Make the API client throw (Approach A's change). Add
a `bool hasError` field to `NotificationPage`. In
`NotificationRepository.getNotifications`, keep the existing
try/catch but on catch emit a snapshot with the existing items +
`hasError: true` (preserves data on failed refresh, which Approach B
loses to the full-screen failure widget). The BLoC's
`_onSnapshotChanged` maps `page.hasError` to
`NotificationFeedStatus.failure`. Mark-read paths still rethrow
(they need imperative response).

**Layers affected:** Client + Repository (model + behavior) + BLoC
(snapshot mapping). Tests across all three layers.

**Pros:**
- Aligns with PR #4247 author's hint.
- Preserves existing data on a failed refresh — user keeps seeing
  the notifications they already have, plus a failure indicator
  (assuming we wire one).
- Architecturally most "pure" with the reactive snapshot model.

**Cons:**
- More files to touch. `NotificationPage` (model + tests),
  `NotificationRepository` (logic + tests), `NotificationFeedBloc`
  (mapping + tests), the four `BlocSelector`/`BlocBuilder` consumers.
- Adds a new signal alongside the existing `NotificationFeedStatus`
  enum — two ways to express failure (snapshot flag → BLoC enum)
  where one would do.
- The "preserves existing data on refresh failure" benefit requires
  a UI affordance to actually show the failure (otherwise it's a
  flag with no consumer). That's additional UI work — snackbar or
  banner — that doesn't exist today and isn't asked for in #3590.
- `NotificationPage.empty` becomes ambiguous: is it "we loaded
  nothing" or "we failed to load"? Need a new
  `NotificationPage.error` constructor or a derived getter, which
  adds API surface.
- Larger PR diff increases review surface and merge risk.
- **Second-guesses the BLoC design**: PR #4034 + PR #4247 set the
  flip-to-failure contract on `_onRefreshed` deliberately. The
  failure-flag approach implicitly argues that contract is wrong.
  That's a BLoC redesign masquerading as an error-handling fix.

**Risks / Unknowns:**
- BLoC's `_onSnapshotChanged` would need to decide when a snapshot
  with `hasError: true` *and* existing items maps to `loaded` (with
  side-channel error indicator) vs `failure` (full-screen).
  Decision surface widens; could land on the same UX problem as
  Approach B.

**Complexity:** Medium.

### Approach D: Client throws + Repository granular error types (rejected as YAGNI)

**Description:** Add a `sealed class NotificationLoadResult` with
`Loaded(items)`, `TransientError(retryAfter)`, `AuthError`,
`OfflineError` variants. Map server response → variant in the repo;
BLoC pattern-matches each variant to a different UI affordance
(snackbar vs full-screen vs re-auth flow).

**Layers affected:** Client + Repository (large redesign) + BLoC + UI.

**Pros:**
- Most expressive. Future-proofs against richer error UX.

**Cons:**
- Issue #3590 does not ask for this. Pure YAGNI — the existing UI
  has one failure state, not four.
- Massive scope creep; would block on product sign-off for the new
  variant taxonomy.
- Sets precedent for similar treatment across the file's 24 methods
  — multiplies into a project-wide refactor.

**Risks / Unknowns:**
- High. Cross-cutting model change with no concrete user need behind
  it.

**Complexity:** High. **Rejected.**

## Recommendation

**Approach B — Client throws + Repository rethrows.**

**No BLoC changes. No view changes.**

The decisive factors:

1. **End-to-end fix in one PR, no follow-up debt.** Approach A
   leaves the `_FailureBody` widget, the failure status enum, and
   the l10n strings stranded; Approach B activates the entire stack
   the team already shipped. Epic #4200's "no new technical debt"
   standard strongly favors B.

2. **Smallest viable change matches stated need.** Approach C's
   failure-flag is over-engineered for the present requirement — the
   snapshot already always emits a value; rethrow-on-catch is a
   simpler signal that maps cleanly to the existing
   `NotificationFeedStatus.failure` enum the BLoC already emits.

3. **Pattern consistency in the same file.** The repository's own
   `markAsRead`/`markAllAsRead` already rethrow after rollback (lines
   197, 230). Making `getNotifications` rethrow after logging matches
   the established local convention.

4. **Eight existing tests validate the choice.** All listed in Prior
   Art — they currently assert behavior against unreachable code.
   Activating the contract is just removing one swallow and making
   them real.

5. **Respects the BLoC design intent.** PR #4034 deliberately set
   `_onRefreshed` to flip to failure status — that contract has been
   in place for over a month and was carried forward unchanged by
   PR #4247. Approach B activates that contract as designed.
   Approach C (failure flag) implicitly argues the contract is
   wrong, which is out of scope for a #3590 fix.

6. **The "data lost on failed refresh" concern is bounded and not a
   regression.** Today, a failed refresh shows empty state ("No
   notifications") — also hides the user's data, with worse signal.
   Approach B replaces that silent-empty experience with a full-
   screen error + retry button, which is strictly better at error
   visibility while no worse at data visibility. The user can tap
   Retry to recover; their data is preserved in the snapshot's
   `BehaviorSubject` value throughout (just hidden behind
   `_FailureBody` until the next successful refresh).

PR #4247's author's hint at the failure-flag shape was a reasonable
suggestion at the time, but on inspection the rethrow path uses
fewer moving parts and arrives at the same observable outcome
without requiring a UI redesign. If a future issue surfaces a real
product need for richer error variants (e.g., "preserve list
visibility on failed refresh and show a snackbar"), Approach C or D
can layer on top — the rethrow does not foreclose that.

## Open Questions for /plan

- [ ] **Repository swallow-vs-rethrow exact shape.** Two candidates:
      (a) `} on Exception catch (e, s) { developer.log(...);
      rethrow; }` — minimal change, preserves the structured log
      line for triage; or (b) delete the catch entirely and let the
      throw propagate raw. Default (a) — keeps the log line that
      existing on-call workflows rely on.
- [ ] **`isAvailable` guard parity.** `getNotifications` and
      `markNotificationsRead` are the only methods in
      `funnelcake_api_client.dart` missing the `if (!isAvailable)
      throw const FunnelcakeNotConfiguredException();` guard.
      Adding it as part of the rewrite is parity, not new behavior
      (production cannot reach these methods with empty
      `baseUrl`), but it makes the file's contract uniform. In
      scope for the same PR — costs ~2 lines.
- [ ] **Doc-comment rewrite.** `getNotifications` (line 2127) and
      `markNotificationsRead` (line 2176) currently doc the silent-
      fail contract. Rewrite to the canonical "Throws: ..." block
      that `getVideosByAuthor` (lines 186-191) uses.
- [ ] **Test file: replace or augment?** The existing 5 silent-fail
      tests in `funnelcake_api_client_notification_test.dart`
      (lines 179, 196, 212, 361, 378) are obsolete after the fix —
      replace with throws-assertions (mirror
      `funnelcake_api_client_test.dart`'s patterns for
      `getVideosByAuthor`). Add four new tests for
      `FunnelcakeNotConfiguredException` (×2) and
      `FunnelcakeTimeoutException` (×2) to match
      `getVideosByAuthor`'s coverage shape.
- [ ] **`notification_repository_test.dart:280`** ("returns empty
      page on API error") — rename to "rethrows on API error after
      logging" and change assertion shape. Add a complementary
      assertion that `watchSnapshot().first` still emits the
      seeded `NotificationPage.empty` (BehaviorSubject preserves
      its prior value across the throw).
- [ ] **No new BLoC tests required.** The existing tests at
      `notification_feed_bloc_test.dart:200, 217, 322, 348, 371`
      already cover the failure paths against mocked throwing
      repositories. They become real-production-path coverage
      automatically. (Confirmed by inspection; do not add
      duplicates.)
- [ ] **No new view tests required.** The existing tests at
      `notifications_view_test.dart:168-193` already cover
      `_FailureBody` rendering and retry tap dispatch.
- [ ] **Crashlytics gating.** Verify with `BlocObserver` /
      `Reportable` that the resulting `addError` calls do *not*
      reach Crashlytics — per `error_handling.md`'s reportable
      matrix, network/IO/HTTP/auth all stay un-reported. Spot-check
      that no `Reportable` wrapping is introduced anywhere in the
      diff.
- [ ] **PR scope: include #3586 (`_request<T>` helper) prep, or
      defer?** Strong default: defer — #3586 is independently
      scoped and would balloon this PR; #3590 is the smaller, more
      reviewable change.
- [ ] **`MarkReadResponse.error` field follow-up (out of scope, flag
      only).** The model has a `String? error` field that's
      populated for 200-with-`success: false` responses. The
      repository discards the response object entirely. Consider
      whether the repo should also gate rollback on
      `response.success == true` — but that's a separate behavior
      change for #4208 to evaluate, not for #3590.
- [ ] **`notification_repository` CI workflow (out of scope, flag
      only).** This package was added in PR #4247 but does not
      have a dedicated CI workflow — its tests run as part of the
      main mobile job. Worth flagging to the team but unrelated
      to #3590.

## Prerequisites

None. All required infrastructure (l10n strings, `_FailureBody`
widget, BLoC failure status, repository rollback semantics, exception
classes, dead-but-passing tests) already exists.

## Next Step

`/plan` against Approach B with these explicit scope boundaries:

**In scope (single PR targeting `main`):**
- `mobile/packages/funnelcake_api_client/lib/src/funnelcake_api_client.dart`
  — rewrite `getNotifications` and `markNotificationsRead` to throw
  the canonical `FunnelcakeException` family, mirroring
  `getVideosByAuthor`. Add `isAvailable` guard parity. Rewrite doc
  comments to "Throws: ..." blocks.
- `mobile/packages/funnelcake_api_client/test/src/funnelcake_api_client_notification_test.dart`
  — reshape 5 existing silent-fail tests to throws-assertions; add
  4 new tests for not-configured and timeout cases (2 each).
- `mobile/packages/notification_repository/lib/src/notification_repository.dart`
  — change `return NotificationPage.empty;` at line 153 to
  `rethrow;`. Update the dartdoc on `getNotifications` to document
  that it rethrows after logging.
- `mobile/packages/notification_repository/test/src/notification_repository_test.dart`
  — reshape 1 existing test (line 280) from "returns empty page on
  API error" to "rethrows on API error after logging".

**Out of scope (deferred):**
- BLoC `_onRefreshed` tweaks — the existing flip-to-failure
  behavior is the design intent (PR #4034) and activating it is
  the right move for #3590.
- `MarkReadResponse.error` field handling — adjacent to #4208.
- `_request<T>` helper extraction — #3586's scope.
- Legacy provider/screen cleanup — #4208's scope.
- New `notification_repository` CI workflow — adjacent.

**PR title:** `fix(notifications): throw typed exceptions from getNotifications and markNotificationsRead (#3590)`. Note: although the issue is labeled `code-review` / `error-handling`, the user-facing impact is a bug (dead failure UI), so `fix(notifications):` is the correct conventional-commit prefix per the project's title conventions and prior precedent (PR #4247 title shape).

**PR description:** Lead with the three reproductions (cold-load
failure, refresh failure, mark-read failure). Reference this
brainstorm document for design rationale. Note that the fix removes
one bullet from #4208's debt list.
