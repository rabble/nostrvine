# Feature-Flagged Light Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a locally persisted System/Light/Dark appearance preference behind default-off feature flags, with semantic Divine light/dark tokens and a separately switchable adaptive media-chrome experiment.

**Architecture:** `divine_ui` owns `VineTheme.lightTheme`, `VineTheme.darkTheme`, and a typed `VineThemeColors` `ThemeExtension`. The app owns an `AppearanceRepository` and `AppearanceCubit`; the root resolves `ThemeMode` from the Cubit and gates it with `FeatureFlag.lightMode`. Adaptive app surfaces consume semantic context tokens; fullscreen video, camera, and editor surfaces consume fixed or adaptive media tokens selected by `FeatureFlag.adaptiveMediaChrome`.

**Tech Stack:** Flutter, `ThemeData`/`ThemeExtension`, `flutter_bloc`, Riverpod for dependency injection and feature flags, `SharedPreferences`, go_router, ARB localization, flutter_test, bloc_test, and golden tests.

---

### Task 1: Add the two typed feature flags

**Files:**
- Modify: `mobile/lib/features/feature_flags/models/feature_flag.dart`
- Modify: `mobile/lib/features/feature_flags/services/build_configuration.dart`
- Test: `mobile/test/services/build_config_test.dart`
- Test: `mobile/test/services/feature_flag_service_test.dart`

- [ ] **Step 1: Write failing enum/config tests**

Add tests that assert `FeatureFlag.lightMode` and
`FeatureFlag.adaptiveMediaChrome` have the exact display names, descriptions,
and environment keys `FF_LIGHT_MODE` and `FF_ADAPTIVE_MEDIA_CHROME`, and that
both build defaults are false.

- [ ] **Step 2: Run the focused tests and verify failure**

Run from `mobile/`:

```bash
flutter test test/services/build_config_test.dart test/services/feature_flag_service_test.dart
```

Expected: compile failure because the enum values and switch cases do not yet
exist.

- [ ] **Step 3: Implement the enum and exhaustive build-configuration cases**

Append the flags to `FeatureFlag` with user-facing metadata, then add matching
cases to `getDefault` and `getEnvironmentKey`. Use
`const bool.fromEnvironment('FF_LIGHT_MODE')` and
`const bool.fromEnvironment('FF_ADAPTIVE_MEDIA_CHROME')` with no true default.

- [ ] **Step 4: Run the focused tests and verify success**

```bash
flutter test test/services/build_config_test.dart test/services/feature_flag_service_test.dart
```

Expected: PASS, including exhaustive coverage of `FeatureFlag.values`.

- [ ] **Step 5: Commit the flag slice**

```bash
git add mobile/lib/features/feature_flags/models/feature_flag.dart mobile/lib/features/feature_flags/services/build_configuration.dart mobile/test/services/build_config_test.dart mobile/test/services/feature_flag_service_test.dart
git commit -m "feat(flags): add light mode experiments"
```

### Task 2: Implement persisted appearance state

**Files:**
- Create: `mobile/lib/features/appearance/models/appearance_mode.dart`
- Create: `mobile/lib/features/appearance/repositories/appearance_repository.dart`
- Create: `mobile/lib/features/appearance/bloc/appearance_cubit.dart`
- Create: `mobile/lib/features/appearance/providers/appearance_providers.dart`
- Create: `mobile/test/features/appearance/appearance_repository_test.dart`
- Create: `mobile/test/features/appearance/appearance_cubit_test.dart`

- [ ] **Step 1: Write repository tests**

Cover a missing preference returning `AppearanceMode.system`, round-tripping
light and dark values through `SharedPreferences`, invalid stored values
falling back to System, and a failed write leaving the in-memory value usable
while surfacing the failure to the Cubit.

- [ ] **Step 2: Run the repository tests and verify failure**

```bash
flutter test test/features/appearance/appearance_repository_test.dart
```

Expected: compile failure because the model and repository do not exist.

- [ ] **Step 3: Implement the repository with a namespaced key**

Use `appearance_mode` as the serialized enum name under a key such as
`appearance_mode_preference`. Keep SharedPreferences access behind the
repository so the Cubit has no storage details.

- [ ] **Step 4: Write Cubit tests**

Cover initial hydration, selecting each mode, a storage failure that still
emits the requested mode, and resolution rules:

```dart
ThemeMode resolveThemeMode({required bool lightModeEnabled, required Brightness systemBrightness})
```

