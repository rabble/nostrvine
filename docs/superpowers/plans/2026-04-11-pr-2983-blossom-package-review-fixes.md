# PR #2983 Review Fixes Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Resolve the should-fix findings from the code review of divinevideo/divine-mobile#2983 ("refactor: extract blossom_upload_service into its own package") without regressing the package boundary or existing behavior.

**Architecture:** Work on the PR author's branch `refactor/extract-blossom-upload-service` in an isolated worktree. Each task is a self-contained commit that leaves `flutter test` and `flutter analyze` green. The package boundary (no `openvine/` / `nostr_sdk` / `firebase_performance` imports in `mobile/packages/blossom_upload_service/lib/`) is a hard invariant — every task verifies it.

**Tech Stack:** Flutter (managed via `mise`), `flutter_bloc`, `mockito`, `very_good_analysis`, `very_good_workflows` CI template, Hive, GitHub Actions.

**Scope — in this plan:**
- Task 1: Measure and raise `min_coverage` for the new package's CI workflow
- Task 2: Deduplicate the ~4,500 lines of near-identical test files between `mobile/test/services/` and `mobile/packages/blossom_upload_service/test/src/`
- Task 3: Decide the fate of the `currentNpub` field on `BlossomAuthProvider` (remove or cover with a test)
- Task 4: Document the transitive `flutter:` SDK dependency in `pubspec.yaml`

