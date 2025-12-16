# Test Failure Analysis Report
**Date:** November 12, 2025
**Total Tests:** 563 tests
**Passed:** ~506 tests
**Failed:** ~57 tests
**Success Rate:** ~90%

## Executive Summary

I've systematically analyzed all test failures using the debugging framework. The failures fall into 4 main categories:

1. **Compilation Errors (7 files)** - Tests won't run due to API changes
2. **Service Mock Issues (~15 tests)** - Tests expecting data but getting empty results
3. **Provider Infrastructure Gaps (~10 tests)** - Missing provider overrides in widget tests
4. **File Naming Convention Violations (~10 tests)** - Legitimate code issues found by tests
5. **Potential Code Bugs (~15 tests)** - Tests failing in ways that suggest real issues

---

## Category 1: COMPILATION ERRORS (Fix Required)
**Status:** Tests cannot run until fixed
**Cause:** Code API changes, tests using old signatures
**Recommendation:** Update tests to match current APIs

### Files:
1. **test/unit/services/video_event_service_expiration_test.dart**
   - **Error:** `VideoEventService()` requires constructor argument (missing NostrService)
   - **Fix:** Pass NostrService to constructor
   - **Action:** UPDATE TEST

2. **test/old_files/manual_thumbnail_test.dart**
   - **Error:** `BlossomUploadResult` no longer has `cdnUrl` parameter
   - **Fix:** Use correct parameter name from current API
   - **Action:** UPDATE TEST or MOVE TO ARCHIVE (it's in old_files/)

3. **test/old_files/event_based_routing_test.dart**
   - **Error:** `RouteContext` no longer has `eventId` parameter
   - **Fix:** Update to current RouteContext API
   - **Action:** UPDATE TEST or MOVE TO ARCHIVE (it's in old_files/)

4. **test/integration/upload_publish_e2e_comprehensive_test.dart**
   - **Error:** `BlossomUploadResult` no longer has `cdnUrl` parameter
   - **Fix:** Update to current API
   - **Action:** UPDATE TEST

5. **test/integration/proofmode_recording_integration_test.dart**
   - **Error:** Missing `proofModeSession` parameter (7 occurrences)
   - **Fix:** Add proofModeSession parameter or update to current API
   - **Action:** UPDATE TEST

6. **test/integration/proofmode_camera_integration_test.dart**
   - **Error:** Similar proofMode API mismatch
   - **Action:** UPDATE TEST

7. **test/providers/vine_recording_provider_notifier_test.dart**
   - **Error:** Compilation failure (need to check specific error)
   - **Action:** INVESTIGATE AND FIX

---

## Category 2: SERVICE MOCK ISSUES (Test Infrastructure)
**Status:** Tests failing due to incorrect mocking
**Cause:** Mock services don't emit data, tests expect data
**Recommendation:** Fix mock service implementations

### VideoEventService Deduplication Tests (6 failures)
**Files:** test/unit/services/video_event_service_deduplication_test.dart

**Failures:**
- `should not add duplicate events with same ID` - Expected: 1, Actual: 0
- `should add different events with unique IDs` - Expected: 3, Actual: 0
- `should handle mix of duplicates and unique events` - Expected: 2, Actual: 0
- `should maintain deduplication across multiple subscriptions` - Expected: 1, Actual: 0
- `should handle rapid duplicate events efficiently` - Expected: 1, Actual: 0
- `should handle events with invalid kind gracefully` - Expected: 1, Actual: 0

**Analysis:** All tests expect events but get 0. This suggests:
- Either the mock NostrService isn't emitting events properly
- Or VideoEventService isn't processing them

**Root Cause Investigation Needed:**
1. Check if mock NostrService emits events to stream
2. Check if VideoEventService subscription is set up correctly in tests
3. Verify event processing logic actually adds to internal lists

**Recommendation:**
- **IF mock is broken:** FIX TEST (update mock to emit events)
- **IF service is broken:** FIX CODE (investigate why events aren't being stored)
- **Action:** INVESTIGATE - Read test file to determine which

### Embedded Relay Service Tests (6 failures)
**Files:** test/unit/services/embedded_relay_service_unit_test.dart

**Failures:**
- `service has correct initial state` - Expected: 1, Actual: 0 (relay count)
- `service provides relay status information` - Expected: non-empty, Actual: {} (status map)
- `service can add external relays` - Expected contains 'ws://localhost:7447', Actual: []
- `service can remove external relays but not embedded relay` - Expected: false, Actual: true
- `service provides relay status checks` - Expected: true, Actual: null
- `service can be disposed` - Expected: true, Actual: false

**Analysis:** NostrService not initializing with embedded relay. Log shows:
```
🏗️  NostrService CONSTRUCTOR called - creating NEW instance
   Initial relay count: 0
```

**This is a CODE BUG!** The embedded relay should be added during construction.

**Recommendation:** FIX CODE
- Check lib/services/nostr_service.dart constructor
- Ensure embedded relay (ws://localhost:7447) is added on init
- **Action:** INVESTIGATE CODE - This looks like a real bug

### BugReportService Tests (2 failures)
**Files:** test/unit/services/bug_report_service_test.dart

**Failures:**
- `should collect diagnostics with all fields` - Expected: non-empty, Actual: {}
- `should handle empty diagnostics gracefully` - Expected: non-empty, Actual: {}

**Analysis:** Diagnostics collection returning empty map

**Recommendation:** INVESTIGATE
- Could be mock issue (mocked dependencies not returning data)
- Could be real bug (diagnostics not collected)
- **Action:** READ TEST to determine if mocks are set up correctly

### Embedded Relay Performance Tests (4 failures)
**Files:** test/unit/services/embedded_relay_performance_unit_test.dart

**Failures:**
- `relay status queries are fast` - Expected: non-empty, Actual: {}
- `multiple relay operations are efficient` - Expected > 0, Actual: 0
- `search interface responds quickly` - Expected > 0, Actual: null
- `performance comparison demonstrates embedded relay speed advantage` - Expected > 0, Actual: 0

**Analysis:** Same root cause as embedded relay service tests above - relay not initializing

**Recommendation:** FIX CODE (same as embedded relay service)

---

## Category 3: PROVIDER OVERRIDE ERRORS (Test Infrastructure)
**Status:** Widget tests missing provider overrides
**Cause:** Tests don't override sharedPreferencesProvider
**Recommendation:** Add provider overrides to test setup

### Affected Tests:
- test/widget/screens/hashtag_feed_screen_test.dart (multiple tests)
- test/widget/video_feed_item_test.dart (likely)

**Error:**
```
UnimplementedError: sharedPreferencesProvider must be overridden in tests
```

**Stack trace shows:**
```
featureFlagService → sharedPreferencesProvider (unoverridden)
VideoOverlayActions._buildEditButton → featureFlagService
```

**Root Cause:** VideoOverlayActions widget uses featureFlagService which depends on sharedPreferencesProvider

**Recommendation:** FIX TESTS
- Add provider override in test setup:
```dart
ProviderScope(
  overrides: [
    sharedPreferencesProvider.overrideWithValue(mockSharedPreferences),
  ],
  child: widget,
)
```
- **Action:** UPDATE ALL WIDGET TESTS

---

## Category 4: FILE NAMING CONVENTION VIOLATIONS (Code Issues)
**Status:** Tests correctly identifying code violations
**Cause:** Files violate naming conventions
**Recommendation:** Fix code to follow conventions OR update conventions

### Router Files (should end with `_screen`):
- lib/screens/home_screen_router.dart
- lib/screens/profile_screen_router.dart
- lib/screens/hashtag_screen_router.dart
- lib/screens/explore_screen_router.dart

**Analysis:** These are router utility files, not screen files

**Recommendation:** DECIDE
- **Option A:** Rename files to follow convention (e.g., home_router.dart)
- **Option B:** Move to lib/router/ directory
- **Option C:** Update test to allow `_router` suffix for screens directory
- **Action:** ASK RABBLE - Which approach?

### Class Name Mismatches:
- lib/database/tables.dart: Expected class name `Tables`
- lib/database/app_database.g.dart: Expected class name `AppDatabase.g`
- lib/mixins/nostr_list_fetch_mixin.dart: Expected class name `NostrListFetchMixin`
- lib/mixins/async_value_ui_helpers_mixin.dart: Expected class name `AsyncValueUiHelpersMixin`

**Analysis:** Test expects file name to match class name exactly

**Recommendation:** INVESTIGATE
- Check if these are legitimate violations or test is too strict
- *.g.dart files are generated - test should exclude them
- **Action:** UPDATE TEST to exclude .g.dart files, check others

---

## Category 5: POTENTIAL CODE BUGS (Needs Investigation)

### NostrKeyManager Backup Hash Test
**File:** test/unit/nostr_key_manager_test.dart
**Failure:** `should handle backup hash` - Expected: true, Actual: false

**Analysis:** Test expects `verifyBackupHash()` to return true but gets false

**Recommendation:** INVESTIGATE CODE
- Check lib/services/nostr_key_manager.dart::verifyBackupHash()
- This could be a real crypto bug
- **Action:** READ TEST AND CODE to understand expected behavior

### UserAvatar Widget Test
**File:** test/unit/user_avatar_tdd_test.dart
**Failure:** `UserAvatar shows fallback initial when image fails` - Expected text "F", found 0 widgets

**Analysis:** Test expects fallback letter "F" to display when image fails, but it's not rendering

**Recommendation:** INVESTIGATE CODE
- Check lib/widgets/user_avatar.dart fallback logic
- This could be a real UI bug
- **Action:** READ TEST AND CODE

### VideoCacheService Test
**File:** test/unit/services/video_cache_service_basic_test.dart
**Failure:** `should provide cache statistics` - (need error details)

**Recommendation:** INVESTIGATE

### Video Loading Flow Integration Tests (3 failures)
**File:** test/integration/video_loading_flow_test.dart

**Failures:**
- `complete flow: service -> provider -> state emission`
- `flow: seen video reordering works correctly`
- `flow: empty state when gates not satisfied`

**Analysis:** Integration test failures suggest data flow issues

**Recommendation:** INVESTIGATE
- These are end-to-end tests, failures could indicate real bugs
- **Action:** READ TEST to understand expectations

### Future.delayed Detector Tests (3 failures)
**File:** test/tools/future_delayed_detector_test.dart

**Failures:**
- Tests expect exit code 1 when Future.delayed found
- Getting exit code 254 instead

**Analysis:** Tool test itself is broken, not a code issue

**Recommendation:** FIX TEST
- Exit code 254 suggests script execution issue
- **Action:** UPDATE TEST

### File Naming Convention Test (Process Violation)
**File:** test/unit/services/video_event_processor_test.dart

**Failure:** `should forbid Future.delayed usage in non-test code`
- Expected: false (no Future.delayed found)
- Actual: true (Future.delayed found)

**Analysis:** **This is a CRITICAL finding!** Code contains prohibited Future.delayed calls

**From CLAUDE.md:**
> **FORBIDDEN patterns:**
> ```dart
> // ❌ NEVER DO THIS
> await Future.delayed(Duration(milliseconds: 500));
> ```

**Recommendation:** FIX CODE IMMEDIATELY
- Find and remove all Future.delayed calls
- Replace with proper async patterns (Completer, Stream, callbacks)
- **Action:** SEARCH FOR AND FIX (this violates coding standards)

---

## Category 6: WIDGET TEST FAILURES

### HashtagFeedScreen Tests (4 failures)
**File:** test/widget/screens/hashtag_feed_screen_test.dart

**Failures:**
- `should display correct video count` - Expected "2 videos", found 0
- `should show new videos indicator` - Expected "1 new in last 24 hours", found 0
- `should handle single video correctly` - Expected "1 videos", found 0
- Multiple mocktail "No method stub was called" errors

**Analysis:** Combination of provider override errors and mock setup issues

**Recommendation:** FIX TESTS
- Add sharedPreferencesProvider override (Category 3)
- Fix mocktail when() setup
- **Action:** UPDATE TEST

---

## Prioritized Action Plan

### IMMEDIATE (Blocking Real Work)
1. **Fix Future.delayed violations in code** (Category 5)
   - Search codebase for Future.delayed
   - Replace with proper async patterns
   - This violates our strict coding standards

2. **Fix NostrService embedded relay initialization** (Category 2)
   - Investigate why embedded relay not added on construction
   - This appears to be a real bug affecting ~10 tests

### HIGH PRIORITY (Code Quality)
3. **Fix NostrKeyManager backup hash bug** (Category 5)
   - Could be security issue with key verification

4. **Fix UserAvatar fallback display** (Category 5)
   - UI bug affecting user experience

5. **Decide on file naming conventions** (Category 4)
   - Resolve router file naming
   - Update test to exclude .g.dart files

### MEDIUM PRIORITY (Test Infrastructure)
6. **Add provider overrides to widget tests** (Category 3)
   - Add sharedPreferencesProvider overrides
   - Fix ~10 widget tests

7. **Update compilation error tests** (Category 1)
   - Fix API signature mismatches
   - Archive or fix old_files/ tests

8. **Fix VideoEventService deduplication tests** (Category 2)
   - Investigate if bug or mock issue
   - Critical for video feed functionality

### LOW PRIORITY (Nice to Have)
9. **Fix video loading flow integration tests** (Category 5)
   - End-to-end tests, could indicate edge cases

10. **Fix future_delayed_detector tool tests** (Category 5)
    - Tool testing infrastructure, not critical

---

## Recommended Next Steps

**What I need from you, Rabble:**

1. **Do you want me to start fixing these systematically?** I can:
   - Start with Category 1 (compilation errors)
   - Then tackle Category 2 (service issues)
   - Then Category 3 (provider overrides)

2. **File naming decision:** What's your preference?
   - Rename `*_screen_router.dart` to `*_router.dart`?
   - Move them out of screens/ directory?
   - Update test to allow `_router` suffix?

3. **Old files in test/old_files/:** Should I:
   - Archive them (move out of test suite)?
   - Fix them to work with current APIs?
   - Delete them?

4. **Priority override:** Do you want me to tackle a specific category first?

Let me know and I'll systematically work through these using TDD principles!
