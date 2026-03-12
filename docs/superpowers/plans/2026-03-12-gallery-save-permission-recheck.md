# Gallery Save Permission Recheck Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent gallery save/export from returning permission denied when the OS permission prompt was accepted but the plugin returns a stale non-granted result.

**Architecture:** Keep the fix inside `GallerySaveService` by re-checking gallery permission status after a non-granted request result. Add one regression test that exercises the save path with a real temp file so the permission code runs.

**Tech Stack:** Flutter, `flutter_test`, `mocktail`, `permissions_service`, `gal`

---

## Chunk 1: Regression Test And Minimal Fix

### Task 1: Add the failing regression test

**Files:**
- Modify: `mobile/test/services/gallery_save_service_test.dart`
- Test: `mobile/test/services/gallery_save_service_test.dart`

- [ ] **Step 1: Write the failing test**

Add a test that configures:

- `checkGalleryStatus()` to return `canRequest`, then `granted`
- `requestGalleryPermission()` to return `canRequest`
- a real temp file path for `EditorVideo.file(...)`

Assert that the result is not `GallerySavePermissionDenied()`.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/services/gallery_save_service_test.dart`
Expected: FAIL because `_checkPermission()` trusts the stale request result and returns denial before saving.

### Task 2: Implement the minimal permission re-check

**Files:**
- Modify: `mobile/lib/services/gallery_save_service.dart`
- Test: `mobile/test/services/gallery_save_service_test.dart`

- [ ] **Step 3: Write minimal implementation**

In `_checkPermission()`, after `requestGalleryPermission()` returns a non-granted status, immediately call `checkGalleryStatus()` again and allow the save flow to continue if the follow-up status is `granted`.

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/services/gallery_save_service_test.dart`
Expected: PASS

- [ ] **Step 5: Run focused verification**

Run: `cd mobile && flutter test test/services/gallery_save_service_test.dart`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add docs/superpowers/specs/2026-03-12-gallery-save-permission-recheck-design.md \
        docs/superpowers/plans/2026-03-12-gallery-save-permission-recheck.md \
        mobile/lib/services/gallery_save_service.dart \
        mobile/test/services/gallery_save_service_test.dart
git commit -m "fix(gallery): recheck permission after save grant prompt"
```
