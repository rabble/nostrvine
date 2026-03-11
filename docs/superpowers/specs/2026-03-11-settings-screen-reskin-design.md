# Settings Screen Reskin Design

**Date:** 2026-03-11

**Goal:** Rebuild the main settings screen to match the Figma visual language while preserving every current settings action, route, and auth-state behavior.

## Context

The current implementation in `mobile/lib/screens/settings_screen.dart` is a long icon-heavy utility list with multiple visual patterns mixed together. The Figma node `5251:98921` shows a simpler settings experience:

- minimal top app bar
- dark full-screen canvas
- one prominent account block near the top
- text-led rows with subtle dividers and trailing chevrons
- sparse section headings
- a quiet version footer

The user wants a design reskin only. We should not remove settings, hide functionality, or change underlying flows beyond UX improvements needed to fit the new information architecture.

## Constraints

- Preserve all current routes, actions, and auth-driven states.
- Keep the screen aligned with existing Flutter patterns, `DiVineAppBar`, and `VineTheme`.
- Do not introduce a new route structure for settings.
- Do not remove advanced or destructive actions. Reorganize them visually instead.
- Keep the screen usable on small phones and tablets.

## Proposed Information Architecture

The screen stays a single scrollable column with the following order:

1. Top app bar
   - back button
   - `Settings` title

2. Account summary block
   - primary account status/message area
   - one or more account-related actions depending on auth state:
     - `Switch Account`
     - `Secure Your Account` for anonymous users
     - `Session Expired` recovery tile when relevant

3. `Preferences`
   - `Notifications`
   - `Safety & Privacy`
   - `Content Language`
   - audio reuse toggle
   - audio device selector when the platform and hardware support it

4. `Nostr Settings`
   - `Relays`
   - `Relay Diagnostics`
   - `Media Servers`
   - `Developer Options`

5. `Support`
   - `Contact Support`
   - `ProofMode Info`
   - `Save Logs`

6. `Account Tools`
   - `Key Management`
   - `Remove Keys from Device`

7. `Danger Zone`
   - `Delete Account and Data`

8. Version footer
   - `Version x.y.z+build`

## Visual Design

### Overall layout

- Use the Figma layout rhythm: wider horizontal padding, taller rows, minimal decoration.
- Remove default leading icons from standard navigation rows.
- Use thin separators between rows instead of card-like blocks.
- Keep content left-aligned with strong typography and quieter helper copy.
- Maintain a constrained content width on larger screens, centered as today.

### Account summary block

- This becomes the one visually distinct block near the top.
- It should carry the current account state with concise supporting text.
- It can include stacked actions if multiple account-related states need to be surfaced.
- It should feel more editorial than utility-driven: larger title, muted detail, more breathing room.

### Navigation rows

- Each row uses:
  - title
  - optional subtitle when needed
  - trailing chevron for navigation
- Standard rows have no leading icon.
- Destructive rows use red text/tint rather than a separate tile style.
- Toggle rows should visually match navigation rows, with the control replacing the chevron.

### Section headings

- Figma-style subdued headings with more top spacing than the current version.
- Use headings only where they improve scanability.

### Footer

- Version text sits as a low-emphasis footer row after all settings content.

## UX Behavior

- All current taps and side effects remain unchanged.
- The screen remains fully scrollable.
- The version footer is part of scroll content, not pinned.
- Auth-specific account actions still render conditionally based on current auth state.
- Support, export, logout, key removal, and delete-account flows keep their current dialog/sheet behavior.

## Component Strategy

Refactor the current settings presentation into smaller visual primitives inside `settings_screen.dart` or nearby private widgets:

- account summary block
- section heading
- navigation row
- toggle row
- footer row

This should replace the current generic `_SettingsTile` approach, which is too tied to the older icon-led layout.

## Testing Strategy

- Update existing widget tests for the settings screen to verify the new visible grouping and that critical settings still render.
- Add focused widget assertions for the account summary block across relevant auth states if the current suite does not cover them clearly.
- Re-enable or replace stale settings tests that are currently skipped where practical.
- Run a targeted settings widget test pass first.
- If the golden harness is stable enough, update or add a focused settings golden for the new layout.

## Out of Scope

- Removing or deprecating settings items
- Changing route structure
- Redesigning downstream settings detail screens
- Altering business logic for auth, support, key management, or destructive actions
