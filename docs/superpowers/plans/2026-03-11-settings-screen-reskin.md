# Settings Screen Reskin Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the approved Figma-style reskin for the main settings screen without removing any current settings functionality or auth-driven behavior.

**Architecture:** Keep existing handlers, routing, and services in `SettingsScreen`, but replace the presentation layer with a smaller set of Figma-style UI primitives. Split the new visual building blocks into a dedicated settings widgets file so the screen owns behavior and composition while the new widgets own styling and row layout.

**Tech Stack:** Flutter, Riverpod, go_router, `divine_ui`, widget tests, optional golden verification

---

## Chunk 1: Lock The New Structure With Failing Tests

### Task 1: Rewrite the main settings widget test around the new information architecture

**Files:**
- Modify: `mobile/test/widgets/settings_screen_test.dart`
- Reference: `mobile/lib/screens/settings_screen.dart`

- [ ] **Step 1: Replace the skipped section assertions with a real failing structure test**

```dart
testWidgets('Settings screen groups rows using the new Figma-style sections', (
  tester,
) async {
  await tester.pumpWidget(buildSettingsScreen(
    authState: AuthState.authenticated,
    isAnonymous: false,
  ));
  await tester.pumpAndSettle();

  expect(find.text('Preferences'), findsOneWidget);
  expect(find.text('Nostr Settings'), findsOneWidget);
  expect(find.text('Support'), findsOneWidget);
  expect(find.text('Account Tools'), findsOneWidget);
  expect(find.text('Danger Zone'), findsOneWidget);

  expect(find.text('Notifications'), findsOneWidget);
  expect(find.text('Safety & Privacy'), findsOneWidget);
  expect(find.text('Relays'), findsOneWidget);
  expect(find.text('Media Servers'), findsOneWidget);
  expect(find.textContaining('Version '), findsOneWidget);
});
```

- [ ] **Step 2: Run the test to verify it fails for the current layout**

Run:

```bash
cd mobile
flutter test test/widgets/settings_screen_test.dart
```

Expected: FAIL because the current screen still renders the older uppercase sections and old tile structure.

- [ ] **Step 3: Add a second failing regression test for preserved menu options**

```dart
testWidgets('Settings screen keeps advanced and destructive actions reachable', (
  tester,
) async {
  await tester.pumpWidget(buildSettingsScreen(
    authState: AuthState.authenticated,
    isAnonymous: false,
  ));
  await tester.pumpAndSettle();

  await tester.scrollUntilVisible(
    find.text('Developer Options'),
    200,
    scrollable: find.byType(Scrollable),
  );

  expect(find.text('Developer Options'), findsOneWidget);
  expect(find.text('Key Management'), findsOneWidget);
  expect(find.text('Remove Keys from Device'), findsOneWidget);
  expect(find.text('Delete Account and Data'), findsOneWidget);
});
```

- [ ] **Step 4: Run the same test file again and confirm the new regression test also fails for the right reason**

Run:

```bash
cd mobile
flutter test test/widgets/settings_screen_test.dart
```

Expected: FAIL on missing section names or misplaced rows, not on provider/bootstrap errors.

- [ ] **Step 5: Commit the failing-test checkpoint**

```bash
git add mobile/test/widgets/settings_screen_test.dart
git commit -m "test(settings): define reskinned settings screen structure"
```

## Chunk 2: Build The New Figma-Style Row System

### Task 2: Extract visual primitives for the new settings layout

**Files:**
- Create: `mobile/lib/widgets/settings/settings_screen_components.dart`
- Modify: `mobile/lib/screens/settings_screen.dart`
- Test: `mobile/test/widgets/settings_screen_test.dart`

- [ ] **Step 1: Create the new visual primitives file**

Add widgets for:

```dart
class SettingsSectionHeading extends StatelessWidget { ... }
class SettingsNavigationRow extends StatelessWidget { ... }
class SettingsToggleRow extends StatelessWidget { ... }
class SettingsFooterRow extends StatelessWidget { ... }
```

Each row should:
- default to no leading icon
- use subtle divider lines
- render a chevron for navigational rows
- support optional subtitle text
- support destructive tint for danger actions

- [ ] **Step 2: Update `SettingsScreen` to compose the new sections using those primitives**

The body should follow this order:

```dart
[
  _buildAccountSummaryBlock(...),
  const SettingsSectionHeading(title: 'Preferences'),
  ...preferenceRows,
  const SettingsSectionHeading(title: 'Nostr Settings'),
  ...nostrRows,
  const SettingsSectionHeading(title: 'Support'),
  ...supportRows,
  const SettingsSectionHeading(title: 'Account Tools'),
  ...accountRows,
  const SettingsSectionHeading(title: 'Danger Zone'),
  ...dangerRows,
  SettingsFooterRow(label: 'Version $_appVersion'),
]
```

- [ ] **Step 3: Keep existing handlers and route pushes intact while swapping only the presentation layer**

Do not change:
- auth-state branching
- Zendesk/support fallback logic
- log export behavior
- key management and delete-account handlers
- language picker and existing modal flows

- [ ] **Step 4: Run the structure test file and get it green**

Run:

```bash
cd mobile
flutter test test/widgets/settings_screen_test.dart
```

Expected: PASS

- [ ] **Step 5: Commit the new row system**

