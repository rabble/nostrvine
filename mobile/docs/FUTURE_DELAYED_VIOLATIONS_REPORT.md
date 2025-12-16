# Future.delayed Violations Report
**Date:** November 12, 2025
**Total Violations:** 30 occurrences across 23 files
**Status:** 🚨 CRITICAL - Violates CLAUDE.md strict async standards

## Executive Summary

Found **30 violations** of the forbidden `Future.delayed()` pattern across the codebase. According to `CLAUDE.md`:

> **FORBIDDEN patterns:**
> ```dart
> // ❌ NEVER DO THIS
> await Future.delayed(Duration(milliseconds: 500));
> await Future.delayed(Duration(seconds: 2));
> Timer(Duration(milliseconds: 100), () => checkAgain());
> ```

**Good news:** We already have `lib/utils/async_utils.dart` with proper async patterns:
- `AsyncUtils.waitForCondition()` - for polling
- `AsyncUtils.retryWithBackoff()` - for retries
- `AsyncUtils.waitForStreamValue()` - for streams
- `AsyncUtils.executeWithRateLimit()` - for rate limiting

**Bad news:** Code isn't using these utilities consistently.

---

## Violations by Category

### CATEGORY 1: POLLING LOOPS (4 violations) - WORST OFFENDERS
**Pattern:** `while (!condition) { await Future.delayed(...) }`
**Proper Fix:** Use `AsyncUtils.waitForCondition()`

#### lib/services/vine_recording_controller.dart (4 occurrences)
**Lines:** 190, 240, 297, 1197

**Current Code:**
```dart
while (_operationInProgress && waitCount < maxWaitMs / 10) {
  await Future.delayed(const Duration(milliseconds: 10));
  waitCount++;
}
```

**Proper Fix:**
```dart
await AsyncUtils.waitForCondition(
  condition: () => !_operationInProgress,
  timeout: Duration(milliseconds: maxWaitMs),
  checkInterval: Duration(milliseconds: 10),
  debugName: 'VineRecordingController camera operation',
);
```

**Impact:** HIGH - Camera operations are critical path, polling adds unnecessary latency

---

### CATEGORY 2: TIMEOUT PATTERNS (5 violations)
**Pattern:** `Future.any([operation, Future.delayed(...)])`
**Proper Fix:** Use timeout parameter in AsyncUtils methods

#### lib/services/curation_service.dart (3 occurrences)
**Lines:** 195, 354, 691

**Current Code:**
```dart
await Future.any([
  completer.future,
  Future.delayed(const Duration(seconds: 5)),
]);
```

**Proper Fix:**
```dart
await AsyncUtils.waitForStreamValue(
  stream: eventStream,
  timeout: Duration(seconds: 5),
  debugName: 'Curation service event',
);
```

#### lib/providers/latest_videos_provider.dart (1 occurrence)
**Line:** 191

**Pattern:** Similar timeout pattern

#### lib/services/analytics_api_service.dart (1 occurrence)
**Line:** 624

**Pattern:** Similar timeout pattern

**Impact:** MEDIUM - Timeout is legitimate use case, but should use proper timeout mechanisms

---

### CATEGORY 3: RETRY PATTERNS (2 violations)
**Pattern:** Retry loops with delay between attempts
**Proper Fix:** Use `AsyncUtils.retryWithBackoff()`

#### lib/services/video_processing_service.dart (2 occurrences)
**Lines:** 107, 129

**Current Code:**
```dart
for (int attempt = 1; attempt <= maxAttempts; attempt++) {
  try {
    // ... operation ...
  } catch (e) {
    await Future.delayed(pollInterval);
  }
}
```

**Proper Fix:**
```dart
await AsyncUtils.retryWithBackoff(
  operation: () async {
    // ... operation ...
  },
  maxAttempts: maxAttempts,
  initialDelay: pollInterval,
  debugName: 'Video processing poll',
);
```

**Impact:** MEDIUM - Retry logic should use exponential backoff

---

### CATEGORY 4: RATE LIMITING (1 violation)
**Pattern:** Delay in loop to rate-limit requests
**Proper Fix:** Use `AsyncUtils.executeWithRateLimit()`

