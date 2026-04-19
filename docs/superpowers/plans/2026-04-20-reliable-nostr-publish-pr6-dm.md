# Reliable Nostr Publish — PR 6: Direct messages (NIP-04 fallback + NIP-17 gift wraps)

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Depends on:** PR 1 merged.

**Goal:** Make DM sending durable. A failed DM today shows as "Sent" locally; if no relay stored the gift wrap, the recipient never gets it. This is the highest-stakes reliability fix in the whole series.

**Architecture:** Two codepaths converge in `dm_repository.dart`:
- NIP-17 gift wraps (preferred) via `nip17_message_service.dart`.
- NIP-04 legacy encrypted DMs (fallback when recipient has no NIP-17 relays).

NIP-17 gift-wraps the message twice — once addressed to the recipient, once to the sender for self-recovery. The recipient wrap **must** succeed; the self-wrap can be best-effort since losing a self-copy only breaks multi-device sync.

Recipient-relay routing is non-trivial. NIP-17 gift wraps go to the recipient's DM relays (kind 10050 list), not the sender's default relays. Preserve that routing through `targetRelays`.

---

## File Structure

### Modified

- `mobile/lib/services/nip17_message_service.dart:104` — recipient gift wrap (must migrate).
- `mobile/lib/services/nip17_message_service.dart:123` — self gift wrap (keep best-effort but use `publishEventAwaitOk` with short timeout for telemetry; don't retry).
- `mobile/lib/repositories/dm_repository.dart:1222` — NIP-04 fallback send.
- `mobile/lib/repositories/dm_repository.dart:1008` — kind 5 DM deletion.
- BLoCs: `DmBloc` / `ConversationBloc` — state gains `sendStatus` + `feedback`.
- UI: conversation view, message bubble — show pending/sent/failed states with retry.

### Tests (created)

- `mobile/test/unit/services/nip17_message_service_reliability_test.dart`
- `mobile/test/repositories/dm_repository_reliability_test.dart`
- `mobile/test/blocs/dm/dm_bloc_reliability_test.dart`
- `mobile/test/widgets/conversation_view_send_test.dart`

---

## Chunk 1: NIP-17 gift wrap (recipient)

### Task 1.1: Migrate `sendGiftWrap` recipient path

**Background:** `nip17_message_service.dart:104` publishes the recipient gift wrap. This is the message the recipient's client actually decrypts. If it doesn't land on at least one of the recipient's DM relays, the message is effectively not sent.

- [ ] **Step 1: Test**

Cover:
- Recipient-wrap succeeds → `GiftWrapResult.success`.
- Recipient-wrap fails transient → retryable failure surfaced.
- Recipient-wrap fails permanent (e.g. `blocked:`) → non-retryable failure.
- The self-wrap failing does NOT cause the overall `sendGiftWrap` to fail (self-wrap is best-effort).

- [ ] **Step 2: Migrate**

```dart
final recipientOutcome = await _nostrService.publishEventWithRetry(
  recipientGiftWrap,
  targetRelays: recipientDmRelays, // kind-10050 list from recipient profile
);
final recipientFeedback = PublishResultMapper.map(recipientOutcome);

if (!recipientOutcome.acceptedByAny) {
  return GiftWrapResult.failure(outcome: recipientOutcome, feedback: recipientFeedback);
}

// Self-wrap — best-effort. Await outcome for telemetry but do not retry.
try {
  final selfOutcome = await _nostrService.publishEventAwaitOk(
    selfGiftWrap,
    timeout: const Duration(seconds: 5),
  );
  // Log only — success/failure does not affect GiftWrapResult.
  Log.info('Self-wrap outcome: $selfOutcome', name: 'Nip17MessageService');
} catch (e, st) {
  Log.warning('Self-wrap failed: $e', name: 'Nip17MessageService', error: e, stackTrace: st);
}

return GiftWrapResult.success(outcome: recipientOutcome, feedback: recipientFeedback);
```

- [ ] **Step 3: Commit**

```bash
git commit -m "feat(dm): NIP-17 recipient gift wrap reliable; self-wrap best-effort"
```

---

## Chunk 2: NIP-04 fallback

### Task 2.1: Migrate `sendNip04Message`

`dm_repository.dart:1222` — used when the recipient has no NIP-17 relay list.

- [ ] **Step 1: Test**

`mobile/test/repositories/dm_repository_reliability_test.dart` — success / transient / permanent paths.

- [ ] **Step 2: Migrate**

```dart
final outcome = await _nostrClient.publishEventWithRetry(signed);
final feedback = PublishResultMapper.map(outcome);
return outcome.acceptedByAny
    ? DmSendResult.success(message: message, outcome: outcome, feedback: feedback)
    : DmSendResult.failure(outcome: outcome, feedback: feedback);
```

- [ ] **Step 3: Commit**

```bash
git commit -m "feat(dm): NIP-04 fallback reliable send"
```

---

## Chunk 3: DM deletion (kind 5)

### Task 3.1: Migrate `deleteMessage`

`dm_repository.dart:1008`. User-facing — "Delete for everyone" button in the chat bubble context menu.

Straightforward migration. Similar contract to content deletion from PR 1.

- [ ] **Step 1: Test**

Add to `dm_repository_reliability_test.dart`.

- [ ] **Step 2: Migrate**

```dart
final outcome = await _nostrClient.publishEventWithRetry(signed);
// Local soft-delete already happens on success per existing flow.
```

- [ ] **Step 3: Commit**

```bash
git commit -m "feat(dm): reliable message deletion"
```

---

## Chunk 4: BLoC + UI integration

### Task 4.1: `DmBloc` state + status enum

Per `.claude/rules/state_management.md`, use an enum status, not an error string in state.

```dart
enum MessageSendStatus { idle, sending, sent, failed }

class DmState {
  final Map<String, MessageSendStatus> sendStatusByMessageId;
  final Map<String, PublishUserFeedback> feedbackByMessageId;
  // ...
}
```

- [ ] **Step 1: Test**

`mobile/test/blocs/dm/dm_bloc_reliability_test.dart` — state transitions: idle → sending → sent or failed; verify feedback is threaded through.

- [ ] **Step 2: Migrate**

Wire `DmSendResult` / `GiftWrapResult` through to state.

- [ ] **Step 3: UI**

The message bubble (`ConversationMessageBubble`) should show:
- `sending` → grey clock icon, opacity 0.6.
- `sent` → no icon (implicit success).
- `failed` → red alert icon with tap → retry action sheet. Show `feedback.firstRejectionReason` in the sheet subtitle if non-null.

For **optimistic rendering**: insert the message into the conversation list immediately with `sending` status so the user's chat feels responsive. Don't remove it on failure — keep it with the `failed` status so the user can retry without retyping.

- [ ] **Step 4: Widget test**

`mobile/test/widgets/conversation_view_send_test.dart` — covers:
- Sending message shows grey clock.
- Failure shows red alert and Retry action.
- Retry triggers a fresh `DmBloc` send event.

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(dm-ui): pending/sent/failed message status with retry"
```

---

## Chunk 5: Verification

- [ ] **Step 1: Analyzer + tests**

- [ ] **Step 2: E2E smoke test against local stack**

`mise run local_up` then manually:
1. Send a NIP-17 DM from user A to user B. Verify on B's device it arrives.
2. Kill B's DM relay mid-send. Verify A sees `failed` status and a Retry button.
3. Delete a message. Verify B's conversation shows it as removed after the deletion event lands.

- [ ] **Step 3: Open PR**

Title: `feat(dm): reliable NIP-17 + NIP-04 send, pending/failed message UI`

Body highlights:
- Recipient gift-wrap now requires relay acknowledgement; self-wrap is explicitly best-effort.
- NIP-04 fallback and DM deletion use `publishEventWithRetry`.
- Adds pending/sent/failed visual states with a Retry affordance — fixes silent-DM-drop bug where failed messages showed as sent.

---

## Risks

- **Recipient-relay routing.** NIP-17 targets the recipient's kind-10050 list. `publishEventWithRetry` preserves `targetRelays` through retries, and `transientRelays` will always be a subset of the original target set — no accidental fan-out.
- **Self-wrap intentional best-effort.** Don't retry self-wrap; the user penalty for retrying a self-only failure is worse than losing a self-copy (multi-device sync glitch vs. slow UX).
- **Optimistic insertion ordering.** Messages inserted in `sending` state must keep chronological position. Don't sort by `confirmed_at` — sort by local `created_at` used when building the event.
- **Delete-for-everyone UX.** A failed delete should leave the message visible, not hidden-with-pending-delete. Gate local hide on `outcome.acceptedByAny`.
