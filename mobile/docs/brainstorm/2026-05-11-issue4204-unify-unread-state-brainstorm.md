# Brainstorm: Unify unread state across badge, inbox list, and detail open (#4204)

Date: 2026-05-11

## Problem Statement

PR #4165 (commit `dd5e68ffd`, 2026-05-09) closed the inbox-open
badge-clear case by adding a one-shot `_relaySynced` cross-cache sync.
Three divergence vectors remain — verified to high confidence in this
turn's investigation: (A) per-row tap doesn't update the legacy
Riverpod cache that powers the badge, (B) real-time WebSocket
arrivals enter the Riverpod cache only (the BLoC's
`NotificationFeedRealtimeReceived` event has no production producers),
and (C) the 5-min auto-refresh timer can race mark-all writes.

#4204 is the *correctness* child of epic #4200. Sibling **#4208**
("refactor(notifications): remove dual notification system and finish
bloc cleanup") is the explicit tracker for the dual-system deletion,
sequenced LAST among notifications children ("Do not start until the
higher-priority correctness issues are mostly stable"). Therefore
#4204's PR should implement the single-source-of-truth architecture
but **defer legacy deletion to #4208**.

## Constraints

- **Engineering Standard in #4204**: "Fix the problem without adding
  new technical debt. If the touched path already has known audit or
  refactor debt, repay the relevant portion as part of the
  implementation instead of layering on a narrow patch." Linked debt:
  `#3596`, `#3590`. But #4208 (LAST execution item) holds the formal
  scope for the dual-system removal — #4204 repays *adjacent* debt
  (the BLoC's dead-code events, the page-level bridge cleanup) but
  not the full Riverpod-stack deletion.
- **Layered architecture** (`.claude/rules/architecture.md`):
  composition / caching / source-selection belongs in the repository.
- **BLoC-first** (`.claude/rules/state_management.md`); Riverpod is
  legacy.
- **No BLoC-to-BLoC dependencies** — coordinate via `BlocListener` or
  shared repository state.
- **Symmetric DM precedent**: `DmUnreadCountCubit`
  (`mobile/lib/blocs/dm/unread_count/dm_unread_count_cubit.dart`)
  subscribes to `dmRepository.watchUnreadAcceptedCount()`
  (`mobile/packages/dm_repository/lib/src/dm_repository.dart:1715-1722`).
  Wired at both app-shell scope (`main.dart:1645-1648`, for the
  bottom-nav badge) and inbox-page scope (`inbox_page.dart:56-58`,
  for the inbox segmented toggle). Notifications should mirror this
  dual-scope pattern.
- **Server-side limitation** at
  `relay_notifications_provider.dart:1063-1080` and tracked at
  `funnelcake#234`: server `unreadCount` reports one row per Kind 3
  republish per follower. Client-side derivation from the
  consolidated visible list is the only correct approach today.
- **DAO supports reactive unread**: `NotificationsDao.watchUnreadCount()`
  (`mobile/packages/db_client/lib/src/database/daos/notifications_dao.dart:102`)
  exists, but `upsertNotification` has zero production callers — the
  DAO is unfed. In-memory `BehaviorSubject` in the repository is the
  smaller blast radius; DAO backfill is an additive follow-up.
- **`notificationRepositoryProvider` is NOT `keepAlive: true`** — on
  auth flip / provider rebuild, the cubit's stream subscription
  becomes stale. Mitigate with `ValueKey(identityHashCode(repo))` on
  the BlocProvider, per
  `.claude/rules/state_management.md` ("Bridging Riverpod-provided
  dependencies into BlocProvider"). The repository constructor takes
  `userPubkey` as a `final` field, so converting the provider to
  `keepAlive: true` requires refactoring the repository to accept
  post-construction credential changes — out of scope here.
- **Verified by this turn's investigation**:
  - There are **three** parallel caches, not two
    (`relay_notifications_provider.dart`, `notification_feed_bloc.dart`,
    `notification_service_enhanced.dart`).
  - `NotificationFeedRealtimeReceived` and
    `NotificationFeedPushReceived` have zero production producers
    (verified by `grep -rn 'NotificationFeedRealtimeReceived' mobile/lib`).
  - `_onItemTapped` at `notification_feed_bloc.dart:255-283` does not
    touch Riverpod.
  - `NotificationsScreen` (`mobile/lib/screens/notifications_screen.dart`,
    765 lines) is dead code — zero references outside its own file.
  - `notification_settings_screen.dart:75` is an additional consumer
    of `relayNotificationsProvider.markAllAsRead()` — out of scope
    for #4204 but noted for #4208.

## Prior Art

- **`mobile/docs/brainstorm/2026-05-09-issue4144-notification-badge-desync-brainstorm.md`**.
  Prior brainstorm scoped to #4144 / #4048 (badge doesn't clear on
  inbox open). Documents four approaches; Approach A shipped as
  PR #4165. Approach C (repository-as-source-of-truth) was tracked
  in #3596 as the "right destination." This document supersedes the
  earlier 2026-05-11 draft at the same path that bundled deletion
  into #4204 (now correctly scoped to #4208 instead).
- **PR #4165 (commit `dd5e68ffd`)**. One-shot `_relaySynced`
  cross-cache sync. Centralized at
  `_InboxNotificationsScaffoldState.initState`
  (`mobile/lib/notifications/view/inbox_notifications_page.dart:85-95`)
  and mirrored in `NotificationsPage`.
- **PR #4034**. Added BLoC-side rollback on `markAllAsRead` failure
  (`notification_feed_bloc.dart:300-329`). The new repository surface
  must preserve this rollback semantic at the repo layer.
- **`DmUnreadCountCubit`** (`mobile/lib/blocs/dm/unread_count/dm_unread_count_cubit.dart`)
  + `DmRepository.watchUnreadAcceptedCount()`. The exact precedent.
- **#4208 (sibling, OPEN)**. "refactor(notifications): remove dual
  notification system and finish bloc cleanup." Last execution item
  under #4200. Scopes: remove dual-system behavior, finish BLoC-era
  cleanup, make failure/loading explicit and testable. Sibling debt
  links: `#3596`, `#3567`, `#3590`, `#3352`.
- **#4216 (post-#4165, CLOSED)**. "Inbox bottom-nav dot stays lit
  after clearing notifications when DMs are unread (no DM count
  surfaced anywhere)." Confirms the bottom-nav badge math is
  `dmCount + notifCount` at `vine_bottom_nav.dart:97-99`. NOT a
  notification bug; closed by adding `messageCount` to the inbox
  segmented toggle. Independent of #4204.
- **#4024 (CLOSED)**. Earlier investigation of mark-all-read
  reliability. Motivated PR #4034's rollback semantics. Resolved.

## Approaches Explored

### Approach A: Tactical bridge extension (extend PR #4165 to remaining callsites)

**Description:** Add a Riverpod-bridge call to
`NotificationFeedBloc._onItemTapped` (`notification_feed_bloc.dart:255-283`)
mirroring PR #4165's `_relaySynced` pattern: after the BLoC's
optimistic emit and `_notificationRepository.markAsRead`, fire
`relayNotificationsProvider.notifier.markAsRead(id)` via a
constructor-injected bridge. For WS realtime, dispatch
`NotificationFeedRealtimeReceived` to the bloc from
`notification_realtime_bridge_provider.dart` — but the bloc is
screen-scoped, so this requires a globally-accessible bloc reference
or a service indirection.

**Layers affected:** UI / page providers + BLoC constructor +
WebSocket bridge.

**Pros:**
- Smallest blast radius — ~3 files, no new architecture surface, no
  cubit.
- Mirrors a pattern reviewers already approved (PR #4165).
- Ships in <1 day.

**Cons:**
- Doubles down on bridge-per-callsite. Every future BLoC mutation
  must remember to bridge or the badge silently regresses.
- WS-into-bloc is awkward: the bloc is screen-scoped, so the bridge
  needs a `GlobalKey` / `NotificationFeedBlocLocator` singleton /
  service indirection — none of which exist in this codebase and all
  of which are anti-patterns.
- Revives `NotificationFeedRealtimeReceived` from dead code, but the
  handler at `notification_feed_bloc.dart:198-252` depends on
  enrichment + dedup logic that belongs in the repository anyway.
- Doesn't honor #4204's "repay relevant debt" engineering standard.
- Adds work for #4208 (more bridge code to unwind).

**Risks / Unknowns:**
- The 5-min auto-refresh timer continues to race the bridged writes
  (Repro C from /investigate).
- If the WS-into-bloc bridge isn't built, divergence B stays open.

**Complexity:** Low–Medium.

---

### Approach B: Reactive repository + thin badge cubit (architecture only, no deletion)

**Description:** Promote `NotificationRepository` to single source of
truth. Add a private `BehaviorSubject<NotificationFeedSnapshot>`,
expose `Stream<NotificationFeedSnapshot> watchSnapshot()` and
`Stream<int> watchUnreadCount()`. Route all writes (`refresh`,
`getNotifications`, `markAsRead`, `markAllAsRead`) through the
snapshot with PR #4034's rollback semantics moved to the repo layer.
Add `acceptRealtime(RelayNotification)` for the WS path. Create
`NotificationBadgeCubit` (mirrors `DmUnreadCountCubit` at ~30 lines).
Provide it at **both** app-shell scope (`main.dart:1645-1648`, for
the bottom-nav badge) and inbox-page scope
(`inbox_page.dart:47-58`, for the inbox segmented toggle), matching
the existing DM-cubit dual-scope pattern. Swap badge consumers
(`vine_bottom_nav.dart:98` and `inbox_view.dart:66`) from
`ref.watch(relayNotificationUnreadCountProvider)` to
`context.watch<NotificationBadgeCubit>().state`. Add a thin realtime
bridge that calls `notificationRepository.acceptRealtime(...)` from
`NotificationServiceEnhanced.instance.onNewNotification`. Delete the
now-unnecessary `_relaySynced` blocks in
`inbox_notifications_page.dart` (lines 70-95, 102-120) and
`notifications_page.dart`. Delete the dead-code
`NotificationFeedRealtimeReceived` / `NotificationFeedPushReceived`
events and handlers (their tests retire too). **Leave the legacy
Riverpod stack alive** — it becomes load-not-bearing (badge consumers
no longer read it); #4208 deletes it.

**Layers affected:** Repository (significant — adds reactive surface,
in-memory snapshot, realtime accept, moves rollback down) + BLoC
(new badge cubit + simplified `_onMarkAllRead`) + UI (two badge
consumer swaps + two page-level Riverpod-sync deletions + dead-event
deletion).

**Pros:**
- **Eliminates the divergence class**. Per-row tap, mark-all, WS
  realtime, future bulk actions all propagate through one stream to
  the badge. No bridge-per-callsite.
- Mirrors `DmUnreadCountCubit` + `dmRepository.watchUnreadAcceptedCount()`
  exactly. Inbox becomes architecturally consistent across DMs and
  notifications.
- Removes load-bearing dead code (`NotificationFeedRealtimeReceived`,
  `NotificationFeedPushReceived`) — repays adjacent debt without
  stepping on #4208's deletion mandate.
- Scope matches #4204's first-execution-item sequencing. #4208 can
  cleanly delete the legacy stack later because nothing reads it
  anymore.
- Honors `.claude/rules/architecture.md` ("Fallback and composition
  logic belongs in the repository").

**Cons:**
- Medium PR size: ~8 files modified, ~3 new files.
- Leaves zombie legacy code
  (`mobile/lib/providers/relay_notifications_provider.dart`,
  `mobile/lib/providers/notification_realtime_bridge_provider.dart`,
  `mobile/lib/screens/notifications_screen.dart`) until #4208. Minor
  interim duplication: WS events feed both the new repository AND
  the unused legacy Riverpod cache. No functional impact since
  nothing reads the legacy cache after the swap.
- Auth-flip handling: needs `ValueKey(identityHashCode(repo))` on
  the new BlocProviders. Pattern already documented and used in
  `pooled_video_feed_item_repo_swap_test.dart`.

**Risks / Unknowns:**
- Stream shape: single `Stream<NotificationFeedSnapshot>` vs. separate
  `watchNotifications()` + `watchUnreadCount()`. Defer to /plan;
  default to the `DmRepository`-style separate streams.
- Repository in-memory cache vs. Drift-DAO-backed stream. DAO is
  unfed (no `upsertNotification` callers in production); in-memory
  is simpler. Defer to /plan; default to in-memory `BehaviorSubject`.
- Realtime accept entry: `acceptRealtime(RelayNotification)` (raw)
  vs. `acceptRealtime(NotificationItem)` (enriched). Raw matches
  existing `enrichOne` + dedup logic. Defer to /plan; default to raw.

**Complexity:** Medium.

---

### Approach C: Architecture + legacy deletion (bundle #4208 into #4204)

**Description:** Same as Approach B, plus delete
`mobile/lib/providers/relay_notifications_provider.dart`,
`mobile/lib/providers/notification_realtime_bridge_provider.dart`,
`mobile/lib/screens/notifications_screen.dart`,
`mobile/lib/widgets/notification_list_item.dart` (legacy variant per
#3567), `mobile/lib/services/notification_model_converter.dart`,
and matching tests. One PR closes #4204, #4208, #3596, #3567.

**Layers affected:** Same as B + deletions.

**Pros:**
- Eliminates dual-stack debt in one shot. No zombie code.
- Closes four issues in one PR.

**Cons:**
- **Conflicts with #4208's explicit "Last execution item" sequencing**
  ("Do not start until the higher-priority correctness issues are
  mostly stable"). #4208 has its own DRI flow under the epic; #4204
  stepping on its scope takes work from a sibling.
- ~3k LOC net negative; significant reviewer load.
- If `#4205` (routing) / `#4206` (row styling) / `#4207` (push) land
  in parallel, the deletion creates merge conflicts. Sequencing
  #4208 last is exactly the mitigation.
- Riskier rollback: reverting unwinds architecture AND deletion.
- The earlier 2026-05-11 draft of this brainstorm at this path
  recommended this approach. After verifying #4208's existence and
  its "Last execution item" sequencing in /investigate, the scope
  split is the cleaner read.

**Risks / Unknowns:**
- Same as B, plus rollback complexity from the bundled deletion.

**Complexity:** High.

---

### Approach D: Server-driven badge

**Description:** As deferred in the prior brainstorm. Drop
client-side derivation; use server's `unreadCount`.

**Complexity:** Blocked on `funnelcake#234`.

## Recommendation

**Approach B — Reactive repository + thin badge cubit, architecture
only, no legacy deletion.**

Why B over A: bridge-per-callsite is fragile (PR #4165 already proved
this — #4204 exists because the pattern doesn't generalize). The
WS-into-bloc bridge specifically requires either a global bloc
locator (anti-pattern) or a service indirection (new architecture
surface that ends up being a poor man's version of Approach B). A
also doesn't honor #4204's "repay relevant debt" engineering
standard.

Why B over C: #4208 *exists* as a separate issue specifically for
the dual-system deletion, sequenced LAST. Bundling deletion into
#4204 violates that sequencing and bloats the PR. Approach B leaves
the legacy stack as zombie code with no behavioral impact until
#4208 cleans it up. Sequencing #4208 last is the explicit mitigation
against merge conflicts with siblings #4205 / #4206 / #4207.

Why B over D: blocked on backend.

The legacy Riverpod stack becomes load-not-bearing after Approach B
ships:
- `relay_notifications_provider.dart` — fed by the existing WS
  bridge + 5-min auto-refresh timer, but no consumer reads
  `relayNotificationUnreadCountProvider` anymore. Wasted CPU/memory
  but no correctness impact.
- `notification_realtime_bridge_provider.dart` — keeps inserting
  into the unused Riverpod cache. Duplicates work the new bridge
  does. Removed by #4208.
- `notifications_screen.dart` — already dead code (zero non-self
  references). Removed by #4208 + #3596.

Adjacent debt repaid in #4204's PR:
- `NotificationFeedRealtimeReceived` and `NotificationFeedPushReceived`
  events + handlers (dead code).
- `_relaySynced` page-level Riverpod sync (no longer needed).
- PR #4034's rollback semantics relocated to the repository layer
  where it belongs.

Adjacent debt NOT in scope (handled by #4208):
- Legacy Riverpod provider deletion.
- Legacy `notifications_screen.dart` deletion.
- Legacy `notification_list_item.dart` deletion (#3567).
- `funnelcake_api_client` error-handling consistency (#3590) — a
  separate client-layer PR can address it once #4208 simplifies the
  repository surface.
- 5-min auto-refresh timer retirement (#3352).

## Open Questions for /plan

- [ ] Reactive surface shape: `Stream<NotificationFeedSnapshot>`
      single stream vs. `Stream<List<NotificationItem>>` +
      `Stream<int>` separate streams. Default: match `DmRepository`'s
      separate-streams shape.
- [ ] Realtime entry shape:
      `acceptRealtime(RelayNotification raw)` vs.
      `acceptRealtime(NotificationItem enriched)`. Default: raw, to
      reuse `_enrichAndGroup`.
- [ ] Auth-flip strategy:
      `ValueKey(identityHashCode(repo))` on the BlocProvider (small,
      well-precedented) vs. converting
      `notificationRepositoryProvider` to `keepAlive: true` (needs
      repository refactor for credential mutability). Default:
      `ValueKey`.
- [ ] `NotificationBadgeCubit` provider placement: confirm both
      app-shell (`main.dart:1645`) and inbox-page
      (`inbox_page.dart:56`) sites are needed, matching the existing
      `DmUnreadCountCubit` dual-scope pattern.
- [ ] Test fixture migration: how much of
      `mobile/test/providers/relay_notifications_provider_test.dart`
      (2,331 lines) gets ported to repository tests vs. left in
      place for #4208 to delete. Default: leave in place; #4208
      deletes alongside the provider.
- [ ] Realtime bridge ownership: a new `@Riverpod(keepAlive: true)`
      service (mirrors `notification_realtime_bridge_provider`
      shape, just pointing at the repository) vs. a long-lived
      subscription inside `NotificationBadgeCubit`'s lifecycle.
      Default: separate service for separation of concerns.

## Prerequisites

- None blocking. All required infrastructure (Drift schema, DM
  precedent, `notification_repository` package, `notificationRepositoryProvider`
  Riverpod bridge) already exists.
- Recommended: confirm with `@Chardot` (epic DRI) that the scope
  split (architecture in #4204, deletion in #4208) matches their
  intent. Sync or async per epic coordination note.

## Next Step

`/plan https://github.com/divinevideo/divine-mobile/issues/4204` —
produce the bottom-up implementation spec for Approach B, including
the repository diff, the cubit shape, the dual-scope provider
placement, the badge consumer swaps, and the test plan.