#### lib/providers/analytics_providers.dart (1 occurrence)
**Line:** 235

**Current Code:**
```dart
for (final video in videos) {
  await trackVideoView(video, source: source);
  await Future.delayed(const Duration(milliseconds: 100));
}
```

**Proper Fix:**
```dart
await AsyncUtils.executeWithRateLimit(
  items: videos,
  operation: (video) => trackVideoView(video, source: source),
  delayBetween: Duration(milliseconds: 100),
  debugName: 'Analytics batch tracking',
);
```

**Impact:** LOW - Rate limiting is intentional, but should use proper utility

---

### CATEGORY 5: ANIMATION/UI COORDINATION (1 violation)
**Pattern:** Waiting for animation to complete
**Proper Fix:** Use animation controller callbacks

#### lib/screens/video_feed_screen.dart (1 occurrence)
**Line:** 295

**Current Code:**
```dart
// Animation is 500ms
await scrollController.animateTo(..., duration: Duration(milliseconds: 500));

// Wait for scroll to complete
Future.delayed(const Duration(milliseconds: 600), _handleRefresh);
```

**Proper Fix:**
```dart
await scrollController.animateTo(..., duration: Duration(milliseconds: 500));
// Animation completes when Future completes, no delay needed!
_handleRefresh();
```

**Impact:** LOW - But creates race condition (what if animation slows down?)

---

### CATEGORY 6: STARTUP/BACKGROUND DELAYS (4 violations)
**Pattern:** Delaying low-priority background tasks
**Proper Fix:** Use proper startup coordinator priority system

#### lib/main.dart (1 occurrence)
**Line:** 890

**Current Code:**
```dart
StartupPerformanceService.instance.deferUntilUIReady(() async {
  await Future.delayed(const Duration(seconds: 2)); // Extra delay for low priority
  // ... background task ...
});
```

**Proper Fix:**
```dart
StartupPerformanceService.instance.deferWithPriority(
  priority: Priority.backgroundSync,
  task: () async {
    // ... background task ...
  },
);
```

#### lib/features/app/startup/startup_coordinator.dart (1 occurrence)
**Line:** 189

#### lib/services/bookmark_sync_worker.dart (1 occurrence)
**Line:** 91

**Current Code:**
```dart
Future.delayed(const Duration(seconds: 2), () => syncSets());
```

**Proper Fix:**
```dart
// Use startup priority system instead of arbitrary delay
```

#### lib/services/background_activity_manager.dart (1 occurrence)
**Line:** 152

**Impact:** MEDIUM - Startup performance matters, but background tasks are lower priority

---

### CATEGORY 7: UI FEEDBACK DELAYS (3 violations)
**Pattern:** Showing success message for "long enough" to read
**Proper Fix:** Use proper UI feedback patterns (SnackBar with duration)

#### lib/screens/pure/video_metadata_screen_pure.dart (2 occurrences)
**Lines:** 917, 1277

**Current Code:**
```dart
// Show success message for longer so user can see it
await Future.delayed(const Duration(milliseconds: 1200));
```

**Proper Fix:**
```dart
// Use SnackBar with proper duration instead
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('Success message'),
    duration: Duration(milliseconds: 1200),
  ),
);
```

#### lib/screens/profile_setup_screen.dart (1 occurrence)
**Line:** 924

**Impact:** LOW - UI feedback, but hardcoded timing is fragile

---

### CATEGORY 8: CAMERA/VIDEO INITIALIZATION (3 violations)
**Pattern:** "Wait a bit" for hardware/frame to be ready
**Proper Fix:** Use proper initialization completion callbacks

#### lib/screens/pure/vine_preview_screen_pure.dart (1 occurrence)
**Line:** 472

**Current Code:**
```dart
// Wait a bit for the frame to be ready
await Future.delayed(const Duration(milliseconds: 100));
```

**Proper Fix:**
```dart
// Use video player initialization callback instead
await videoController.initialize();
```

#### lib/screens/pure/universal_camera_screen_pure.dart (1 occurrence)
**Line:** 1119

#### lib/services/video_first_frame_service.dart (1 occurrence)
**Line:** 60

**Impact:** HIGH - Camera initialization should use proper callbacks, not guesses

