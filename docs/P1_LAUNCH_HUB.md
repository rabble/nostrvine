# P1 Launch Hub

Status: Launch-critical
Validated against: `mobile/pubspec.yaml`, `mobile/ios/Runner/Info.plist`, `mobile/android/app/build.gradle.kts`, active settings/support screens, and current build scripts on 2026-03-19.

P1 launch is the milestone for submitting Divine to the App Store for review and cutting the matching Android release candidate. This doc is the single entry point for launch-ready documentation.

## Product Snapshot

- App name: `Divine`
- Mobile package name: `openvine`
- iOS bundle identifier: `co.openvine.app`
- Android application ID: `co.openvine.app`
- Current app version: `1.0.7+497`
- Primary app entrypoint: `mobile/lib/main.dart`

## Launch Doc Set

- [docs/RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md) - release execution checklist
- [docs/APP_STORE_REVIEW_DOSSIER.md](APP_STORE_REVIEW_DOSSIER.md) - reviewer-facing evidence and submission notes
- [mobile/docs/APPLE_REVIEW_RESPONSE.md](../mobile/docs/APPLE_REVIEW_RESPONSE.md) - prior Apple review response and current compliance posture
- [mobile/docs/ENCRYPTION_EXPORT_COMPLIANCE.md](../mobile/docs/ENCRYPTION_EXPORT_COMPLIANCE.md) - export compliance record
- [mobile/docs/ANDROID_DEPLOYMENT.md](../mobile/docs/ANDROID_DEPLOYMENT.md) - Play Console upload flow

## Current Release Path

From `mobile/`:

- Install dependencies: `flutter pub get`
- Generate code if needed: `dart run build_runner build --delete-conflicting-outputs`
- Run the core checks: `flutter analyze`, `flutter test`
- Build iOS archive: `./build_ios.sh release`
- Build Android AAB: `./build_android.sh release`
- Optional Play upload helper: `./deploy_android.sh internal|closed|production`

## Reviewer-Sensitive Flows

These are the areas that need to stay defensible in docs and in the app:

- Welcome flow links to Terms, Privacy, and Safety pages.
- Settings now route through:
  - `Settings`
  - `Support Center`
  - `Content Preferences`
  - `Moderation Controls`
  - `Nostr Settings`
- Support Center links to FAQ, ProofMode, Privacy Policy, and Safety Standards.
- Moderation controls live under `Safety & Privacy` and expose blocklists, moderation providers, and adult-content gates.

## External Dependencies To Validate

These pages are linked from the app and should be reviewed before submission even though they are not authored in this repo:

- `https://divine.video/terms`
- `https://divine.video/privacy`
- `https://divine.video/safety`
- `https://divine.video/faq`
- `https://divine.video/proofmode`

## Not Source Of Truth

Do not use older legacy deployment notes, package release notes, or web-deployment docs as the launch checklist. Those are tracked from [docs/archive/README.md](archive/README.md).
