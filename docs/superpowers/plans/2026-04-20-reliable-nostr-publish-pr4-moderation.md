# Reliable Nostr Publish — PR 4: Mutes, blocklists, reports

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Depends on:** PR 1 merged.

**Goal:** Make moderation-state publishes durable. A mute/block/report that fails silently leaves the user thinking a harmful pubkey is muted when it isn't — a safety bug, not a cosmetic one.

**Architecture:** Three independent services, each publishing a different kind:
- `mute_service.dart:530` — kind 10000 (NIP-51 mute list — replaceable).
- `content_blocklist_service.dart:240` — kind 30000 (addressable block list — d-tagged).
- `content_reporting_service.dart:179` — kind 1984 (NIP-56 report) with `targetRelays` specified (sends to the moderation relay).

All three migrate to `publishEventWithRetry`. For replaceable/addressable kinds, `NostrClient.publishEventAwaitOk` already caches on success only — we preserve that.

---

## File Structure

### Modified files

- `mobile/lib/services/mute_service.dart:530`
- `mobile/lib/services/content_blocklist_service.dart:240`
- `mobile/lib/services/content_reporting_service.dart:179`
- BLoCs/Cubits owning each flow (locate via grep).
- UI: `MuteUserBottomSheet`, `ReportDialog`, blocklist manager screen — show feedback.

### Created tests

- `mobile/test/unit/services/mute_service_reliability_test.dart`
- `mobile/test/unit/services/content_blocklist_service_reliability_test.dart`
- `mobile/test/unit/services/content_reporting_service_reliability_test.dart`

---

## Chunk 1: Mute service

### Task 1.1: Migrate `publishMuteList`

**Background:** Kind 10000 is a replaceable list event. Users toggle mute via a bottom sheet. Current flow: add/remove a pubkey locally, then publish. If publish fails, local list diverges from what any relay has — on next device sign-in, the user sees the unmuted list because no relay ever stored the new version.

- [ ] **Step 1: Write failing test**

```dart
// Covers:
// 1. Toggle mute → publish succeeds → MuteState.mutedPubkeys updated.
// 2. Toggle mute → publish fails transient → local list rolled back; feedback surfaces retryable.
// 3. Toggle mute → publish permanent reject → local list rolled back; feedback surfaces reason.
```

- [ ] **Step 2: Migrate**

```dart
// Compute NEW mute list locally.
final outcome = await _nostrService.publishEventWithRetry(event);
final feedback = PublishResultMapper.map(outcome);

if (outcome.acceptedByAny) {
  _mutedPubkeys = newMutedPubkeys; // commit to memory state only after relay ack
  _persistLocal();
  return MuteResult.success(outcome: outcome, feedback: feedback);
}
return MuteResult.failure(outcome: outcome, feedback: feedback);
```

**Key contract change:** do not update the in-memory mute set until `outcome.acceptedByAny`. The current code optimistically updates then publishes — that's the silent-divergence bug.

- [ ] **Step 3: BLoC/Cubit wiring**

`MuteBloc` state gains `status` and `feedback`. UI shows a snackbar on failure.

- [ ] **Step 4: UI**

The bottom sheet should:
- Show a loading state during publish.
- On failure, keep the sheet open with a retry button, OR dismiss with a retryable snackbar (project pattern — match what the delete flow from PR 1 does).

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(mute): reliable mute-list publish with rollback on failure"
```

---

## Chunk 2: Content blocklist

### Task 2.1: Migrate `publishBlockList`

`content_blocklist_service.dart:240` — kind 30000 addressable. Similar contract to mute: currently optimistic local update, then publish; fix by gating update behind `outcome.acceptedByAny`.

- [ ] **Step 1: Test**

`mobile/test/unit/services/content_blocklist_service_reliability_test.dart` — mirror mute tests.

- [ ] **Step 2: Migrate**

Same pattern as mute. `publishEventWithRetry`, only commit local state on acceptance.

- [ ] **Step 3: UI**

Blocklist management screen shows a snackbar on failure. Since blocklist actions are rarer than mute, a simple error + Retry button is sufficient.

- [ ] **Step 4: Commit**

```bash
git commit -m "feat(blocklist): reliable blocklist publish with relay ack gating"
```

---

## Chunk 3: Content reports (kind 1984)

### Task 3.1: Migrate `reportContent`

**Background:** Reports go to a specific moderation relay (current code passes `targetRelays`). A failed report means the moderation pipeline never sees it. This is user-visible — reports show a "Report submitted" confirmation today regardless of outcome.

- [ ] **Step 1: Test**

`mobile/test/unit/services/content_reporting_service_reliability_test.dart`:
- Successful report → state reflects submission, history entry added.
- Failed report → feedback surfaces; history NOT marked as submitted (retry-eligible).

- [ ] **Step 2: Migrate**

```dart
final outcome = await _nostrService.publishEventWithRetry(
  event,
  policy: const RetryPolicy(maxAttempts: 3, timeoutPerAttempt: Duration(seconds: 10)),
  targetRelays: [moderationRelayUrl], // preserve existing target routing
);
```

- [ ] **Step 3: UI wiring**

`ReportContentDialog` (currently shows "Report submitted" unconditionally) now waits on the outcome. On success, show the confirmation. On failure, show a retryable snackbar.

Watch out for **UI modality**: the report dialog currently closes before the publish completes. Change the flow to keep the dialog's submit button in a loading state until the outcome resolves (matches `delete` flow from PR 1).

- [ ] **Step 4: Commit**

```bash
git commit -m "feat(report): reliable content-report publish with confirmed submission"
```

---

## Chunk 4: Verification

- [ ] **Step 1: Analyzer + tests**

```bash
cd mobile && flutter analyze lib test
flutter test test/unit/services/mute_service_reliability_test.dart \
             test/unit/services/content_blocklist_service_reliability_test.dart \
             test/unit/services/content_reporting_service_reliability_test.dart
```

- [ ] **Step 2: Manual moderation smoke test**

Against the local stack:
- Mute a pubkey, verify kind 10000 on the relay (`mise run local_up` then query the relay).
- Block content, verify kind 30000 with correct d-tag.
- Submit a report, verify kind 1984 on the moderation relay.

- [ ] **Step 3: Open PR**

Title: `feat(moderation): reliable mute / blocklist / report publishing`

Body:
- All three moderation publishes now gate local state behind relay acceptance.
- Fixes silent-divergence bug: user thought a pubkey was muted, but no relay stored it → on next login the user saw content from the supposedly-muted pubkey.
- Report dialog waits on confirmed submission before closing.

---

## Risks

- **Replaceable-event semantics.** Kind 10000 is replaceable by pubkey — retrying an older version accidentally could overwrite a newer local version. `publishEventWithRetry` passes the SAME event each attempt, so its `created_at` doesn't drift. Not a problem, but worth flagging in review.
- **Addressable-event d-tag on blocklist.** The d-tag must be stable across updates. PR 4 does not touch the d-tag logic — verify existing tests still pass.
- **Report relay routing.** Preserve `targetRelays` in the retry path. `publishEventWithRetry` threads `targetRelays` through to each attempt; on retry, `publishEventAwaitOk` uses the `transientRelays` from the prior outcome — but for reports where we intentionally only target one relay, `transientRelays` will be a subset of that single relay. Verify the retry path still targets the moderation relay.
