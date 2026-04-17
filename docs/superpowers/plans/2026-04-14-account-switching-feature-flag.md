# Account Switching Feature Flag Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Hide account switching behind the existing feature-flag system so the settings entry point is disabled by default but can still be re-enabled for testing.

**Architecture:** Extend the existing typed feature-flag enum and build-configuration mapping, then gate both the Settings UI and `SettingsAccountCubit` behavior with the new flag. Use TDD so the widget and cubit behavior are proven in both disabled and enabled states before implementation lands.

**Tech Stack:** Flutter, Riverpod, flutter_bloc, SharedPreferences-backed feature flags, flutter_test, bloc_test, mocktail

---

## File Map

- Modify: `mobile/lib/features/feature_flags/models/feature_flag.dart`
  Add the new typed feature flag entry and user-facing metadata.
- Modify: `mobile/lib/features/feature_flags/services/build_configuration.dart`
  Add the new build-time environment key and default.
- Modify: `mobile/lib/screens/settings/settings_screen.dart`
  Hide the account action control when the new flag is disabled and pass the flag state into the account header.
- Modify: `mobile/lib/blocs/settings_account/settings_account_cubit.dart`
  Inject the existing feature-flag service and guard switch/add actions when disabled.
- Modify: `mobile/test/widgets/settings_screen_test.dart`
  Cover disabled and enabled rendering behavior.
- Modify: `mobile/test/blocs/settings_account/settings_account_cubit_test.dart`
  Cover disabled and enabled cubit behavior.

## Chunk 1: Widget-Level Flag Coverage

### Task 1: Add a failing widget test for the disabled default

**Files:**
- Modify: `mobile/test/widgets/settings_screen_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('hides the account action when account switching is disabled', (
  tester,
) async {
  await tester.pumpWidget(buildSubject(
    knownAccounts: twoAccounts,
  ));
  await tester.pumpAndSettle();

  expect(find.text('Switch account'), findsNothing);
  expect(find.text('Add another account'), findsNothing);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/widgets/settings_screen_test.dart --plain-name "hides the account action when account switching is disabled"`
Expected: FAIL because the button still renders today.

- [ ] **Step 3: Write the minimal implementation**

```dart
final accountSwitchingEnabled = ref.watch(
  isFeatureEnabledProvider(FeatureFlag.accountSwitching),
);

_AccountHeader(
  onSwitchAccount: _handleSwitchAccount,
  accountSwitchingEnabled: accountSwitchingEnabled,
)
```

```dart
if (accountSwitchingEnabled)
  DivineButton(...)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/widgets/settings_screen_test.dart --plain-name "hides the account action when account switching is disabled"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/screens/settings/settings_screen.dart mobile/test/widgets/settings_screen_test.dart
git commit -m "fix(settings): hide account action when account switching is disabled"
```

### Task 2: Preserve enabled-path widget behavior

**Files:**
- Modify: `mobile/test/widgets/settings_screen_test.dart`
- Modify: `mobile/lib/features/feature_flags/models/feature_flag.dart`
- Modify: `mobile/lib/features/feature_flags/services/build_configuration.dart`

- [ ] **Step 1: Write the failing test**

```dart
testWidgets('renders Switch account button when flag is enabled', (
  tester,
) async {
  sharedPreferences.setBool('feature_flag_accountSwitching', true);

  await tester.pumpWidget(buildSubject(knownAccounts: twoAccounts));
  await tester.pumpAndSettle();

  expect(find.text('Switch account'), findsOneWidget);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/widgets/settings_screen_test.dart --plain-name "renders Switch account button when flag is enabled"`
Expected: FAIL because `FeatureFlag.accountSwitching` does not exist yet.

- [ ] **Step 3: Write the minimal implementation**

```dart
enum FeatureFlag {
  ...
  accountSwitching(
    'Account Switching',
    'Enable switching between remembered accounts in Settings',
  ),
}
```

```dart
case FeatureFlag.accountSwitching:
  return const bool.fromEnvironment('FF_ACCOUNT_SWITCHING');
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/widgets/settings_screen_test.dart --plain-name "renders Switch account button when flag is enabled"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/features/feature_flags/models/feature_flag.dart mobile/lib/features/feature_flags/services/build_configuration.dart mobile/test/widgets/settings_screen_test.dart
git commit -m "feat(flags): add account switching feature flag"
```

