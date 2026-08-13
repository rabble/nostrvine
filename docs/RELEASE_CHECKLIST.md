# Divine Release Checklist

Status: Launch-critical
Validated against: `mobile/pubspec.yaml`, `mobile/build_ios.sh`, `mobile/build_android.sh`, `mobile/deploy_android.sh`, `.github/workflows/mobile_ci.yaml`, and current launch docs on 2026-03-19.

Use this checklist for P1 release prep and store submission. This replaces older package-release and legacy deployment checklists.

## 1. Freeze The Candidate

"Freeze" here means pin the commit you are about to build. It is not a merge
freeze — Divine does not run release freezes, including before launch. See
[Release Policy: No Freezes](P1_LAUNCH_HUB.md#release-policy-no-freezes).

- [ ] Confirm the target commit is on `main` or the intended release branch.
- [ ] Confirm `mobile/pubspec.yaml` has the release version and build number you expect.
- [ ] Review `git status` and remove temporary files, logs, or unfinished work.
- [ ] Confirm launch-critical docs are updated:
  - [ ] [docs/P1_LAUNCH_HUB.md](P1_LAUNCH_HUB.md)
  - [ ] [docs/APP_STORE_REVIEW_DOSSIER.md](APP_STORE_REVIEW_DOSSIER.md)
  - [ ] [mobile/docs/APPLE_REVIEW_RESPONSE.md](../mobile/docs/APPLE_REVIEW_RESPONSE.md)
  - [ ] [mobile/docs/ENCRYPTION_EXPORT_COMPLIANCE.md](../mobile/docs/ENCRYPTION_EXPORT_COMPLIANCE.md)

## 2. Naming And Identifiers

- Use `Divine` for the product name in prose, UI, store metadata, release notes, docs, and commit messages.
- Keep `openvine` only where it is a legacy technical identifier:
  - Dart package name: `mobile/pubspec.yaml`
  - Store bundle IDs: `co.openvine.app` and shipped child bundle IDs such as `co.openvine.app.NotificationServiceExtension`
- Do not rename the Dart package or bundle IDs during release cleanup. They are compatibility identifiers, not brand copy drift.
- macOS direct-download builds are not App Store submissions today, so their Xcode marketing/build settings remain intentionally separate from the iOS store version path.

## 3. Run The Required Checks

From `mobile/`:

```bash
flutter pub get
flutter analyze
flutter test
bash scripts/check_ios_shipping_versions.sh
```

Run these when relevant:

- `dart run build_runner build --delete-conflicting-outputs`
- `./scripts/golden.sh verify`
- `cd packages/videos_repository && flutter test --coverage`

## 4. Verify Reviewer-Facing Behavior

- [ ] Welcome flow links open Terms, Privacy, and Safety pages.
- [ ] Settings hub routes to Support Center, Content Preferences, Moderation Controls, and Nostr Settings.
- [ ] Support Center opens the current support/legal destinations.
- [ ] Moderation Controls expose reporting, block/mute, age gate, and moderation-provider management.
- [ ] Deep links and auth callbacks still work for `https://divine.video/...`, `https://login.divine.video/...`, and `divine://`.

## 5. Build The Release Artifacts

From `mobile/`:

```bash
./build_ios.sh release
./build_android.sh release
```

- [ ] iOS archive completed successfully in Xcode Organizer.
- [ ] Android release AAB exists at `build/app/outputs/bundle/release/app-release.aab`.
- [ ] If using the Play upload helper, verify `android/play-store-service-account.json` is present before running `./deploy_android.sh`.

## 6. iOS Submission Checklist

- [ ] Confirm app metadata matches the release candidate:
  - App name: `Divine`
  - Bundle identifier: `co.openvine.app`
  - Version name from `mobile/pubspec.yaml`; Codemagic build number from App Store Connect latest + 1.
- [ ] Confirm the built IPA's app bundle and embedded extension bundle versions agree.
- [ ] Verify `ITSAppUsesNonExemptEncryption` remains `false` in `mobile/ios/Runner/Info.plist`.
- [ ] Re-check camera, microphone, photo-library, Bluetooth, Bonjour, and location usage strings in `Info.plist`.
- [ ] Ensure App Store Connect screenshots, subtitle, description, keywords, privacy answers, and support URL are current.
- [ ] Attach reviewer notes using [docs/APP_STORE_REVIEW_DOSSIER.md](APP_STORE_REVIEW_DOSSIER.md).
- [ ] Upload the archive to TestFlight or App Store Connect and verify processing succeeds.

## 7. Android Submission Checklist

- [ ] Confirm app ID is still `co.openvine.app`.
- [ ] Confirm the manifest still removes Advertising ID and unused location/Bluetooth permissions.
- [ ] Verify the current release notes and tester notes are ready.
- [ ] Upload the AAB to the intended track:
  - Manual Play Console upload, or
  - `./deploy_android.sh internal|closed|production`
- [ ] Verify release track assignment and staged rollout settings.

## 8. Final Sign-Off

- [ ] All launch-critical docs point to current scripts and screens.
- [ ] No active doc still uses outdated project naming unless clearly historical.
- [ ] External reviewer pages are live:
  - [ ] `https://divine.video/terms`
  - [ ] `https://divine.video/privacy`
  - [ ] `https://divine.video/safety`
  - [ ] `https://divine.video/faq`
  - [ ] `https://divine.video/proofmode`
- [ ] The final release commit and store submissions are recorded in the release channel or ship notes.
