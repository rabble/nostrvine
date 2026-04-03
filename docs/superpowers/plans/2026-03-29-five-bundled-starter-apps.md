# Five Bundled Starter Apps Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Agora, Treasures, Blobbi, Espy, and Jumble to the mobile bundled integrations catalog so they appear in the starter fallback list.

**Architecture:** Keep the change mobile-only. Drive it from the existing directory-service test suite, then add the minimal bundled app definitions in the preloaded app catalog using the shared vetted defaults already used by the other starter apps.

**Tech Stack:** Flutter, Dart, existing Nostr app directory service tests.

---

## Chunk 1: Starter catalog tests

### Task 1: Expand the starter catalog expectations with TDD

**Files:**
- Modify: `mobile/test/services/nostr_app_directory_service_test.dart`

- [ ] **Step 1: Write failing expectations for the five new starter app slugs**
- [ ] **Step 2: Add focused assertions for each new app’s name, launch URL, and allowed origin**
- [ ] **Step 3: Run `flutter test --no-pub test/services/nostr_app_directory_service_test.dart` from `mobile/` and confirm it fails for the missing starter apps**

## Chunk 2: Bundled app definitions

### Task 2: Add the new bundled starter entries

**Files:**
- Modify: `mobile/lib/services/preloaded_nostr_apps.dart`

- [ ] **Step 1: Add the five new bundled starter app entries with shared vetted defaults**
- [ ] **Step 2: Assign consecutive sort orders after the existing Ditto entry**
- [ ] **Step 3: Keep the copy aligned with current site branding where available**

## Chunk 3: Verification

### Task 3: Verify and hand off the change

**Files:**
- Modify: `mobile/test/services/nostr_app_directory_service_test.dart`
- Modify: `mobile/lib/services/preloaded_nostr_apps.dart`

- [ ] **Step 1: Re-run `flutter test --no-pub test/services/nostr_app_directory_service_test.dart` from `mobile/` and confirm it passes**
- [ ] **Step 2: Review `git diff --stat` and `git status --short`**
- [ ] **Step 3: Commit with a focused conventional commit message**
