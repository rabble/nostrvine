# Login Autofill And Keyboard Recovery Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore password-manager support on the sign-in screen and recover from the known Flutter desktop keyboard-state assertion after logout/resume flows.

**Architecture:** Keep the fix local to the sign-in route and global Flutter error hook. Reuse the existing auth form autofill pattern, and contain the keyboard recovery to the already recognized `HardwareKeyboard` framework failure path.

**Tech Stack:** Flutter, flutter_test, go_router, Riverpod, BLoC

---

## Chunk 1: Login Autofill Structure

### Task 1: Add regression coverage for the login form container

**Files:**
- Modify: `mobile/test/screens/auth/login_options_screen_test.dart`
- Test: `mobile/test/screens/auth/login_options_screen_test.dart`

- [ ] **Step 1: Write the failing test**

Add a widget test that pumps `LoginOptionsScreen` and expects the email/password `DivineAuthTextField`s to live inside both an `AutofillGroup` and a `Form`.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/screens/auth/login_options_screen_test.dart`
Expected: FAIL because the login screen currently has `AutofillGroup` but no `Form`.

- [ ] **Step 3: Write minimal implementation**

Wrap the existing login `AutofillGroup` contents in `Form`, matching the structure already used by `AuthFormScaffold`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/screens/auth/login_options_screen_test.dart`
Expected: PASS

### Task 2: Preserve existing sign-in behavior

**Files:**
- Modify: `mobile/test/screens/auth/login_options_screen_test.dart`
- Test: `mobile/test/screens/auth/login_options_screen_test.dart`

- [ ] **Step 1: Re-run existing login flow assertions**

Use the existing sign-in interaction test coverage as the regression proof that the form wrapper did not change submit behavior.

- [ ] **Step 2: Run test file to verify behavior stays green**

Run: `flutter test test/screens/auth/login_options_screen_test.dart`
Expected: PASS with existing interaction tests still green.

## Chunk 2: Keyboard Recovery

### Task 3: Add focused test coverage for the known Flutter keyboard error path

**Files:**
- Create: `mobile/test/main_keyboard_error_handler_test.dart`
- Modify: `mobile/lib/main.dart`
- Test: `mobile/test/main_keyboard_error_handler_test.dart`

- [ ] **Step 1: Write the failing test**

Extract or expose the keyboard-specific Flutter error handling enough to test that the known `KeyDownEvent`/`HardwareKeyboard` assertion path calls `HardwareKeyboard.clearState()` and returns without delegating.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/main_keyboard_error_handler_test.dart`
Expected: FAIL because the current handler only logs and returns.

- [ ] **Step 3: Write minimal implementation**

Update the keyboard-specific error branch in `main.dart` to clear the stale keyboard state before returning. Keep all other error handling unchanged.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/main_keyboard_error_handler_test.dart`
Expected: PASS

### Task 4: Run focused verification

**Files:**
- Modify: `mobile/lib/main.dart`
- Modify: `mobile/lib/screens/auth/login_options_screen.dart`
- Modify: `mobile/test/screens/auth/login_options_screen_test.dart`
- Create: `mobile/test/main_keyboard_error_handler_test.dart`

- [ ] **Step 1: Run focused verification**

Run: `flutter test test/screens/auth/login_options_screen_test.dart test/main_keyboard_error_handler_test.dart`
Expected: PASS

- [ ] **Step 2: Review diff and commit**

Run:

```bash
git status --short
git diff -- mobile/lib/main.dart mobile/lib/screens/auth/login_options_screen.dart mobile/test/screens/auth/login_options_screen_test.dart mobile/test/main_keyboard_error_handler_test.dart
git add mobile/lib/main.dart mobile/lib/screens/auth/login_options_screen.dart mobile/test/screens/auth/login_options_screen_test.dart mobile/test/main_keyboard_error_handler_test.dart docs/superpowers/specs/2026-03-28-login-autofill-keyboard-design.md docs/superpowers/plans/2026-03-28-login-autofill-keyboard.md
git commit -m "fix(auth): restore login autofill and keyboard recovery"
```

Expected: Clean staged diff and a focused commit on the task branch.
