# Brainstorm: Delete dual notification system (#3596)

Date: 2026-05-12

## Problem Statement

Issue #3596 asked for deletion of the dual (legacy Riverpod + new BLoC)
notification system. Since the issue was filed, four sibling PRs have
landed that retire most of the dual-system surface (#4247 unified the
unread state, #4271 added typed exceptions, #4276 made the legacy
provider's refresh event-driven, #4277 deleted the dead screen +
widget). What remains is a one-call-site migration in
`notification_settings_screen.dart`, plus deletion of the legacy
provider + converter + 5 test files. Once those are gone, the BLoC-
based `lib/notifications/` feature is the only notifications stack.

## Constraints

- **Repo conventions** (from `.claude/rules/agent_workflow.md`): every
  PR targets `main`; **no stacked PRs**; rebase onto fresh `origin/main`
  before push.
- **Architecture** (`.claude/rules/architecture.md`,
  `.claude/rules/state_management.md`): Riverpod is legacy; new code
  uses BLoC. `notificationRepositoryProvider` returns `null` until
  `ProfileRepository` is ready — the settings screen has to handle
  that.
- **#4208 sequencing**: "Last execution item under notifications. Do
  not start until unread / routing / push correctness are stable
  enough." Applies to the *BLoC path*; the legacy-deletion scope is
  orthogonal — it does not modify any `lib/notifications/...` file
  that #4205 / #4206 / #4207 are working on.
- **No new technical debt** (#4208 engineering standard): the
  migration must not introduce TODOs, ignore-lints, or partial
  states.

## Prior Art

- PR #4247 (MERGED) — built `NotificationRepository.{watchSnapshot,
  watchUnreadCount, markAllAsRead, markAsRead, refresh,
  acceptRealtime}` and `NotificationBadgeCubit`. Replacement surfaces
  are live.
- PR #4277 (MERGED today, by realmeylisdev) — deleted
  `screens/notifications_screen.dart` (799 lines) +
  `widgets/notification_list_item.dart` (277 lines) + 4 screen-level
  tests + the stale `_MockRelayNotifications` plumbing from
  `inbox_page_test.dart` (cleaner than the PR body advertised). Closed
  #3567.
- PR #4276 (MERGED today, by realmeylisdev) — replaced polling timers
  with event-driven signals (#3352). Site B (the 5-min Timer in
  `relay_notifications_provider.dart`) was kept intact — left to be
  deleted along with the file in this PR. Added a new test file
  `test/providers/relay_notifications_refresh_triggers_test.dart` (233
  lines) that also joins the deletion set.
- PR #4271 (MERGED today, by realmeylisdev) — typed exceptions in the
  notification API (#3590). Touched only the new repository path; no
  overlap.
- Brainstorms:
  `2026-05-09-issue4144-notification-badge-desync-brainstorm.md`
  (Approach C — promote `watchUnreadCount` to a stream, shipped via
  #4247) and
  `2026-05-11-issue4204-unify-unread-state-brainstorm.md` (sequencing
  rationale that deferred deletion to #4208; #4277's body confirmed
  this PR closes the deletion half).

## Approaches Explored

### Approach A: Bundled deletion (one PR)

**Description:** Branch off fresh `origin/main` and ship one PR
containing: (1) migration of `notification_settings_screen.dart` from
`relayNotificationsProvider.notifier.markAllAsRead()` to
`NotificationRepository.markAllAsRead()` via
`ref.watch(notificationRepositoryProvider)`; (2) deletion of
`relay_notifications_provider.dart` + `.g.dart` +
`notification_model_converter.dart` + their 5 test files; (3) a new
`notification_settings_screen_test.dart` covering success / failure /
disabled paths; (4) one stale-doc-comment fix in
`notification_realtime_bridge.dart` that references the deleted
converter; (5) a new ARB key
`notificationSettingsMarkAllAsReadFailed` for the failure snackbar.

**Layers affected:** Riverpod legacy (delete), Settings UI (migrate),
Tests (delete + add).

**Pros:**
- Single atomic review.
- Smallest blast radius once #4277 is in — only
  `notification_settings_screen.dart` changes in production code
  beyond the deletions.
- Matches `agent_workflow.md`'s "combine truly dependent work into
  one PR" guidance.

**Cons:**
- None on-balance.

**Complexity:** Low.

### Approach B: Split — settings migration first, deletion second

Two PRs in sequence. Rejected — inflates the operational cost for no
review benefit. The migration is one line + one import + a try/catch
around the call; reviewers see the full picture faster in one diff
than two PRs in sequence.

### Approach C: Wait for more upstream cleanup

Defer until the rest of #4208's children (routing #4205, row styling
#4206, push #4207) ship. Rejected — those touch the BLoC path; nothing
they change conflicts with the legacy-file deletion in this PR. There
is no reason to block.

## Recommendation

**Approach A.** Confidence **0.97**.

### Settings-screen failure-snackbar UX

Transient `SnackBar(backgroundColor: VineTheme.error, ...)`. Matches
the failure-snackbar pattern in `blossom_settings_screen.dart`
(`backgroundColor: VineTheme.error` on three failure sites) and in
nostr-settings flows. No persistent alert.

### New ARB key

`notificationSettingsMarkAllAsReadFailed` = `"Failed to mark all as
read"`. Style matches existing keys
`relaySettingsFailedToRemoveRelay`, `relaySettingsFailedToAddRelay` —
short, no `{error}` placeholder (server cause isn't meaningful to the
user). The success-side key `notificationSettingsAllMarkedAsRead`
stays unchanged.

