# Reliable Nostr Publish — PR 5: Lists, bookmarks, curation, labels

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Depends on:** PR 1 merged.

**Goal:** Migrate all list/curation/label publishes to reliable delivery. Users expect a "Saved to bookmarks" confirmation to mean the bookmark will survive sign-out → sign-in on another device.

**Architecture:** Four services, all publishing replaceable or addressable kinds. Existing ad-hoc reliability logic in `curation_service.dart` (5-second timeout + failedAttempts state) is deleted in favour of the shared `RetryPolicy`.

---

## File Structure

### Modified

- `mobile/lib/services/bookmark_service.dart:608` — kind 10003 global bookmarks.
- `mobile/lib/services/bookmark_service.dart:669` — kind 30003 named bookmark set.
- `mobile/lib/services/curated_list_service.dart:900` — kind 30005 curated list.
- `mobile/lib/services/curation_service.dart:1011` — kind 30005 curation set. Delete the `failedAttempts`/`lastFailureReason` instance-variable state (violates "no mutable instance variables in BLoC" — moves to state type via outcome+feedback).
- `mobile/lib/services/account_label_service.dart:148` — kind 1985 account labels.

### UI

- Bookmark button on video cards.
- Bookmark-set rename/create sheet.
- Curated-list editor page.
- Account labels settings screen.

### Tests (created)

- `bookmark_service_reliability_test.dart`
- `curated_list_service_reliability_test.dart`
- `curation_service_reliability_test.dart`
- `account_label_service_reliability_test.dart`

---

## Chunk 1: Bookmarks

### Task 1.1: Global bookmarks (kind 10003)

`bookmark_service.dart:608` — user taps bookmark icon on a video. Snackbar shows "Saved".

- [ ] **Step 1: Test**

Success / transient / permanent scenarios + state rollback on failure.

- [ ] **Step 2: Migrate**

```dart
// 1. Compute the NEW bookmark list.
// 2. Build event.
// 3. publishEventWithRetry(event).
// 4. On acceptedByAny: commit local state, persist.
// 5. On failure: return BookmarkResult.failure(outcome, feedback) — UI shows retry snackbar.
```

- [ ] **Step 3: UI**

Bookmark icon on `VideoTile` / `VideoDetailPage`:
- During publish: show in-flight state (icon spins or goes to a "pending" tint).
- On success: persistent bookmarked state (filled icon).
- On failure: revert to un-bookmarked, retryable snackbar.

- [ ] **Step 4: Commit**

```bash
git commit -m "feat(bookmarks): reliable global bookmark publish"
```

### Task 1.2: Named bookmark sets (kind 30003)

`bookmark_service.dart:669` — creating/renaming a bookmark set.

Same pattern as Task 1.1. Commit separately to keep the diff focused.

```bash
git commit -m "feat(bookmarks): reliable bookmark-set publish"
```

---

## Chunk 2: Curated lists (`curated_list_service.dart`)

### Task 2.1: Migrate `publishCuratedList`

`curated_list_service.dart:900` — kind 30005. User creates a curated list and adds videos to it.

- [ ] **Step 1: Test**

`mobile/test/unit/services/curated_list_service_reliability_test.dart`.

- [ ] **Step 2: Migrate**

`publishEventWithRetry`. No existing ad-hoc reliability here — straight swap.

- [ ] **Step 3: UI**

Curated-list editor page — Save button shows loading, failure snackbar with Retry.

- [ ] **Step 4: Commit**

```bash
git commit -m "feat(curated-lists): reliable curated-list publish"
```

---

## Chunk 3: Curation service (`curation_service.dart`)

### Task 3.1: Delete the ad-hoc 5s timeout + failedAttempts state

**Background:** `curation_service.dart:1011` has a custom 5s timeout wrapping `publishEvent` plus `failedAttempts` / `lastFailureReason` instance fields. Per `.claude/rules/state_management.md` ("no mutable instance variables in BLoC"), these violate the rule. Move to `publishEventWithRetry` and expose outcome via the service's state/result type.

- [ ] **Step 1: Test**

`mobile/test/unit/services/curation_service_reliability_test.dart`.

- [ ] **Step 2: Migrate**

Delete the custom timeout block and the `failedAttempts` / `lastFailureReason` fields:

```dart
// DELETE the timeout wrapper
// DELETE _failedAttempts
// DELETE _lastFailureReason

Future<CurationResult> publishCuration(...) async {
  final event = await _buildEvent(...);
  final outcome = await _nostrService.publishEventWithRetry(
    event,
    policy: const RetryPolicy(maxAttempts: 3, timeoutPerAttempt: Duration(seconds: 15)),
  );
  final feedback = PublishResultMapper.map(outcome);
  return outcome.acceptedByAny
      ? CurationResult.success(outcome: outcome, feedback: feedback)
      : CurationResult.failure(outcome: outcome, feedback: feedback);
}
```

- [ ] **Step 3: Update callers**

Grep for `failedAttempts` / `lastFailureReason` — callers that read those need to migrate to `CurationResult.feedback.retryable` / `feedback.firstRejectionReason`.

- [ ] **Step 4: Commit**

```bash
git commit -m "refactor(curation): drop ad-hoc timeout/retry state, use publishEventWithRetry"
```

---

## Chunk 4: Account labels (`account_label_service.dart`)

### Task 4.1: Migrate `publishAccountLabels`

`account_label_service.dart:148` — kind 1985. User updates their own account labels from the settings screen.

- [ ] **Step 1: Test**

`mobile/test/unit/services/account_label_service_reliability_test.dart`.

- [ ] **Step 2: Migrate**

`publishEventWithRetry`. Gate local commit on `outcome.acceptedByAny` (matches other replaceable-list migrations).

- [ ] **Step 3: UI**

Settings screen Labels section — Save button shows loading, failure snackbar, success confirmation.

- [ ] **Step 4: Commit**

```bash
git commit -m "feat(account-labels): reliable kind-1985 label publish"
```

---

## Chunk 5: Verification

- [ ] **Step 1: Analyzer + tests**

```bash
cd mobile && flutter analyze lib test
flutter test test/unit/services/bookmark_service_reliability_test.dart \
             test/unit/services/curated_list_service_reliability_test.dart \
             test/unit/services/curation_service_reliability_test.dart \
             test/unit/services/account_label_service_reliability_test.dart
```

- [ ] **Step 2: Manual smoke test**

Against local stack:
- Bookmark a video → verify kind 10003 replaceable event on the relay.
- Create a named bookmark set → verify kind 30003 with correct d-tag.
- Create a curated list with 3 videos → verify kind 30005 with 3 `a`/`e` tags.
- Update account labels → verify kind 1985 with correct tags.

- [ ] **Step 3: Open PR**

Title: `feat(lists): reliable bookmark / curated-list / curation / account-label publishing`

Body:
- Drops `curation_service.dart`'s bespoke 5s timeout + `failedAttempts` fields (violated the "no mutable instance vars in BLoC" rule).
- All list publishes now gate local commit on confirmed relay acceptance.
- Five distinct kinds migrated (10003, 30003, 30005 × 2, 1985).

---

## Risks

- **`curation_service.dart` callers breaking.** The `failedAttempts` / `lastFailureReason` fields are read by some widgets. Migrate those callers in the same PR — don't leave dangling references.
- **Bookmark UX regressions.** Users expect instant "Saved" feedback. Show optimistic icon state during publish but rollback cleanly on failure. Cover with a widget test.
- **Addressable event d-tags.** Kind 30003, 30005 use d-tags for replacement. Verify the d-tag computation is unchanged.
