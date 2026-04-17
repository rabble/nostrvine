# Account Switching Feature Flag Design

## Summary

Account switching exists today but is still buggy and too advanced for general users. We will reuse the existing local feature-flag system to disable the account-switching entry point by default while keeping the implementation available for internal testing.

## Goals

- Reuse the existing typed feature-flag system.
- Hide account switching and add-account controls from Settings when the flag is disabled.
- Keep the current account-switching behavior unchanged when the flag is enabled.
- Enforce the disabled state in logic as well as UI.

## Non-Goals

- Rework multi-account flows outside Settings.
- Remove the underlying account-switching implementation.
- Introduce a new feature-flag mechanism.

## User-Facing Behavior

- Add a new `accountSwitching` feature flag with build-time environment key `FF_ACCOUNT_SWITCHING`.
- Default the flag to `false`.
- When the flag is `false`, the Settings account header still shows the current profile but hides the action button that currently opens the account switcher.
- When the flag is `true`, Settings keeps the current behavior:
  - Single-account users see `Add another account`.
  - Multi-account users see `Switch account`.
  - The bottom sheet still allows switching accounts or adding another account.

## Technical Design

### Existing Flag System

Use the existing feature-flag stack in:

- `mobile/lib/features/feature_flags/models/feature_flag.dart`
- `mobile/lib/features/feature_flags/services/build_configuration.dart`
- `mobile/lib/features/feature_flags/providers/feature_flag_providers.dart`

This keeps the change consistent with the rest of the app and makes the flag available in the existing Experimental Features screen without custom plumbing.

### Settings UI Gate

`SettingsScreen` already reads feature flags via Riverpod. It should read `isFeatureEnabledProvider(FeatureFlag.accountSwitching)` and pass that state into the account-header UI.

The account action control should only render when `accountSwitching` is enabled. The rest of the header remains visible so the current profile still anchors the screen.

### Logic Gate

`SettingsAccountCubit` currently exposes `switchToAccount` and `addNewAccount` without any flag awareness. Add a small dependency for the existing feature-flag service and early-return when `FeatureFlag.accountSwitching` is disabled.

This prevents accidental behavior regressions if the UI gate is bypassed in a future refactor or a widget test instantiates the cubit directly.

## Testing

- Update widget tests for `SettingsScreen` to verify:
  - the account action is hidden when the flag is disabled
  - the action still appears when enabled and account state requires it
- Update `SettingsAccountCubit` tests to verify:
  - `switchToAccount` no-ops when the flag is disabled
  - `addNewAccount` no-ops when the flag is disabled
  - existing enabled-path behavior still works

## Risks

- If only the UI is gated, future callers could still trigger switching. The cubit guard closes that gap.
- The flag defaults to `false`, so tests that assumed the old default must set the flag explicitly when they need the control visible.