### Settings-screen null handling

Render the "Mark all as read" action card with `onTap: null` while
`notificationRepositoryProvider` returns null (Material's built-in
disabled affordance). Matches other action-card patterns in
`settings_screen.dart`.

### Test fixture

Inline `class _MockNotificationRepository extends Mock implements
NotificationRepository {}` (mocktail). Identical pattern already used
in 4 existing test files:
`test/blocs/notifications/badge/notification_badge_cubit_test.dart`,
`test/notifications/view/inbox_notifications_page_test.dart`,
`test/notifications/view/notifications_page_test.dart`,
`test/notifications/services/notification_realtime_bridge_test.dart`.

### Behaviour delta acknowledged

`RelayNotifications.markAllAsRead()` silently swallows server errors;
`NotificationRepository.markAllAsRead()` rolls back the snapshot and
rethrows. The new behaviour is strictly safer — the legacy "always
green snackbar" misleadingly confirmed writes that didn't reach the
server. The settings screen's new try/catch handles the throw.

## Open Questions for /plan

None blocking. Two follow-up items deliberately deferred (see below).

## Prerequisites

- [x] PR #4277 merged (removes the dead `notifications_screen.dart`).
- [x] PR #4276 merged (kept Site B intact for this PR to delete).
- [x] PR #4271 merged (no file overlap; included here for context).

## Out-of-scope (file as follow-ups to #4208 after this PR ships)

1. `notification_settings_screen.dart`'s 4 unpersisted local flags
   (`_systemEnabled`, `_pushNotificationsEnabled`, `_soundEnabled`,
   `_vibrationEnabled`) — flipping their Switch widgets does nothing
   across app restarts. UI lie.
2. Audit whether per-type toggles (likes/comments/follows/mentions/
   reposts) actually gate notification ingestion or are decorative.

## Implementation commit order (5 commits)

1. `docs(notifications): add brainstorm for #3596 deletion` — this
   file.
2. `feat(l10n): add notificationSettingsMarkAllAsReadFailed` — ARB
   entry + `flutter gen-l10n` regen.
3. `refactor(notifications): migrate settings screen to NotificationRepository` —
   swap import; try/catch with success+failure snackbars; disable
   action card when repo is null; update the stale doc comment in
   `notification_realtime_bridge.dart`.
4. `test(notifications): cover settings-screen mark-all-as-read paths` —
   new `notification_settings_screen_test.dart` with success / failure
   / disabled scenarios.
5. `refactor(notifications): delete legacy Riverpod notifications stack` —
   delete 8 files (provider 1,092 + .g.dart 439 + converter 224 + 5
   test files 3,295 = 5,050 lines).

Net change: **≈ −4,896 LOC**.

## Verification (from `mobile/`)

```
dart format lib test
flutter analyze lib test integration_test
dart run build_runner build --delete-conflicting-outputs
flutter test test/notifications/ test/screens/ test/blocs/notifications/ test/router/
flutter test test/screens/inbox/ test/screens/notification_settings_screen_test.dart
```

## Manual test plan

- iOS: Settings → Notifications → "Mark All as Read" → green success
  snackbar; badge clears.
- iOS airplane mode: tap "Mark All as Read" → red `VineTheme.error`
  snackbar with "Failed to mark all as read".
- Android: same two paths.
- Account switch: sign out → sign in fast → Settings → Notifications.
  Action card briefly disabled until repo wakes up; no crash.

## Next Step

Implement the 5 commits above against
`task/3596-delete-dual-notification-system` branched from
`origin/main`. Closes #3596; advances epic #4208.