---

### CATEGORY 9: CONNECTION/RELAY DELAYS (3 violations)
**Pattern:** "Wait a bit" for connections to establish
**Proper Fix:** Use connection status callbacks

#### lib/screens/relay_diagnostic_screen.dart (1 occurrence)
**Line:** 187

**Current Code:**
```dart
// Wait a bit for connections to establish
await Future.delayed(const Duration(seconds: 2));
```

**Proper Fix:**
```dart
await AsyncUtils.waitForCondition(
  condition: () => relayService.isConnected,
  timeout: Duration(seconds: 5),
  debugName: 'Relay connection',
);
```

#### lib/services/nostr_service.dart (1 occurrence)
**Line:** 643

**Current Code:**
```dart
// Wait before closing embedded relay's storage stream
Future.delayed(const Duration(seconds: 2), () async {
  // ... cleanup ...
});
```

**Proper Fix:**
```dart
// Wait for pending operations to complete properly
await AsyncUtils.waitForCondition(
  condition: () => !hasPendingOperations,
  timeout: Duration(seconds: 2),
  debugName: 'Embedded relay cleanup',
);
```

#### lib/services/nostr_service_web.dart (1 occurrence)
**Line:** 228

#### lib/services/connection_status_service.dart (1 occurrence)
**Line:** 79

**Impact:** HIGH - Connection timing is unpredictable, arbitrary delays cause bugs

---

### CATEGORY 10: SERVICE INITIALIZATION (2 violations)
**Pattern:** Generic "wait a bit" for service initialization
**Proper Fix:** Use proper initialization completion

#### lib/services/analytics_service.dart (1 occurrence)
**Line:** 265

#### lib/services/upload_initialization_helper.dart (1 occurrence)
**Line:** 214

**Impact:** MEDIUM - Service initialization should be deterministic

---

### CATEGORY 11: OTHER/MISC (1 violation)

#### lib/scripts/bulk_thumbnail_generator.dart (1 occurrence)
**Line:** 255

**Pattern:** Script delay between operations

**Impact:** LOW - Script code, not production

#### lib/widgets/video_feed_item.dart (1 occurrence)
**Line:** 207

**Pattern:** Unknown (need to inspect)

---

## Summary by Impact

### 🔴 CRITICAL (Fix Immediately) - 11 violations
1. **Polling loops (4)** - vine_recording_controller.dart
2. **Camera initialization (3)** - Camera timing guesses
3. **Connection timing (3)** - Relay connection guesses
4. **Animation coordination (1)** - Race condition

### 🟡 HIGH PRIORITY - 10 violations
5. **Retry patterns (2)** - video_processing_service.dart
6. **Service initialization (2)** - Various services
7. **Startup delays (4)** - main.dart, startup_coordinator.dart, etc.
8. **Video processing (2)** - video_processing_service.dart

### 🟢 MEDIUM PRIORITY - 9 violations
9. **Timeout patterns (5)** - curation_service.dart, etc.
10. **UI feedback (3)** - Screen success messages
11. **Rate limiting (1)** - analytics_providers.dart

---

## Prioritized Fix Plan

### Phase 1: Fix CRITICAL Polling Loops (HIGH RISK)
**Files:** lib/services/vine_recording_controller.dart

**Why Critical:** Camera is critical path, polling adds latency and can cause race conditions

**Action:**
```dart
// Replace all 4 polling loops with:
await AsyncUtils.waitForCondition(
  condition: () => !_operationInProgress,
  timeout: Duration(milliseconds: maxWaitMs),
  checkInterval: Duration(milliseconds: 10),
  debugName: 'Camera operation lock',
);
```

**Estimated Time:** 30 minutes
**Risk:** LOW - AsyncUtils.waitForCondition is well-tested

---

### Phase 2: Fix Camera/Video Initialization (HIGH RISK)
**Files:**
- lib/screens/pure/vine_preview_screen_pure.dart
- lib/screens/pure/universal_camera_screen_pure.dart
- lib/services/video_first_frame_service.dart

**Why Critical:** Hardware timing is unpredictable, arbitrary delays cause bugs

**Action:** Replace with proper initialization callbacks from camera/video controller

