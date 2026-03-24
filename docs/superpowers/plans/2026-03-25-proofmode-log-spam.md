# ProofMode Log Spam Reduction Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop `ProofModeBadgeRow` from flooding captured logs during routine widget rebuilds while preserving badge behavior.

**Architecture:** Keep the fix local to the badge row. Remove the per-build diagnostic log and narrow the moderation provider selection to the AI score only so routine loading-state churn does not trigger extra rebuilds.

**Tech Stack:** Flutter, Riverpod, flutter_test, mocktail

---

## Chunk 1: Regression Coverage

### Task 1: Add a failing widget test for rebuild log spam

**Files:**
- Modify: `mobile/test/widgets/proofmode_badge_row_test.dart`

- [ ] **Step 1: Write the failing test**

Add a test that:
- clears `LogCaptureService`
- builds `ProofModeBadgeRow`
- forces one or more parent rebuilds
- asserts there are no captured log entries with `name == 'ProofModeBadgeRow'`

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widgets/proofmode_badge_row_test.dart --plain-name "does not capture badge decision logs during rebuilds"`
Expected: FAIL because the widget currently logs from `build()`

## Chunk 2: Minimal Fix

### Task 2: Remove per-build logging and narrow rebuild triggers

**Files:**
- Modify: `mobile/lib/widgets/proofmode_badge_row.dart`

- [ ] **Step 1: Remove the badge-decision `Log.verbose(...)` call**

Delete the per-build diagnostic log so the widget has no logging side effects during normal rendering.

- [ ] **Step 2: Simplify the moderation provider selection**

Change the `select(...)` call to watch only the AI score instead of a tuple that includes loading and error state, so null-to-null transitions do not trigger extra rebuilds.

- [ ] **Step 3: Keep badge behavior unchanged**

Retain the existing badge decision rules and moderation lookup behavior.

## Chunk 3: Verification

### Task 3: Verify the regression and surrounding behavior

**Files:**
- Verify: `mobile/test/widgets/proofmode_badge_row_test.dart`

- [ ] **Step 1: Run the focused badge-row test file**

Run: `flutter test test/widgets/proofmode_badge_row_test.dart`
Expected: PASS

- [ ] **Step 2: Review the diff**

Run: `git diff -- mobile/lib/widgets/proofmode_badge_row.dart mobile/test/widgets/proofmode_badge_row_test.dart docs/superpowers/plans/2026-03-25-proofmode-log-spam.md`
Expected: only the planned log-spam reduction changes