The resolver returns `ThemeMode.dark` when the flag is disabled, and otherwise
maps System to the platform brightness and Light/Dark directly.

- [ ] **Step 5: Implement Cubit and Riverpod providers**

Create `AppearanceCubit` with `AppearanceMode` state, a repository dependency,
`load()`, `setMode(AppearanceMode)`, and a pure resolver method. Expose the
repository and Cubit through providers using the existing
`sharedPreferencesProvider`; do not create a new singleton.

- [ ] **Step 6: Run appearance tests**

```bash
flutter test test/features/appearance/appearance_repository_test.dart test/features/appearance/appearance_cubit_test.dart
```

Expected: PASS.

- [ ] **Step 7: Commit the state slice**

```bash
git add mobile/lib/features/appearance mobile/test/features/appearance
git commit -m "feat(theme): add persisted appearance state"
```

### Task 3: Build semantic Divine light and dark themes

**Files:**
- Create: `mobile/packages/divine_ui/lib/src/theme/vine_theme_colors.dart`
- Modify: `mobile/packages/divine_ui/lib/src/theme/vine_theme.dart`
- Modify: `mobile/packages/divine_ui/lib/divine_ui.dart`
- Create: `mobile/packages/divine_ui/test/src/theme/vine_theme_colors_test.dart`
- Modify: `mobile/packages/divine_ui/test/src/theme/vine_theme_switch_theme_test.dart`

- [ ] **Step 1: Write token and theme tests**

Assert that light and dark palettes expose the same semantic fields, that the
light palette uses `#F9F7F6`/white surfaces with dark-green content, that the
dark palette preserves current constants, and that fixed media tokens remain
unchanged between palettes.

- [ ] **Step 2: Run package theme tests and verify failure**

```bash
cd mobile/packages/divine_ui
flutter test test/src/theme/vine_theme_colors_test.dart test/src/theme/vine_theme_switch_theme_test.dart
```

Expected: compile failure because the extension and light theme do not exist.

- [ ] **Step 3: Implement `VineThemeColors`**

Define a `ThemeExtension<VineThemeColors>` with typed fields for adaptive
background/surface/content/outline/navigation/control colors and separate
fixed-media fields. Implement `copyWith` and `lerp` so Flutter theme changes
animate safely. Export it from `divine_ui.dart`.

- [ ] **Step 4: Add stable `VineTheme.lightTheme` and `VineTheme.darkTheme`**

Refactor the existing static theme into stable final theme objects. Register
`VineThemeColors` in each theme's `extensions`, set light/dark `brightness`,
and configure app bar, navigation, text, card, switch, selection, and button
subthemes from the matching palette. Keep `VineTheme.theme` as a dark-theme
compatibility alias until all callers are migrated.

- [ ] **Step 5: Run package theme tests**

