# Ditto Starter App Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `ditto.pub` to the mobile bundled integrations catalog so it appears in the starter fallback list.

**Architecture:** Keep the change mobile-only. Drive the work from the existing Nostr app directory service test suite, then add the minimal bundled app definition in the preloaded app catalog with the shared vetted defaults already used by the other starter apps.

**Tech Stack:** Flutter, Dart, existing Nostr app directory service tests.

---

## Chunk 1: Bundled Ditto Catalog Entry

### Task 1: Add Ditto to the starter catalog with TDD

**Files:**
- Modify: `mobile/test/services/nostr_app_directory_service_test.dart`
- Modify: `mobile/lib/services/preloaded_nostr_apps.dart`

- [ ] **Step 1: Write the failing test**
- [ ] **Step 2: Run `flutter test --no-pub test/services/nostr_app_directory_service_test.dart` from `mobile/` and confirm it fails for the missing Ditto starter app**
- [ ] **Step 3: Add the minimal bundled Ditto entry in `preloaded_nostr_apps.dart`**
- [ ] **Step 4: Re-run `flutter test --no-pub test/services/nostr_app_directory_service_test.dart` and confirm it passes**

## Verification

- [ ] Run `flutter test --no-pub test/services/nostr_app_directory_service_test.dart` from `mobile/`.
- [ ] Review `git diff --stat` and `git status --short`.
