# iOS Build Troubleshooting

When iOS build fails with "Could not resolve package dependencies" and Firebase plugins require different FlutterFire versions (`'X' depends on 'flutterfire' A-firebase-core-swift and 'Y' depends on 'flutterfire' B-firebase-core-swift`), there are two distinct causes. Diagnose which one you have before fixing.

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