**Estimated Time:** 1 hour
**Risk:** MEDIUM - Need to verify callbacks exist in camera plugin

---

### Phase 3: Fix Connection Timing (HIGH RISK)
**Files:**
- lib/screens/relay_diagnostic_screen.dart
- lib/services/nostr_service.dart
- lib/services/nostr_service_web.dart
- lib/services/connection_status_service.dart

**Why Critical:** Network timing is unpredictable

**Action:** Replace with `AsyncUtils.waitForCondition()` checking connection status

**Estimated Time:** 1 hour
**Risk:** LOW - Connection status is already tracked

---

### Phase 4: Fix Retry Patterns
**Files:** lib/services/video_processing_service.dart

**Action:** Use `AsyncUtils.retryWithBackoff()` with exponential backoff

**Estimated Time:** 30 minutes
**Risk:** LOW - Direct replacement

---

### Phase 5: Fix Timeout Patterns
**Files:** curation_service.dart, latest_videos_provider.dart, analytics_api_service.dart

**Action:** Use timeout parameter in AsyncUtils methods

**Estimated Time:** 45 minutes
**Risk:** LOW - Timeout logic already exists

---

### Phase 6: Fix Startup/Background Delays
**Files:** main.dart, startup_coordinator.dart, bookmark_sync_worker.dart, background_activity_manager.dart

**Action:** Implement proper priority system in StartupPerformanceService

**Estimated Time:** 1-2 hours
**Risk:** MEDIUM - Needs architectural change

---

### Phase 7: Fix UI/Misc (Lower Priority)
**Files:** video_feed_screen.dart, video_metadata_screen_pure.dart, etc.

**Action:** Case-by-case fixes

**Estimated Time:** 1 hour
**Risk:** LOW

---

## Total Estimated Time: 6-7 hours

---

## Recommended Approach

**Option A: Fix All at Once (1 focused session)**
- Dedicate 1 day to systematically fix all violations
- Test thoroughly with existing test suite
- High risk of breaking things, but gets it done

**Option B: Fix by Phase (3-4 sessions)**
- Fix Phase 1-3 first (CRITICAL - 3-4 hours)
- Test and verify
- Fix Phase 4-7 later (MEDIUM/LOW - 3 hours)
- Lower risk, iterative approach

**Option C: Fix Opportunistically (Slow but Safe)**
- Fix violations as you touch files
- Add rule to pre-commit hook to prevent new violations
- Slow but zero risk

---

## Recommendation

**I recommend Option B: Fix by Phase**

1. **This week:** Fix Phase 1-3 (CRITICAL violations)
   - Polling loops (camera)
   - Camera/video initialization
   - Connection timing

2. **Next week:** Fix Phase 4-7 (remaining violations)
   - Retry patterns
   - Timeout patterns
   - Startup delays
   - UI/misc

3. **Add pre-commit hook** to prevent new violations

---

## Pre-commit Hook Proposal

Add to `.claude/pre-commit.sh`:
```bash
# Check for forbidden Future.delayed usage
echo "Checking for Future.delayed violations..."
DELAYED_VIOLATIONS=$(git diff --cached --name-only | grep "\.dart$" | xargs grep -l "Future.delayed" | grep -v "async_utils.dart" | grep -v "test/" || true)

if [ ! -z "$DELAYED_VIOLATIONS" ]; then
  echo "❌ ERROR: Future.delayed usage found in:"
  echo "$DELAYED_VIOLATIONS"
  echo ""
  echo "Use AsyncUtils instead:"
  echo "  - AsyncUtils.waitForCondition() for polling"
  echo "  - AsyncUtils.retryWithBackoff() for retries"
  echo "  - AsyncUtils.waitForStreamValue() for streams"
  echo "  - AsyncUtils.executeWithRateLimit() for rate limiting"
  exit 1
fi
```

---

## Next Steps

Rabble, what's your preference?

1. **Start fixing Phase 1-3 now?** (CRITICAL violations - ~3 hours)
2. **Fix all 30 violations in one go?** (~6-7 hours)
3. **Add pre-commit hook first, fix opportunistically?**
4. **Something else?**

Let me know and I'll start systematically replacing these violations with proper async patterns!
