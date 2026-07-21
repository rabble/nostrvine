# Light mode behind feature flags

**Date:** 2026-07-20  
**Status:** Approved design; implementation not started

## Goal

Give users a Divine light theme while preserving the existing dark experience
as the default. The first release is an experiment: the light theme is gated,
users can choose System, Light, or Dark when the gate is enabled, and a second
flag lets us compare two treatments for media controls.

The experience must work consistently on iOS, Android, web, and macOS.

## User experience

The existing Experimental Features screen exposes two default-off flags:

- **Light Mode** — enables the Appearance preference and allows the app to
  resolve to a light theme.
- **Adaptive Media Chrome** — only has an effect when Light Mode is enabled and
  the resolved theme is light; it switches fullscreen-video controls to light
  surfaces so we can compare that treatment with the fixed high-contrast one.

When Light Mode is disabled, Divine is forced to dark mode. A stored appearance
choice is retained but inactive, so re-enabling the flag restores the user's
choice. The Appearance row is hidden while the flag is disabled.

Appearance lives in General Settings as a full-screen page with three radio
choices: System, Light, and Dark. System is the default. Changes apply
immediately, follow platform brightness changes, and persist locally per
device. They are not synced to Nostr or the user's account.

Light mode uses warm off-white content surfaces, white raised surfaces,
dark-green text and navigation anchors, and Divine green actions. This keeps
the clean light-content / green-framing feel associated with the original Vine
while using the current Divine palette and typography.

## Theme architecture

`divine_ui` will provide two complete `ThemeData` values from `VineTheme`:
`darkTheme` and `lightTheme`. The current dark theme remains behaviorally
unchanged and remains the compatibility default while migration is in flight.

Theme-sensitive colors move into a typed `VineThemeColors extends
ThemeExtension<VineThemeColors>` resolved from `BuildContext`. It covers:

- app background, surfaces, elevated containers, borders, and dividers;
- primary, secondary, muted, disabled, and inverse content colors;
- app-bar and navigation surfaces; and
- control states such as selected, pressed, disabled, and error containers.

Fixed media tokens remain separate and explicit. They cover video overlays,
scrims, camera/editor surfaces, on-video controls, and brand colors that must
remain legible regardless of the surrounding app theme. The media token
selection is:

- fixed dark/high-contrast treatment when Adaptive Media Chrome is off;
- adaptive light treatment only when both flags are on and the resolved theme
  is light; and
- the existing dark treatment whenever the resolved theme is dark.

The app's `MaterialApp.router` will provide `theme: VineTheme.lightTheme`,
`darkTheme: VineTheme.darkTheme`, and a `themeMode` driven by appearance state.
When Light Mode is disabled, the root supplies `ThemeMode.dark` regardless of
the saved appearance choice. The implementation must preserve stable theme
object identity to avoid unnecessary `ThemeData.lerp` cascades.

Existing direct uses of dark `VineTheme` constants are migrated by semantic
surface. General settings, profiles, lists, dialogs, forms, navigation, and
shared design-system components use context-resolved tokens. Fullscreen video,
camera, editor, scrims, and media overlays keep explicit fixed-media tokens.
Font helpers used on adaptive surfaces must inherit or receive the resolved
semantic text color; helpers used over media continue to receive the fixed
media color explicitly.

## State and persistence

Add an Appearance feature with:

- a small local preferences repository backed by the existing
  `SharedPreferences` dependency;
- an `AppearanceCubit` owning the UI state (`system`, `light`, `dark`);
- a full-screen Appearance page/view split; and
- root wiring that supplies the Cubit before `MaterialApp.router` is built.

The repository uses a namespaced preference key and treats missing values as
System. A read or write failure must not crash startup: the Cubit applies the
new value in memory for the current session, logs the storage failure through
the existing logger, and falls back to System on the next launch if persistence
was not successful.

The two flags use the existing typed `FeatureFlag`, `BuildConfiguration`,
`FeatureFlagService`, and Experimental Features UI. Their compile-time keys
are `FF_LIGHT_MODE` and `FF_ADAPTIVE_MEDIA_CHROME`, both defaulting to false.

## Localization and accessibility

All new visible strings—flag names/descriptions, Appearance title, option
labels, and summaries—are added to `app_en.arb` and every locale, followed by
the repository ARB consistency test. The Appearance choices use semantic radio
controls and retain platform-standard focus, keyboard, and screen-reader
behavior. Light and dark token pairs must meet the existing contrast
expectations for body text, labels, controls, and error states.

## Verification

Add or update:

- `BuildConfiguration` and feature-flag service tests for both flags;
- Appearance repository and Cubit tests covering defaults, persistence,
  storage failure, System resolution, and platform brightness changes;
- General Settings and Appearance page widget tests covering flag gating,
  selection, persistence wiring, and immediate theme changes;
- semantic theme token tests for light and dark palettes;
- light/dark goldens for General Settings and representative shared
  components; and
- fixed-media/adaptive-media goldens for a fullscreen feed surface and a
  camera/editor surface.

Run the affected package tests, the ARB consistency test, `flutter analyze`,
and `mobile/scripts/golden.sh verify`. Because the migration crosses the app
and `divine_ui`, broaden verification to the app test suite before publishing.
Add a source-audit contract test so newly migrated adaptive surfaces do not
reintroduce hard-coded dark tokens.

## Scope boundaries

This work does not change video playback, media encoding, Nostr data, account
sync, or the brand palette. It does not remove dark mode or flip either flag
on in production. The experiment flags remain available for controlled
dogfooding and visual comparison until the product decision is made.
