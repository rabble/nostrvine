# Android Deployment Guide

Status: Launch-critical
Validated against: `mobile/build_android.sh`, `mobile/deploy_android.sh`, `mobile/android/app/build.gradle.kts`, and `mobile/android/app/src/main/AndroidManifest.xml` on 2026-03-19.

This is the current Android release path for Divine.

## App Metadata

- App name: `Divine`
- Application ID: `co.openvine.app`
- Namespace: `co.openvine.app`
- Release artifact: `build/app/outputs/bundle/release/app-release.aab`

## Preferred Build Flow

From `mobile/`:

```bash
./build_android.sh release
```

What the script does:

1. Loads `.env` dart defines if present.
2. Auto-increments the build number for release builds.
3. Runs `flutter clean`, `flutter pub get`, and `build_runner`.
4. Builds a signed release AAB for Play Console upload.

## Upload Options

### Manual Play Console upload

1. Build the release AAB with `./build_android.sh release`.
2. Open Google Play Console.
3. Upload `build/app/outputs/bundle/release/app-release.aab`.
4. Add release notes and assign the correct testing or production track.

### Scripted upload helper

```bash
./deploy_android.sh internal
./deploy_android.sh closed
./deploy_android.sh production
```

The helper requires:

- `android/play-store-service-account.json`
- working Fastlane installation
- a previously built or buildable release AAB

## Pre-Upload Checks

- Confirm `mobile/pubspec.yaml` version/build is correct.
- Confirm signing configuration and keystore access are available locally or in CI.
- Confirm release notes are ready.
- Confirm the manifest still removes Advertising ID and dependency-added location/Bluetooth permissions that are not used in this release.

## Manifest Notes For Store Compliance

Current Android manifest behavior:

- uses camera and microphone for recording
- uses media permissions for profile image and gallery interactions
- removes Advertising ID permission
- removes unused dependency-added Bluetooth, location, and nearby permissions
- registers deep links for `divine.video` and `login.divine.video`

## Troubleshooting

### Release build fails

- Run `flutter doctor`.
- Check keystore availability and `android/key.properties`.
- Re-run `flutter pub get` and `dart run build_runner build --delete-conflicting-outputs`.

### Upload helper fails

- Confirm `android/play-store-service-account.json` exists.
- Confirm Fastlane is installed and authenticated.
- Fall back to manual Play Console upload if needed.