```bash
flutter test test/src/theme/vine_theme_colors_test.dart test/src/theme/vine_theme_switch_theme_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit the theme foundation**

```bash
git add mobile/packages/divine_ui/lib/src/theme mobile/packages/divine_ui/lib/divine_ui.dart mobile/packages/divine_ui/test/src/theme
git commit -m "feat(divine-ui): add semantic light and dark themes"
```

### Task 4: Wire theme mode at the app root

**Files:**
- Modify: `mobile/lib/main.dart`
- Modify: `mobile/lib/features/appearance/providers/appearance_providers.dart`
- Create: `mobile/test/features/appearance/app_theme_mode_test.dart`

- [ ] **Step 1: Write root theme-resolution tests**

Test the four combinations of Light Mode flag and Appearance mode, plus System
resolution for light and dark platform brightness. Assert the selected
`ThemeData` identity is stable and the disabled flag always resolves dark.

- [ ] **Step 2: Run the tests and verify failure**

```bash
flutter test test/features/appearance/app_theme_mode_test.dart
```

Expected: failure because `main.dart` still supplies only `VineTheme.theme`.

- [ ] **Step 3: Add root Cubit wiring and theme selection**

Provide `AppearanceCubit` above the `MaterialApp.router`, watch
`FeatureFlag.lightMode`, map the Cubit state to `ThemeMode`, and supply
`theme: VineTheme.lightTheme` plus `darkTheme: VineTheme.darkTheme`. Keep the
database-corruption gate and both platform-specific root branches intact.

- [ ] **Step 4: Run root tests and analyze**

```bash
flutter test test/features/appearance/app_theme_mode_test.dart
flutter analyze
```

Expected: focused tests pass; any remaining analyzer errors identify callers
that still assume the old theme API and are handled in the migration tasks.

- [ ] **Step 5: Commit root wiring**

```bash
git add mobile/lib/main.dart mobile/lib/features/appearance/providers mobile/test/features/appearance/app_theme_mode_test.dart
git commit -m "feat(theme): wire appearance mode at app root"
```

### Task 5: Add the Appearance page and settings entry

**Files:**
- Create: `mobile/lib/features/appearance/view/appearance_page.dart`
- Create: `mobile/lib/features/appearance/view/appearance_view.dart`
- Modify: `mobile/lib/screens/settings/general_settings_screen.dart`
- Modify: `mobile/lib/router/routes/settings_routes.dart`
- Modify: `mobile/lib/l10n/app_en.arb` and every `mobile/lib/l10n/app_*.arb`
- Create: `mobile/test/features/appearance/appearance_page_test.dart`
- Modify: `mobile/test/screens/settings/settings_taxonomy_test.dart`

- [ ] **Step 1: Add localization keys and run generation**

Add Appearance title, description, System/Light/Dark labels, and summaries to
every locale file. Run `flutter gen-l10n` from `mobile/` and inspect `git
status` for only expected generated outputs under `mobile/lib/l10n/generated/`.

- [ ] **Step 2: Write failing page and settings tests**

Test that the Appearance row is absent when Light Mode is disabled, present
when enabled, navigates to the full-screen route, and selecting Light/Dark/System
dispatches the Cubit. Test the route is registered and preserves back
navigation.

- [ ] **Step 3: Implement the Page/View and route**

Use `AppearancePage` as a `ConsumerWidget` for provider wiring and
`AppearanceView` as a stateless Cubit consumer. Render a semantic
`RadioListTile<AppearanceMode>` group using `Theme.of(context)` and
`VineThemeColors`. Define `AppearancePage.routeName` and
`AppearancePage.path`, then register that path in `settings_routes.dart`.

- [ ] **Step 4: Add the gated General Settings tile**

Watch `isFeatureEnabledProvider(FeatureFlag.lightMode)`, insert Appearance in
the Viewing/App section, and navigate with `context.push(AppearancePage.path)`.

- [ ] **Step 5: Run localization and focused tests**

```bash
cd mobile
flutter test test/l10n/arb_consistency_test.dart
flutter test test/features/appearance/appearance_page_test.dart test/screens/settings/settings_taxonomy_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit the user-facing flow**

```bash
git add mobile/lib/features/appearance/view mobile/lib/screens/settings/general_settings_screen.dart mobile/lib/router/routes/settings_routes.dart mobile/lib/l10n mobile/test/features/appearance mobile/test/screens/settings/settings_taxonomy_test.dart
git commit -m "feat(settings): add gated appearance controls"
```

### Task 6: Migrate shared `divine_ui` components to semantic tokens

**Files:**
- Modify: `mobile/packages/divine_ui/lib/src/app_bar/*.dart`
- Modify: `mobile/packages/divine_ui/lib/src/bottom_sheet/*.dart`
- Modify: `mobile/packages/divine_ui/lib/src/button/*.dart`
- Modify: `mobile/packages/divine_ui/lib/src/checkbox/*.dart`
- Modify: `mobile/packages/divine_ui/lib/src/search_bar/*.dart`
- Modify: `mobile/packages/divine_ui/lib/src/slider/*.dart`
- Modify: `mobile/packages/divine_ui/lib/src/text_field/*.dart`
- Modify: `mobile/packages/divine_ui/lib/src/skeleton/*.dart`
- Add/update component tests under `mobile/packages/divine_ui/test/`

- [ ] **Step 1: Create the migration inventory**

Run:

```bash
rg -n "VineTheme\.(backgroundColor|cardBackground|surfaceBackground|surfaceContainer|surfaceContainerHigh|whiteText|primaryText|secondaryText|lightText|onSurface|onSurfaceVariant|onSurfaceMuted|onSurfaceDisabled|outlineMuted|outlineVariant|navGreen|iconButtonBackground)" mobile/packages/divine_ui/lib -g '*.dart'
```

Classify every match as adaptive component chrome or fixed media styling;
there must be no unclassified match before committing this task.

- [ ] **Step 2: Add failing light-theme component tests**

Render representative app bars, buttons, bottom sheets, fields, checkboxes,
search, sliders, and skeletons under both `VineTheme.lightTheme` and
`VineTheme.darkTheme`; assert text/background/border colors come from
`VineThemeColors` rather than dark constants.

