# iOS Build Troubleshooting

When iOS build fails with "Could not resolve package dependencies" and Firebase plugins require different FlutterFire versions (`'X' depends on 'flutterfire' A-firebase-core-swift and 'Y' depends on 'flutterfire' B-firebase-core-swift`), there are two distinct causes. Diagnose which one you have before fixing. A third, unrelated failure shape — every plugin "requires minimum platform version 15.0/16.0 ... but this target supports 13" — is covered last.

## Cause 1: misaligned Firebase plugin versions (check this first)

Each FlutterFire plugin's `Package.swift` pins the shared `flutterfire` Swift package at exactly the `firebase_core` minimum declared in that plugin's own pubspec. If any Firebase plugin in `mobile/pubspec.lock` declares a different `firebase_core` minimum than its siblings, SPM resolution fails deterministically on every fresh machine, including CI — no cache clearing helps. (Codemagic iOS Build broke this way when `firebase_remote_config` 6.1.2 declared `^4.2.1` while every sibling declared `^4.4.0`; fixed by #7016.)

Check the constraints for the locked plugin versions:

```bash
grep -h "firebase_core:" ~/.pub-cache/hosted/pub.dev/firebase_*/pubspec.yaml
```

All `firebase_core` minimums must be identical and match the locked `firebase_core` version. If one differs, bump that plugin to the release aligned with the locked `firebase_core` — pub.dev's API lists every version's dependencies (`https://pub.dev/api/packages/<pkg>`) — and commit the pubspec + lockfile change. GitHub CI does not run an SPM iOS build, so this misalignment goes green on PRs and only surfaces on Codemagic after merge.

To confirm a suspected conflict without building the app: a scratch `Package.swift` with `.package(path:)` dependencies into `~/.pub-cache/hosted/pub.dev/<pkg>-<version>/ios/<pkg>` for `firebase_core` plus the suspect plugins reproduces the exact error with `swift package resolve` in seconds.

## Cause 2: stale local Xcode SPM cache

If the plugin constraints are aligned and the failure is on a local machine, it's a stale Xcode SPM cache, not a code issue.

Fix:

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData
cd mobile/ios && rm -rf Pods Podfile.lock .symlinks
flutter clean && flutter pub get && cd ios && pod install
```

Do not create PRs to change `pubspec.lock` or `Package.resolved` for the stale-cache case.

## Cause 3: the generated Swift package floor is stuck at iOS 13

Xcode reports, for `FlutterGeneratedPluginSwiftPackage`, that `firebase-*` require iOS 15.0 and `c2pa-flutter` / `divine-video-player` require 16.0 "but this target supports 13". The project is not misconfigured: every `IPHONEOS_DEPLOYMENT_TARGET` in `mobile/ios/Runner.xcodeproj/project.pbxproj` and the Podfile `platform` are 16.0. The floor that fails is the `platforms:` line of the generated, gitignored `mobile/ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift`.

Flutter (3.44) writes that manifest at its default `.iOS("13.0")` every time it injects plugins — `flutter pub get`, `flutter analyze`, `flutter test`, and the implicit pub step of most other commands. Only `flutter build ios` and `flutter run` raise it to the project's deployment target afterwards, and that step silently does nothing when `xcodebuild -showBuildSettings` exceeds Flutter's 60-second timeout (a cold machine or a fresh worktree). Building straight from Xcode never raises it.

Fix, from `mobile/`, then verify before opening Xcode:

```bash
flutter build ios --config-only
grep -A1 "platforms:" ios/Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage/Package.swift
```

If the grep still shows `13.0`, run the same command again — the second pass has warm Xcode caches and lands under the timeout. Repeat the two steps after any `flutter pub get`, `flutter analyze` or `flutter test` you run before the next Xcode build.

Do not add a Flutter command to `mobile/pre_build_ios.sh`: it runs as a pre-action of the shared Runner scheme on every Xcode build, so a `flutter pub get` there re-lowered the floor mid-build and made every Xcode build and Profile run fail this way; the script now only syncs CocoaPods. CI patches the generated manifest separately in `codemagic.yaml` before archiving.
