# Password Manager Autofill (iOS + Android) — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make iOS (iCloud Keychain) and Android (Google Password Manager) reliably offer "Save password?" prompts across every Divine auth flow that creates or changes a password.

**Architecture:** Three parallel fixes, all small. (1) Add the `webcredentials:` associated-domain on iOS so the OS permits save prompts. (2) Call `TextInput.finishAutofillContext(shouldSave: true)` on success in every auth flow that currently mounts `AutofillGroup` but never commits it. (3) Add missing `autofillHints` + `AutofillGroup` wrapping on the two screens that don't have them yet (`ResetPasswordScreen`, `ForgotPasswordSheetContent`).

**Tech Stack:** Flutter 3.x, flutter_bloc + Riverpod (legacy), GoRouter, iOS Associated Domains entitlement, Android Autofill framework (no config needed beyond hints).

---

## Background (read before starting)

**Why these changes are needed** — from research against Flutter + Apple + Android docs:

1. **iOS needs `webcredentials:<domain>`** in `com.apple.developer.associated-domains` **in addition to** `applinks:<domain>` for iCloud Keychain to offer a save prompt. We already have `applinks:divine.video` + `applinks:login.divine.video` but **no `webcredentials:`** entry. Server-side `apple-app-site-association` already declares `webcredentials.apps` — so this is a one-line client-side fix.
2. **`TextInput.finishAutofillContext(shouldSave: true)`** is the reliable cross-platform trigger. On Android it calls `AutofillManager.commit()` (what shows the Google "Save password?" sheet). On iOS it terminates the autofill context, which is one of the triggers iOS uses to prompt save-to-Keychain. `AutofillGroup` auto-calls this on dispose, but with BLoC-driven navigation the timing is non-deterministic, so **we call it explicitly on confirmed success, before `context.go(...)`**.
3. **Android needs nothing** besides `autofillHints` on the field. `minSdk` is already 28 (≥ 26 required). `assetlinks.json` is already hosted.
4. **Never call `finishAutofillContext` on validation failure** — it generates spurious save prompts with bad data. Only on confirmed success.
5. **Anti-patterns to avoid** (documented pitfalls that break autofill on iOS 17.5+): don't add a "show password" eye toggle that rebuilds the field with different widget identity; don't add a confirm-password field with `AutofillHints.newPassword` (it confuses iOS's save pairing); keep `keyboardType: TextInputType.emailAddress` paired with `AutofillHints.email`.
6. **Reset-password limitation:** iCloud Keychain / Google PM ideally need a username field in the same `AutofillGroup` as the new-password field to *update* an existing credential rather than create a duplicate. Our reset flow currently carries only a token (no email) — see Task 5 below. Minimal fix ships without the username field (OS will save as a new entry, not update); plumbing email through is tracked as a follow-up in Task 6.

**Scope bounds — out of scope for this plan:**
- Plumbing email into the reset-password route (tracked as follow-up Task 6; needs backend + link-template change).
- Passkey / WebAuthn integration.
- Sign-in-with-Apple / Google federated flows.

---

## File Structure

**iOS config (1 file modified):**
- `mobile/ios/Runner/Runner.entitlements` — add `webcredentials:divine.video` + `webcredentials:login.divine.video` strings to the existing associated-domains array.

**Flutter screens (4 files modified):**
- `mobile/lib/screens/auth/create_account_screen.dart` — call `TextInput.finishAutofillContext(shouldSave: true)` inside the existing `BlocListener` before `context.go(...)` when state becomes `DivineAuthEmailVerification`.
- `mobile/lib/screens/auth/secure_account_screen.dart` — call `TextInput.finishAutofillContext(shouldSave: true)` at the start of `_continueToApp()` before `context.go(ExploreScreen.path)`.
- `mobile/lib/screens/auth/reset_password.dart` — wrap form in `AutofillGroup` + `Form`, add `autofillHints: [AutofillHints.newPassword]` to password field, call `finishAutofillContext` on success before `context.pop()`.
- `mobile/lib/screens/auth/forgot_password/forgot_password_sheet_content.dart` — add `autofillHints: [AutofillHints.email]` to email field.

**Tests (4 files modified or created):**
- `mobile/test/screens/auth/create_account_screen_test.dart` — add test that `finishAutofillContext` fires on `DivineAuthEmailVerification`.
- `mobile/test/screens/auth/secure_account_screen_test.dart` — add test that `finishAutofillContext` fires on verified-continue path.
- `mobile/test/screens/auth/reset_password_test.dart` — **create** (or extend if it already exists) to verify form wrapping + hint + `finishAutofillContext` on success.
- `mobile/test/screens/auth/forgot_password/forgot_password_sheet_content_test.dart` — assert email field has the hint.

**Test helper (1 new file):**
- `mobile/test/helpers/autofill_context_mock.dart` — shared helper that installs a mock handler on `SystemChannels.textInput` and exposes a list of captured `MethodCall`s so tests can assert `TextInput.finishAutofillContext` was called with `true`.

---

## Chunk 1: iOS entitlement + shared test helper

### Task 1: Add `webcredentials:` to iOS Associated Domains

**Files:**
- Modify: `mobile/ios/Runner/Runner.entitlements:5-10`

**Why:** Without `webcredentials:<domain>` iOS never offers the iCloud Keychain save prompt, regardless of correct hints and `finishAutofillContext` calls. This is the single most common cause of "hints are set but no prompt appears" reports in Flutter repos (flutter/flutter#129346).

- [ ] **Step 1: Modify `Runner.entitlements`**

Open `mobile/ios/Runner/Runner.entitlements`. Inside the `com.apple.developer.associated-domains` `<array>` (currently lines 6–10), add two `<string>` entries alongside the existing `applinks:` entries. Final array should read:

```xml
<key>com.apple.developer.associated-domains</key>
<array>
    <!-- divine.video plus the canonical login hostname -->
    <string>applinks:divine.video</string>
    <string>applinks:login.divine.video</string>
    <string>webcredentials:divine.video</string>
    <string>webcredentials:login.divine.video</string>
</array>
```

- [ ] **Step 2: Verify the AASA file already advertises `webcredentials`**

Run:
```bash
grep -n webcredentials mobile/docs/apple-app-site-association
```
Expected output: a line containing `"webcredentials"` with `"apps": ["GZCZBKH7MY.co.openvine.app"]`. If missing, STOP and surface to the user — server-side support is a precondition for this task and cannot be added by this plan.

- [ ] **Step 3: Build iOS locally to confirm entitlements are accepted**

Run from `mobile/`:
```bash
flutter build ios --debug --no-codesign
```
Expected: build succeeds. A codesigning failure is OK (we passed `--no-codesign`); a plist-parse or "invalid entitlement" failure is NOT OK and must be fixed before committing.

- [ ] **Step 4: Commit**

```bash
git add mobile/ios/Runner/Runner.entitlements
git commit -m "ios: add webcredentials associated domain for iCloud Keychain save"
```

---

### Task 2: Create shared autofill-context test helper

**Files:**
- Create: `mobile/test/helpers/autofill_context_mock.dart`

**Why:** `TextInput.finishAutofillContext` is a static call on the `TextInput` method channel. To assert it fired from a widget test we install a mock handler on `SystemChannels.textInput` and capture method calls. Centralising this keeps screen tests small and consistent.

- [ ] **Step 1: Write the helper**

Create `mobile/test/helpers/autofill_context_mock.dart` with:

```dart
// ABOUTME: Test helper that captures TextInput method-channel calls
// ABOUTME: so tests can assert finishAutofillContext fired with shouldSave=true.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Captures method calls made on [SystemChannels.textInput] during a test.
///
/// Install at the start of a test with [install], then read [calls] or
/// [didFinishAutofillContext] to assert behaviour. The handler is torn
/// down automatically by Flutter's test binding at the end of the test.
class AutofillContextRecorder {
  AutofillContextRecorder._();

  /// Installs the mock handler and returns the recorder.
  static AutofillContextRecorder install() {
    final recorder = AutofillContextRecorder._();
    TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.textInput, (call) async {
      recorder._calls.add(call);
      return null;
    });
    return recorder;
  }

  final List<MethodCall> _calls = [];

  /// Every method call the text-input channel received.
  List<MethodCall> get calls => List.unmodifiable(_calls);

  /// True when `TextInput.finishAutofillContext` was called with
  /// `shouldSave: true` (the default, and the only value we ever send).
  bool get didFinishAutofillContext => _calls.any(
        (call) =>
            call.method == 'TextInput.finishAutofillContext' &&
            call.arguments == true,
      );
}
```

- [ ] **Step 2: Write a smoke test for the helper**

Create `mobile/test/helpers/autofill_context_mock_test.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/test/helpers/autofill_context_mock.dart';

void main() {
  test('captures finishAutofillContext call', () async {
    final recorder = AutofillContextRecorder.install();

    TextInput.finishAutofillContext();

    // Let the async channel microtask drain.
    await Future<void>.delayed(Duration.zero);

    expect(recorder.didFinishAutofillContext, isTrue);
  });

  test('ignores unrelated channel traffic', () async {
    final recorder = AutofillContextRecorder.install();

    await TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .handlePlatformMessage(
      SystemChannels.textInput.name,
      SystemChannels.textInput.codec
          .encodeMethodCall(const MethodCall('TextInput.hide')),
      (_) {},
    );

    expect(recorder.didFinishAutofillContext, isFalse);
  });
}
```

> **Note on the import path:** use the project's existing import style for test files. If the project uses `package:openvine/...` for `lib/` imports, test helpers under `test/helpers/` are imported by tests as `package:openvine/../test/helpers/autofill_context_mock.dart` — check an existing test helper (e.g. `grep -rn "test/helpers" mobile/test | head`) and match that pattern. Most likely this is a relative import; use whatever the project does.

- [ ] **Step 3: Run the helper tests**

Run from `mobile/`:
```bash
flutter test test/helpers/autofill_context_mock_test.dart
```
Expected: 2 tests pass.

- [ ] **Step 4: Commit**

```bash
git add mobile/test/helpers/autofill_context_mock.dart mobile/test/helpers/autofill_context_mock_test.dart
git commit -m "test: add AutofillContextRecorder helper for password-manager tests"
```

---

## Chunk 2: Wire up `finishAutofillContext` in registration flows

### Task 3: CreateAccountScreen — commit autofill on email-verification handoff

**Files:**
- Modify: `mobile/lib/screens/auth/create_account_screen.dart:61-74`
- Modify (test): `mobile/test/screens/auth/create_account_screen_test.dart`

**Why:** `AuthFormScaffold` already wraps email + password in `AutofillGroup` with correct hints. The BLoC emits `DivineAuthEmailVerification` when the signup POST succeeds. That's the "confirmed success" moment — call `finishAutofillContext` *before* `context.go(...)` so the save prompt fires against the still-mounted form.

- [ ] **Step 1: Write a failing test**

In `mobile/test/screens/auth/create_account_screen_test.dart`, add (inside the existing `main()`):

```dart
testWidgets(
  'calls TextInput.finishAutofillContext on DivineAuthEmailVerification',
  (tester) async {
    final recorder = AutofillContextRecorder.install();

    // Use whatever existing harness this file already uses to pump the
    // CreateAccountScreen with a mock DivineAuthCubit. Emit a
    // DivineAuthEmailVerification state and pump.
    final cubit = _MockDivineAuthCubit(); // use existing mock in this file
    whenListen(
      cubit,
      Stream.fromIterable([
        const DivineAuthFormState(/* defaults */),
        const DivineAuthEmailVerification(
          email: 'user@example.com',
          deviceCode: 'device-code',
          verifier: 'verifier',
        ),
      ]),
      initialState: const DivineAuthFormState(/* defaults */),
    );

    await tester.pumpWidget(_buildSubject(cubit: cubit));
    await tester.pump(); // flush BlocListener

    expect(recorder.didFinishAutofillContext, isTrue);
  },
);
```

Add the import: `import '../../helpers/autofill_context_mock.dart';` (match the project's relative-import style).

> If `_MockDivineAuthCubit`, `whenListen`, or `_buildSubject` aren't already defined in this test file, reuse whichever mocking pattern the adjacent tests in the same file use — don't reinvent one. The goal is to trigger `DivineAuthEmailVerification` and observe the channel.

- [ ] **Step 2: Run to verify failure**

```bash
cd mobile && flutter test test/screens/auth/create_account_screen_test.dart --plain-name "finishAutofillContext"
```
Expected: test fails (`didFinishAutofillContext` is false).

- [ ] **Step 3: Make it pass — edit `create_account_screen.dart`**

Add this import near the top of `mobile/lib/screens/auth/create_account_screen.dart`:
```dart
import 'package:flutter/services.dart';
```

Modify the `BlocListener` body (lines 64-74) to call `finishAutofillContext` before navigation:

```dart
listener: (context, state) {
  if (state is DivineAuthEmailVerification) {
    // Signal password managers to save credentials BEFORE we unmount
    // the form via navigation. Keychain / Google PM commit the
    // autofill context when this call fires.
    TextInput.finishAutofillContext();
    final encodedEmail = Uri.encodeComponent(state.email);
    context.go(
      '${EmailVerificationScreen.path}'
      '?deviceCode=${state.deviceCode}'
      '&verifier=${state.verifier}'
      '&email=$encodedEmail',
    );
  }
},
```

- [ ] **Step 4: Run to verify pass**

```bash
cd mobile && flutter test test/screens/auth/create_account_screen_test.dart
```
Expected: all tests in the file pass, including the new one.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/screens/auth/create_account_screen.dart mobile/test/screens/auth/create_account_screen_test.dart
git commit -m "feat(auth): commit autofill context on signup success"
```

---

### Task 4: SecureAccountScreen — commit autofill on continue-to-app

**Files:**
- Modify: `mobile/lib/screens/auth/secure_account_screen.dart:161-165` (`_continueToApp()`)
- Modify (test): `mobile/test/screens/auth/secure_account_screen_test.dart`

**Why:** Same pattern as Task 3, but this screen uses `ConsumerStatefulWidget` + a dialog-driven success path instead of a `BlocListener`. The single exit point to the authenticated app is `_continueToApp()`. Fire the commit there.

- [ ] **Step 1: Write a failing test**

In `mobile/test/screens/auth/secure_account_screen_test.dart`, add:

```dart
testWidgets(
  'calls TextInput.finishAutofillContext when continuing to app',
  (tester) async {
    final recorder = AutofillContextRecorder.install();

    await tester.pumpWidget(_buildSubject(/* existing harness */));
    await tester.pumpAndSettle();

    // Drive the success path used in the adjacent tests — submit the
    // form with a mocked OAuth client returning success, then tap
    // the "Continue" button on the verification dialog. Reuse whatever
    // the existing tests in this file do for this.
    await _completeSignupSuccessfully(tester);
    await _tapContinueOnVerificationDialog(tester);
    await tester.pumpAndSettle();

    expect(recorder.didFinishAutofillContext, isTrue);
  },
);
```

Add import: `import '../../helpers/autofill_context_mock.dart';`

> Use whatever mocking/pumping pattern is already established in this file — the existing tests already verify navigation to `ExploreScreen.path`, so the harness exists.

- [ ] **Step 2: Run to verify failure**

```bash
cd mobile && flutter test test/screens/auth/secure_account_screen_test.dart --plain-name "finishAutofillContext"
```
Expected: test fails.

- [ ] **Step 3: Make it pass — edit `secure_account_screen.dart`**

Add import (if not already present):
```dart
import 'package:flutter/services.dart';
```

Replace `_continueToApp()` (currently lines 161-165):

```dart
void _continueToApp() {
  if (!mounted) return;
  // Signal password managers to save credentials BEFORE we unmount
  // the form via navigation.
  TextInput.finishAutofillContext();
  context.go(ExploreScreen.path);
}
```

Also update the inline `onSuccess` closure at line 151-156 (which navigates directly without going through `_continueToApp`) so it also fires the commit:

```dart
onSuccess: () {
  if (!mounted) return;
  TextInput.finishAutofillContext();
  context.go(ExploreScreen.path);
},
```

- [ ] **Step 4: Run to verify pass**

```bash
cd mobile && flutter test test/screens/auth/secure_account_screen_test.dart
```
Expected: all tests pass.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/screens/auth/secure_account_screen.dart mobile/test/screens/auth/secure_account_screen_test.dart
git commit -m "feat(auth): commit autofill context on secure-account success"
```

---

## Chunk 3: ResetPasswordScreen + ForgotPasswordSheet

### Task 5: ResetPasswordScreen — wrap in AutofillGroup, add hint, commit on success

**Files:**
- Modify: `mobile/lib/screens/auth/reset_password.dart`
- Create: `mobile/test/screens/auth/reset_password_test.dart` (extend if it exists)

**Why:** The reset-password form has no `Form`, no `AutofillGroup`, no hints. Without `AutofillHints.newPassword` the OS has no idea this is a password-change flow, so no prompt fires. Minimal fix: wrap + hint + commit. We do **not** plumb a username field in this task — the route only carries a token, and fixing that requires backend changes. The OS will save as a new entry rather than *update* an existing one; that's an acceptable first pass. Update-existing behaviour is tracked in Task 6 as a follow-up.

- [ ] **Step 1: Write a failing test — hint is present**

Create `mobile/test/screens/auth/reset_password_test.dart` (or extend existing). Add:

```dart
// ABOUTME: Tests for ResetPasswordScreen autofill + success behaviour

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/auth/reset_password.dart';

import '../../helpers/autofill_context_mock.dart';

void main() {
  group(ResetPasswordScreen, () {
    testWidgets('password field has AutofillHints.newPassword', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ResetPasswordScreen(token: 'reset-token'),
          ),
        ),
      );

      final passwordField = tester.widget<DivineAuthTextField>(
        find.byType(DivineAuthTextField),
      );
      expect(
        passwordField.autofillHints,
        contains(AutofillHints.newPassword),
      );
    });

    testWidgets('wraps form in AutofillGroup', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: ResetPasswordScreen(token: 'reset-token'),
          ),
        ),
      );

      expect(find.byType(AutofillGroup), findsOneWidget);
    });

    testWidgets(
      'calls finishAutofillContext on successful reset',
      (tester) async {
        final recorder = AutofillContextRecorder.install();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              // Override oauthClientProvider with a mock that returns
              // ResetPasswordResult(success: true) — match the project's
              // existing test pattern for mocking OAuth client.
              oauthClientProvider.overrideWith(/* ... */),
            ],
            child: const MaterialApp(
              home: ResetPasswordScreen(token: 'reset-token'),
            ),
          ),
        );

        await tester.enterText(
          find.byType(DivineAuthTextField),
          'ValidPass123',
        );
        await tester.tap(find.text('Update password'));
        await tester.pumpAndSettle();

        expect(recorder.didFinishAutofillContext, isTrue);
      },
    );
  });
}
```

> If `DivineAuthTextField` doesn't expose `autofillHints` as a public field, change the assertion to `find.byWidgetPredicate((w) => w is TextField && w.autofillHints?.contains(AutofillHints.newPassword) == true)` — inspect the widget once locally to pick the right assertion form. Do NOT add a new getter to `DivineAuthTextField` just for the test.

> Mocking `oauthClientProvider` should follow whatever the existing tests in `mobile/test/screens/auth/` already do (see how `create_account_screen_test.dart` mocks it) — reuse that pattern.

- [ ] **Step 2: Run to verify failure**

```bash
cd mobile && flutter test test/screens/auth/reset_password_test.dart
```
Expected: all three tests fail.

- [ ] **Step 3: Make them pass — edit `reset_password.dart`**

Add imports:
```dart
import 'package:flutter/services.dart';
```

Replace the password-field region (currently lines 143-157) — wrap it in `AutofillGroup` + `Form`, add the hint. The final structure inside the outer `Column` children should look like:

```dart
// AutofillGroup + Form enables password manager save prompts.
AutofillGroup(
  child: Form(
    child: DivineAuthTextField(
      controller: _passwordController,
      label: 'New Password',
      obscureText: true,
      autofillHints: const [AutofillHints.newPassword],
      errorText: _errorMessage,
      enabled: !_isLoading,
      onChanged: (_) {
        if (_errorMessage != null) {
          setState(() => _errorMessage = null);
        }
      },
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _handleSubmit(),
    ),
  ),
),
```

In `_handleSubmit()` success branch (currently line 67-68), fire the commit before the pop:

```dart
if (result.success) {
  TextInput.finishAutofillContext();
  if (!mounted) return;
  context.pop();
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Password reset successful. Please log in.'),
    ),
  );
}
```

- [ ] **Step 4: Run to verify pass**

```bash
cd mobile && flutter test test/screens/auth/reset_password_test.dart
```
Expected: all three tests pass.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/screens/auth/reset_password.dart mobile/test/screens/auth/reset_password_test.dart
git commit -m "feat(auth): wire reset-password flow into password-manager save"
```

---

### Task 6: ForgotPasswordSheetContent — add email hint

**Files:**
- Modify: `mobile/lib/screens/auth/forgot_password/forgot_password_sheet_content.dart:205-211`
- Modify (test): `mobile/test/screens/auth/forgot_password/forgot_password_sheet_content_test.dart`

**Why:** Pairs the email field with Keychain/Google PM lookup so existing saved emails surface as autofill suggestions. No `finishAutofillContext` call needed here — nothing is being saved at this step (it's a request-a-reset-link flow).

- [ ] **Step 1: Write a failing test**

In the existing test file for this sheet (or create it if it doesn't exist — check with `ls mobile/test/screens/auth/forgot_password/`), add:

```dart
testWidgets('email field has AutofillHints.email', (tester) async {
  await tester.pumpWidget(_buildSubject());

  final emailField = tester.widget<DivineAuthTextField>(
    find.byType(DivineAuthTextField),
  );
  expect(emailField.autofillHints, contains(AutofillHints.email));
});
```

If no test file exists, create `mobile/test/screens/auth/forgot_password/forgot_password_sheet_content_test.dart` with this test and whatever minimal harness the sheet needs (look at how the sheet is wired from its parent screen test for reference).

- [ ] **Step 2: Run to verify failure**

```bash
cd mobile && flutter test test/screens/auth/forgot_password/forgot_password_sheet_content_test.dart
```
Expected: test fails.

- [ ] **Step 3: Make it pass — edit the widget**

At line 205-211 of `forgot_password_sheet_content.dart`, add the hint to the email field:

```dart
DivineAuthTextField(
  label: 'Email',
  controller: emailController,
  keyboardType: TextInputType.emailAddress,
  autocorrect: false,
  autofillHints: const [AutofillHints.email],
  validator: Validators.validateEmail,
),
```

- [ ] **Step 4: Run to verify pass**

```bash
cd mobile && flutter test test/screens/auth/forgot_password/forgot_password_sheet_content_test.dart
```
Expected: test passes.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/screens/auth/forgot_password/forgot_password_sheet_content.dart mobile/test/screens/auth/forgot_password/
git commit -m "feat(auth): add email autofill hint to forgot-password sheet"
```

---

## Chunk 4: Verification + follow-ups

### Task 7: Full test sweep + analyze

- [ ] **Step 1: Run the full test suite**

```bash
cd mobile && flutter test
```
Expected: all tests pass. If a pre-existing unrelated test fails, surface to the user — do not "fix" unrelated failures as part of this plan.

- [ ] **Step 2: Run analyze**

```bash
cd mobile && flutter analyze lib test integration_test
```
Expected: no new issues. Pre-existing warnings are acceptable but do not add any.

- [ ] **Step 3: Run `dart format` check**

```bash
cd mobile && dart format --output=none --set-exit-if-changed lib test
```
Expected: clean. If it fails, run `dart format lib test` and amend into the last relevant commit.

---

### Task 8: Manual verification (required — automated tests cannot prove the OS prompt appears)

**This is the only real verification.** `flutter test` can confirm our code calls `finishAutofillContext`; it cannot prove iOS actually shows the save prompt. That requires a real device and release build.

- [ ] **Step 1: iOS — physical device, TestFlight or release build**

Per Flutter + Apple docs, the save prompt is **frequently suppressed on simulator and debug builds**. Use a real device + archive/TestFlight build.

Test flows on iOS:
1. Fresh install → Create Account → email + new password → submit. Expect "Save Password to iCloud Keychain?" sheet to appear before the verification screen.
2. Existing account → Secure Account → email + new password → submit + verify. Expect save prompt before Explore.
3. Use a password-reset link → enter new password → submit. Expect save prompt (will save as a new entry since we don't pass the email through yet — see follow-up Task 9).
4. Forgot Password sheet → Email field → tap it. Expect Keychain suggestions toolbar above the keyboard for previously saved `divine.video` entries.
5. Login with email + password → submit. Expect save or update prompt if the credential is new.

**iOS caveat:** Associated-domain propagation takes minutes after the first install of a build with new entitlements. If the prompt doesn't appear on the first try, reinstall the app once and retry.

- [ ] **Step 2: Android — physical device, API 26+**

1. Same five flows. Expect Google "Save password?" sheet at the bottom of the screen at the same trigger points.
2. On a device signed into a Google account with Autofill enabled, verify saved credentials appear as suggestions on the login screen.

- [ ] **Step 3: Record results**

Post a quick table in the PR description:

| Flow | iOS save prompt | Android save prompt |
|------|-----------------|---------------------|
| Create Account | ✅ / ❌ | ✅ / ❌ |
| Secure Account | ✅ / ❌ | ✅ / ❌ |
| Reset Password | ✅ / ❌ | ✅ / ❌ |
| Forgot Password (autofill suggestions) | ✅ / ❌ | ✅ / ❌ |
| Login | ✅ / ❌ | ✅ / ❌ |

---

### Task 9 (follow-up — do NOT implement in this plan): Plumb email into reset-password route

**Why separate:** fixing reset-password to *update* existing Keychain entries rather than create new ones requires the OS to see a `username` hint in the same `AutofillGroup` as the new-password field. Our reset route currently carries only a token; the email is not known client-side until we either (a) change the reset link template to include the email, or (b) have the backend return the email in the verify-token response and load it before rendering the form. Both are real product/backend decisions.

- [ ] **Step 1:** File an issue referencing this plan and Task 5, describing:
  - Goal: update (not duplicate) existing password-manager entries on reset.
  - Required: email available on `ResetPasswordScreen`.
  - Options: reset-link template change, or new verify-token API endpoint.
  - Acceptance: `ResetPasswordScreen` has hidden `TextField(readOnly: true, autofillHints: [AutofillHints.username])` populated with the account email inside the existing `AutofillGroup`.

- [ ] **Step 2:** Do not modify any code for this task. This is a tracker only.

---

## Completion checklist

- [ ] Task 1: iOS entitlement committed.
- [ ] Task 2: Shared test helper committed.
- [ ] Task 3: CreateAccountScreen commit-autofill committed.
- [ ] Task 4: SecureAccountScreen commit-autofill committed.
- [ ] Task 5: ResetPasswordScreen AutofillGroup + hint + commit committed.
- [ ] Task 6: ForgotPasswordSheetContent email hint committed.
- [ ] Task 7: Full test sweep + analyze + format clean.
- [ ] Task 8: Manual iOS + Android verification recorded in PR.
- [ ] Task 9: Follow-up issue filed for reset-password email plumbing.