- [ ] **Step 3: Migrate adaptive component chrome**

Replace adaptive constant references with
`Theme.of(context).extension<VineThemeColors>()!`. Leave video overlays,
scrims, and camera/editor colors on fixed media tokens.

- [ ] **Step 4: Run package tests and goldens**

```bash
cd mobile/packages/divine_ui
flutter test
```

Expected: PASS with both theme variants rendered.

- [ ] **Step 5: Commit shared-component migration**

```bash
git add mobile/packages/divine_ui/lib mobile/packages/divine_ui/test
git commit -m "refactor(divine-ui): resolve adaptive colors from theme"
```

### Task 7: Migrate app-level adaptive surfaces and media experiments

**Files:**
- Modify: the app-level Dart files listed by the semantic-token inventory under `mobile/lib/`
- Create: `mobile/lib/features/appearance/media_theme_tokens.dart`
- Add/update: focused tests beside settings, profile, navigation, feed, camera, and editor widgets

- [ ] **Step 1: Generate and group the app migration inventory**

Run:

```bash
rg -l "VineTheme\." mobile/lib -g '*.dart' | sort
```

Migrate groups in this order: app shell/navigation, settings/auth, profiles/
lists/search, dialogs/forms, then feed/explore. For every direct color, decide
whether it is adaptive app chrome or fixed/adaptive media styling.

- [ ] **Step 2: Add media token selection tests**

Test a pure selector that returns fixed dark media tokens when the adaptive flag
is false, returns light media tokens only for light brightness with the flag
true, and returns fixed dark tokens for dark brightness.

- [ ] **Step 3: Migrate app chrome in small compile-safe batches**

Use context-resolved semantic tokens for scaffold backgrounds, cards, text,
settings, profiles, lists, search, dialogs, and navigation. Remove `const`
only where a widget now receives a runtime theme color; keep static brand and
media constants `const`.

- [ ] **Step 4: Migrate feed/media surfaces with the selector**

Keep fullscreen video canvas, scrims, camera backgrounds, editor chrome, and
on-video text fixed by default. Route only the adaptive-media experiment's
control surfaces through the light media token set.

- [ ] **Step 5: Run focused app tests after each group**

```bash
cd mobile
flutter test test/widgets/settings_screen_test.dart test/screens/settings/settings_taxonomy_test.dart
flutter test test/widgets/video_feed_item test/widgets/video_editor
flutter analyze
```

Expected: no direct adaptive dark constants remain in the migrated groups and
all focused tests pass.

- [ ] **Step 6: Commit app migration batches**

Use one focused commit per group. The first group commit is:

```bash
git add mobile/lib mobile/test
git commit -m "refactor(app): migrate settings and shell to semantic theme"
```

### Task 8: Add visual regression coverage and complete verification

**Files:**
- Create/update: light/dark golden tests under `mobile/test/goldens/`
- Modify: `mobile/test/flutter_test_config.dart` only if theme setup requires a shared fixture
- Modify: `mobile/docs/DESIGN_SYSTEM_COMPONENTS.md` to document light/dark and fixed-media tokens

- [ ] **Step 1: Add light/dark General Settings goldens**

Render the General Settings and Appearance pages in both themes with Light Mode
enabled; include System, Light, and Dark selection states.

- [ ] **Step 2: Add fixed/adaptive media goldens**

Render one fullscreen feed overlay and one editor/camera control in each media
flag state. Assert fixed mode is unchanged and adaptive light mode uses readable
dark controls.

- [ ] **Step 3: Run golden verification**

```bash
cd mobile
scripts/golden.sh verify
```

Update goldens only when the rendered result matches the approved palette and
media-boundary behavior.

- [ ] **Step 4: Run the required verification suite**

```bash
cd mobile
flutter test test/l10n/arb_consistency_test.dart
flutter test test/features/appearance test/services/build_config_test.dart test/services/feature_flag_service_test.dart
flutter test
flutter analyze
```

If a package under `mobile/packages/models` or `mobile/packages/videos_repository`
was touched, run its package-specific tests and coverage command from the repo
guidelines.

- [ ] **Step 5: Review the final diff and commit documentation**

```bash
git diff origin/main...HEAD --stat
git status --short
git add mobile/docs/DESIGN_SYSTEM_COMPONENTS.md mobile/test
git commit -m "test(theme): verify feature-flagged light mode"
```

The final status must be clean except for intentional generated outputs, and
both feature flags must remain default-off.
