# Apps Explore Tab And Directory Bootstrap Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Promote vetted apps into Explore’s top tabs and add a repo-owned remote manifest bootstrap for the first app catalog.

**Architecture:** Reuse the existing directory screen as both a standalone route and an embedded Explore tab. Keep manifests in the worker package as versioned data plus a small import path, so mobile continues to fetch the catalog remotely instead of shipping app metadata.

**Tech Stack:** Flutter, Riverpod, GoRouter, existing directory worker/admin packages, Vitest, Flutter widget tests.

---

## Chunk 1: Explore Tab Integration

### Task 1: Add failing tests for the embedded apps directory and Explore navigation

**Files:**
- Modify: `mobile/test/screens/apps/apps_directory_screen_test.dart`
- Modify: `mobile/test/widgets/settings_screen_test.dart`
- Modify: `mobile/test/router/explore_tab_navigation_test.dart`

- [ ] **Step 1: Write failing tests**
- [ ] **Step 2: Run the focused Flutter tests and confirm they fail for the expected reasons**
- [ ] **Step 3: Add embedded-mode support to `AppsDirectoryScreen` and add `Apps` to Explore tabs**
- [ ] **Step 4: Update the Settings `Apps` entry to route into Explore’s `apps` tab**
- [ ] **Step 5: Re-run the focused Flutter tests and confirm they pass**

## Chunk 2: Directory Bootstrap

### Task 2: Add failing worker tests for versioned vetted-app manifests

**Files:**
- Create: `website/apps-directory-worker/manifests/*.json`
- Create or Modify: `website/apps-directory-worker/src/lib/seed-manifests.ts`
- Modify: `website/apps-directory-worker/test/manifest-schema.test.ts`
- Modify: `website/apps-directory-worker/test/routes.test.ts`

- [ ] **Step 1: Write failing tests that load the repo-owned manifests and validate them**
- [ ] **Step 2: Run the focused worker tests and confirm they fail for the expected reasons**
- [ ] **Step 3: Add the seven vetted app manifests and a small loader/import helper**
- [ ] **Step 4: Re-run the focused worker tests and confirm they pass**

## Verification

- [ ] Run focused Flutter tests covering apps directory, settings navigation, and Explore tabs.
- [ ] Run focused worker tests covering manifest validation/routes.
- [ ] Review `git diff --stat` and `git status --short`.
