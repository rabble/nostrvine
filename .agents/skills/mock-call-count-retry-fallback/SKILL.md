---
name: mock-call-count-retry-fallback
description: |
  Fix test failures when adding retry/fallback logic causes mock call count mismatches.
  Use when: (1) Test fails with "Expected: <1>, Actual: <2>" or similar call count errors
  after adding retry or fallback mechanisms, (2) MissingStubError appears for methods
  in new fallback code paths, (3) Mockito verify().called(N) assertions fail after
  behavior changes. Applies to Dart/Flutter with Mockito, but pattern is universal.
author: Claude Code
version: 1.0.0
date: 2026-02-01
---

# Mock Call Count Failures After Adding Retry/Fallback Logic

## Problem

When you add retry logic, fallback mechanisms, or alternative code paths to a service,
existing tests that verify exact mock method call counts will fail. The tests were
written for the original behavior and don't account for the new retry/fallback calls.

## Context / Trigger Conditions

- Test fails with: `Expected: <N>, Actual: <M>` where M > N
- Error message: "Unexpected number of calls"
- `MissingStubError: 'methodName' No stub was found which matches the arguments`
- You recently added:
  - Retry logic (e.g., retry after timeout)
  - Fallback mechanisms (e.g., try primary server, fall back to secondary)
  - Alternative code paths (e.g., try REST API, fall back to WebSocket)
- The failing test uses `verify(...).called(N)` assertions

## Solution

### Step 1: Identify the New Code Paths

Trace through your new retry/fallback logic to understand:
- How many times the mocked method will now be called
- What new methods are being called that weren't before

### Step 2: Mock New Dependencies

If your fallback code calls methods that weren't previously mocked:

```dart
// BEFORE: Only mocked the primary method
when(mockService.primaryMethod(any)).thenAnswer((_) async => 'result');

// AFTER: Also mock fallback-related methods
when(mockService.primaryMethod(any)).thenAnswer((_) async => 'result');
when(mockService.addFallbackServer(any)).thenAnswer((_) async => false);  // Graceful failure
when(mockService.queryFallback(any)).thenAnswer((_) async => []);
```

### Step 3: Update Expected Call Counts

```dart
// BEFORE: Expected single call
verify(mockService.createSubscription(...)).called(1);

// AFTER: Expected calls = initial + retries
// Document WHY the count changed
verify(mockService.createSubscription(...)).called(2);  // initial + retry after fallback
```

### Step 4: Add Comments Explaining the Count

```dart
// Verify subscription was created
// Note: With the indexer fallback logic, createSubscription is called twice:
// 1. First attempt via main relay batch fetch
// 2. Retry attempt after indexer fallback fails
verify(
  mockService.createSubscription(...),
).called(2);
```

## Verification

1. Run the specific test: `flutter test --name "test name"`
2. Verify the test passes
3. Verify the service's actual behavior matches the expected retry count

## Example

**Scenario**: Added indexer relay fallback to profile fetching

**Original behavior**:
- Fetch profile from main relay → 1 subscription created

**New behavior**:
1. Fetch profile from main relay (subscription #1)
2. If not found, try indexer relays
3. If indexers fail, retry main relay (subscription #2)
4. After 2 failures, mark profile as missing

**Test fix**:

```dart
test('should force refresh profile with forceRefresh parameter', () async {
  // Setup mock subscription manager
  when(
    mockSubscriptionManager.createSubscription(...),
  ).thenAnswer((_) async => 'sub_123');

  // Mock addRelay to return false (indexer relays not available)
  // This prevents MissingStubError and simulates unavailable indexers
  when(mockNostrService.addRelay(any)).thenAnswer((_) async => false);

  // ... test setup ...

  await service.fetchProfile(pubkey, forceRefresh: true);

  // Expect 2 calls: initial attempt + retry after indexer fallback
  verify(
    mockSubscriptionManager.createSubscription(...),
  ).called(2);
});
```

## Notes

- **Don't just change the number**: Always understand WHY the count changed
- **Mock fallback paths to fail gracefully**: Return false/empty instead of throwing
- **Consider test isolation**: Some tests may need different mock setups for different scenarios
- **Document behavior changes**: Future maintainers need to understand the expected flow
- **This pattern applies universally**: Java Mockito, Python unittest.mock, Jest, etc.

## Related Patterns

- When adding caching: methods may be called 0 times on cache hit
- When adding circuit breakers: methods may be called fewer times on open circuit
- When adding rate limiting: methods may be delayed or batched

## References

- [Mockito Dart - Verifying Interactions](https://pub.dev/packages/mockito#verifying-interactions)
- [Flutter Testing - Mocking](https://docs.flutter.dev/testing/overview#mock-dependencies-using-mockito)
