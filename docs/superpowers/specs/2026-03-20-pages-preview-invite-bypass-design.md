# GitHub Actions Pages Preview Invite Bypass

**Date:** 2026-03-20
**Status:** Approved

## Goal

Allow the Flutter web builds deployed by the GitHub Actions PR preview workflow to skip invite-code gating so Chrome-based preview debugging is easier.

## Scope

This change only applies to the preview artifacts produced by `.github/workflows/mobile_pr_preview_build.yml` and deployed to Cloudflare Pages by the trusted preview deploy workflow.

It does not apply to:

- local Chrome runs
- production web builds
- arbitrary `*.pages.dev` hosts
- the invite server

## Chosen Approach

Use an explicit build-time flag that is only set by the GitHub Actions PR preview build:

- add a new `GH_ACTIONS_PR_PREVIEW` `dart-define`
- expose that flag in `AppConfig`
- let `InviteApiService` override the fetched onboarding mode to `OnboardingMode.open` when that flag is enabled

## Why This Approach

This keeps the bypass explicit and isolated to the preview artifact. It avoids host sniffing, avoids tying app behavior to Cloudflare URL formats, and avoids cross-repo server work for a debugging-only need.

## Current Code Paths

The invite gate already depends on `InviteClientConfig.mode`:

- `mobile/lib/screens/auth/invite_gate_screen.dart`
- `mobile/lib/screens/auth/invite_protected_create_account_screen.dart`
- `mobile/lib/blocs/invite_gate/invite_gate_bloc.dart`
- `mobile/lib/services/invite_api_service.dart`

When `mode == OnboardingMode.open`, the UI already proceeds to create-account instead of requiring an invite code. The missing piece is a preview-only way to force that mode.

## Design Details

### 1. Add a preview build flag

Add a new build-time boolean in `mobile/lib/config/app_config.dart`:

- `AppConfig.isGhActionsPrPreviewBuild`

Use `bool.fromEnvironment` directly for this flag instead of routing through the existing feature-flag helper. This keeps the new preview switch explicit and avoids coupling it to unrelated feature-flag behavior.

### 2. Make the invite service preview-aware

Update `InviteApiService` so it can be constructed with an optional override:

- `forceOpenOnboarding`

If not supplied, it should default to `AppConfig.isGhActionsPrPreviewBuild`.

In `getClientConfig()`:

- fetch and parse the server response as usual
- if preview bypass is disabled, return the parsed config unchanged
- if preview bypass is enabled, return a copy-equivalent config with `mode: OnboardingMode.open` while preserving fields like `supportEmail`

This keeps the server contract intact and confines preview behavior to the client.

### 3. Wire the workflow

Update `.github/workflows/mobile_pr_preview_build.yml` so the preview web build passes:

`--dart-define=GH_ACTIONS_PR_PREVIEW=true`

That ensures only the GitHub Actions preview artifact gets the bypass.

## Testing Strategy

Add focused coverage in three places:

1. `mobile/test/services/invite_api_service_test.dart`
   Verify that `InviteApiService(forceOpenOnboarding: true)` converts an invite-required server config into `OnboardingMode.open` while preserving `supportEmail`.

2. `mobile/test/screens/auth/invite_gate_screen_test.dart`
   Verify that a real `InviteApiService` configured with `forceOpenOnboarding: true` causes the invite gate route to continue directly to create-account even when the mocked server says invites are required.

3. `mobile/test/screens/auth/invite_protected_create_account_screen_test.dart`
   Verify that the protected create-account route also allows access without an invite grant when the service is in preview-bypass mode.

## Risks

- If the preview build workflow is copied elsewhere with the same `dart-define`, that new build will also bypass invites.
- The bypass only affects client-side gating. It does not disable invite consumption logic later in the auth flow, which is acceptable because the request is specifically about removing the pre-auth invite requirement for debugging.

## Out Of Scope

- hostname-based `pages.dev` detection
- invite server changes
- production web onboarding changes
- new UI labels or banners for preview mode
