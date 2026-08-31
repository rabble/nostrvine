# app_device_integrity Override

This directory is a local fork of `app_device_integrity` 1.1.0 from pub.dev.
The upstream README and package metadata are preserved for package context; this
file documents Divine's override-specific rationale.

## Owner

Mobile platform/security maintainers. The app uses this plugin from
`lib/services/ios_device_attestation_service.dart` for publish-time App Attest
payloads.

## Rationale

The upstream Android plugin leaves `ActivityAware` detach/configuration-change
callbacks as throwing TODO stubs. This package declares an Android plugin, so
Flutter registers it in Android builds and can call those callbacks during
activity teardown even though Divine only requests App Attest on iOS. The
upstream stubs can therefore crash app teardown regardless of method-channel
use.

This fork keeps the package API and version at 1.1.0 while carrying the minimum
local fixes needed by Divine.

## Local Changes

- `android/src/main/kotlin/co/bubotech/app_device_integrity/AppDeviceIntegrityPlugin.kt`
  stores the attached activity as nullable state and makes detach callbacks
  clear it without throwing.
- The same plugin validates `challengeString` and Android `gcp` arguments and
  returns explicit Flutter errors instead of leaving callers waiting forever.
- `android/src/test/kotlin/co/bubotech/app_device_integrity/AppDeviceIntegrityPluginTest.kt`
  covers nonce generation, lifecycle detach safety, and argument validation.
- `ios/Classes/AppDeviceIntegrity.swift` scopes App Attest state to the
  publishing account, reuses each account's rate-limited key, resumes one
  generated-but-unattested key before replacing it, and serializes concurrent
  provisioning behind a 30-second watchdog.
- The iOS challenge binds the media proof hash to the publishing pubkey. Cached
  credentials answer later challenges with assertions, and invalid restored
  key identifiers re-provision once without clearing a newer replacement.
- The iOS assertion callback has a 15-second native watchdog above Dart's
  10-second attestation budget. Each `generateAssertion` leg releases its
  pending completion at that deadline when Apple's callback never returns,
  without shortening Dart's existing success window. Provisioning, retry, and
  recursive re-provisioning have their own deadlines, so the complete native
  flow is not capped at 15 seconds.

## Removal Condition

Remove this override when a maintained upstream release includes equivalent
Android lifecycle and argument-validation behavior, or when the app migrates to
a maintained device-attestation plugin. Track that work in #6918.
