# Foreground-resume account-state refetch (mobile)

Design for the mobile half of divinevideo/support-trust-safety#185, part of
the protected-minor (13-15) safeguards epic #173. Surfaced during the #176
DM-restriction review.

## Problem (verified against code)

The two account-state providers are plain `FutureProvider`s that only
recompute on an auth-state transition (they `ref.watch(currentAuthStateProvider)`)
or an explicit `ref.invalidate`:

- `protectedMinorStatusProvider` — drives the #176 DM gate + #175 content
  lock through `isProtectedMinorProvider` / `isDmRestrictedProvider`.
- `currentMinorAccountReviewStatusProvider` — drives the #174/#175 blocking
  review gate (the app-router redirect).

`app_lifecycle_handler.dart`'s `AppLifecycleState.resumed` branch already does
resume work (relay reconnect, notification refresh, perf-tracker reset,
foreground flag) but touches neither provider. So when account state flips
**server-side while the app sits idle-authenticated** — a moderator sets or
clears `verified_minor`, or a review status changes — the client keeps
enforcing the stale state until the next relaunch or re-auth.

Web already covers this: `useProtectedMinorStatus` sets `staleTime: 0` +
`refetchOnWindowFocus: true`. This is mobile parity.

Impact fails **open** in the strengthen direction: an account flagged a
protected minor mid-session keeps DM + adult-content access until relaunch.
The lift direction (an aged-up teen staying restricted until relaunch) is the
less-severe tail, and the sticky store intentionally holds protection until a
positive not-a-minor signal anyway.

## The design nut

Resolving `protectedMinorStatusProvider` can trigger a Keycast token refresh
via `getSessionOrRefresh()` (a network call + storage write) when the cached
session is stale — so invalidating on **every** resume would hit Keycast on
every foreground. The guard is a min-interval TTL: skip the refetch if the
account state was refreshed within the last N. (In the common case a valid
session is reused with no refresh; the guard bounds the worst case.)

## Decisions

- **Min-interval: 15 minutes.** This is the strengthen-protection direction,
  so propagation latency matters; the worst case is bounded (~4 refreshes/hour,
  and only when the token is actually stale).
- **Refetch scope: both providers.** The epic frames #185 as hardening the
  #174 review gate + #175 content lock + #176 DM gate together, and the
  review-status provider drives the most consequential (suspend/blocking) gate.
  The review-status provider hits the app's own API, not Keycast, so the only
  Keycast-cost concern is the protected-minor one, already bounded by the TTL.

## Design

A small pure-Dart coordinator owns the TTL decision; a keep-alive provider
injects the two invalidations; the existing resume orchestrator calls it.

```dart
class AccountStateResumeRefresher {
  AccountStateResumeRefresher({
    required VoidCallback invalidateProtectedMinorStatus,
    required VoidCallback invalidateReviewStatus,
    Duration minInterval = const Duration(minutes: 15),
    DateTime Function() now = DateTime.now,
  });

  /// Invalidate both account-state providers on foreground resume, unless the
  /// account is unauthenticated or the last refresh was within [minInterval].
  void refreshOnResume({required bool authenticated}) {
    if (!authenticated) return;
    final t = _now();
    if (_lastRefreshedAt != null &&
        t.difference(_lastRefreshedAt!) < _minInterval) {
      return;
    }
    _lastRefreshedAt = t;
    _invalidateProtectedMinorStatus();
    _invalidateReviewStatus();
  }
}
```

- **State:** in-memory `_lastRefreshedAt`. No persistence — a cold start
  re-auths and refetches anyway.
- **Provider:** `accountStateResumeRefresherProvider` (plain `Provider`, alive
  for the container lifetime) wires the two invalidations to
  `ref.invalidate(protectedMinorStatusProvider)` and
  `ref.invalidate(currentMinorAccountReviewStatusProvider)`.
- **Call site:** one line in the `AppLifecycleState.resumed` branch of
  `app_lifecycle_handler.dart`, alongside the reconnect / notification-refresh
  work it already orchestrates:
  ```dart
  ref.read(accountStateResumeRefresherProvider).refreshOnResume(
    authenticated: ref.read(authServiceProvider).isAuthenticated,
  );
  ```

### Fail-safe

Invalidation drops `protectedMinorStatusProvider` to `AsyncLoading`. Both gate
providers read the sticky last-known value during reload
(`store.isProtectedMinorFor` / `store.lastKnownFor`), so a protected minor
stays protected through the refetch — no flicker-open window. A resume-refetch
that resolves to unknown/error therefore never reduces protection; it can only
strengthen it or correctly lift it on a positive not-a-minor signal.

## Test plan

- **Pure-class unit tests** (fake clock, spy invalidators):
  - first resume refreshes both providers;
  - a second resume within 15m does not refresh;
  - a second resume after 15m refreshes again;
  - unauthenticated never refreshes;
  - the interval boundary (exactly 15m).
- **`ProviderContainer` integration test:** the two real providers rebuild on
  `refreshOnResume` and do not within the interval (build-count spy).

## Out of scope

- The in-app age-review-completion path invalidating the review provider but
  not `protectedMinorStatusProvider` — a separate narrower miss the issue
  scopes away from this ticket.
- #186 (blocked-send terminal in the DM queue drain) — its own PR.
