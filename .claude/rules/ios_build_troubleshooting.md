# iOS Build Troubleshooting

When iOS build fails with "Could not resolve package dependencies" and Firebase plugins require different FlutterFire versions, it's a stale Xcode SPM cache, not a code issue.

Fix:

```bash
rm -rf ~/Library/Developer/Xcode/DerivedData
cd mobile/ios && rm -rf Pods Podfile.lock .symlinks
flutter clean && flutter pub get && cd ios && pod install
```

Do not create PRs to change `pubspec.lock` or `Package.resolved` for this.
