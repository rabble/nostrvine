Status: Historical

> Historical note
> Preserved for context during the P1 documentation refresh. This generated cleanup plan is not maintained as a current source of truth.

# Test Cleanup Plan

**Generated**: 2025-10-20
**Total Tests**: 231 passed, 60 failed

## Category 1: Tests for Deleted Features (DELETE)

No tests appear to be for completely deleted features. All test files reference code that still exists in the codebase.

**Count: 0 tests**

## Category 2: Outdated Expectations (UPDATE)

### Kind 32222 Migration (NIP-71 Kind Deprecation)
- [ ] `test/unit/video_event_real_parsing_test.dart` - "should parse kind 32222 event with url tag correctly" - Reason: Kind 32222 is no longer accepted, only (22, 21, 34236, 34235) are valid NIP-71 kinds
- [ ] `test/unit/video_event_real_parsing_test.dart` - "should parse kind 32222 event with r tag correctly" - Reason: Kind 32222 is no longer accepted
- [ ] `test/unit/video_event_real_parsing_test.dart` - "URL validation should accept api.openvine.co URLs" - Reason: Kind 32222 is no longer accepted
- [ ] `test/unit/models/video_event_blurhash_parsing_test.dart` - "should extract blurhash from imeta tag in kind 32222 event" - Reason: Kind 32222 tests need migration to kind 34236
- [ ] `test/unit/models/video_event_blurhash_parsing_test.dart` - "should extract blurhash from another real event format" - Reason: Kind 32222 tests need migration to kind 34236
- [ ] `test/unit/models/video_event_blurhash_parsing_test.dart` - "should handle event without blurhash gracefully" - Reason: Kind 32222 tests need migration to kind 34236

### Classic Vines Priority Ordering
- [ ] `test/unit/services/classic_vines_priority_test.dart` - "should prioritize classic vines at top of feed" - Reason: Expected 4 videos but got 0, sorting/priority logic may have changed
- [ ] `test/unit/services/classic_vines_priority_test.dart` - "should maintain classic vines priority when adding new regular videos" - Reason: Expected 6 videos but got 0
- [ ] `test/unit/services/classic_vines_priority_test.dart` - "should handle multiple classic vines with correct internal ordering" - Reason: Expected 5 videos but got 0
- [ ] `test/unit/services/classic_vines_priority_test.dart` - "should correctly order all priority levels" - Reason: Expected 3 videos but got 0

### Repost Handling
- [ ] `test/unit/services/video_event_processor_test.dart` - "should handle kind 6 repost events" - Reason: Expected false but got true, repost processing logic changed

**Count: 11 tests**

## Category 3: Broken Mocks/Setup (FIX MOCKS)

### Plugin Initialization Issues
- [ ] `test/unit/providers/comments_provider_test.dart` - "Comment Posting should show optimistic update immediately" - Reason: Missing plugin exception for path_provider (MissingPluginException)
- [ ] `test/unit/services/social_service_comment_test.dart` - Multiple tests - Reason: Missing mock stubs or plugin initialization issues
- [ ] `test/unit/services/embedded_relay_performance_unit_test.dart` - Performance tests - Reason: Performance expectations may be environment-dependent, need mock adjustments
- [ ] `test/unit/services/embedded_relay_service_unit_test.dart` - Multiple tests - Reason: Embedded relay mock setup incomplete

### Subscription/Filter Mock Issues
- [ ] `test/unit/services/subscription_manager_filter_test.dart` - "should preserve hashtag filters when optimizing" - Reason: Mock not returning expected filter results
- [ ] `test/unit/services/subscription_manager_filter_test.dart` - "should preserve both hashtag and group filters" - Reason: Mock filter optimization not working correctly
- [ ] `test/unit/services/subscription_manager_filter_test.dart` - "should optimize multiple filters independently" - Reason: Mock filter handling needs update

### Video Service Mock Issues
- [ ] `test/unit/services/video_event_service_deduplication_test.dart` - Multiple tests - Reason: Deduplication logic mocks not matching current implementation
- [ ] `test/unit/services/video_event_service_infinite_scroll_test.dart` - Multiple tests - Reason: Pagination mock setup incomplete
- [ ] `test/unit/services/video_event_service_subscription_test.dart` - "should reject truly duplicate subscriptions" - Reason: Subscription validation mock needs update
- [ ] `test/unit/services/video_event_service_subscription_test.dart` - "should allow multiple author-specific subscriptions" - Reason: Subscription mock logic mismatch

**Count: 11+ tests (many individual test cases within these files)**

## Category 4: Real Bugs (FIX CODE)

### Error Handler Not Working
- [ ] `test/unit/global_error_handler_test.dart` - "OpenVineApp should show user-friendly error when widget throws exception" - Reason: Error boundary not catching widget errors, appears to be a real bug in error handling
- [ ] `test/unit/global_error_handler_test.dart` - "Error widget should show debug information in debug mode only" - Reason: ErrorWidget.builder not configured correctly
- [ ] `test/unit/global_error_handler_test.dart` - "Error boundary should allow retry after error recovery" - Reason: Retry mechanism not implemented

