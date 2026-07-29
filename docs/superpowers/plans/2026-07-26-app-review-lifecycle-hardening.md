# App Review Lifecycle Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prevent in-app review prompts from surviving account/lifecycle changes and make eligibility use refreshed profile statistics.

**Architecture:** Keep the existing coordinator widget and Cubit boundary. Pass a live account/lifecycle predicate through the Cubit, make Cubit shutdown cancellation-safe, and introduce a feature-local bounded stats loader that refreshes before reading Drift.

**Tech Stack:** Flutter, Riverpod, flutter_bloc, ProfileRepository, flutter_test

---

### Task 1: Make Cubit evaluation cancellation-safe

**Files:**
- Modify: `mobile/test/features/app_review/app_review_coordinator_cubit_test.dart`
- Modify: `mobile/lib/features/app_review/app_review_coordinator_cubit.dart`

- [ ] **Step 1: Write failing lifecycle tests**

Add a test that starts `evaluate`, closes the Cubit while the fake frame
scheduler is pending, completes the scheduler, and expects the evaluation to
complete without a platform request. Add a second test whose active predicate
changes to false while a completer-backed `isAvailable` call is pending and
expects no cooldown or request.

```dart
test('stops cleanly when closed during frame wait', () async {
  final evaluation = cubit.evaluate(
    inputs: inputs(),
    isActive: () => true,
  );
  await cubit.close();
  frameScheduler.complete();

  await expectLater(evaluation, completes);
  expect(platform.requests, 0);
});
```

- [ ] **Step 2: Run tests and verify the post-close case fails**

Run:

```bash
cd mobile
mise exec -- flutter test test/features/app_review/app_review_coordinator_cubit_test.dart
```

Expected: failure from emitting after `close()` or from the missing
`isActive` API.

- [ ] **Step 3: Implement the minimal Cubit guards**

Rename the callback to `isActive`, return immediately when `isClosed`, check
both `isClosed` and `isActive()` after async boundaries, and guard the final
emit:

```dart
bool canContinue() => !isClosed && isActive();

if (isClosed || state) return;
emit(true);
try {
  await _evaluate(inputs: inputs, isActive: isActive);
} finally {
  if (!isClosed) emit(false);
}
```

- [ ] **Step 4: Run the Cubit tests and verify they pass**

Run the command from Step 2. Expected: all Cubit tests pass.

### Task 2: Refresh profile stats before reading the cache

**Files:**
- Create: `mobile/lib/features/app_review/app_review_profile_stats_loader.dart`
- Create: `mobile/test/features/app_review/app_review_profile_stats_loader_test.dart`
- Modify: `mobile/lib/features/app_review/app_review_coordinator.dart`

- [ ] **Step 1: Write failing loader tests**

Create tests proving the watcher is not subscribed until the refresh completes,
the refreshed row is returned, and refresh errors/timeouts return null.

```dart
final refresh = Completer<void>();
var refreshed = false;
final result = loader.load(
  refresh: () async {
    await refresh.future;
    refreshed = true;
  },
  watch: () => Stream.value(refreshed ? freshStats : staleStats),
);

expect(refreshed, isFalse);
refresh.complete();
expect(await result, freshStats);
```

- [ ] **Step 2: Run the loader test and verify it fails**

Run:

```bash
cd mobile
mise exec -- flutter test test/features/app_review/app_review_profile_stats_loader_test.dart
```

Expected: compile failure because `AppReviewProfileStatsLoader` does not exist.

- [ ] **Step 3: Implement the bounded refresh-first loader**

Create `AppReviewProfileStatsLoader` with a three-second default timeout:

```dart
Future<ProfileStats?> load({
  required Future<void> Function() refresh,
  required Stream<ProfileStats?> Function() watch,
}) async {
  try {
    return await (() async {
      await refresh();
      return watch().whereType<ProfileStats>().first;
    })().timeout(timeout);
  } on Object {
    return null;
  }
}
```

Update the coordinator to call the loader with
`fetchFreshProfile(pubkey: pubkey)` before `watchProfileStats`.

- [ ] **Step 4: Run the loader and coordinator tests**

Run:

```bash
cd mobile
mise exec -- flutter test \
  test/features/app_review/app_review_profile_stats_loader_test.dart \
  test/features/app_review/app_review_coordinator_cubit_test.dart
```

Expected: all tests pass.

### Task 3: Bind the coordinator to the active account

**Files:**
- Modify: `mobile/lib/features/app_review/app_review_coordinator.dart`
- Modify: `mobile/test/features/app_review/app_review_coordinator_cubit_test.dart`

- [ ] **Step 1: Add the live active-context predicate**

Implement a widget helper that returns true only while the original pubkey is
still authenticated, the widget is mounted, and the app remains foreground:

```dart
bool _isActiveFor(String pubkey) {
  if (!mounted || !ref.read(appForegroundProvider)) return false;
  final authService = ref.read(authServiceProvider);
  return authService.authState == AuthState.authenticated &&
      authService.currentPublicKeyHex == pubkey;
}
```

Check it after profile-stat loading and pass it through `evaluate`.

- [ ] **Step 2: Run focused review tests**

Run:

```bash
cd mobile
mise exec -- flutter test \
  test/features/app_review/app_review_coordinator_cubit_test.dart \
  test/features/app_review/app_review_profile_stats_loader_test.dart \
  test/services/app_review_prompt_service_test.dart
```

Expected: all tests pass.

### Task 4: Verify and publish

**Files:**
- Verify all files changed by Tasks 1–3.

- [ ] **Step 1: Run formatting and guardrails**

```bash
cd mobile
mise exec -- dart format --output=none --set-exit-if-changed \
  lib/features/app_review \
  test/features/app_review
bash scripts/check_process_global_mutations.sh
```

Expected: both commands exit zero.

- [ ] **Step 2: Run analysis**

```bash
cd mobile
mise exec -- flutter analyze
```

Expected: no issues found.

- [ ] **Step 3: Commit and push**

Stage only the design, plan, app-review production files, and their tests.
Commit with:

```bash
git commit -m "fix(review): cancel stale prompt evaluations"
git push origin HEAD:feat/in-app-review-prompt
```

- [ ] **Step 4: Monitor PR checks**

Run:

```bash
gh pr checks 6399 --repo divinevideo/divine-mobile --watch
```

Expected: every required check passes on the pushed head.

