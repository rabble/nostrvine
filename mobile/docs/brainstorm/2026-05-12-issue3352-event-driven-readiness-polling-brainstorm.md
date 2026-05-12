# Brainstorm: Issue #3352 — Replace readiness and notification polling timers with event-driven signals

Date: 2026-05-12

## Problem Statement

Three independent sites in `mobile/lib` use timers as coordination primitives where an explicit signal would be cleaner and cheaper:

1. `isNostrReady` polls `NostrClient.hasKeys` every 50 ms until it flips.
2. `RelayNotifications` runs a 5-min auto-refresh `Timer` that the unread-badge stack no longer needs (PR #4247).
3. `EmailVerificationCubit` polls a divine OAuth endpoint every 3 s for 15 min with no backoff, and no test pins the "stop on dispose / navigate-away" contract.

We need to drop these timers in favour of explicit readiness, lifecycle, and realtime signals — without introducing new `Future.delayed` workarounds or breaking the existing notification, push, and email-verification flows.

## Constraints

- **Layered architecture (`UI → BLoC → Repository → Client`).** Site B & C touch the BLoC/Cubit and Repository layers; Site A is a provider/services concern. Source-selection and fallback logic stays in repositories.
- **BLoC-first for new state; Riverpod for legacy maintenance.** Site A unavoidably touches Riverpod (the polling site is a Riverpod provider). Site C is already a Cubit; we extend it. Site B currently lives in Riverpod but the user-visible badge has already moved to BLoC + `NotificationRepository` (PR #4247 / #4204).
- **No new arbitrary `Future.delayed` / tight timer coordination.** Acceptance criterion 4 is self-imposed.
- **`origin/main` always passes.** Each site fix must ship green, ideally with `fakeAsync` tests that prove no idle timers remain.
- **#4208 is the parent epic's "last execution item".** Anything that bites off the legacy notification stack must coordinate with that issue; #3352 sits as related debt under #4208.
- **PR #4162 (DRAFT, large) already removes the 50 ms polling** via `NostrSessionReadiness` / `nostrSessionProvider`, closes #3929, has no reviewers requested. State at brainstorm time: `isDraft: true`, `state: OPEN`.
- **`divine_ui` / VineTheme.** No UI surface changes are required; this is purely backend/state plumbing.
- **Nostr protocol alignment.** No NIP needs amendment. The realtime notification path already uses Nostr-WS subscriptions surfaced through `NotificationServiceEnhanced.onNewNotification`. FCM push is a divine-specific signal (kinds 3079/3080/3083), not a NIP.

## Prior Art

**In the codebase:**
- `mobile/lib/providers/app_providers.dart:1201-1236` — current `isNostrReady` 50 ms polling site.
- `mobile/lib/providers/app_providers.dart:1889-1893` — sibling `Future.delayed(500ms)` ×30 polling in `notificationServiceEnhanced` provider. Same root cause; should ride along.
- `mobile/lib/providers/relay_notifications_provider.dart:96-184` — 5-min `Timer` + background-skip-and-restart logic. Now mostly dormant after PR #4247.
- `mobile/lib/blocs/email_verification/email_verification_cubit.dart:51-105` — fixed 3 s polling.
- `mobile/lib/services/background_activity_manager.dart` — singleton with a `BackgroundAwareService` interface (`onAppResumed`, `onAppBackgrounded`, …) already used by 5+ services. No `Stream` exposed yet, but the interface is sufficient.
- `mobile/lib/services/push_notification_service.dart:203` — `handleForegroundMessage(Map<String, dynamic>)` is the FCM-foreground entrypoint; `app_providers.dart:1353-1358` is the wiring site.
- `mobile/packages/notification_repository/lib/src/notification_repository.dart` (post-#4247) — owns `BehaviorSubject<NotificationPage>` snapshot, `acceptRealtime(RelayNotification)`, `watchSnapshot()`, `watchUnreadCount()`. The active path for the badge and inbox feed.
- `mobile/lib/notifications/services/notification_realtime_bridge.dart` (post-#4247) — translates `NotificationServiceEnhanced.onNewNotification` into `repo.acceptRealtime(...)`.

**Open PRs and related issues:**
- **PR #4162 (DRAFT)** — `NostrSessionReadiness` / `nostrSessionProvider`, removes the 50 ms timer entirely. Closes #3929, not #3352. 1057+/233- lines, no reviewers requested as of brainstorm.
- **PR #4247 (MERGED)** — `NotificationRepository` snapshot + `NotificationBadgeCubit`. Explicitly defers timer deletion to #3352.
- **Issue #3336** — broader DI-readiness refactor; #3352 is the bite-sized subset.
- **Issue #4208** — "last execution item" of the notifications epic, lists #3352 as related debt.
- **Issue #1948 (CLOSED)** — earlier patch that added `backgroundManager.isAppInBackground` skip to the 5-min timer. Confirms the timer's lifecycle has been brittle historically.
- **Issue #2701 (CLOSED)** — earlier patch to email-verification cubit guards. Confirms zombie-cubit handling on this code path needs explicit test coverage.

**Prior brainstorm docs in `mobile/docs/brainstorm/`:**
- `2026-05-09-issue4144-notification-badge-desync-brainstorm.md` — feeds into PR #4247.
- `2026-05-11-issue4204-unify-unread-state-brainstorm.md` — direct precursor; deferred timer deletion to #3352.

## Approaches Explored

The issue contains three independent acceptance criteria. Each has its own approach matrix; I treat them as parallel sub-decisions and then summarise the combined recommendation.

---

### Site A — `isNostrReady` 50 ms polling

#### Approach A1: Wait for / rebase on PR #4162

**Description:** Stop work on Site A; coordinate with `@dcadenas` to get PR #4162 reviewed and merged. After it lands, #3352 inherits the `nostrSessionProvider` design and only owns Sites B + C. Acceptance criterion 1 is satisfied transitively.

**Pros:**
- Zero duplication.
- The #4162 design is more complete than the minimal alternative — it tracks identity + ready-client tuple, not just a bool flag.
- Sister polling at `app_providers.dart:1889-1893` is also addressed because that provider is in #4162's blast radius.

**Cons:**
- #4162 is DRAFT, no requested reviewers, 1057 lines — landing is not imminent.
- #3352 deliverable becomes "wait for someone else's PR" for criterion 1.

**Complexity:** Low (for this PR), but high coordination cost.

#### Approach A2: Independently implement `NostrSessionReadiness`

**Description:** Recreate the `NostrSessionReadiness` / `nostrSessionProvider` design from PR #4162 inside #3352.

**Cons:**
- Duplicates #4162's work. Two parallel readiness designs racing each other is exactly the failure mode `feedback_scan_parallel_work_first.md` warns about.

**Complexity:** High.

#### Approach A3: Minimal one-shot ready signal

**Description:** Add the smallest possible event mechanism: `NostrClient.initialize()` resolves a `Completer<void>` exposed via `Future<void> get ready`. `NostrService` awaits it and calls `ref.invalidate(isNostrReadyProvider)`. Delete the 50 ms `Timer.periodic`. Apply the same pattern to `notificationServiceEnhanced` at `app_providers.dart:1889-1893`.

**Pros:**
- Smallest possible change.
- No conflict with #4162 — `Future<void> get ready` is independent of `NostrSessionReadiness`.
- Sister polling site at `app_providers.dart:1889` is also addressed.

**Cons:**
- Doesn't solve the identity-flip / account-switch race that #4162 explicitly addresses.

**Complexity:** Low.

---

### Site B — `RelayNotifications` 5-min auto-refresh timer

#### Approach B1: Delete the timer, drive refresh from FCM + lifecycle + pull-to-refresh

**Description:** Remove `_autoRefreshTimer`, `_startAutoRefresh`, `_stopAutoRefresh`, and `_autoRefreshInterval`. Add three explicit refresh triggers:
1. **Realtime FCM push** — extend the existing `firebaseOnMessageProvider.listen(...)` block to also call `ref.read(relayNotificationsProvider.notifier).refresh()`.
2. **App resume** — `BackgroundActivityManager` exposes a `Stream<AppLifecycleState>`; `RelayNotifications` `ref.listen`s it and triggers `refresh()` on `resumed`.
3. **Explicit user action** — pull-to-refresh already wired.

**Pros:**
- Satisfies acceptance criterion 2 verbatim.
- Aligned with the post-#4247 architecture.
- Low blast radius — only `notification_settings_screen.dart` and the (dead) `notifications_screen.dart` consume this provider.

**Cons:**
- `BackgroundActivityManager` doesn't expose a `Stream` yet — must add one.

**Complexity:** Medium.

#### Approach B2: Migrate remaining consumers to `NotificationRepository` and delete `relay_notifications_provider.dart` entirely

**Cons:** Out of scope per #4208 sequencing.

**Complexity:** High.

#### Approach B3: 60-min timer (kick the can)

**Cons:** Does not satisfy criterion 2.

**Complexity:** Low.

---

### Site C — `EmailVerificationCubit` bounded backoff

#### Approach C1: Exponential backoff with capped delay

**Description:** Replace `Timer.periodic(_pollInterval, …)` with a recursive `Timer(currentDelay, …)` whose delay grows: `[3, 3, 5, 8, 13, 21]` seconds, capped at 30 s. Total budget remains 15 min (~33 ticks vs current 300).

**Pros:** Boring, proven pattern. Easy to test with `fakeAsync`. ~10× reduction in poll count.

**Cons:** Worst-case wait grows from 3 s to 30 s for users who click late.

**Complexity:** Low.

#### Approach C2: Two-phase schedule (fast then slow)

**Cons:** Arbitrary pivot, no telemetry to justify.

#### Approach C3: Hybrid

**Cons:** Same constants-without-telemetry concern.

#### Approach C4: Server long-poll / push channel

**Cons:** Cross-stack, out of scope.

---

## Recommendation

**A1 (coordinate-and-wait) + B1 (delete + event-drive) + C1 (exponential backoff), with A3 as hot-swappable fallback if #4162 stalls.**

Why:

1. **Site A — A1 default, A3 fallback.** The `NostrSessionReadiness` design in #4162 is strictly more complete than anything #3352 could justify on its own. Doing A2 violates the project's "scan parallel work first" memory rule. **Action:** ping `@dcadenas` to request review on #4162. If #4162 hasn't moved when #3352 reaches review, fall back to A3.

2. **Site B — B1 fits the architecture.** PR #4247 already established the event-driven pattern. B1 wires the legacy provider's `refresh()` to the same realtime signal plus app-resume. B2 belongs in #4208. B3 is a non-fix.

3. **Site C — C1 is boring and testable.** Bounded backoff is the textbook answer and trivial to pin with `fakeAsync`.

## Open Questions for /plan

- [ ] Coordination protocol with #4162: block on it or ship Sites B + C first?
- [ ] `BackgroundActivityManager` surface: `Stream<AppLifecycleState>` (cleaner) vs `BackgroundAwareService` implementation?
- [ ] Schedule constants for C1: 3-3-5-8-13-21-30 vs strict doubling?
- [ ] Sister polling at `app_providers.dart:1889`: in scope here or #3336?
- [ ] `notifications_screen.dart`: dead enough to delete?

## Prerequisites

- [ ] Confirm `notifications_screen.dart` is unreachable from `app_router.dart`.
- [ ] Dialogue with `@dcadenas` on #4162 review timeline.
- [ ] Confirm with `@realmeylisdev` on #3352 vs #4208 sequencing.

## Next Step

`/plan https://github.com/divinevideo/divine-mobile/issues/3352`
