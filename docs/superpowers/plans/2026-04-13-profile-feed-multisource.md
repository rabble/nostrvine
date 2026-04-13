# Profile Feed Multi-Source Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the profile feed render faster and stay fresher by coordinating cache, REST, and Nostr in parallel while preserving REST pagination and Nostr-correct merge behavior.

**Architecture:** Keep `ProfileFeed` as the existing Riverpod entrypoint, but refactor its internal orchestration into a source coordinator. Reuse current metadata cache, optimistic insertion, and Nostr enrichment helpers while adding stable multi-source merge helpers and mixed-source contract tests.

**Tech Stack:** Flutter, Riverpod, Funnelcake REST client, Nostr client/service, Flutter test, mocktail

---

## Chunk 1: Canonical Merge Helpers

### Task 1: Add failing merge-contract tests

**Files:**
- Modify: `mobile/test/providers/profile_feed_pagination_contract_test.dart`
- Reference: `mobile/lib/providers/profile_feed_provider.dart`

- [ ] **Step 1: Write failing tests for mixed-source dedupe and ordering**

Add tests covering:
- relay-first initial head item remains when slower REST arrives without that item
- REST overlays additional metadata without duplicating a replaceable video
- stable identity merges edited replaceable events by `pubkey + stableId`

- [ ] **Step 2: Run the targeted test file to verify failure**

Run: `flutter test test/providers/profile_feed_pagination_contract_test.dart`
Expected: FAIL on the new mixed-source expectations.

- [ ] **Step 3: Add minimal merge helpers in `ProfileFeed`**

Introduce focused helpers for:
- canonical stable key creation
- source merge of `List<VideoEvent>`
- deterministic publish-order sorting

- [ ] **Step 4: Run the targeted test file to verify the new helpers pass**

Run: `flutter test test/providers/profile_feed_pagination_contract_test.dart`
Expected: PASS for new and existing tests.

## Chunk 2: Parallel Initial Load

### Task 2: Make initial load cache-first and multi-source

**Files:**
- Modify: `mobile/lib/providers/profile_feed_provider.dart`
- Test: `mobile/test/providers/profile_feed_pagination_contract_test.dart`
- Reference: `mobile/lib/providers/profile_feed_session_cache.dart`
- Reference: `mobile/lib/services/video_event_service.dart`

- [ ] **Step 1: Write failing tests for initial parallel behavior**

Add tests covering:
- cached state is emitted immediately while background sync continues
- relay result can satisfy the visible head before REST returns
- REST later updates counts and hasMore metadata without discarding relay-only head items

- [ ] **Step 2: Run the targeted test file to verify failure**

Run: `flutter test test/providers/profile_feed_pagination_contract_test.dart`
Expected: FAIL on the new parallel initial-load cases.

- [ ] **Step 3: Implement the minimal initial-load coordinator**

Update `build(String userId)` to:
- emit retained state immediately when present
- kick off REST and relay startup concurrently
- accept the first useful result
- merge later source data into canonical state
- keep existing filtering and listener behavior intact

- [ ] **Step 4: Run the targeted test file to verify the initial-load changes pass**

Run: `flutter test test/providers/profile_feed_pagination_contract_test.dart`
Expected: PASS for the initial-load cases and no regressions in existing pagination cases.

## Chunk 3: Parallel Refresh And REST Pagination Preservation

### Task 3: Refresh with the same source-coordinator rules

**Files:**
- Modify: `mobile/lib/providers/profile_feed_provider.dart`
- Test: `mobile/test/providers/profile_feed_pagination_contract_test.dart`

- [ ] **Step 1: Write failing tests for refresh merge behavior**

Add tests covering:
- refresh keeps relay-fresh head items while REST count data lands later
- refresh degrades gracefully when one source errors

- [ ] **Step 2: Run the targeted test file to verify failure**

Run: `flutter test test/providers/profile_feed_pagination_contract_test.dart`
Expected: FAIL on the new refresh behavior.

- [ ] **Step 3: Implement minimal refresh coordinator changes**

Update refresh paths to:
- run REST and relay head sync in parallel
- reuse canonical merge helpers
- preserve `_totalVideoCount` and `_nextOffset`
- avoid dropping into a single-source fallback state when one source is still healthy

- [ ] **Step 4: Run the targeted test file to verify the refresh behavior passes**

Run: `flutter test test/providers/profile_feed_pagination_contract_test.dart`
Expected: PASS for refresh cases.

### Task 4: Keep `loadMore()` REST-backed but canonical

**Files:**
- Modify: `mobile/lib/providers/profile_feed_provider.dart`
- Test: `mobile/test/providers/profile_feed_pagination_contract_test.dart`

- [ ] **Step 1: Write a failing test for mixed-source `loadMore()`**

Add a test proving that after a relay-first or mixed-source initial state, REST `loadMore()` appends only genuinely older content and does not duplicate head items.

- [ ] **Step 2: Run the targeted test file to verify failure**

Run: `flutter test test/providers/profile_feed_pagination_contract_test.dart`
Expected: FAIL on the new `loadMore()` case.

- [ ] **Step 3: Implement minimal `loadMore()` canonical merge**

Update `loadMore()` to:
- merge incoming REST pages through the same stable identity rules
- maintain deterministic ordering
- preserve REST pagination metadata

- [ ] **Step 4: Run the targeted test file to verify `loadMore()` behavior passes**

Run: `flutter test test/providers/profile_feed_pagination_contract_test.dart`
Expected: PASS for the new `loadMore()` case and existing pagination cases.

## Chunk 4: Verification

### Task 5: Run focused verification

**Files:**
- Verify: `mobile/lib/providers/profile_feed_provider.dart`
- Verify: `mobile/test/providers/profile_feed_pagination_contract_test.dart`

- [ ] **Step 1: Run targeted analyze**

Run: `flutter analyze lib/providers/profile_feed_provider.dart test/providers/profile_feed_pagination_contract_test.dart`
Expected: `No issues found!`

- [ ] **Step 2: Run targeted provider tests**

Run: `flutter test test/providers/profile_feed_pagination_contract_test.dart`
Expected: All tests pass.

- [ ] **Step 3: Run the existing profile provider regression tests**

Run: `flutter test test/providers/profile_feed_provider_test.dart`
Expected: All tests pass.

- [ ] **Step 4: Review git diff for stray changes**

Run: `git status --short` and `git diff --stat`
Expected: Only spec, plan, provider, and targeted test changes.
