---
name: mockito-stale-mock-silent-trycatch-failure
description: |
  Fix misleading Flutter/Dart test failures where expected data is empty ([]) or
  default values instead of the mocked response, caused by stale Mockito generated
  mocks or missing stubs being silently swallowed by try/catch in provider/repository
  code. Use when: (1) Test expects non-empty data but gets [], (2) Mock stubs for a
  method are set up but the code under test returns fallback/empty results, (3) A PR
  added new methods to a service class and tests that previously passed now fail with
  misleading "expected X, actual: empty" assertions, (4) "Generated files are out of
  date" CI error alongside test failures. The root cause is MissingStubError thrown by
  unstubbed mock methods, caught by production try/catch blocks, causing silent fallback
  to empty state.
author: Claude Code
version: 1.0.0
date: 2026-02-17
---

# Mockito Stale Mock + Silent Try/Catch Test Failures

## Problem
When a PR adds new methods to a service class (e.g., `AnalyticsApiService`), and those
methods are called from existing code paths that are wrapped in try/catch blocks, tests
fail with misleading symptoms. The test assertion shows `Expected: non-empty, Actual: []`
or `Expected: true, Actual: false` — but the actual root cause is a `MissingStubError`
being silently caught.

## Context / Trigger Conditions

- **Symptom**: Test expects data (non-empty list, specific values) but gets empty/default
- **No obvious error**: No `MissingStubError` in test output because production code catches it
- **PR context**: The PR added new methods to a `@GenerateMocks`-annotated service class
- **CI also shows**: "Generated files are out of date" (stale `.g.dart` / `.mocks.dart`)
- **Existing tests were passing** before the PR's changes

### The Failure Chain

```
1. PR adds method `getBulkVideoViews()` to AnalyticsApiService
2. PR adds `_enrichVideosWithBulkStats()` to HomeFeedProvider.build()
3. _enrichVideosWithBulkStats calls getBulkVideoViews (new method)
4. Generated mock is stale — doesn't have getBulkVideoViews at all
5. Even if regenerated, test setUp doesn't stub getBulkVideoViews
6. Mock throws MissingStubError when unstubbed method is called
7. Provider's try/catch catches ALL exceptions (including MissingStubError)
8. Provider falls back to empty state → test sees [] instead of expected data
```

## Solution

### Step 1: Regenerate mocks

```bash
dart run build_runner build --delete-conflicting-outputs
```

This updates all `.g.dart` and `.mocks.dart` files to include new methods.

### Step 2: Identify new method calls in modified code paths

Trace the code path from the test's entry point. Look for any method calls on mocked
services that were added or modified by the PR. Pay special attention to methods called
**after** the already-stubbed method (e.g., enrichment/post-processing steps).

### Step 3: Add stubs for ALL methods in the call chain

```dart
// In test setUp():

// Existing stub (was already there)
when(mockService.getHomeFeed(
  pubkey: anyNamed('pubkey'),
  limit: anyNamed('limit'),
)).thenAnswer((_) async => HomeFeedResult(videos: mockVideos));

// NEW stubs needed for enrichment methods added by PR
when(mockService.getBulkVideoStats(
  argThat(isA<List<String>>()),  // non-nullable positional param
)).thenAnswer((_) async => <String, BulkVideoStatsEntry>{});

when(mockService.getBulkVideoViews(
  argThat(isA<List<String>>()),  // non-nullable positional param
  maxVideos: anyNamed('maxVideos'),
  maxConcurrent: anyNamed('maxConcurrent'),
)).thenAnswer((_) async => <String, int>{});
```

### Step 4: Handle non-nullable parameters

Mockito's `any` returns `null` which fails for non-nullable params. Use:

- `argThat(isA<List<String>>())` for non-nullable positional params
- `anyNamed('paramName')` works for named params with default values
  (but NOT for non-nullable named params without defaults)

## Verification

After fixing:
1. Run the specific test file: `flutter test test/path/to/test.dart`
2. Confirm previously failing assertions now pass
3. Run full test suite to check for no regressions

## Example

**Before (failing)**:
```
Expected: non-empty
  Actual: []

  test/providers/home_feed_loading_fix_test.dart 253:9
```

**Root cause**: `_enrichVideosWithBulkStats` called `getBulkVideoStats` (unstubbed) →
`MissingStubError` → caught by provider try/catch → empty fallback state.

**Fix**: Added stubs in `setUp()` for `getBulkVideoStats` and `getBulkVideoViews`.

**After (passing)**: All 11 tests pass, including the 2 that were failing.

## Notes

- **Always regenerate mocks when a PR modifies `@GenerateMocks`-annotated classes**.
  The `.mocks.dart` files must match the current interface.
- **Check the full call chain**, not just the primary method. A `getHomeFeed` stub is
  useless if the provider then calls `enrichVideos` which calls 2 more unstubbed methods.
- **This pattern is invisible in test output**. The `MissingStubError` is caught by
  production error handling. You'll never see it unless you add temporary `print`
  statements inside the catch block or use `@GenerateNiceMocks` (which returns defaults
  instead of throwing, potentially masking different bugs).
- **Non-nullable params in Dart null-safety**: Mockito `any` returns `null` at the type
  level. For non-nullable positional params, use `argThat(isA<Type>())` which returns a
  properly typed matcher.

## References

- [Mockito Dart - Null Safety](https://pub.dev/packages/mockito#null-safety)
- [build_runner documentation](https://pub.dev/packages/build_runner)