```bash
git add mobile/lib/screens/settings_screen.dart mobile/lib/widgets/settings/settings_screen_components.dart mobile/test/widgets/settings_screen_test.dart
git commit -m "feat(settings): reskin settings list layout"
```

## Chunk 3: Add The Account Summary Block And Auth-State Coverage

### Task 3: Replace the old top profile tiles with the new account summary block

**Files:**
- Create: `mobile/test/widgets/settings_screen_account_block_test.dart`
- Modify: `mobile/lib/screens/settings_screen.dart`
- Modify: `mobile/lib/widgets/settings/settings_screen_components.dart`

- [ ] **Step 1: Add a failing widget test for authenticated account summary content**

```dart
testWidgets('authenticated users see the account summary and switch account row', (
  tester,
) async {
  await tester.pumpWidget(buildSettingsScreen(
    authState: AuthState.authenticated,
    isAnonymous: false,
  ));
  await tester.pumpAndSettle();

  expect(find.text('Switch Account'), findsOneWidget);
  expect(find.textContaining('currently logged in'), findsOneWidget);
});
```

- [ ] **Step 2: Add a failing widget test for anonymous or expired-session messaging**

```dart
testWidgets('anonymous users see secure your account in the account summary', (
  tester,
) async {
  await tester.pumpWidget(buildSettingsScreen(
    authState: AuthState.authenticated,
    isAnonymous: true,
  ));
  await tester.pumpAndSettle();

  expect(find.text('Secure Your Account'), findsOneWidget);
});
```

Add a second variant for expired OAuth session if the existing mock helper makes that easy.

- [ ] **Step 3: Implement the new account summary block with Figma-style spacing and typography**

Add a private builder in `SettingsScreen`:

```dart
Widget _buildAccountSummaryBlock({
  required bool isAuthenticated,
  required AuthService authService,
}) { ... }
```

Requirements:
- top-most content block under the app bar
- concise explanatory copy
- reuses existing switch/secure/session recovery actions
- no new business logic

- [ ] **Step 4: Run the account summary tests and existing settings widget test together**

Run:

```bash
cd mobile
flutter test test/widgets/settings_screen_test.dart test/widgets/settings_screen_account_block_test.dart
```

Expected: PASS

- [ ] **Step 5: Commit the account summary slice**

```bash
git add mobile/lib/screens/settings_screen.dart mobile/lib/widgets/settings/settings_screen_components.dart mobile/test/widgets/settings_screen_account_block_test.dart mobile/test/widgets/settings_screen_test.dart
git commit -m "feat(settings): add figma-style account summary block"
```

## Chunk 4: Clean Up Verification And Visual Regression Coverage

### Task 4: Update the remaining settings verification surface

**Files:**
- Modify: `mobile/test/widgets/settings_screen_scaffold_test.dart`
- Modify: `mobile/test/goldens/screens/settings_screen_golden_test.dart`
- Modify: `mobile/test/goldens/screens/goldens/settings_screen_*.png` (if goldens are intentionally refreshed)

- [ ] **Step 1: Update scaffold assertions only if the reskin changes anything those tests should still care about**

Keep these checks meaningful:
- the screen still uses the expected dark background
- the screen still renders the standard app bar path

Remove stale expectations tied to the old `AppBar` implementation if `DiVineAppBar` no longer exposes them reliably.

- [ ] **Step 2: Re-enable or replace the settings golden test with a focused dark-mode layout capture**

Prefer a single stable case first:

```dart
testGoldens('SettingsScreen dark layout', (tester) async {
  await tester.pumpWidgetBuilder(
    createSettingsScreen(),
    wrapper: (child) => MaterialApp(
      theme: ThemeData.dark(),
      themeMode: ThemeMode.dark,
      home: child,
    ),
    surfaceSize: const Size(402, 874),
  );

  await screenMatchesGolden(tester, 'settings_screen_dark');
});
```

- [ ] **Step 3: Run the targeted widget tests**

Run:

```bash
cd mobile
flutter test test/widgets/settings_screen_test.dart test/widgets/settings_screen_account_block_test.dart test/widgets/settings_screen_scaffold_test.dart
```

Expected: PASS

- [ ] **Step 4: Run the settings golden verification**

Run:

```bash
cd mobile
./scripts/golden.sh verify test/goldens/screens/settings_screen_golden_test.dart
```

Expected:
- PASS if existing goldens already match
- or FAIL with intentional diff, followed by:

```bash
cd mobile
./scripts/golden.sh update test/goldens/screens/settings_screen_golden_test.dart
```

- [ ] **Step 5: Review the diff and commit the verification updates**

```bash
git add mobile/test/widgets/settings_screen_scaffold_test.dart mobile/test/goldens/screens/settings_screen_golden_test.dart mobile/test/goldens/screens/goldens/settings_screen_*.png
git commit -m "test(settings): refresh reskinned settings verification"
```

## Final Verification

- [ ] Run the full targeted verification pass:

```bash
cd mobile
flutter test test/widgets/settings_screen_test.dart test/widgets/settings_screen_account_block_test.dart test/widgets/settings_screen_scaffold_test.dart
./scripts/golden.sh verify test/goldens/screens/settings_screen_golden_test.dart
```

- [ ] Review the final diff carefully:

```bash
git status --short
git diff --stat
git log --oneline -5
```

- [ ] If everything is green, hand off for code review or continue with the branch-finishing workflow.