## Chunk 2: Cubit Guardrails

### Task 3: Add failing cubit tests for disabled behavior

**Files:**
- Modify: `mobile/test/blocs/settings_account/settings_account_cubit_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
blocTest<SettingsAccountCubit, SettingsAccountState>(
  'does nothing when switching is disabled',
  seed: () => SettingsAccountState(
    status: SettingsAccountStatus.loaded,
    accounts: testAccounts,
    currentPubkey: testAccounts.first.pubkeyHex,
  ),
  build: buildCubit,
  act: (cubit) => cubit.switchToAccount(testAccounts.last.pubkeyHex),
  verify: (_) {
    verifyNever(() => mockAuthService.pendingAccountSwitchPubkey = any());
    verifyNever(() => mockAuthService.signOut());
  },
);
```

```dart
blocTest<SettingsAccountCubit, SettingsAccountState>(
  'does nothing when add account is disabled',
  build: buildCubit,
  act: (cubit) => cubit.addNewAccount(),
  verify: (_) {
    verifyNever(() => mockAuthService.signOut());
  },
);
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd mobile && flutter test test/blocs/settings_account/settings_account_cubit_test.dart`
Expected: FAIL because the cubit still calls through unconditionally.

- [ ] **Step 3: Write the minimal implementation**

```dart
if (!_featureFlagService.isEnabled(FeatureFlag.accountSwitching)) return;
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd mobile && flutter test test/blocs/settings_account/settings_account_cubit_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/blocs/settings_account/settings_account_cubit.dart mobile/test/blocs/settings_account/settings_account_cubit_test.dart
git commit -m "fix(settings): guard account switching actions behind feature flag"
```

## Chunk 3: Verification And Cleanup

### Task 4: Run focused verification and inspect the diff

**Files:**
- Modify: `mobile/lib/features/feature_flags/models/feature_flag.dart`
- Modify: `mobile/lib/features/feature_flags/services/build_configuration.dart`
- Modify: `mobile/lib/screens/settings/settings_screen.dart`
- Modify: `mobile/lib/blocs/settings_account/settings_account_cubit.dart`
- Modify: `mobile/test/widgets/settings_screen_test.dart`
- Modify: `mobile/test/blocs/settings_account/settings_account_cubit_test.dart`

- [ ] **Step 1: Run the targeted widget test file**

Run: `cd mobile && flutter test test/widgets/settings_screen_test.dart`
Expected: PASS.

- [ ] **Step 2: Run the targeted cubit test file**

Run: `cd mobile && flutter test test/blocs/settings_account/settings_account_cubit_test.dart`
Expected: PASS.

- [ ] **Step 3: Inspect the task diff**

Run: `git diff -- mobile/lib/features/feature_flags/models/feature_flag.dart mobile/lib/features/feature_flags/services/build_configuration.dart mobile/lib/screens/settings/settings_screen.dart mobile/lib/blocs/settings_account/settings_account_cubit.dart mobile/test/widgets/settings_screen_test.dart mobile/test/blocs/settings_account/settings_account_cubit_test.dart docs/superpowers/specs/2026-04-14-account-switching-feature-flag-design.md docs/superpowers/plans/2026-04-14-account-switching-feature-flag.md`
Expected: only the planned account-switching flag changes and the new docs.

- [ ] **Step 4: Create the final commit**

```bash
git add docs/superpowers/specs/2026-04-14-account-switching-feature-flag-design.md docs/superpowers/plans/2026-04-14-account-switching-feature-flag.md mobile/lib/features/feature_flags/models/feature_flag.dart mobile/lib/features/feature_flags/services/build_configuration.dart mobile/lib/screens/settings/settings_screen.dart mobile/lib/blocs/settings_account/settings_account_cubit.dart mobile/test/widgets/settings_screen_test.dart mobile/test/blocs/settings_account/settings_account_cubit_test.dart
git commit -m "fix(settings): gate account switching behind feature flag"
```
