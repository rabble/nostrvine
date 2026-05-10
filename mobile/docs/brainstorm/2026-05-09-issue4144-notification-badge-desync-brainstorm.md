# Brainstorm: Notification badge does not clear after viewing notifications (#4144 / #4048)

Date: 2026-05-09

Status: Resolved — Approach A shipped in PR #4165. Approach C tracked in
issue #3596 (Delete dual notification system).

## Problem Statement

The unread badge on the bottom-nav Inbox icon and the inbox segmented toggle
stay visible after the user opens the Notifications tab and views their
notifications. The badge only clears after a 5-minute auto-refresh fires
(or the app is restarted). Issue #4144 is a duplicate of #4048 (originally
reported May 6 from Discord/Zendesk by `Crystal_Goth`).

The notifications subsystem is mid-migration from a Riverpod-only stack to a
BLoC stack. The badge consumer is still wired to the Riverpod cache while the
inbox screen's "mark all read" only updates the BLoC's cache. Both paths POST
to the same server endpoint (`/api/users/{pubkey}/notifications/read`), so the
server is consistent — only the client-side Riverpod cache stays stale until
its 5-minute auto-refresh.

## Constraints

- **Layered architecture mandate** (`.claude/rules/architecture.md`):
  UI → BLoC → Repository → Client. BLoCs must not import Riverpod.
  Repositories own composition, caching, and source-selection logic.
- **BLoC-first for new state management** (`.claude/rules/state_management.md`).
  Riverpod is legacy; the project has an open migration target.
- **No BLoC-to-BLoC dependencies** — coordination goes through `BlocListener`
  in the UI or shared repository state.
- **Migration marker already on file**: `relay_notifications_provider.dart:1`
  carries a `notifications-refactor` deferred-removal comment flagging the
  provider for retirement after the migration completes.
- **Server-side limitation** documented in
  `relay_notifications_provider.dart:1064-1080`: server `unreadCount` is
  unreliable until `funnelcake#234` ships Kind 3 dedup.
- **Inbox already follows the recommended pattern on the DMs side**:
  `DmUnreadCountCubit` (`mobile/lib/blocs/dm/unread_count/dm_unread_count_cubit.dart`)
  watches `dmRepository.watchUnreadAcceptedCount()`. Notifications should be
  symmetric.

## Prior Art

- **PR #4149** (`notification-not-going-away` branch, OPEN, CHANGES_REQUESTED).
  Authored by emir, addresses both bugs identified here:
  1. `_onStarted`/`_onMarkAllRead` ordering race (early-exit on empty initial
     state).
  2. BLoC ↔ Riverpod desync.

  Reviewer (NotThatKindOfDrLiz) blocked on three items:
  - Inline mark-read in `_onStarted` is a weaker duplicate of
    `_onMarkAllRead` — bypasses rollback / `addError`.
  - `markAllAsRead` fires from every `NotificationsView.initState`, but
    `inbox_notifications_page.dart` mounts 5 tab views in `TabBarView` →
    fans out into 5 server writes per inbox open.
  - Widget-test stub silences the side effect rather than asserting it.

- **PR #4034** (Meylis, MERGED) — added BLoC-side rollback on mark-all-read
  failure. Patched the BLoC's own row state but the badge consumer (Riverpod)
  remained stale, which is why #4144 / #4048 are still firing.

- **`DmUnreadCountCubit`** (mobile/lib/blocs/dm/unread_count/dm_unread_count_cubit.dart)
  — the symmetric pattern on the DMs side. Reads `dmRepository.watchUnreadAcceptedCount()`
  as a stream. Mark-read mutations on `DmRepository` propagate automatically.

- **`notification_realtime_bridge_provider.dart`** — current WebSocket
  bridge that pushes Nostr events into the Riverpod notifications notifier
  via `relayNotificationsProvider.notifier.insertFromWebSocket(notification)`.

## Approaches Explored

### Approach A: Tactical bridge (adopt PR #4149 with CR cleanup)

**Description:** Keep both stacks. From the inbox scaffold
(`inbox_notifications_page.dart`), fire
`relayNotificationsProvider.notifier.markAllAsRead()` once on inbox open,
guarded by an unread check. Fix the BLoC ordering race by having
`_onStarted` re-dispatch `NotificationFeedMarkAllRead` after the loaded
state is emitted, preserving the existing rollback / `addError` path.
Remove the per-`NotificationsView` Riverpod call so it does not fan out
across the 5 tab views.