**Scope — explicitly deferred** (separate follow-up PR, not in this plan):
- Introducing a `BlossomServerConfig` interface to lift `SharedPreferences` out of the package (nit #4 in review). Bigger refactor, deserves its own plan.
- Re-adding emoji glyphs to log lines (nit #5). Cosmetic; only revisit if log dashboards actually key on them.

**Ground rules:**
- Work in a worktree; never edit main directly (memory: `feedback_always_use_worktrees`).
- Follow TDD — write or adjust the failing test before changing production code where applicable.
- Commit at the end of each task so the PR history is reviewable.
- Never truncate Nostr IDs in code, logs, tests, or debug output (project rule).
- Do NOT run destructive git commands (no `reset --hard`, no `branch -D`) — ask the user first if needed.

---

## Chunk 1: Setup and Task 1 (CI coverage)

### Task 0: Worktree and branch setup

**Files:**
- No code changes in this task.

- [ ] **Step 1: Create an isolated worktree off the PR branch**

```bash
cd /Users/rabble/code/divine/divine-mobile
git fetch origin refactor/extract-blossom-upload-service
git worktree add ../divine-mobile-pr2983 refactor/extract-blossom-upload-service
cd ../divine-mobile-pr2983
```

Expected: new directory `../divine-mobile-pr2983` checked out on `refactor/extract-blossom-upload-service`.

- [ ] **Step 2: Install git hooks and pub dependencies**

```bash
cd mobile && mise run setup_hooks && mise exec -- flutter pub get
cd packages/blossom_upload_service && mise exec -- flutter pub get
```

Expected: `.git/hooks/pre-commit` and `pre-push` present; both `pub get` commands succeed with no errors.

- [ ] **Step 3: Baseline verification that the branch is green**

```bash
cd /Users/rabble/code/divine/divine-mobile-pr2983/mobile
mise exec -- flutter analyze lib test integration_test
cd packages/blossom_upload_service
mise exec -- flutter analyze
mise exec -- flutter test
```

Expected:
- `flutter analyze lib test integration_test` from `mobile/`: 0 issues.
- `flutter analyze` from the package: 0 issues.
- `flutter test` from the package: 42 pass, 3 skipped.

If any of the above fails, stop and surface to the user — do not start task work on a broken baseline.

---

### Task 1: Raise `min_coverage` on the package CI workflow

**Context:** `.github/workflows/blossom_upload_service.yaml:27` sets `min_coverage: 40`. The project memory rule is "100% test coverage required", and peer package workflows use 80–98 (e.g. `media_cache: 98`, `comments_repository: 80`, `nostr_client: 82`). We will measure the current achieved coverage for the package, then pin `min_coverage` just below it so future regressions are caught without immediately breaking CI.

**Files:**
- Modify: `.github/workflows/blossom_upload_service.yaml:27`

- [ ] **Step 1: Measure actual coverage for the package**

```bash
cd /Users/rabble/code/divine/divine-mobile-pr2983/mobile/packages/blossom_upload_service
mise exec -- flutter test --coverage
```

Expected: `coverage/lcov.info` is created. If `lcov` is installed, generate a summary:

```bash
mise exec -- lcov --summary coverage/lcov.info 2>/dev/null || \
  awk -F: '/^LF:/ {lf+=$2} /^LH:/ {lh+=$2} END {printf "lines: %d/%d = %.1f%%\n", lh, lf, (lh/lf)*100}' coverage/lcov.info
```

Record the percentage (call it `ACTUAL`). It will almost certainly be well above 40 — probably 80–95% given 42 tests against ~2,500 lines of source.

- [ ] **Step 2: Decide the new floor**

Rule: `new_min_coverage = floor(ACTUAL - 2)` clamped to a whole number. The 2-point buffer absorbs small innocuous changes. Examples: actual 92.3 → min 90; actual 78.8 → min 76.

If `ACTUAL < 70`, do NOT silently raise the floor. Instead, flag to the user that the package is under-tested, note it in the PR comment thread, and leave `min_coverage` at 40 for this PR — covering the package back up is out of scope and belongs in a separate test-backfill plan.

- [ ] **Step 3: Update the workflow**

Edit `.github/workflows/blossom_upload_service.yaml:27` — change `min_coverage: 40` to `min_coverage: <new value>`.

- [ ] **Step 4: Sanity-check the workflow still parses**

```bash
cd /Users/rabble/code/divine/divine-mobile-pr2983
python3 -c "import yaml, sys; yaml.safe_load(open('.github/workflows/blossom_upload_service.yaml'))" \
  && echo "workflow YAML parses"
```

Expected: `workflow YAML parses`.

- [ ] **Step 5: Commit**

```bash
cd /Users/rabble/code/divine/divine-mobile-pr2983
git add .github/workflows/blossom_upload_service.yaml
git commit -m "ci(blossom_upload_service): raise min_coverage floor to match reality"
```

---

## Chunk 2: Task 2 (Test deduplication)

**Context:** After the move, six near-identical test files exist:

| App-level copy | Package copy | Lines (app / package) |
|---|---|---|
| `mobile/test/services/blossom_upload_service_test.dart` | `mobile/packages/blossom_upload_service/test/src/blossom_upload_service_test.dart` | ~2,265 / ~2,253 |
| `mobile/test/services/blossom_auth_service_test.dart` | `mobile/packages/blossom_upload_service/test/src/blossom_auth_service_test.dart` | large |
| `mobile/test/services/blossom_upload_proofmode_test.dart` | `mobile/packages/blossom_upload_service/test/src/blossom_upload_proofmode_test.dart` | large |

The CI-parallelization goal (parent issue #2890) is undermined if every edit has to land twice, and the copies will drift. The package tests are the canonical location; the app-level copies should be either deleted or reduced to a tiny adapter-wiring smoke test that protects `_BlossomAuthAdapter` and `_FirebasePerformanceAdapter` in `mobile/lib/providers/app_providers.dart`.

**Strategy:** Before deleting anything, confirm the package copies cover every test group in the app copies. If any app-level test exercises the adapter (i.e. calls through `AuthService` or `PerformanceMonitoringService`), that test belongs in `mobile/test/` because it exercises app-level glue. Anything else is pure package logic and is redundant.

### Task 2: Deduplicate blossom test files

**Files:**
- Delete: `mobile/test/services/blossom_upload_service_test.dart` (partial — keep only adapter-wiring tests, if any)
- Delete: `mobile/test/services/blossom_auth_service_test.dart` (partial — same rule)
- Delete: `mobile/test/services/blossom_upload_proofmode_test.dart` (partial — same rule)
- Possibly create: `mobile/test/providers/app_providers_blossom_adapter_test.dart`

- [ ] **Step 1: Diff the three pairs to confirm equivalence**

```bash
cd /Users/rabble/code/divine/divine-mobile-pr2983/mobile
diff -u test/services/blossom_upload_service_test.dart \
        packages/blossom_upload_service/test/src/blossom_upload_service_test.dart > /tmp/diff_upload.txt
diff -u test/services/blossom_auth_service_test.dart \
        packages/blossom_upload_service/test/src/blossom_auth_service_test.dart > /tmp/diff_auth.txt
diff -u test/services/blossom_upload_proofmode_test.dart \
        packages/blossom_upload_service/test/src/blossom_upload_proofmode_test.dart > /tmp/diff_proofmode.txt
wc -l /tmp/diff_upload.txt /tmp/diff_auth.txt /tmp/diff_proofmode.txt
```

Expected: each diff is small (mostly just import paths flipping between `package:openvine/...` and `package:blossom_upload_service/...`).

- [ ] **Step 2: Classify each `group(...)` in each app-level file**

For each `group(...)` or top-level `test(...)` in the app-level files, decide:
- (A) **Pure package logic** — mocks `Dio` / `http.Client`, tests `BlossomUploadService` or `BlossomAuthService` in isolation. → delete from app.
- (B) **Adapter-wiring** — instantiates the real `AuthService`, real `PerformanceMonitoringService`, or the Riverpod provider graph, and proves the adapter forwards correctly. → keep in app, move to `mobile/test/providers/app_providers_blossom_adapter_test.dart`.
- (C) **Depends on something `openvine/` only has** (e.g. `VideoPublishService`, `UploadManager`, Hive boxes with app-owned types). → keep in app, at current path.

Do this classification pass from the diff output, not by re-reading both files. If a group exists in both files and the only delta is the import line, it's category (A).

- [ ] **Step 3: If there are any category (B) tests, write the failing adapter test first**

If step 2 found adapter-wiring tests worth keeping, extract them into a new file `mobile/test/providers/app_providers_blossom_adapter_test.dart`. Run the new file in isolation to confirm it fails (because it doesn't exist yet) and then compiles:

```bash
mise exec -- flutter test test/providers/app_providers_blossom_adapter_test.dart
```

Expected: RED the first time (either "file not found" or a real failing test), then GREEN after you fill it in.

If there are no category (B) tests, skip this step.

- [ ] **Step 4: Delete category (A) test groups from the three app-level files**

Use `Edit` to surgically remove only the redundant `group(...)` blocks. Do NOT blanket-delete the files unless every group in them is category (A) — if the entire file is category (A), delete the whole file.

Likely outcome: all three app-level files are entirely category (A) and get deleted in full.

- [ ] **Step 5: Verify both test surfaces still pass**

```bash
cd /Users/rabble/code/divine/divine-mobile-pr2983/mobile
mise exec -- flutter test test/ 2>&1 | tail -5
cd packages/blossom_upload_service
mise exec -- flutter test 2>&1 | tail -5
```

Expected:
- Package: 42 pass, 3 skipped (unchanged from baseline).
- App: total count drops by roughly the number of tests removed. No new failures.

- [ ] **Step 6: Verify nothing else was importing the deleted files**

```bash
cd /Users/rabble/code/divine/divine-mobile-pr2983
grep -rn "test/services/blossom_upload_service_test\|test/services/blossom_auth_service_test\|test/services/blossom_upload_proofmode_test" mobile/ || echo "no stale references"
```

Expected: `no stale references`.

- [ ] **Step 7: Analyzer sanity check**

```bash
cd /Users/rabble/code/divine/divine-mobile-pr2983/mobile
mise exec -- flutter analyze lib test integration_test
```

Expected: 0 issues.

- [ ] **Step 8: Commit**

```bash
cd /Users/rabble/code/divine/divine-mobile-pr2983
git add -A mobile/test mobile/packages/blossom_upload_service/test
git commit -m "test(blossom_upload_service): remove app-level test duplicates after package extraction"
```

---

## Chunk 3: Task 3 and Task 4

### Task 3: Resolve the unused `currentNpub` field on `BlossomAuthProvider`

**Context:** `mobile/packages/blossom_upload_service/lib/src/blossom_auth_provider.dart:29` declares `String? get currentNpub;`. The review found it's only forwarded through `BlossomAuthService.currentUserPubkey` (`blossom_auth_service.dart:220`) and that getter has no in-package callers. It's either dead weight on the contract or it's silently required by an app-level caller.

**Before deleting anything, verify.** The field might be part of the public API that app-level code depends on, in which case the right move is to add a test that exercises it, not to remove it.

**Files:**
- Modify: `mobile/packages/blossom_upload_service/lib/src/blossom_auth_provider.dart`
- Modify: `mobile/packages/blossom_upload_service/lib/src/blossom_auth_service.dart`
- Modify: `mobile/lib/providers/app_providers.dart` (the `_BlossomAuthAdapter` class)
- Possibly modify: `mobile/packages/blossom_upload_service/test/src/blossom_auth_service_test.dart`

- [ ] **Step 1: Search for every consumer of `currentNpub` and `currentUserPubkey`**

```bash
cd /Users/rabble/code/divine/divine-mobile-pr2983
grep -rn "currentNpub\|currentUserPubkey" mobile/lib mobile/test mobile/integration_test mobile/packages/blossom_upload_service
```

Record every hit. Expected hits include:
- The interface declaration
- The `BlossomAuthService` getter
- The adapter in `app_providers.dart`
- Possibly test files

- [ ] **Step 2: Decide path A or path B based on findings**

- **Path A — remove the field.** Pick this if the ONLY consumers are the interface itself, the adapter, and the unused package getter. No production code actually reads the value.
- **Path B — cover the field with a test.** Pick this if any production call site in `mobile/lib/` or any integration test reads `currentUserPubkey` or `currentNpub` and expects a real value.

State your decision explicitly as a comment at the top of the task before proceeding.

- [ ] **Step 3A: If Path A, remove the field**

1. Delete the `currentNpub` getter from `blossom_auth_provider.dart` (the 3 lines of doc + declaration).
2. Delete the `currentUserPubkey` getter from `blossom_auth_service.dart`.
3. Delete the `currentNpub` override in `_BlossomAuthAdapter` in `app_providers.dart`.
4. Re-run both analyzers and both test surfaces:

```bash
cd /Users/rabble/code/divine/divine-mobile-pr2983/mobile/packages/blossom_upload_service
mise exec -- flutter analyze && mise exec -- flutter test
cd /Users/rabble/code/divine/divine-mobile-pr2983/mobile
mise exec -- flutter analyze lib test integration_test
mise exec -- flutter test test/providers test/services 2>&1 | tail -5
```

Expected: all green. If analyzer finds an unknown override or unknown method, you missed a consumer from step 1 — restore the field, re-run step 1 with a wider grep (including `.g.dart`, `.mocks.dart`, generated files), and pivot to Path B.

- [ ] **Step 3B: If Path B, add a direct test**

Add a test to `mobile/packages/blossom_upload_service/test/src/blossom_auth_service_test.dart` that:
- Constructs a `BlossomAuthService` with a fake `BlossomAuthProvider` whose `currentNpub` returns a full npub (never truncate).
- Asserts `service.currentUserPubkey` forwards the exact npub.
- Asserts `null` is forwarded when the provider returns `null`.

Example shape:

```dart
group('currentUserPubkey', () {
  test('forwards currentNpub from the provider', () {
    const npub = 'npub1exampleexampleexampleexampleexampleexampleexampleexampleexampleexample';
    final provider = _FakeAuthProvider(currentNpub: npub, isAuthenticated: true);
    final service = BlossomAuthService(authProvider: provider);
    expect(service.currentUserPubkey, equals(npub));
  });

  test('returns null when the provider has no active user', () {
    final provider = _FakeAuthProvider(currentNpub: null, isAuthenticated: false);
    final service = BlossomAuthService(authProvider: provider);
    expect(service.currentUserPubkey, isNull);
  });
});
```

Run the new test:

```bash
cd /Users/rabble/code/divine/divine-mobile-pr2983/mobile/packages/blossom_upload_service
mise exec -- flutter test --plain-name "currentUserPubkey"
```

Expected: 2 pass.

- [ ] **Step 4: Verify the package still has no leaks**

```bash
cd /Users/rabble/code/divine/divine-mobile-pr2983
grep -rn "package:openvine/\|package:nostr_sdk/\|package:firebase_performance/" mobile/packages/blossom_upload_service/lib || echo "package boundary intact"
```

Expected: `package boundary intact`.

- [ ] **Step 5: Commit**

Pick one message, depending on which path you took:

```bash
# Path A
git add mobile/packages/blossom_upload_service mobile/lib/providers/app_providers.dart
git commit -m "refactor(blossom_upload_service): drop unused currentNpub from auth interface"

# Path B
git add mobile/packages/blossom_upload_service/test
git commit -m "test(blossom_upload_service): cover BlossomAuthService.currentUserPubkey forwarding"
```

---

### Task 4: Document the transitive `flutter:` SDK dependency

**Context:** `mobile/packages/blossom_upload_service/pubspec.yaml` declares `flutter: sdk: flutter` but the package's `lib/` has zero direct Flutter imports (the grep passes clean). The Flutter SDK is only pulled in transitively by `flutter_test` and `image_metadata_stripper`. A future reader will wonder why it's there and might innocently delete it. A one-line comment prevents that.

**Files:**
- Modify: `mobile/packages/blossom_upload_service/pubspec.yaml`

- [ ] **Step 1: Add an explanatory comment above the `flutter:` entry**

Locate the `dependencies:` block in `mobile/packages/blossom_upload_service/pubspec.yaml` and add, immediately above the `flutter:` SDK line:

```yaml
  # Required transitively by flutter_test (dev) and image_metadata_stripper.
  # The lib/ sources do NOT import dart:ui or any flutter/* package — the
  # package is a pure Dart data layer. Do not remove without first confirming
  # both transitive deps are gone.
  flutter:
    sdk: flutter
```

- [ ] **Step 2: Confirm `pub get` still resolves**

```bash
cd /Users/rabble/code/divine/divine-mobile-pr2983/mobile/packages/blossom_upload_service
mise exec -- flutter pub get
```

Expected: resolves cleanly, no errors.

- [ ] **Step 3: Re-verify the package boundary claim in the comment**

```bash
grep -rn "package:flutter/\|dart:ui" mobile/packages/blossom_upload_service/lib || echo "no flutter imports in lib/"
```

Expected: `no flutter imports in lib/`. If this fails, the comment is a lie — delete the comment and surface the finding to the user before continuing.

- [ ] **Step 4: Commit**

```bash
cd /Users/rabble/code/divine/divine-mobile-pr2983
git add mobile/packages/blossom_upload_service/pubspec.yaml
git commit -m "docs(blossom_upload_service): explain transitive flutter SDK dependency"
```

---

## Chunk 4: Final verification and handoff

### Task 5: End-to-end verification

- [ ] **Step 1: Fresh `pub get` and codegen check**

```bash
cd /Users/rabble/code/divine/divine-mobile-pr2983/mobile
mise exec -- flutter pub get
cd packages/blossom_upload_service
mise exec -- flutter pub get
```

Expected: both resolve. If any `build_runner` inputs were touched (none expected in this plan), also run:

```bash
cd /Users/rabble/code/divine/divine-mobile-pr2983/mobile
mise exec -- dart run build_runner build --delete-conflicting-outputs
```

- [ ] **Step 2: Full analyzer sweep**

```bash
cd /Users/rabble/code/divine/divine-mobile-pr2983/mobile
mise exec -- flutter analyze lib test integration_test
cd packages/blossom_upload_service
mise exec -- flutter analyze
```

Expected: 0 issues from both.

- [ ] **Step 3: Full test sweep for affected surfaces**

```bash
cd /Users/rabble/code/divine/divine-mobile-pr2983/mobile/packages/blossom_upload_service
mise exec -- flutter test
cd /Users/rabble/code/divine/divine-mobile-pr2983/mobile
mise exec -- flutter test test/providers test/services test/models test/blocs 2>&1 | tail -10
```

Expected:
- Package: 42 pass, 3 skipped, OR (42 + new count from Path B) pass, 3 skipped.
- App: all blossom-related suites green. Total count reduced by the deduplicated tests from Task 2.

- [ ] **Step 4: Re-run the package boundary check one last time**

```bash
cd /Users/rabble/code/divine/divine-mobile-pr2983
grep -rn "package:openvine/\|package:nostr_sdk/\|package:firebase_performance/\|package:flutter/\|dart:ui" mobile/packages/blossom_upload_service/lib || echo "boundary intact"
```

Expected: `boundary intact`.

- [ ] **Step 5: Push to the PR branch and update the PR**

```bash
cd /Users/rabble/code/divine/divine-mobile-pr2983
git log --oneline origin/refactor/extract-blossom-upload-service..HEAD
```

Review the commit list — should be 3 or 4 commits matching the tasks above. Then push:

```bash
git push origin refactor/extract-blossom-upload-service
```

**STOP HERE if the PR author is not rabble.** Since PR #2983 is authored by `realmeylisdev`, pushing directly to their branch may require explicit permission. Before pushing, confirm with the user whether to:
- (a) push directly to the fork branch (requires write access),
- (b) open a follow-up PR targeting the same branch,
- (c) post the commits as suggested changes in the PR review instead.

Default: (c). Do not push without explicit user approval.

- [ ] **Step 6: Post a PR comment summarizing the changes**

Use `gh pr comment 2983 --repo divinevideo/divine-mobile --body-file -` with a short note linking each commit to its review finding. Example body:

```markdown
Addressed should-fix findings from review:

- `ci: raise min_coverage to N` — Task 1 in plan
- `test: remove app-level test duplicates` — Task 2
- `refactor: drop currentNpub` (or `test: cover currentUserPubkey`) — Task 3
- `docs: explain transitive flutter dep` — Task 4

Deferred to follow-up:
- `BlossomServerConfig` interface to lift `SharedPreferences` out of the package
- Decision on whether to restore emoji in log lines
```

Expected: comment posted.

---

## Remember
- Never truncate Nostr IDs anywhere (code, logs, tests, debug output).
- Dark-mode only — no theme work in this plan, but don't introduce `Colors.*` anywhere.
- Package `lib/` has a hard boundary: no `package:openvine/`, `package:nostr_sdk/`, `package:firebase_performance/`, `package:flutter/`, or `dart:ui` imports. Every task re-verifies this.
- Commit after each task. Do NOT squash during development.
- If `min_coverage` measurement shows the package is under 70% covered, STOP Task 1 and surface to user — don't silently accept a low floor.
- If Task 3 Step 1 turns up a production caller you missed, pivot to Path B without hesitation. Deleting a field that's silently used is worse than keeping dead code.