### Upload Manager Path Lookup
- [ ] `test/unit/services/upload_manager_get_by_path_test.dart` - Multiple tests - Reason: getUploadByFilePath not returning expected results, may be real lookup bug

**Count: 4+ tests**

## Category 5: Deprecated Patterns (REFACTOR)

### Future.delayed Usage
- [ ] `test/unit/services/classic_vines_priority_test.dart` - Multiple tests using `await Future.delayed(const Duration(milliseconds: 10))` - Reason: Uses arbitrary delays instead of proper async patterns

### Performance Tests with Arbitrary Expectations
- [ ] `test/unit/services/embedded_relay_performance_unit_test.dart` - "subscription stream creation is fast" - Reason: Performance timing tests are fragile and environment-dependent, should use relative comparisons or remove
- [ ] `test/unit/services/embedded_relay_performance_unit_test.dart` - "multiple relay operations are efficient" - Reason: Same fragility issue
- [ ] `test/unit/services/embedded_relay_performance_unit_test.dart` - "performance comparison demonstrates embedded relay speed advantage" - Reason: Same fragility issue

**Count: 6+ tests**

## Summary by Category

- **Category 1 (DELETE)**: 0 tests
- **Category 2 (UPDATE)**: 11 tests
- **Category 3 (FIX MOCKS)**: ~25 tests
- **Category 4 (FIX CODE)**: ~20 tests
- **Category 5 (REFACTOR)**: ~4 tests

**Total Known Failures**: 60 tests across 13 test files

## Recommended Priority

### 1. Fix Category 4 (Real Bugs) - HIGHEST PRIORITY
Start here - these represent actual functionality issues:
- Global error handler not catching widget errors
- Upload manager path lookup returning wrong results
- Repost handling logic changed unexpectedly

### 2. Update Category 2 (Simple fixes) - QUICK WINS
These are straightforward test updates:
- Update all kind 32222 tests to use kind 34236 (NIP-71 addressable video events)
- Fix classic vines priority test expectations (check if priority logic was intentionally changed)

### 3. Fix Category 3 (Mocks) - MEDIUM EFFORT
These require mock setup fixes:
- Add proper plugin mock initialization (path_provider)
- Update filter/subscription mocks to match current implementation
- Fix video service pagination and deduplication mocks

### 4. Refactor Category 5 (Technical debt) - LOW PRIORITY
These are code quality improvements:
- Replace Future.delayed with proper async patterns (Completers, Streams)
- Remove or fix fragile performance tests

### 5. Delete Category 1 (Obsolete) - N/A
No obsolete tests found.

## Detailed Action Items

### Immediate Actions (Week 1)

1. **Investigate Error Handler Bug**
   - File: `test/unit/global_error_handler_test.dart`
   - Read the error handler implementation
   - Check if ErrorWidget.builder is properly configured in main.dart
   - Fix or document why error boundary isn't working

2. **Fix Kind 32222 Migration**
   - Files: `test/unit/video_event_real_parsing_test.dart`, `test/unit/models/video_event_blurhash_parsing_test.dart`
   - Update all test events from kind 32222 to kind 34236
   - Add "d" tag identifier required for addressable events
   - Verify tests pass with migrated kinds

3. **Debug Classic Vines Priority**
   - File: `test/unit/services/classic_vines_priority_test.dart`
   - Check why discoveryVideos.length is 0 instead of expected count
   - Verify if priority sorting was intentionally changed
   - Update test expectations or fix bug

### Medium-term Actions (Week 2-3)

4. **Fix Mock Setup Issues**
   - Add TestWidgetsFlutterBinding for plugin tests
   - Update subscription manager filter mocks
   - Fix video event service deduplication mocks
   - Update embedded relay service mocks

5. **Remove Future.delayed Anti-pattern**
   - Replace with StreamController + await stream.first
   - Use Completer for async coordination
   - Add proper state change listeners

### Long-term Actions (Month 2)

6. **Performance Test Strategy**
   - Decide: keep, remove, or make relative
   - If keeping: use benchmarks with statistical analysis
   - Document acceptable variance ranges

## Notes

- The 60 failing tests represent ~21% failure rate (60/291 total)
- Most failures are in service layer tests (video_event_service, subscription_manager)
- No integration tests in unit/ directory are failing (good sign)
- Kind 32222 deprecation was likely a recent architectural decision
- Classic vines priority feature may be broken or intentionally disabled

## Migration Guide: Kind 32222 to Kind 34236

### Before (Kind 32222)
```dart
final event = Event(
  'pubkey...',
  32222,  // Old kind
  [
    ["url", "https://api.openvine.co/media/video.mp4"],
    ["m", "video/mp4"],
  ],
  'content',
);
```

### After (Kind 34236)
```dart
final event = Event(
  'pubkey...',
  34236,  // NIP-71 addressable video kind
  [
    ["d", "unique-identifier-123"],  // REQUIRED for addressable events
    ["url", "https://api.openvine.co/media/video.mp4"],
    ["m", "video/mp4"],
  ],
  'content',
);
```

**Key Changes**:
- Kind 32222 → Kind 34236 (or 22, 21, 34235)
- Must include `["d", "identifier"]` tag for addressable events (kinds 34236, 34235)
- Regular video events (kind 22, 21) don't require "d" tag