**Layers affected:** UI (inbox scaffold) + BLoC (`_onStarted` only).

**Pros:**
- Smallest blast radius — ships in 1–2 days.
- Preserves PR #4034's rollback semantics.
- Closes #4144 / #4048 immediately.
- Leverages existing CR feedback on PR #4149.

**Cons:**
- Doubles down on dual-stack debt.
- Future BLoC writes (e.g. `_onItemTapped` per-row mark-read) silently
  regress the badge unless each new write site remembers to bridge.
- Riverpod's 5-min auto-refresh keeps racing with BLoC mutations (stale
  fetch can re-introduce `isRead: false`).
- Doesn't address the `notifications-refactor` deferred-removal marker.

**Risks / Unknowns:**
- Are there callsites that mount `NotificationsView` outside
  `InboxNotificationsPage`? If yes, centralizing at the scaffold misses
  them. (Quick grep before plan.)
- Does the re-dispatched `add(const NotificationFeedMarkAllRead())` from
  inside `_onStarted` cause any existing `bloc_test` to gain an extra
  emission?

**Complexity:** Low

---

### Approach B: BLoC-only badge (promote feature BLoC to app shell)

**Description:** Move `NotificationFeedBloc` (or a thinner sibling) up to
the app shell as a global `BlocProvider`, retire
`relayNotificationUnreadCountProvider`, and have the badge consumers read
`state.unreadCount` from the BLoC. Fold the Riverpod auto-refresh timer
and the `notification_realtime_bridge_provider` WebSocket subscription
into the BLoC's lifecycle.

**Layers affected:** UI (badge consumers, app shell) + BLoC (lifecycle +
WebSocket subscription).

**Pros:**
- Removes dual-stack debt and the migration marker.
- Aligns with BLoC-first mandate.
- Single source of truth.

**Cons:**
- BLoCs in this codebase are typically screen-scoped. Promoting a feature
  bloc to the app shell mixes lifecycle concerns.
- BLoC must own auth-flip rebuild, app foreground/background pause/resume,
  and WebSocket bridging — currently distributed across
  `currentAuthStateProvider`, `BackgroundActivityManager`, and
  `NotificationRealtimeBridge`.
- The screen-scoped `NotificationFeedBloc` and the app-shell BLoC would
  either be the same instance (lifecycle complications) or two instances
  with their own copies of the list — back to dual-state.

**Risks / Unknowns:**
- App-shell BLoC instance disposal on logout is non-trivial; mistakes
  here cause "stale notifications across account switch" bugs.

**Complexity:** High

---

### Approach C: Repository-as-source-of-truth + thin badge cubit

**Description:** Promote `NotificationRepository` to own a long-lived
in-memory cache, and expose `Stream<int> watchUnreadCount()` (and
`Stream<List<NotificationItem>> watchNotifications()`). Add
`NotificationBadgeCubit` that subscribes to `watchUnreadCount()` —
mirrors the existing `DmUnreadCountCubit` pattern.
`NotificationFeedBloc` keeps owning the screen but reads/writes through
the same repository, so its mark-read mutations propagate to the badge
stream automatically. Retire `relayNotificationsProvider` entirely. The
WebSocket bridge becomes `NotificationRepository.acceptRealtime(...)`
instead of pushing into a Riverpod notifier.

**Layers affected:** Repository (significant — adds reactive surface) +
BLoC (new badge cubit, light edits to `NotificationFeedBloc`) + UI
(badge consumers swap to `BlocSelector<NotificationBadgeCubit, int>`) +
Client (no changes).

**Pros:**
- Cleanest layered architecture: repository owns caching, per
  `.claude/rules/architecture.md`.
- Mirrors `DmUnreadCountCubit` + `dmRepository.watchUnreadAcceptedCount()`.
  The inbox becomes consistent across DMs and notifications.
- Closes the migration marker and removes Riverpod from notifications.
- Mark-read writes from anywhere (per-row tap, mark-all on inbox open,
  future per-type bulk actions) propagate to the badge automatically —
  no per-call-site bridging needed.
