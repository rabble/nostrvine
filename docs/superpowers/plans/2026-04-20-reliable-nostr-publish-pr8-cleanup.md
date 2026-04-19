# Reliable Nostr Publish — PR 8: Cleanup of legacy / ambiguous publishes

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Depends on:** PR 1 merged; PR 6 (DM) merged (we reuse NIP-17 primitives).

**Goal:** Deprecate or explicitly document the three publish sites that don't fit the Bucket A migration pattern, so the codebase ends this series with every publish either (a) using `publishEventWithRetry`, (b) using bare `publishEvent` with a code comment stating *why*, or (c) deleted.

**Architecture:** No shared library changes. Three independent cleanups:
1. `video_sharing_service.dart:194` — deprecated NIP-04-based share. Replace with NIP-17 share or delete entirely.
2. `corrupted_video_repair_service.dart:126` — best-effort metadata fix. Keep `publishEvent` but document the rationale.
3. Fire-and-forget ephemeral publishers (view/analytics/push-notification service) — add a comment linking to the rationale so future contributors don't "fix" them.

---

## File Structure

### Modified

- Delete or replace: `mobile/lib/services/video_sharing_service.dart`.
- Modify: `mobile/lib/services/corrupted_video_repair_service.dart:126` — add a rationale comment; keep `publishEvent`.
- Modify: `mobile/lib/services/view_event_publisher.dart` — add rationale comment above both `publishEvent` calls (`:180` and `:284`).
- Modify: `mobile/lib/services/push_notification_service.dart` — rationale comments above `:120`, `:182`, `:276`.

---

## Chunk 1: `video_sharing_service.dart` — NIP-04 deprecated share

### Task 1.1: Decide: replace with NIP-17 or delete

**Background:** `video_sharing_service.dart:194` builds a kind-4 encrypted DM carrying a shared video. The NIP-04 flow is security-deprecated; the rest of the DM surface area moved to NIP-17 in PR 6. Users today may still hit this codepath via "Share via DM" action; verify by grepping the UI.

- [ ] **Step 1: Audit callers**

```bash
cd mobile && grep -rn "VideoSharingService\|sharePrivatelyViaDm\|shareVideo" lib/ --include='*.dart'
```

Two outcomes to consider:
- **Path A: still reachable from UI** → rewrite on top of `Nip17MessageService` (reuse the sendGiftWrap primitive from PR 6). Build a NIP-17 gift wrap whose inner content is the video reference. Route through `publishEventWithRetry`.
- **Path B: dead code / orphaned** → delete the service and any widget that referenced it. Zero-change path for callers.

Which path applies is determined by the audit. If in doubt, prefer **Path B** (delete) — this service pre-dates NIP-17 and duplicates functionality.

### Task 1.2: Execute chosen path

- [ ] **Step 1 (Path A): Rewrite on NIP-17**

```dart
class VideoSharingService {
  VideoSharingService({required Nip17MessageService messageService}) : _messageService = messageService;

  final Nip17MessageService _messageService;

  Future<ShareResult> shareVideo({required VideoEvent video, required String recipientPubkey}) async {
    final content = _formatVideoShareMessage(video);
    final result = await _messageService.sendGiftWrap(
      recipientPubkey: recipientPubkey,
      content: content,
      // ... other params
    );
    return ShareResult.fromGiftWrap(result);
  }
}
```

Update callers + add a test covering the new flow. Commit as:

```bash
git commit -m "refactor(video-share): migrate from deprecated NIP-04 to NIP-17 gift wrap"
```

- [ ] **Step 1 (Path B): Delete**

```bash
git rm mobile/lib/services/video_sharing_service.dart \
       mobile/test/unit/services/video_sharing_service_test.dart
```

Grep for remaining imports and remove them. Verify UI compiles and no menu item still points at the removed function.

```bash
git commit -m "chore: remove deprecated NIP-04 video sharing service"
```

---

## Chunk 2: `corrupted_video_repair_service.dart`

### Task 2.1: Document rationale, keep fire-and-forget

**Background:** This service runs in the background to heal corrupted kind-34236 events. A failed repair is harmless — the video just stays corrupted until the next run. Retrying under bad-network conditions makes the problem worse by burning relay budget. Keep `publishEvent`.

- [ ] **Step 1: Add rationale comment**

At `corrupted_video_repair_service.dart:126`:

```dart
// Fire-and-forget by design: video repair is best-effort background cleanup.
// A failed repair re-runs on the next cycle; relay-level retry would amplify
// load without user benefit. See docs/superpowers/plans/2026-04-20-reliable-nostr-publish-pr8-cleanup.md.
final sent = await _nostrClient.publishEvent(signedEvent);
```

- [ ] **Step 2: Commit**

```bash
git commit -m "docs: annotate video-repair fire-and-forget rationale"
```

---

## Chunk 3: Ephemeral publishers — rationale comments

### Task 3.1: View events (kind 22236)

`view_event_publisher.dart:180` and `:284`.

- [ ] **Step 1: Add comment**

```dart
// Kind 22236 view analytics are NIP-01-ephemeral. Relays are not required to
// OK these, and retry would skew analytics. Fire-and-forget is the contract.
```

### Task 3.2: Push notification service

`push_notification_service.dart:120` (3080 deregister), `:182` (3083 preferences), `:276` (3079 register).

- [ ] **Step 1: Add comment**

```dart
// Push service events are ephemeral hand-offs to our push relay. Delivery
// retry is managed by the push relay's own retry queue, not the client.
```

### Task 3.3: Commit all three

```bash
git commit -m "docs: annotate ephemeral publishers to prevent accidental migration"
```

---

## Chunk 4: Verification

- [ ] **Step 1: Run full analyzer**

`cd mobile && flutter analyze lib test`. Zero issues.

- [ ] **Step 2: Run full unit test suite**

`cd mobile && flutter test`. All green.

- [ ] **Step 3: Verify the publish-inventory is now canonical**

Grep for remaining `publishEvent` and `sendEvent` call sites. Every remaining one should fall into exactly one of:
- `publishEventWithRetry` / `publishEventAwaitOk` call.
- A `publishEvent` call with a rationale comment on the line above.
- Internal SDK / client helpers used by the above.

```bash
cd mobile && grep -rn "\.publishEvent(\|\.sendEvent(" lib/ packages/ --include='*.dart' \
  | grep -v "publishEventWithRetry\|publishEventAwaitOk\|sendEventAwaitOk"
```

Expected: every line returned has a rationale comment within two lines above it, or lives in a package's internal plumbing (nostr_sdk, nostr_client).

- [ ] **Step 4: Open PR**

Title: `chore(nostr-publish): deprecate NIP-04 share, annotate intentional fire-and-forget`

Body:
- Completes the 8-PR series. Every publish in divine-mobile now either goes through the reliable path or is explicitly annotated as intentionally fire-and-forget.
- Removes (or rewrites) the legacy NIP-04 video share service.
- Documents the rationale for every remaining `publishEvent` call so future contributors don't "fix" one that should stay fire-and-forget.

---

## Risks

- **Path A vs Path B uncertainty on `video_sharing_service`.** Run the grep in Task 1.1 first; if there are UI call sites, Path A; otherwise Path B. Don't delete without confirming no runtime path reaches it.
- **Annotation drift.** Comments can rot. PR 8 lands a comment; PR series ends. A pre-commit lint rule could enforce the annotation going forward — out of scope here but worth a follow-up ticket.
- **Ephemeral relay migration.** If the push relay's retry semantics change, the rationale comment may become wrong. The comment links back to this plan; if the contract changes, update the plan doc too.
