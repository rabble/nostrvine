# Early NIP-07 Bridge Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make vetted third-party apps see the Divine NIP-07 signer during their initial bootstrap so they start in a logged-in state without per-app login taps.

**Architecture:** Keep the current sandbox route and bridge service, but move bridge availability earlier. Apple platforms get a real document-start WebKit user script. Android gets an initial HTML bootstrap path that injects the bridge script ahead of the remote app bundles while keeping the remote app URL as the base URL. The current bridge request/response channel stays intact.

**Tech Stack:** Flutter, `webview_flutter`, `webview_flutter_wkwebview`, Dart `http`, widget tests.

---

## Chunk 1: Sandbox bootstrap tests

### Task 1: Add failing tests for early bridge availability

**Files:**
- Modify: `mobile/test/screens/apps/nostr_app_sandbox_screen_test.dart`
- Test: `mobile/test/screens/apps/nostr_app_sandbox_screen_test.dart`

- [ ] **Step 1: Write a failing test that expects Android-style sandbox startup to use HTML bootstrap loading instead of a direct URL request**
- [ ] **Step 2: Write a failing test that expects the initial HTML passed into the WebView to contain the Divine bridge script before app boot**
- [ ] **Step 3: Run `flutter test --no-pub test/screens/apps/nostr_app_sandbox_screen_test.dart` from `mobile/` and confirm the new expectations fail for the current late-injection implementation**

## Chunk 2: Early bridge implementation

### Task 2: Implement platform-aware early bridge setup

**Files:**
- Modify: `mobile/lib/screens/apps/nostr_app_sandbox_screen.dart`
- Modify: `mobile/pubspec.yaml`

- [ ] **Step 1: Add the minimal sandbox helper code needed to build a platform-specific controller and initial load path**
- [ ] **Step 2: Add the Apple WebKit document-start bridge installation using the public WebKit controller/native bindings**
- [ ] **Step 3: Add the Android initial-document HTML bootstrap loader with the app URL as the base URL**
- [ ] **Step 4: Keep the existing late bridge injection path only as a fallback for already-loaded pages and bridge responses**

## Chunk 3: Verification

### Task 3: Prove the sandbox behavior end to end

**Files:**
- Modify: `mobile/test/screens/apps/nostr_app_sandbox_screen_test.dart`

- [ ] **Step 1: Re-run `flutter test --no-pub test/screens/apps/nostr_app_sandbox_screen_test.dart` from `mobile/` and confirm the sandbox tests pass**
- [ ] **Step 2: Run a focused analyze pass for the touched files**
- [ ] **Step 3: Review `git diff --stat` and `git status --short`**
- [ ] **Step 4: Commit the implementation with a focused conventional commit message**