- Eliminates the *class* of bug, not just this instance.

**Cons:**
- Largest churn. ~5–8 files including tests.
- `notificationsDao` already supports `markAsRead` and `markAllAsRead`,
  but a `watchUnreadCount()` query and the realtime accept path need to
  be added.
- Auth-flip rebuild semantics migrate from `ref.watch(currentAuthStateProvider)`
  to repo per-pubkey instance flip (already how the repo is constructed).

**Risks / Unknowns:**
- Reactive surface shape — single
  `Stream<NotificationFeedSnapshot>` vs. separate count and list streams.
  Match `DmRepository`'s shape.
- Whether the realtime accept path is invoked by the repository owning
  its own `Stream<RelayNotification>` subscription, or by an external
  bridge calling `acceptRealtime` — second option matches existing
  `notification_realtime_bridge_provider` shape better.

**Complexity:** Medium-High

---

### Approach D: Server-driven badge

**Description:** Drop client-side derivation entirely. Use the server's
`unreadCount` from the notifications API as the badge value. Optionally
add a dedicated WebSocket channel for unread-count deltas.

**Layers affected:** Repository + Client + UI.

**Pros:**
- No client-side cache desync possible.
- Smallest client surface area.

**Cons:**
- **Blocked on backend.** The existing comment at
  `relay_notifications_provider.dart:1064-1080` documents that the
  server count is unreliable: "the server reports one row per Kind 3
  republish per follower — so the same N followers can produce 2N+ rows
  after a few contact-list edits." Tracked at `funnelcake#234` but not
  shipped.
- Doesn't help today.

**Complexity:** Low (client) / blocked (server).

---

## Decision

**Approach A shipped as the hotfix** in PR #4165, addressing the three
reviewer blockers from PR #4149:

1. Centralized the Riverpod sync at the inbox scaffold (one fire per
   inbox open, not five per tab view).
2. Re-dispatched `NotificationFeedMarkAllRead` from `_onStarted` instead
   of inlining a weaker variant — preserves the rollback / `addError`
   path added by #4034.
3. Added coverage that proves the side effect fires once per inbox open
   and does not fan out across the five filter tabs.

This closed the user-facing bug without committing to a larger refactor.

**Approach C is tracked in issue #3596** (Delete dual notification
system) as the architecturally correct destination —
repository-as-source-of-truth via `NotificationRepository.watchUnreadCount()`
plus a `NotificationBadgeCubit` mirroring `DmUnreadCountCubit`. Reasons
it is the right destination:

- The DMs side already does exactly this against `DmRepository`. The
  notifications side should be symmetric.
- It closes the dual-stack migration debt described in #3596 — the
  legacy `screens/notifications_screen.dart` and
  `providers/relay_notifications_provider.dart` retire together with
  the badge bridge.
- It eliminates the *class* of bug (BLoC writes invisible to badge),
  not just this instance. Issue #4034 (BLoC-side rollback) and issue
  #4144 / #4048 (badge desync) are two faces of the same dual-cache
  problem; patching them one at a time keeps producing similar tickets.

**Approach B was rejected** — promoting a feature BLoC to the app shell
mixes lifecycle concerns and would still leave a screen-scoped BLoC
alongside it, putting the codebase back into a dual-state shape.

**Approach D was deferred** — blocked on `funnelcake#234` server-side
dedup. Worth revisiting once that ships, possibly in combination with C.

## Outcome

- **Shipped:** Approach A in PR #4165 — closes #4144 / #4048. Lives in
  `mobile/lib/notifications/bloc/notification_feed_bloc.dart`,
  `mobile/lib/notifications/view/inbox_notifications_page.dart`,
  `mobile/lib/notifications/view/notifications_page.dart`, and
  `mobile/lib/notifications/view/notifications_view.dart`, with coverage
  in the matching test files under `mobile/test/notifications/`.
- **Follow-up:** issue #3596 (Delete dual notification system) tracks
  the Approach C migration — reactive
  `NotificationRepository.watchUnreadCount()` plus
  `NotificationBadgeCubit`, retiring
  `mobile/lib/providers/relay_notifications_provider.dart` and
  `mobile/lib/screens/notifications_screen.dart`.
