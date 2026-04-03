# Integrated Apps Framing Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reframe the apps surface so users and App Review see a bounded set of approved third-party integrations rather than open-ended web access.

**Architecture:** Keep the existing routing and bridge behavior intact, but tighten the naming and explanatory copy across the Explore tab, settings entry, directory, detail screen, and integration loading/error states. Add only enough UI structure to explain the boundary before launch.

**Tech Stack:** Flutter, Riverpod, GoRouter, existing widget tests.

---

## Chunk 1: Integrated Apps Copy

### Task 1: Lock the new wording with failing tests

**Files:**
- Modify: `mobile/test/screens/explore_screen_apps_tab_test.dart`
- Modify: `mobile/test/screens/apps/apps_directory_screen_test.dart`
- Modify: `mobile/test/screens/apps/app_detail_screen_test.dart`
- Modify: `mobile/test/screens/apps/nostr_app_sandbox_screen_test.dart`
- Modify: `mobile/test/widgets/settings_screen_test.dart`

- [ ] **Step 1: Write failing tests for `Integrated Apps` labels, approved-integration copy, and `Open Integration`**
- [ ] **Step 2: Run the focused Flutter tests and confirm they fail for the expected reasons**
- [ ] **Step 3: Update the user-facing strings in Explore, Settings, directory, detail, and integration status states**
- [ ] **Step 4: Re-run the focused Flutter tests and confirm they pass**

## Chunk 2: Integration Boundary Explainer

### Task 2: Add a clear bounded-access explainer before launch

**Files:**
- Modify: `mobile/lib/screens/apps/app_detail_screen.dart`
- Modify: `mobile/test/screens/apps/app_detail_screen_test.dart`

- [ ] **Step 1: Write a failing test for the approved-integration explainer copy**
- [ ] **Step 2: Run the focused app detail test and confirm it fails for the expected reason**
- [ ] **Step 3: Add a short explainer section describing approved integrations, scoped permissions, and blocked off-origin navigation**
- [ ] **Step 4: Re-run the focused app detail test and confirm it passes**

## Verification

- [ ] Run focused Flutter tests for explore apps tab, apps directory, app detail, sandbox screen, and settings.
- [ ] Run `flutter analyze --no-fatal-infos` from `mobile/` after moving stale `mobile/build/macos` artifacts out of tree if needed.
- [ ] Review `git diff --stat` and `git status --short`.
