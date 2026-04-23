# Brainstorm: Notifications persistence & stale-feed behaviour (#3151)

Date: 2026-04-23 (revised after backend audit)

## Problem Statement

Users on production (build `1.0.8+2480`) see the same notifications
resurface on every open with seemingly-updated timestamps, the unread
badge doesn't deflate, and follower counts on the profile disagree with
the count of follow-notifications in the feed. An audit of the
`divine-funnelcake`, `divine-push-service`, and `divine-relay-sync`
repos shows the dominant cause is **server-side, not mobile-side**:
funnelcake's notifications materialized view fans every Kind 3 contact-
list republish into N new rows (one per `p` tag) with fresh
`source_created_at`, server-side dedupe keys on `source_event_id` which
changes per republish, and the unread count is inflated by the same
duplicates. Funnelcake
[#234](https://github.com/divinevideo/divine-funnelcake/issues/234) and
[#204](https://github.com/divinevideo/divine-funnelcake/issues/204)
track this and are both OPEN with no assignee, no comments, and no
in-flight PR. The cursor-format bug in the mobile legacy client that
the first pass of this brainstorm identified as the "primary root
cause" is a real API-contract violation, but ClickHouse's overflow
handling almost certainly saturates the 13-digit input to the 2106
maximum — equivalent to "give me the newest page" — making the fix
hygiene, not a hotfix. Revised brainstorm question: **what, if
anything, should the mobile team ship for #3151?**

## Constraints

- Divine is BLoC-first for new work; Riverpod is legacy. Notifications
  still runs on Riverpod in production (`InboxView` embeds
  `NotificationsScreen`, not the newer `NotificationsPage`).
- S2 severity — repeat Zendesk reports (#3151, #3272, closed-dup #3196).
  Ship speed matters only if a shippable mobile fix exists.
- Layered architecture (UI → BLoC → Repository → Client). The visible
  bug surface is in Client + BLoC; the authoritative fix is on the
  server.
- Cannot change the dark-mode-only / VineTheme / divine_ui surface.
- Server contract documents `before` as Unix seconds
  (`docs/FUNNELCAKE_API.md:940`).
- The server fixes for Kind 3 dedup (funnelcake #234, #204) are both
  OPEN with no assignee and no comments. There is no ETA. Any mobile
  mitigation must either (a) remain useful after the server fix ships,
  or (b) be cheap enough to revert.

## Prior Art

### Mobile

- **PR #3009 (merged 2026-04-13)** — Fixed the cursor-format bug on
  `FunnelcakeApiClient.notificationsUri` (BLoC path). Added a test
  asserting the default cursor is Unix seconds (< 10¹⁰). Never landed
  on the legacy `RelayNotificationApiService` path.
- **PR #2822, #2378** — earlier patches on the legacy path. None
  addressed the Kind 3 republish root cause.
- **PR #2820** — kicked off the BLoC migration; left the legacy path
  running behind the `inbox_view.dart:89-94` "until the BLoC migration
  matches production" TODO.
- **`_consolidateFollowNotifications`** in
  `mobile/lib/providers/relay_notifications_provider.dart:960-1014` —
  already dedupes follow notifications by `sourcePubkey` and keeps
  the earliest timestamp. Cross-batch variant at lines 1019-1039.
  `_minVisibleItems = 10` keeps auto-paging until the consolidated
  count reaches 10. This is the existing client-side Kind 3 mitigation.

### Server (from the audit)

- **funnelcake `crates/api/src/router.rs:687` /
  `crates/api/src/handlers.rs:4600`** — `GET /api/users/{pubkey}/notifications`
  handler. `before` is passed verbatim as an `i64` into `toDateTime(?)`
  in ClickHouse (`crates/clickhouse/src/client.rs:5594`). Documented as
  Unix seconds in `docs/FUNNELCAKE_API.md:940`.
- **funnelcake `database/migrations/000016_add_notifications_system.up.sql:95-108`**
  — `notifications_ptag_mv` materialized view. Fans every Kind 3 event
  into N notification rows, `source_created_at = e.created_at`,
  `created_at = now()`. No Kind 3 diffing.
- **funnelcake `crates/clickhouse/src/client.rs:5533-5548`** — inner
  dedupe CTE: `GROUP BY source_event_id`. Each Kind 3 republish is a
  new `source_event_id`, so server dedupe does not collapse them.
- **funnelcake `crates/clickhouse/src/client.rs:5632`** —
  `get_unread_notification_count` takes only pubkey; no type filter,
  no dedupe of follow republishes. Inflated badge.
- **funnelcake
  [#234](https://github.com/divinevideo/divine-funnelcake/issues/234)
  (OPEN, 2026-04-06)** — "fix: deduplicate follow notifications from
  Kind 3 republishing". No comments, no assignee, no in-flight PR.
- **funnelcake
  [#204](https://github.com/divinevideo/divine-funnelcake/issues/204)
  (OPEN, 2026-04-02)** — "fix(notifications): follow notifications
  lack contact list diffing — duplicates and wrong dates". Production
  data cited in body: ~396 duplicate follow notifications per target
  from a single source.
- **funnelcake
  `docs/superpowers/specs/2026-04-07-notification-dedupe-design.md`**
  — planned server-side dedupe design. Phase 1 is reactions only;
  follows explicitly out of scope.
- **divine-push-service `src/event_handler.rs:398-403`** — Kind 3 is
  an explicit no-op ("follow notifications not yet implemented").
  Push service is NOT a contributor to repeated follow notifications.
- **divine-relay-sync `src/sync/engine.rs:24-27`** —
  `DEFAULT_EXCLUDE_KINDS = &[1, 5]`; Kind 3 is NOT excluded. A
  `--fresh` sync run that includes Kind 3 republishes historical
  contact lists to the Divine relay, compounding #234's effect on
  funnelcake's materialization. Nostr signatures are immutable, so
  relay-sync cannot create fresh timestamps on its own — it is a
  secondary amplifier, not an independent root cause.
- **Lesson precedent** (`tasks/lessons.md`, "Package extractions can
  silently regress sibling fixes") — adjacent pattern. This brainstorm
  adds two new lessons (see Open Questions → Lessons).

## Backend Reality Check

**The cursor bug is probably harmless in prod.** ClickHouse's `DateTime`
is a 32-bit Unix-seconds type with max 2106-02-07. A 13-digit ms
cursor is ~55,700 years in the future. The outcome depends on the
`date_time_overflow_behavior` server setting, which is not pinned in
the funnelcake repo:

- **Saturate to 2106 (most common default)** — `source_created_at <
  2106` is trivially true for every row → first page returns the
  newest 50, which is the correct behavior for an initial fetch.
  `loadMore` uses `_nextCursor` from the server (already Unix
  seconds), so pagination works.
- **Throw** — the API returns 500, and the mobile legacy service's
  catch-all returns an empty `NotificationsResponse`. Users would see
  "no notifications" — which does not match the reported symptom.
- **Wrap** — edge case; unlikely to match the symptom either.

Given users are seeing notifications (they report "same notifications
for a long time"), the server is not throwing. The cursor bug is
therefore a contract violation worth fixing for hygiene and latent-risk
reasons, not the cause of the user complaint.

**Kind 3 republish is the dominant cause.** Kind 3 is replaceable in
Nostr; every follow/unfollow republishes the entire contact list with
a new `event_id` and new `created_at`. Funnelcake's MV emits one
notification row per `p` tag per republish; server dedupe keys on
`source_event_id` which differs per republish; mark-as-read on
yesterday's republish does not cover tomorrow's (different
`source_event_id`); and `unread_count` is the raw row count, inflating
the badge. All of this is documented in #234 and #204.

**Mobile's existing consolidation is correct but incomplete.**
`_consolidateFollowNotifications` already keeps the earliest follow
per `sourcePubkey` (correct). However:

- The **badge** reads `state.unreadCount` (server's inflated raw
  count), not a count derived from the consolidated list.
- The **timestamp shown** is the earliest of *what has been fetched*,
  not the earliest *ever* — page 1 may only contain recent republish
  timestamps until `_minVisibleItems = 10` triggers more pages.

**Push service and relay-sync are not independent causes.** Push
service is a Kind 3 no-op. Relay-sync can amplify #234 when a
`--fresh` run includes Kind 3, but the source events it copies retain
their original `created_at` (Nostr signatures).

**Source asymmetry is a separate residual issue.** The user's log
shows `Followers: API=9, relays=7, indexers=7, merged=9`. Profile
count unions all sources. The notifications feed sees only Kind 3
events indexed by the Divine relay. If 2 of the 9 followers are on
relays the Divine relay has not synced, the notifications feed will
show 7 — independent of #234.

## Approaches Explored

### Approach R1 — Treat #3151 as blocked on funnelcake #234 + #204

**Description.** Declare #3151 a server-side bug. Leave the mobile as
is. Link #3151 → funnelcake #234 and #204. Post a comment on #3151 and
#3272 summarizing the backend finding so the next triager does not
repeat the investigation.

**Layers affected.** None (mobile).

**Pros.**
- Correct — the root cause is server-side. No mobile churn.
- Zero regression risk.
- Sets the right expectation for the team and reporter.
- Leaves the existing `_consolidateFollowNotifications` mitigation as
  the best the mobile can currently do.

**Cons.**
- Users keep seeing the symptom until #234 ships. No ETA.
- The cursor-format contract violation remains on the legacy path.
  Latent risk if ClickHouse's overflow mode is ever changed to throw.
- Does not address the source-asymmetry residual (9 vs 7).

**Risks / Unknowns.**
- Server-side fix timeline.

**Complexity.** Trivial.

---

### Approach R2 — Ship cursor fix as independent hygiene, keep #3151 blocked on server

**Description.** Apply PR #3009's cursor fix to
`mobile/lib/services/relay_notification_api_service.dart:219`:
`before ?? (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString()`.
Add a regression test in
`mobile/test/services/relay_notification_api_service_test.dart`
asserting the default cursor is `< 10¹⁰` and `> 1.7×10⁹`. Title:
`chore(notifications): match PR #3009 cursor format on legacy API
service`. Do NOT claim it fixes #3151 — file it as an independent
hygiene PR with a link to the "sibling-check" lesson. Leave #3151
blocked on funnelcake #234.

**Layers affected.** Client only.

**Pros.**
- Restores API-contract compliance on the legacy path.
- Protects against the "ClickHouse overflow mode changes to throw"
  latent risk.
- Small, safe, reviewable; mirrors PR #3009 exactly.
- Creates the natural hook for the new `tasks/lessons.md` entry.

**Cons.**
- Gives the user no relief from the actual complaint.
- Tempting to mislabel as "fixes #3151" — must be explicit in the PR
  body that it does not.

**Risks / Unknowns.** Very low. `_nextCursor` from the server is
already seconds-shaped; no callers rely on ms.

**Complexity.** Low.

---

### Approach R3 — Mobile mitigations while #234 is pending

**Description.** On top of R2, add two scoped changes inside the
legacy Riverpod path (no BLoC cutover):

1. **Consolidated badge count.** Add a new Riverpod provider
   `consolidatedUnreadCountProvider` that counts unique unread
   *target events* (likes/comments/reposts/mentions) plus unique
   unread *follower pubkeys* (follows) from
   `relayNotificationsProvider.state.notifications`, rather than
   returning `state.unreadCount`. Rewire `vine_bottom_nav.dart:94`
   and `inbox_view.dart:63` to read the consolidated count when the
   state is loaded and fall back to the server count while loading.
2. **Earliest-seen timestamp for follows.** Existing consolidation
   already retains the earliest; audit the render path in
   `notifications_screen.dart` + `notification_list_item.dart` to
   confirm that is the timestamp displayed. Optionally, suppress the
   "Xm ago" suffix for follow notifications to sidestep the
   "fresh timestamp on an old follow" illusion entirely.

**Layers affected.** Provider (new derived provider) + UI (badge
consumers). No repository / client changes beyond R2.

**Pros.**
- Addresses the "badge count doesn't match follower count" pole of
  the complaint.
- Sidesteps the "fresh timestamps on old follows" illusion.
- Survives the server fix — consolidated count remains correct after
  #234 lands; it just converges with the server count.
- Scoped change, ~50 lines, no migration risk.

**Cons.**
- Becomes dead code when server #234 ships — the consolidated count
  equals the server count.
- Cold-start before the feed has loaded still shows the server count
  briefly.
- Does not help other platforms (web, if any).

**Risks / Unknowns.**
- Cold-start UX — fallback to server count when state is loading is
  the obvious choice, but the symptom briefly flashes.
- Future BLoC-path badge source would need the same treatment —
  consider shipping parity in `NotificationFeedBloc` state too.

**Complexity.** Medium.

---

### Approach R4 — R2 + R3 + push funnelcake team on #234

**Description.** All of R2 and R3, plus active coordination with the
funnelcake team:

1. Comment on funnelcake #234 (and #204) with mobile impact evidence
   (Zendesk #1040, #1068; #3151; #3272). Ask for an ETA.
2. If ETA ≤ 2 weeks — ship R2 (hygiene) and skip R3 as soon-to-be-dead
   code.
3. If ETA > 2 weeks or indefinite — ship R2 and R3, in separate PRs.
4. When #234 ships — remove R3's dead code in a small follow-up PR;
   close #3151.

**Layers affected.** Same as R2 + R3 (conditional on ETA).

**Pros.**
- Makes the server-side dependency explicit.
- Sizes mobile work to server reality rather than to guesses.
- Converts the user complaint into forcing pressure on #234.

**Cons.**
- Requires human coordination outside the mobile PR flow.
- Slightly more ceremony than R2 alone.

**Risks / Unknowns.**
- Funnelcake team's availability and priorities.

**Complexity.** Low coordination; medium if R3 ships.

## Comparison

|                                       | R1       | R2         | R3            | R4             |
|---------------------------------------|----------|------------|---------------|----------------|
| Fixes primary user complaint          | No       | No         | Partial       | Partial        |
| Addresses API contract violation      | No       | Yes        | Yes           | Yes            |
| Survives server fix                   | Yes      | Yes        | Partial       | Yes, conditional |
| Regression risk                       | None     | Very low   | Low           | Low            |
| Ship speed                            | Instant  | Hours      | Days          | Days+          |
| Addresses source asymmetry (9 vs 7)   | No       | No         | No            | No             |

## Recommendation

**Approach R4.**

- R1 alone is correct but leaves users stuck and keeps the legacy
  contract violation latent.
- R2 alone is the right independent hygiene PR regardless of #234's
  timeline.
- R3 is worth shipping only if the server fix is far off; if the
  funnelcake team commits to #234 this sprint, R3 becomes dead code
  before it delivers value.
- R4 asks the right question first (server ETA), then sizes mobile
  scope accordingly.

Explicitly rejected: **Inbox → BLoC cutover for this ticket.** The
BLoC path hits the same server API with the same #234 bug; cutting
over solves nothing for this complaint and adds parity-audit risk.

## Open Questions

### For the funnelcake team

- [ ] ETA on #234 (Kind 3 follow dedupe at query time)?
- [ ] ETA on #204 (contact list diffing at ingest)?
- [ ] Prod ClickHouse `date_time_overflow_behavior` setting —
      saturate, throw, or wrap? Determines whether R2 is pure
      hygiene or load-bearing.
- [ ] Is the dedup spec at
      `docs/superpowers/specs/2026-04-07-notification-dedupe-design.md`
      on the roadmap? It explicitly defers follows to out-of-scope
      in phase 1.

### For mobile (if R3 ships)

- [ ] Ship parity consolidated-count in `NotificationFeedBloc` state
      now, so a future Inbox → BLoC cutover inherits it for free?
- [ ] Source asymmetry (profile 9 vs indexed 7) — separate follow-up
      after R2+R3, or investigate inline?

### Lessons (add both to `tasks/lessons.md` as part of R2 PR)

- [ ] **Check the server before committing to a mobile fix.** The
      original investigation identified a client-side cursor bug as
      the root cause; a 20-minute audit of the funnelcake repo
      showed ClickHouse almost certainly saturates the bad value
      away, reducing the fix from hotfix to hygiene. When a user
      complaint involves a server-served feed, audit the server
      repo before committing the mobile team to a scope.
- [ ] **In Nostr notification feeds, suspect Kind 3 republishing
      first when notifications "repeat" with fresh timestamps.**
      Kind 3 is replaceable; every full contact-list republish has
      a new `event_id` and new `created_at`; materialized views
      that key on `event_id` cannot dedupe them. The server
      generates N fresh rows per republish for a user with N
      follows. Confirmed precedent: funnelcake #234, #204.

## Prerequisites

- For R2: none.
- For R3: the funnelcake #234 ETA decision from the coordination
  step in R4.

## Next Step

1. Post a comment on funnelcake #234 and #204 with the mobile impact
   summary (link #3151, #3272, Zendesk 1040/1068). Ask for timeline.
2. Post a comment on #3151 and #3272 with the backend-reality
   summary, linking to funnelcake #234 and #204 as the authoritative
   fix location. Mark #3151 as blocked-by #234.
3. Regardless of response: open `/plan` for R2 (cursor hygiene PR),
   titled `chore(notifications): match PR #3009 cursor format on
   legacy API service`. Do not claim it fixes #3151. Include the two
   new `tasks/lessons.md` entries.
4. If funnelcake's #234 ETA is > 2 weeks or indefinite: open a
   second mobile plan for R3 as a separate PR
   (`fix(notifications): use consolidated count for badge to
   mitigate funnelcake #234`).
5. When #234 ships: small follow-up PR to remove R3 and close #3151.
